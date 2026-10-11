/// 依赖组合根。
/// 集中构造并持有跨页面共享的服务与状态，避免全局可变单例散落各处；
/// 新增服务在这里显式注入，页面不自行创建平台 adapter。
import SwiftUI

@Observable
final class AppEnvironment {
    let themeStore: ThemeStore

    init(themeStore: ThemeStore) {
        self.themeStore = themeStore
    }

    /// 默认装配。后端就绪前固定为显式模拟服务，界面与报告标注"模拟服务"。
    static func makeDefault() -> AppEnvironment {
        AppEnvironment(themeStore: ThemeStore())
    }
}
