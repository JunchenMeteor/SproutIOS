/// 录音-提交-上传链路的纯状态机定义。
/// 职责：集中声明 RecordingState 与 RecordingEvent，
/// 并由 RecordingStateMachine 校验每次转移是否合法。
/// 边界：不依赖 AVFoundation、不做文件与网络 IO，可独立单元测试；
/// 录音文件清理、上传调度、幂等键管理均由调用方按状态语义执行。
/// 副作用：无。
/// 约束：非法转移一律忽略并返回当前状态；confirmed 为终态，只能经 reset 回到 idle；
/// error 的 message 必须是家长可读中文文案。
import Foundation

/// 录音生命周期状态。
enum RecordingState: Equatable {
    /// 空闲，可以开始一段新录音。
    case idle
    /// 录音中；duration 为进入该状态时的秒数快照，实时时长由服务层单独暴露。
    case recording(duration: TimeInterval)
    /// 被来电或音频路由切换中断；recordedSeconds 为已保留的可恢复进度。
    case interrupted(recordedSeconds: TimeInterval)
    /// 录音完成并已转存持久目录；fileID 为 RecordingFileStore 中的稳定文件标识。
    case recorded(fileID: UUID, duration: TimeInterval)
    /// 已提交进入离线队列，等待上传编排。
    case queued
    /// 上传中。
    case uploading
    /// 服务端已确认，本次录音链路结束。
    case confirmed
    /// 出错；message 为家长可读中文文案，retryable 表示是否允许重试。
    case error(message: String, retryable: Bool)
}


/// 驱动状态机的用户与系统事件。
enum RecordingEvent: Equatable {
    /// 用户点击开始；在 recorded 状态下表示重录，旧片段由调用方清理。
    case startTapped
    /// 用户点击结束或到达时长上限自动停止，携带持久化后的文件标识与真实时长。
    case stopTapped(fileID: UUID, duration: TimeInterval)
    /// 系统中断开始（来电、耳机拔出、进后台等），携带已录秒数。
    case interruptionBegan(recordedSeconds: TimeInterval)
    /// 中断结束；shouldResume 为 true 表示用户确认恢复录音。
    case interruptionEnded(shouldResume: Bool)
    /// 录音预览播放结束；仅在 recorded 状态有意义，为原地事件。
    case playbackFinished
    /// 麦克风权限被拒绝。
    case permissionDenied
    /// 磁盘空间不足预检未通过。
    case diskFull
    /// 录制、编码、保存或上传失败，携带家长可读中文文案。
    case failed(String)
    /// 用户提交当前录音，进入离线队列。
    case submitTapped
    /// 上传编排开始上传该队列条目（任务书事件清单无法表达 queued→uploading，故补）。
    case uploadStarted
    /// 服务端确认完成（同上，补此事件表达 uploading→confirmed）。
    case uploadConfirmed
    /// 用户放弃或取消，回到 idle。
    case reset
}


/// 状态转移校验器。合法转移表（未列出的组合一律忽略并返回当前状态）：
/// idle        + startTapped                     → recording(duration: 0)
/// idle        + permissionDenied/diskFull/failed → error(retryable: true)
/// recording   + stopTapped                      → recorded(fileID:duration:)
/// recording   + interruptionBegan               → interrupted
/// recording   + permissionDenied/diskFull/failed → error(retryable: true)
/// interrupted + interruptionEnded(true)         → recording(duration: 已保留秒数)
/// interrupted + interruptionEnded(false)        → interrupted（原地，等待用户决定）
/// interrupted + failed                          → error(retryable: true)
/// interrupted + reset                           → idle（用户放弃）
/// recorded    + submitTapped                    → queued（提交）
/// recorded    + startTapped                     → recording（重录，旧片段由调用方清理）
/// recorded    + playbackFinished                → recorded（原地）
/// recorded    + reset                           → idle（取消）
/// queued      + uploadStarted                   → uploading
/// queued      + reset                           → idle
/// uploading   + uploadConfirmed                 → confirmed
/// uploading   + failed                          → error(retryable: true)
/// error       + reset                           → idle
/// confirmed   + reset                           → idle
struct RecordingStateMachine {
    /// 当前状态，只允许经 handle(_:) 变更。
    private(set) var state: RecordingState

    /// 以 idle 为初始状态。
    init() {
        state = .idle
    }

    /// 处理一个事件并返回处理后的状态；非法转移忽略，返回原状态。
    @discardableResult
    mutating func handle(_ event: RecordingEvent) -> RecordingState {
        switch (state, event) {
        case (.idle, .startTapped), (.recorded, .startTapped):
            state = .recording(duration: 0)
        case (.recording, .stopTapped(let fileID, let duration)):
            state = .recorded(fileID: fileID, duration: duration)
        case (.recording, .interruptionBegan(let seconds)):
            state = .interrupted(recordedSeconds: seconds)
        case (.interrupted, .interruptionEnded(let shouldResume)):
            if shouldResume, case .interrupted(let seconds) = state {
                state = .recording(duration: seconds)
            }
        case (.recorded, .playbackFinished):
            break
        case (.recorded, .submitTapped):
            state = .queued
        case (.queued, .uploadStarted):
            state = .uploading
        case (.uploading, .uploadConfirmed):
            state = .confirmed
        case (_, .reset) where Self.canReset(from: state):
            state = .idle
        case (_, .permissionDenied) where Self.canFail(from: state):
            state = .error(message: Self.permissionDeniedMessage, retryable: true)
        case (_, .diskFull) where Self.canFail(from: state):
            state = .error(message: Self.diskFullMessage, retryable: true)
        case (_, .failed(let message)) where Self.canFail(from: state):
            state = .error(message: message, retryable: true)
        default:
            break
        }
        return state
    }

    /* reset 只允许从 interrupted/recorded/queued/error/confirmed 回到 idle；
     recording 与 uploading 必须先走完各自终态路径，不能直接放弃。 */
    private static func canReset(from state: RecordingState) -> Bool {
        switch state {
        case .interrupted, .recorded, .queued, .error, .confirmed:
            return true
        case .idle, .recording, .uploading:
            return false
        }
    }

    /* 错误转移只允许从 idle（启动即失败）、recording、interrupted、uploading 进入；
     recorded/queued/confirmed/error 下的重复失败事件视为噪音忽略。 */
    private static func canFail(from state: RecordingState) -> Bool {
        switch state {
        case .idle, .recording, .interrupted, .uploading:
            return true
        case .recorded, .queued, .confirmed, .error:
            return false
        }
    }

    private static let permissionDeniedMessage = "麦克风权限未开启，请家长在系统“设置”里允许后重试。"
    private static let diskFullMessage = "设备存储空间不足，请先清理一些空间再录音。"
}
