/// 今日入口页。
/// 三个日模式大选择卡、新课建议确认卡与今日计划列表；
/// 只组合 TodayViewModel 与组件，不含网络与存储细节。
import SwiftUI
import UIKit


/// 今日页。顶部在模拟服务模式下展示 MockServiceBanner。
struct TodayView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.theme) private var theme
    @State private var viewModel: TodayViewModel?
    @State private var isPracticePresented = false

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel: viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(theme.page)
        .navigationTitle("今天")
        .navigationDestination(isPresented: $isPracticePresented) {
            if let plan = viewModel?.plan {
                PracticeView(plan: plan)
            }
        }
        .task { await prepareViewModel() }
    }

    private func prepareViewModel() async {
        guard viewModel == nil else { return }
        let created = TodayViewModel(backend: environment.backend, localStore: environment.localStore)
        viewModel = created
        await created.load()
    }

    private func content(viewModel: TodayViewModel) -> some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                if environment.isMockBackend {
                    MockServiceBanner()
                }
                if viewModel.isLoading && viewModel.plan == nil {
                    ProgressView("正在准备今天的内容…")
                } else if let message = viewModel.errorMessage, viewModel.plan == nil {
                    errorCard(message: message) {
                        Task { await viewModel.load() }
                    }
                } else if let plan = viewModel.plan {
                    planSection(viewModel: viewModel, plan: plan)
                } else {
                    modeSection(viewModel: viewModel)
                    if viewModel.selectedDayMode == .new {
                        newLessonCard(viewModel: viewModel)
                    }
                }
            }
            .padding(AppSpacing.large)
            .frame(maxWidth: AppLayout.readingMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .toastBanner(toastBinding(of: viewModel))
    }

    private func modeSection(viewModel: TodayViewModel) -> some View {
        VStack(spacing: AppSpacing.medium) {
            dayModeCard(viewModel: viewModel, mode: .new, icon: "sparkles",
                title: "学了新内容", subtitle: "今天上课学了新课文")
            dayModeCard(viewModel: viewModel, mode: .review, icon: "arrow.clockwise",
                title: "复习旧内容", subtitle: "巩固之前学过的课文")
            dayModeCard(viewModel: viewModel, mode: .unknown, icon: "questionmark.circle",
                title: "没上课或不清楚", subtitle: "今天没上课，保持当前进度")
        }
    }

    private func dayModeCard(
        viewModel: TodayViewModel,
        mode: DayMode,
        icon: String,
        title: String,
        subtitle: String
    ) -> some View {
        CardContainer {
            VStack(spacing: AppSpacing.medium) {
                HStack(spacing: AppSpacing.medium) {
                    Image(systemName: icon)
                        .font(AppFont.title)
                        .foregroundStyle(theme.accent)
                        .frame(width: AppLayout.minTouchTarget, height: AppLayout.minTouchTarget)
                    VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
                        Text(title)
                            .font(AppFont.section)
                            .foregroundStyle(theme.textPrimary)
                        Text(subtitle)
                            .font(AppFont.helper)
                            .foregroundStyle(theme.textSecondary)
                    }
                    Spacer(minLength: AppSpacing.small)
                }
                AppButton("就选这个", kind: .secondary, isLoading: viewModel.isCreatingPlan) {
                    viewModel.selectDayMode(mode)
                }
            }
        }
    }

    /* 新课建议：家长可确认或修改课次，确认后才推进进度。 */
    private func newLessonCard(viewModel: TodayViewModel) -> some View {
        @Bindable var bindable = viewModel
        return CardContainer {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Label("建议下一课", systemImage: "bookmark")
                    .font(AppFont.section)
                    .foregroundStyle(theme.textPrimary)
                Text("家长可确认或修改课次，确认后才会推进课程进度。")
                    .font(AppFont.helper)
                    .foregroundStyle(theme.textSecondary)
                AppFormField(
                    label: "下一课",
                    text: $bindable.editedNewLessonId,
                    placeholder: "课次编号",
                    isRequired: true,
                    error: nil,
                    keyboardType: .numberPad,
                    onSubmit: {}
                )
                AppButton("家长确认，开始今天的新课", isLoading: viewModel.isCreatingPlan) {
                    viewModel.confirmNewLessonAndCreatePlan()
                }
            }
        }
    }

    private func planSection(viewModel: TodayViewModel, plan: Plan) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text("今日计划")
                .font(AppFont.section)
                .foregroundStyle(theme.textPrimary)
            if viewModel.isOfflineSaved {
                Label("已在这台设备保存，联网后确认", systemImage: "arrow.triangle.2.circlepath")
                    .font(AppFont.helper)
                    .foregroundStyle(theme.info.foreground)
            }
            CardContainer {
                VStack(spacing: AppSpacing.small) {
                    ForEach(plan.items, id: \.id) { item in
                        planItemRow(item: item)
                    }
                }
            }
            AppButton("开始练习") {
                isPracticePresented = true
            }
        }
    }

    private func planItemRow(item: PlanItem) -> some View {
        HStack(spacing: AppSpacing.small) {
            Image(systemName: item.type == .repeat ? "waveform" : "bubble.left.and.bubble.right")
                .foregroundStyle(theme.iconPrimary)
            Text(item.type == .repeat ? "跟读" : "自由表达")
                .font(AppFont.body)
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Text("约 \(item.suggestedSeconds) 秒")
                .font(AppFont.helper)
                .foregroundStyle(theme.textTertiary)
        }
    }

    private func errorCard(message: String, onRetry: @escaping () -> Void) -> some View {
        CardContainer {
            VStack(spacing: AppSpacing.medium) {
                Text(message)
                    .font(AppFont.body)
                    .foregroundStyle(theme.error.foreground)
                AppButton("重试", kind: .secondary, action: onRetry)
            }
        }
    }

    private func toastBinding(of viewModel: TodayViewModel) -> Binding<ToastMessage?> {
        Binding(
            get: { viewModel.toast },
            set: { viewModel.toast = $0 }
        )
    }
}
