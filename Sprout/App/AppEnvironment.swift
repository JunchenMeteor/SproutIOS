/// 依赖组合根。
/// 集中构造并持有跨页面共享的服务与状态，避免全局可变单例散落各处；
/// 新增服务在这里显式注入，页面不自行创建平台 adapter。
/// 后端就绪前固定装配显式模拟服务（MockBackendService），界面与报告标注"模拟服务"。
import SwiftUI

@Observable
final class AppEnvironment {
    let themeStore: ThemeStore
    let backend: any BackendService
    let recorder: AudioRecorderService
    let player: AudioPlayerService
    let localStore: LocalStore
    let recordingFiles: RecordingFileStore
    let offlineQueue: OfflineQueue
    /// 当前后端是否为模拟服务。为 true 时界面必须持续标注"模拟服务"。
    let isMockBackend: Bool

    init(
        themeStore: ThemeStore,
        backend: any BackendService,
        recorder: AudioRecorderService,
        player: AudioPlayerService,
        localStore: LocalStore,
        recordingFiles: RecordingFileStore,
        offlineQueue: OfflineQueue,
        isMockBackend: Bool
    ) {
        self.themeStore = themeStore
        self.backend = backend
        self.recorder = recorder
        self.player = player
        self.localStore = localStore
        self.recordingFiles = recordingFiles
        self.offlineQueue = offlineQueue
        self.isMockBackend = isMockBackend
    }

    /// 默认装配。持久化目录创建失败时回退临时目录，保证应用可启动并暴露问题，
    /// 不因存储初始化失败闪退；真实后端就绪后在此替换 backend 装配。
    /// @MainActor：录音/播放 adapter 是主线程隔离类型，组合根须在主 actor 创建。
    @MainActor
    static func makeDefault() -> AppEnvironment {
        let stores = makeStores()
        return AppEnvironment(
            themeStore: ThemeStore(),
            backend: MockBackendService(),
            recorder: AudioRecorderService(fileStore: stores.recordingFiles),
            player: AudioPlayerService(),
            localStore: stores.localStore,
            recordingFiles: stores.recordingFiles,
            offlineQueue: stores.offlineQueue,
            isMockBackend: true
        )
    }

    /* 持久化三件套创建；默认目录失败时回退临时目录，再失败才视为不可恢复。
       用显式 return 而不是在 do/catch 双侧给 let 赋值。 */
    private static func makeStores() -> (
        recordingFiles: RecordingFileStore, localStore: LocalStore, offlineQueue: OfflineQueue
    ) {
        do {
            return (try RecordingFileStore(), try LocalStore(), try OfflineQueue())
        } catch {
            let fallback = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent("SproutFallback-\(UUID().uuidString)", isDirectory: true)
            do {
                return (
                    try RecordingFileStore(rootDirectory: fallback
                        .appendingPathComponent("Recordings", isDirectory: true)),
                    try LocalStore(directory: fallback
                        .appendingPathComponent("LocalState", isDirectory: true)),
                    try OfflineQueue(directory: fallback
                        .appendingPathComponent("Queue", isDirectory: true))
                )
            } catch {
                preconditionFailure("持久化目录与临时回退均不可用: \(error)")
            }
        }
    }
}
