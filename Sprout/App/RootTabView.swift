/// 根 Tab 导航骨架。
/// 未完成首次设置时全屏托管家长设置流程（ParentSetupView 由 Onboarding 任务提供）；
/// 完成后呈现「今天 / 日历 / 收藏 / 家长」四个 tab，
/// 模拟服务期间在顶部安全区内固定 MockServiceBanner，iPad 上整体按 wideMaxWidth 限宽居中。
import SwiftUI

struct RootTabView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.theme) private var theme

    var body: some View {
        content
            .frame(maxWidth: AppLayout.wideMaxWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.page)
            .safeAreaInset(edge: .top, spacing: 0) { mockBanner }
    }

    @ViewBuilder
    private var content: some View {
        if environment.localStore.hasCompletedOnboarding {
            mainTabs
        } else {
            ParentSetupView()
        }
    }

    private var mainTabs: some View {
        TabView {
            TodayView()
                .tabItem { Label("今天", systemImage: "sun.max") }
            CalendarView()
                .tabItem { Label("日历", systemImage: "calendar") }
            CollectionView()
                .tabItem { Label("收藏", systemImage: "shield") }
            ParentView()
                .tabItem { Label("家长", systemImage: "figure.and.child.holdinghands") }
        }
        .tint(theme.accent)
    }

    @ViewBuilder
    private var mockBanner: some View {
        if environment.isMockBackend {
            MockServiceBanner()
        }
    }
}
