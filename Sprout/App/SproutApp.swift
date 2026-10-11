/// 应用入口与组合根。
/// 只装配依赖与根视图；业务用例、平台 adapter 与持久化由 AppEnvironment 注入。
/// 后端未就绪期间使用显式标注的模拟服务（Debug），不自称真实链路。
import SwiftUI

@main
struct SproutApp: App {
    /// 组合根在主 actor 创建（录音/播放 adapter 的隔离要求）；App 初始化在主线程运行。
    @State private var environment: AppEnvironment

    init() {
        _environment = State(wrappedValue: MainActor.assumeIsolated {
            AppEnvironment.makeDefault()
        })
    }

    var body: some Scene {
        WindowGroup {
            RootContainerView()
                .environment(environment)
                .environment(environment.themeStore)
        }
    }
}
