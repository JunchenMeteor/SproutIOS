/// 应用入口与组合根。
/// 只装配依赖与根视图；业务用例、平台 adapter 与持久化由 AppEnvironment 注入。
/// 后端未就绪期间使用显式标注的模拟服务（Debug），不自称真实链路。
import SwiftUI

@main
struct SproutApp: App {
    @State private var environment = AppEnvironment.makeDefault()

    var body: some Scene {
        WindowGroup {
            RootContainerView()
                .environment(environment)
                .environment(environment.themeStore)
        }
    }
}
