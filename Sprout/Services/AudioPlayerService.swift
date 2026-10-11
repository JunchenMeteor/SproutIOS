/// 播放平台 adapter：封装 AVAudioPlayer 的整文件回放。
/// 职责：播放前把 AVAudioSession 切到 .playback，播完或停止后 deactivate 并
/// 以 .notifyOthersOnDeactivation 让系统恢复其他音频；暴露播放进度供 UI 绑定。
/// 边界：与录音的互斥由调用方编排（开始播放前应先停 AudioRecorderService）；
/// 本类只保证自身播放期间会话为 playback，不感知录音状态机与上传链路。
/// 副作用：持有 AVAudioPlayer 与进度 Timer，修改全局 AVAudioSession 类别。
/// 约束：播放不存在或已删除的文件进入中文错误状态，不崩溃、不向 UI 层抛错；
/// currentTime 由进度 Timer 从 player.currentTime 刷新，不使用假进度。
import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class AudioPlayerService: NSObject {
    /// 是否正在播放。
    private(set) var isPlaying = false
    /// 当前播放位置（秒），播放中由进度 Timer 刷新。
    private(set) var currentTime: TimeInterval = 0
    /// 当前文件总时长（秒），未加载时为 0。
    private(set) var duration: TimeInterval = 0
    /// 最近一次错误的中文文案；nil 表示无错误。
    private(set) var playbackError: String?

    private static let progressTimerInterval: TimeInterval = 0.1

    private var player: AVAudioPlayer?
    private var progressTimer: Timer?

    override init() {
        super.init()
    }

    isolated deinit {
        progressTimer?.invalidate()
        player?.stop()
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            /* deinit 无法抛出：失败仅说明会话已被系统回收，无需处理。 */
        }
    }

    /// 播放指定文件；自动停止上一段播放并把会话切到 .playback，播完自动恢复。
    func play(url: URL) {
        stop()
        playbackError = nil
        guard FileManager.default.fileExists(atPath: url.path) else {
            playbackError = "录音文件不存在或已被删除。"
            return
        }
        do {
            try configurePlaybackSession()
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.delegate = self
            newPlayer.prepareToPlay()
            guard newPlayer.play() else {
                playbackError = "播放启动失败，请重试。"
                return
            }
            player = newPlayer
            duration = newPlayer.duration
            currentTime = 0
            isPlaying = true
            startProgressTimer()
        } catch {
            playbackError = "音频加载失败，文件可能已损坏。"
        }
    }

    /// 停止播放、清空进度并恢复音频会话。
    func stop() {
        stopProgressTimer()
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        deactivateSession()
    }

    private func configurePlaybackSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true, options: [])
    }

    /* 播放结束让出音频会话并通知其他 App 恢复；
     deactivate 失败不阻断 UI 状态收敛，会话最终由系统策略回收。 */
    private func deactivateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch { /* 见上方块注释 */ }
    }

    private func startProgressTimer() {
        stopProgressTimer()
        let interval = Self.progressTimerInterval
        progressTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.progressTimerFired() }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func progressTimerFired() {
        guard let player, isPlaying else { return }
        currentTime = player.currentTime
    }
}


extension AudioPlayerService: AVAudioPlayerDelegate {
    /// 播放完成：收敛状态并让出会话；解码失败给出中文错误而不是静默。
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stopProgressTimer()
            self.isPlaying = false
            self.currentTime = self.duration
            self.deactivateSession()
            if !flag {
                self.playbackError = "播放中断，文件可能已损坏。"
            }
        }
    }
}
