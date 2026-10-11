/// 根容器视图。
/// 负责把系统外观与主题选择解析为当前 ThemeTokens 并注入环境，
/// 使已打开的弹层/toast 等订阅同一主题并即时切换。
/// 页面骨架在 Features 下逐步替换本占位内容。
import SwiftUI

struct RootContainerView: View {
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var systemScheme

    var body: some View {
        let theme = themeStore.currentTheme(systemScheme: systemScheme)
        Text("Sprout")
            .font(AppFont.title)
            .foregroundStyle(theme.textPrimary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.page)
            .environment(\.theme, theme)
    }
}
