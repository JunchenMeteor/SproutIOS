/// 根容器视图。
/// 负责把系统外观与主题选择解析为当前 ThemeTokens 并注入环境，
/// 使已打开的弹层/toast 等订阅同一主题并即时切换；
/// 业务导航骨架为 RootTabView（首次设置分流在其内部）。
import SwiftUI

struct RootContainerView: View {
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var systemScheme

    var body: some View {
        let theme = themeStore.currentTheme(systemScheme: systemScheme)
        RootTabView()
            .background(theme.page)
            .environment(\.theme, theme)
            .preferredColorScheme(preferredScheme)
    }

    /// 显式 light/dark 模式时锁定应用外观；system 时跟随设备。
    private var preferredScheme: ColorScheme? {
        switch themeStore.mode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
