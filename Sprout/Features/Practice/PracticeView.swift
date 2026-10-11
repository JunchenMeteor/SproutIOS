/// 练习流程页。
/// 当前题卡片、录音控件、提交与跳过、反馈卡与完成打卡入口；
/// 只组合 PracticeViewModel 与组件，不含网络与存储细节。
import SwiftUI


/// 界面反馈内容：状态、儿童提示、鼓励语与家长细节；不含分数。
struct FeedbackContent {
    let state: FeedbackState
    let childTip: String
    let encouragement: String
    let parentDetails: String?

    /// 初始与重置态。
    static let pending = FeedbackContent(state: .pending, childTip: "", encouragement: "", parentDetails: nil)
    /// 轮询超时：不阻塞流程，明确不确定。
    static let timeout = FeedbackContent(state: .uncertain, childTip: "点评还没准备好",
        encouragement: "先练下一题，稍后再看", parentDetails: nil)
    /// 评测请求失败，可重试。
    static let requestFailed = FeedbackContent(
        state: .error(message: "点评加载失败", retryable: true),
        childTip: "点评加载失败",
        encouragement: "稍后再试一次",
        parentDetails: nil
    )
    /// 转写不清，明确不确定。
    static let unclear = FeedbackContent(state: .uncertain, childTip: "这次没有听太清楚",
        encouragement: "再试一次会更好！", parentDetails: nil)
    /// 题型暂不支持评测，不显示分数。
    static let unsupported = FeedbackContent(state: .uncertain, childTip: "这个题型暂不支持评测",
        encouragement: "多听多练就很棒！", parentDetails: nil)
}


/// 评测轮询与呈现映射：最多 10 次、间隔取 nextPollAfterMs（默认 1500ms）、取消感知。
/// 全部组件缺席或跳过表示暂不支持评测，转写质量不足或需复核映射为不确定，均不产出分数。
struct EvaluationPoller {
    let backend: any BackendService

    /// 轮询至终态反馈；超时或取消返回不确定内容，不阻塞练习流程。
    func poll(jobId: String) async -> FeedbackContent {
        var remaining = 10
        var delayMs = 1500
        while remaining > 0, !Task.isCancelled {
            do {
                let job = try await backend.fetchEvaluation(jobId: jobId)
                if let content = Self.content(for: job) { return content }
                delayMs = job.nextPollAfterMs ?? 1500
                try await Task.sleep(for: .milliseconds(delayMs))
            } catch is CancellationError {
                break
            } catch {
                guard !Task.isCancelled else { break }
                return .requestFailed
            }
            remaining -= 1
        }
        return .timeout
    }

    /* 仅终态返回反馈内容；进行中返回 nil 继续轮询。 */
    private static func content(for job: EvaluationJob) -> FeedbackContent? {
        switch job.status {
        case .succeeded:
            return succeededContent(for: job)
        case .partial:
            return FeedbackContent(state: .partial, childTip: job.feedback?.childTip ?? "这次只评出了一部分",
                encouragement: job.feedback?.encouragement ?? "继续加油！", parentDetails: job.feedback?.parentDetails)
        case .failed, .cancelled:
            return .requestFailed
        default:
            return nil
        }
    }

    /* 组件缺席不算失败；全部缺席或全部 skipped 视为暂不支持；stt 质量不足或需复核为不确定。 */
    private static func succeededContent(for job: EvaluationJob) -> FeedbackContent {
        let present = [job.components.stt, job.components.grammar, job.components.pronunciation]
            .compactMap { $0 }
        guard !present.isEmpty, !present.allSatisfy({ $0.status == .skipped }) else {
            return .unsupported
        }
        if let quality = job.components.stt?.sttResult?.quality,
           quality == .insufficient || quality == .needsReview {
            return .unclear
        }
        guard let feedback = job.feedback else { return .unclear }
        return FeedbackContent(state: .ready, childTip: feedback.childTip,
            encouragement: feedback.encouragement, parentDetails: feedback.parentDetails)
    }
}


/// 练习页。完成打卡成功后导航到完成页。
struct PracticeView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PracticeViewModel?

    let plan: Plan

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
        .navigationTitle("练习")
        .navigationBarBackButtonHidden(viewModel?.showCompletion ?? false)
        .navigationDestination(isPresented: completionBinding) {
            completionView
        }
        .task { prepareViewModel() }
    }

    private func prepareViewModel() {
        guard viewModel == nil else { return }
        viewModel = PracticeViewModel(plan: plan, environment: environment)
    }

    private func content(viewModel: PracticeViewModel) -> some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                if environment.isMockBackend {
                    MockServiceBanner()
                }
                progressHeader(viewModel: viewModel)
                if let item = viewModel.currentItem {
                    itemCard(item: item)
                    recorderSection(viewModel: viewModel)
                    feedbackSection(viewModel: viewModel)
                    actionSection(viewModel: viewModel, item: item)
                }
                if viewModel.canCheckIn {
                    AppButton("完成打卡", isLoading: viewModel.isCheckingIn) {
                        Task { await viewModel.completePlan() }
                    }
                }
            }
            .padding(AppSpacing.large)
            .frame(maxWidth: AppLayout.readingMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .toastBanner(toastBinding(of: viewModel))
    }

    private func progressHeader(viewModel: PracticeViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            Text("第 \(min(viewModel.currentItemIndex + 1, plan.items.count)) 题 · 共 \(plan.items.count) 题")
                .font(AppFont.helper)
                .foregroundStyle(theme.progressLabel)
            progressBar(fraction: settledFraction(viewModel: viewModel))
        }
    }

    private func progressBar(fraction: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.progressTrack)
                Capsule()
                    .fill(theme.progressFill)
                    .frame(width: proxy.size.width * fraction)
            }
        }
        .frame(height: AppSpacing.xSmall)
    }

    private func settledFraction(viewModel: PracticeViewModel) -> Double {
        guard !plan.items.isEmpty else { return 0 }
        let settled = viewModel.completedItemIds.count + viewModel.skipReasons.count
        return min(Double(settled) / Double(plan.items.count), 1)
    }

    private func itemCard(item: PlanItem) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                typeBadge(item: item)
                if let reference = item.referenceText {
                    Text(reference)
                        .font(AppFont.english)
                        .foregroundStyle(theme.textPrimary)
                } else {
                    Text(item.prompt)
                        .font(AppFont.body)
                        .foregroundStyle(theme.textPrimary)
                }
                exampleAudioHint(item: item)
            }
        }
    }

    private func typeBadge(item: PlanItem) -> some View {
        Label(
            item.type == .repeat ? "跟读" : "自由表达",
            systemImage: item.type == .repeat ? "waveform" : "bubble.left.and.bubble.right"
        )
        .font(AppFont.helper)
        .foregroundStyle(theme.accent)
    }

    /* 示范音频首版仅支持本地资源；无本地音频时禁用并提示，不假装可播放。 */
    @ViewBuilder
    private func exampleAudioHint(item: PlanItem) -> some View {
        if item.exampleAudioId != nil {
            Label("示范音频暂未就绪", systemImage: "speaker.wave.2")
                .font(AppFont.helper)
                .foregroundStyle(theme.disabledForeground)
        }
    }

    private func recorderSection(viewModel: PracticeViewModel) -> some View {
        VStack(spacing: AppSpacing.small) {
            RecorderControl(
                state: viewModel.recorderControlState,
                isPlaybackAvailable: viewModel.canSubmit,
                onRecord: { viewModel.onRecord() },
                onStop: { viewModel.onStop() },
                onPlay: { viewModel.onPlay() },
                onDiscard: { viewModel.onDiscard() }
            )
            AppButton("提交这道题", isLoading: viewModel.isSubmitting, isEnabled: viewModel.canSubmit) {
                Task { await viewModel.submitCurrentItem() }
            }
        }
    }

    private func feedbackSection(viewModel: PracticeViewModel) -> some View {
        @Bindable var bindable = viewModel
        return Group {
            if viewModel.feedback.state != .pending {
                FeedbackCard(
                    state: viewModel.feedback.state,
                    childTip: viewModel.feedback.childTip,
                    encouragement: viewModel.feedback.encouragement,
                    parentDetails: viewModel.feedback.parentDetails,
                    onRetry: {
                        Task { await viewModel.submitCurrentItem() }
                    },
                    isParentExpanded: $bindable.isParentExpanded
                )
            }
        }
    }

    private func actionSection(viewModel: PracticeViewModel, item: PlanItem) -> some View {
        HStack(spacing: AppSpacing.medium) {
            if !viewModel.isSettled(item.id), !plan.completionPolicy.allowedSkipReasons.isEmpty {
                skipMenu(viewModel: viewModel)
            }
            if viewModel.isSettled(item.id), hasRemainingItems(viewModel: viewModel) {
                AppButton("下一题", kind: .secondary) {
                    viewModel.goToNextItem()
                }
            }
        }
    }

    private func hasRemainingItems(viewModel: PracticeViewModel) -> Bool {
        plan.items.contains { !viewModel.isSettled($0.id) }
    }

    private func skipMenu(viewModel: PracticeViewModel) -> some View {
        Menu("跳过这道题") {
            ForEach(plan.completionPolicy.allowedSkipReasons, id: \.self) { reason in
                Button(reason) {
                    viewModel.skipCurrentItem(reason: reason)
                }
            }
        }
        .font(AppFont.body)
        .foregroundStyle(theme.link)
        .frame(minHeight: AppLayout.minTouchTarget)
    }

    private var completionView: some View {
        CompletionView(
            rewardGrants: viewModel?.checkInResult?.rewardGrants ?? [],
            calendarSummary: viewModel?.checkInResult?.calendarSummary,
            isOfflineSaved: viewModel?.isOfflineSaved ?? false,
            onExtraPractice: { viewModel?.startExtraPractice() },
            onDone: { dismiss() }
        )
    }

    private var completionBinding: Binding<Bool> {
        Binding(
            get: { viewModel?.showCompletion ?? false },
            set: { viewModel?.showCompletion = $0 }
        )
    }

    private func toastBinding(of viewModel: PracticeViewModel) -> Binding<ToastMessage?> {
        Binding(
            get: { viewModel.toast },
            set: { viewModel.toast = $0 }
        )
    }
}
