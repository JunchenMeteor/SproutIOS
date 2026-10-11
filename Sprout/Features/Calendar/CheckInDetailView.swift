/// 打卡详情页（sheet 呈现）。
/// 分行标注「服务端确认」与「本机记录」两个时间来源，补卡显示 info 色组徽章；
/// 反馈摘要经 FeedbackCard 展示，feedbackPending 时提示「反馈稍后送达」；
/// 录音回放仅在 playableAudioId 非空且本机文件存在时可用，文字反馈不依赖录音是否保留。
import SwiftUI

struct CheckInDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CheckInDetailViewModel?
    @State private var isParentExpanded = false
    let checkInId: String

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.page)
                .navigationTitle("记录详情")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("关闭") { dismiss() }
                            .foregroundStyle(theme.link)
                    }
                }
        }
        .task { await prepareIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        if let viewModel {
            switch viewModel.state {
            case .loading:
                ProgressView("加载中…")
            case .failed(let message):
                failedView(message)
            case .loaded(let detail):
                loadedView(detail)
            }
        } else {
            ProgressView("加载中…")
        }
    }

    private func loadedView(_ detail: CheckInDetail) -> some View {
        ScrollView {
            VStack(spacing: AppSpacing.medium) {
                dateCard(detail.checkIn)
                timeCard(detail.checkIn)
                feedbackSection(detail)
                audioSection(detail)
            }
            .padding(AppSpacing.medium)
        }
    }

    private func dateCard(_ checkIn: CheckIn) -> some View {
        CardContainer {
            HStack {
                Text(checkIn.targetDate.rawValue)
                    .font(AppFont.section)
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                if checkIn.isMakeup {
                    makeupBadge
                }
            }
        }
    }

    private var makeupBadge: some View {
        Text("补卡")
            .font(AppFont.helper)
            .foregroundStyle(theme.info.foreground)
            .padding(.horizontal, AppSpacing.small)
            .padding(.vertical, AppSpacing.xxSmall)
            .background(theme.info.background)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
    }

    private func timeCard(_ checkIn: CheckIn) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                infoRow(title: "服务端确认", value: confirmedText(checkIn.confirmedAt))
                infoRow(title: "本机记录", value: format(checkIn.clientCompletedAt))
            }
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(AppFont.helper)
                .foregroundStyle(theme.textSecondary)
            Spacer()
            Text(value)
                .font(AppFont.body)
                .foregroundStyle(theme.textPrimary)
        }
    }

    @ViewBuilder
    private func feedbackSection(_ detail: CheckInDetail) -> some View {
        if let feedback = detail.feedbackSummary {
            FeedbackCard(
                state: .ready,
                childTip: feedback.childTip,
                encouragement: feedback.encouragement,
                parentDetails: feedback.parentDetails,
                onRetry: nil,
                isParentExpanded: $isParentExpanded)
        } else if detail.checkIn.feedbackPending {
            infoBanner("反馈稍后送达")
        } else {
            infoBanner("暂无文字反馈")
        }
    }

    private func audioSection(_ detail: CheckInDetail) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text("录音回放")
                    .font(AppFont.section)
                    .foregroundStyle(theme.textPrimary)
                audioContent(detail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func audioContent(_ detail: CheckInDetail) -> some View {
        if let audioId = detail.playableAudioId {
            if viewModel?.audioUnavailable == true {
                Text("录音不可用（可能已按保留策略删除）")
                    .font(AppFont.helper)
                    .foregroundStyle(theme.textSecondary)
            } else {
                AppButton(environment.player.isPlaying ? "停止播放" : "播放录音",
                          kind: .secondary, isLoading: false, isEnabled: true) {
                    toggleAudio(audioId: audioId)
                }
            }
        } else {
            Text("该记录没有可回放的录音")
                .font(AppFont.helper)
                .foregroundStyle(theme.textSecondary)
        }
    }

    private func infoBanner(_ text: String) -> some View {
        Text(text)
            .font(AppFont.helper)
            .foregroundStyle(theme.info.foreground)
            .padding(.horizontal, AppSpacing.small)
            .padding(.vertical, AppSpacing.xSmall)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.info.background)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
    }

    private func failedView(_ message: String) -> some View {
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

    /* 本机文件缺失不抛错，按保留策略降级为文字提示；播放中再次点击即停止。 */
    private func toggleAudio(audioId: String) {
        if environment.player.isPlaying {
            environment.player.stop()
            return
        }
        guard let fileID = UUID(uuidString: audioId),
              let url = environment.recordingFiles.url(for: fileID) else {
            viewModel?.markAudioUnavailable()
            return
        }
        environment.player.play(url: url)
    }

    private func confirmedText(_ confirmedAt: Date?) -> String {
        guard let confirmedAt else { return "待服务端确认" }
        return format(confirmedAt)
    }

    private func format(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private func prepareIfNeeded() async {
        guard viewModel == nil else { return }
        let model = CheckInDetailViewModel(backend: environment.backend, checkInId: checkInId)
        viewModel = model
        await model.load()
    }
}
