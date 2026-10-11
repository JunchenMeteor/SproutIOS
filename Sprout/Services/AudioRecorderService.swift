/// 录音平台 adapter：封装 AVAudioSession 与 AVAudioRecorder 的整文件录制流程。
/// 职责：麦克风权限申请（iOS 17 AVAudioApplication API）、.record 会话配置、
/// AAC/M4A 单声道 44.1kHz 录制到临时目录、完成后立即经 RecordingFileStore 转存持久目录、
/// 中断/路由切换/进后台处理、磁盘空间预检、时长上限自动停止。
/// 边界：不做上传编排与离线队列（由上层调用 mark* 系列推进状态机）；
/// 与 AudioPlayerService 的互斥由调用方编排（播放前先停录音），本类不感知播放器。
/// 副作用：持有 AVAudioRecorder 与 Timer、注册系统通知、写临时与持久音频文件。
/// 约束：仅 iOS 17+；时长一律取自 recorder.currentTime，禁止假波形/假时长；
/// 中断结束后不自动恢复录音，必须由用户再次点击确认；损坏片段不自动提交。
import AVFoundation
import Foundation
import Observation
import UIKit

/// 录音启动阶段的可预期错误，userMessage 为家长可读中文文案。
private enum RecorderStartError: Error {
    case diskFull
    case sessionConfigurationFailed
    case recorderCreationFailed

    var userMessage: String {
        switch self {
        case .diskFull: return "设备存储空间不足，请先清理一些空间再录音。"
        case .sessionConfigurationFailed: return "音频设备配置失败，请重试。"
        case .recorderCreationFailed: return "录音初始化失败，请重试。"
        }
    }
}


/// 录音链路对全局 AVAudioSession 的配置与让出。
private enum RecordingAudioSession {
    /// 配置 .record 会话并激活；失败抛 RecorderStartError.sessionConfigurationFailed。
    static func activateForRecording() throws {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default, options: [.allowBluetoothHFP])
            try session.setActive(true, options: [])
        } catch {
            throw RecorderStartError.sessionConfigurationFailed
        }
    }

    /* 录音链路结束时让出音频会话并通知其他 App 恢复；
     deactivate 失败不阻断状态推进，会话最终由系统策略回收。 */
    static func deactivate() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch { /* 见上方块注释 */ }
    }
}


/// 会话中断、路由切换与进后台通知的订阅封装；解析 userInfo 后转成语义事件回调。
private final class SessionNotificationObserver {
    /// 语义化后的通知事件。
    enum Event {
        case interruptionBegan
        case interruptionEnded
        case routeDeviceLost
        case enteredBackground
    }

    private var tokens: [NSObjectProtocol] = []

    init(handler: @escaping (Event) -> Void) {
        let center = NotificationCenter.default
        tokens = [
            center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { note in
                guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
                if type == .began { handler(.interruptionBegan) }
                if type == .ended { handler(.interruptionEnded) }
            },
            center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { note in
                guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                      AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
                handler(.routeDeviceLost)
            },
            center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
                handler(.enteredBackground)
            }
        ]
    }

    deinit {
        tokens.forEach { NotificationCenter.default.removeObserver($0) }
    }
}


/// AAC/M4A 单声道 44.1kHz 录音参数。
private func recorderSettings() -> [String: Any] {
    [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 44_100,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]
}


/* 用 volumeAvailableCapacityForImportantUsage 预检临时目录所在卷；
 容量读取失败不阻塞录制，真实写入失败会经编码错误回调或转存失败进入 error。 */
private func assertSufficientDiskSpace(minimumFreeBytes: Int64) throws {
    let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    do {
        let values = try tempDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        let freeBytes = values.volumeAvailableCapacityForImportantUsage ?? 0
        if freeBytes < minimumFreeBytes {
            throw RecorderStartError.diskFull
        }
    } catch let error as RecorderStartError {
        throw error
    } catch {
        return
    }
}


@MainActor
@Observable
final class AudioRecorderService: NSObject {
    /// 状态机驱动的当前状态，只允许经 RecordingStateMachine 变更。
    private(set) var state: RecordingState = .idle
    /// 录音中的实时秒数，来自 recorder.currentTime；非录音状态为 0。
    private(set) var elapsedSeconds: TimeInterval = 0
    private static let durationTimerInterval: TimeInterval = 0.1
    private let fileStore: RecordingFileStore
    private let maxDuration: TimeInterval
    private let minimumFreeBytes: Int64
    private var sessionObserver: SessionNotificationObserver?
    private var machine = RecordingStateMachine()
    private var recorder: AVAudioRecorder?
    private var durationTimer: Timer?
    private var currentFileID: UUID?

    /// 注入文件存储与参数；maxDuration 默认 60 秒，到达后自动走与 stopRecording 等价的路径。
    init(fileStore: RecordingFileStore, maxDuration: TimeInterval = 60, minimumFreeBytes: Int64 = 20 * 1024 * 1024) {
        self.fileStore = fileStore
        self.maxDuration = maxDuration
        self.minimumFreeBytes = minimumFreeBytes
        super.init()
        sessionObserver = SessionNotificationObserver { [weak self] event in
            Task { @MainActor in self?.handleSessionEvent(event) }
        }
    }

    isolated deinit {
        durationTimer?.invalidate()
        recorder?.stop()
    }

    /// 开始录音；interrupted 状态下表示用户确认恢复中断的录音，recorded 状态下表示重录。
    func startRecording() {
        if case .interrupted = state {
            resumeInterruptedRecording()
            return
        }
        let replacedFileID: UUID?
        switch state {
        case .idle: replacedFileID = nil
        case .recorded(let oldID, _): replacedFileID = oldID
        default: return
        }
        Task { await self.beginRecording(replacing: replacedFileID) }
    }

    /// 结束录音并立即把临时文件转存持久目录；转存失败进入 error，不自动提交。
    func stopRecording() {
        guard case .recording = state, let activeRecorder = recorder, let fileID = currentFileID else { return }
        stopDurationTimer()
        let duration = activeRecorder.currentTime
        /* 先 stop 确保文件完整关闭，再同卷原子 move；
         损坏或写失败的片段不进入提交链路。 */
        activeRecorder.stop()
        RecordingAudioSession.deactivate()
        recorder = nil
        currentFileID = nil
        do {
            _ = try fileStore.persistTemporaryRecording(from: activeRecorder.url, id: fileID)
            state = machine.handle(.stopTapped(fileID: fileID, duration: duration))
        } catch {
            state = machine.handle(.failed("录音保存失败，请重试。"))
        }
    }

    /// 放弃当前录音：删除已持久化片段或中断残留的临时文件，状态回到 idle；
    /// queued 之后的取消由上传编排负责，不走本方法。
    func discardRecording() {
        var persistedID: UUID?
        if case .recorded(let fileID, _) = state { persistedID = fileID }
        let tempURL = recorder?.url
        recorder?.stop()
        recorder = nil
        currentFileID = nil
        stopDurationTimer()
        RecordingAudioSession.deactivate()
        cleanupArtifacts(persistedID: persistedID, tempURL: tempURL)
        state = machine.handle(.reset)
    }

    /// 上传编排：条目已入离线队列（recorded → queued）。
    func markQueued() { state = machine.handle(.submitTapped) }

    /// 上传编排：开始上传该条目（queued → uploading）。
    func markUploading() { state = machine.handle(.uploadStarted) }

    /// 上传编排：服务端已确认（uploading → confirmed）。
    func markConfirmed() { state = machine.handle(.uploadConfirmed) }

    /// 上传编排：失败进入 error，message 须为家长可读中文文案。
    func markFailed(_ message: String) { state = machine.handle(.failed(message)) }

    private func beginRecording(replacing replacedFileID: UUID?) async {
        guard await AVAudioApplication.requestRecordPermission() else {
            state = machine.handle(.permissionDenied)
            return
        }
        do {
            try assertSufficientDiskSpace(minimumFreeBytes: minimumFreeBytes)
            try RecordingAudioSession.activateForRecording()
            try makeRecorderAndStart()
            state = machine.handle(.startTapped)
            startDurationTimer()
            cleanupArtifacts(persistedID: replacedFileID, tempURL: nil)
        } catch let error as RecorderStartError {
            state = machine.handle(.failed(error.userMessage))
        } catch {
            state = machine.handle(.failed("录音启动失败，请重试。"))
        }
    }

    private func makeRecorderAndStart() throws {
        let fileID = UUID()
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(fileID.uuidString)
            .appendingPathExtension(RecordingFileStore.fileExtension)
        do {
            let newRecorder = try AVAudioRecorder(url: tempURL, settings: recorderSettings())
            newRecorder.delegate = self
            guard newRecorder.record() else { throw RecorderStartError.recorderCreationFailed }
            recorder = newRecorder
            currentFileID = fileID
            elapsedSeconds = 0
        } catch {
            throw RecorderStartError.recorderCreationFailed
        }
    }

    /* 中断结束后不自动恢复：保持 interrupted，由用户再次点击（startRecording）
     确认恢复；恢复时沿用同一临时文件继续追加，保留已录进度。 */
    private func resumeInterruptedRecording() {
        guard let activeRecorder = recorder else {
            state = machine.handle(.failed("中断的录音无法恢复，请重新开始。"))
            return
        }
        do {
            try AVAudioSession.sharedInstance().setActive(true, options: [])
            guard activeRecorder.record() else { throw RecorderStartError.recorderCreationFailed }
            state = machine.handle(.interruptionEnded(shouldResume: true))
            startDurationTimer()
        } catch {
            state = machine.handle(.failed("录音恢复失败，请重新开始。"))
        }
    }

    private func pauseForInterruption() {
        guard case .recording = state, let activeRecorder = recorder else { return }
        let seconds = activeRecorder.currentTime
        activeRecorder.pause()
        stopDurationTimer()
        state = machine.handle(.interruptionBegan(recordedSeconds: seconds))
    }

    /* 中断开始、路由设备丢失与进后台都按中断处理：暂停并保留已录进度；
     中断结束不自动恢复，等待用户确认。 */
    private func handleSessionEvent(_ event: SessionNotificationObserver.Event) {
        switch event {
        case .interruptionBegan, .routeDeviceLost, .enteredBackground:
            pauseForInterruption()
        case .interruptionEnded:
            state = machine.handle(.interruptionEnded(shouldResume: false))
        }
    }

    private func startDurationTimer() {
        stopDurationTimer()
        let interval = Self.durationTimerInterval
        durationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.durationTimerFired() }
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }

    /* 实时时长只取自 recorder.currentTime；到达上限自动走与手动停止完全相同的路径。 */
    private func durationTimerFired() {
        guard let activeRecorder = recorder, case .recording = state else { return }
        elapsedSeconds = activeRecorder.currentTime
        if elapsedSeconds >= maxDuration {
            stopRecording()
        }
    }

    /* 清理失败不阻断主流程：持久残留由 RecordingFileStore.discardOrphans 按引用集合兜底，
     临时残留由系统定期清空临时目录兜底。 */
    private func cleanupArtifacts(persistedID: UUID?, tempURL: URL?) {
        if let persistedID {
            do { try fileStore.delete(id: persistedID) } catch { /* 兜底见块注释 */ }
        }
        if let tempURL {
            do { try FileManager.default.removeItem(at: tempURL) } catch { /* 兜底见块注释 */ }
        }
    }
}


extension AudioRecorderService: AVAudioRecorderDelegate {
    /// 编码中途失败：进入 error 并提示重录，损坏片段不自动提交。
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            self.state = self.machine.handle(.failed("录音编码失败，请重新录制。"))
        }
    }
}
