/// 日历页。
/// 组合 CalendarGrid 与统计条：左右切换月份、点选有记录的日期打开打卡详情 sheet；
/// 数据来源为 BackendService.listCheckIns（当前为模拟服务），含 loading/empty/error 三态与重试。
import SwiftUI

/// 打卡详情 sheet 的路由载荷。
private struct CheckInRoute: Identifiable {
    let id: String
}


struct CalendarView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.theme) private var theme
    @State private var viewModel: CalendarViewModel?
    @State private var selectedRoute: CheckInRoute?

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.medium) {
                header
                content
            }
            .padding(AppSpacing.medium)
        }
        .frame(maxWidth: AppLayout.readingMaxWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.page)
        .task { await prepareIfNeeded() }
        .sheet(item: $selectedRoute) { route in
            CheckInDetailView(checkInId: route.id)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let viewModel {
            if let message = viewModel.errorMessage {
                errorView(message)
            } else {
                loadedView(viewModel)
            }
        } else {
            ProgressView("加载中…")
                .padding(AppSpacing.xLarge)
        }
    }

    private var header: some View {
        HStack {
            monthButton(title: "上个月", systemImage: "chevron.left", offset: -1)
            Spacer()
            Text(viewModel?.monthTitle ?? "")
                .font(AppFont.section)
                .foregroundStyle(theme.textPrimary)
            Spacer()
            monthButton(title: "下个月", systemImage: "chevron.right", offset: 1)
        }
    }

    private func monthButton(title: String, systemImage: String, offset: Int) -> some View {
        Button {
            Task { await viewModel?.shiftMonth(by: offset) }
        } label: {
            Image(systemName: systemImage)
                .foregroundStyle(theme.iconPrimary)
                .frame(minWidth: AppLayout.minTouchTarget, minHeight: AppLayout.minTouchTarget)
        }
        .accessibilityLabel(title)
    }

    private func loadedView(_ viewModel: CalendarViewModel) -> some View {
        VStack(spacing: AppSpacing.medium) {
            statsBar(viewModel)
            if viewModel.isLoading {
                ProgressView("加载中…")
                    .padding(AppSpacing.large)
            } else {
                grid(viewModel)
                if viewModel.monthCompletedCount == 0 {
                    Text("本月还没有打卡记录，回到「今天」完成第一次打卡吧")
                        .font(AppFont.helper)
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
    }

    private func statsBar(_ viewModel: CalendarViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
            Text("本月打卡 \(viewModel.monthCompletedCount) 天 · 本月记录 \(viewModel.monthRecordCount) 条")
                .font(AppFont.body)
                .foregroundStyle(theme.textPrimary)
            Text("数据来自模拟服务；连续/历史最长统计待真实统计接口提供")
                .font(AppFont.helper)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func grid(_ viewModel: CalendarViewModel) -> some View {
        CalendarGrid(month: viewModel.month, days: viewModel.days) { day in
            guard day.isInMonth, let checkInId = viewModel.checkInId(for: day.date) else { return }
            selectedRoute = CheckInRoute(id: checkInId)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: AppSpacing.medium) {
            Text(message)
                .font(AppFont.body)
                .foregroundStyle(theme.error.foreground)
            AppButton("重试", kind: .primary, isLoading: false, isEnabled: true) {
                Task { await viewModel?.load() }
            }
        }
        .padding(AppSpacing.large)
    }

    private func prepareIfNeeded() async {
        guard viewModel == nil else { return }
        let model = CalendarViewModel(backend: environment.backend)
        viewModel = model
        await model.load()
    }
}
