/// 评测反馈卡片。
/// 儿童区展示反馈状态：等待/部分/不确定/就绪/失败；
/// 家长区可展开查看详细说明。pending 与 partial 用不定值加载，不造假进度。
/// 组件只渲染输入，不访问评测服务。
import SwiftUI

/// 反馈状态输入。
enum FeedbackState: Equatable {
    /// 反馈生成中。
    case pending
    /// 已有部分内容，其余稍后送达。
    case partial
    /// 录音置信度不足，需回放确认。
    case uncertain
    /// 反馈就绪。
    case ready
    /// 失败，携带中文原因与是否可重试。
    case error(message: String, retryable: Bool)
}


/// 反馈卡片视图。
/// 输入状态、儿童提示、鼓励语、家长详情与重试回调；
/// isParentExpanded 由页面持有，便于跨组件记忆展开状态。
struct FeedbackCard: View {
    @Environment(\.theme) private var theme

    private let state: FeedbackState
    private let childTip: String?
    private let encouragement: String?
    private let parentDetails: String?
    private let onRetry: (() -> Void)?
    @Binding private var isParentExpanded: Bool

    /// 创建反馈卡片。onRetry 仅在 error 且 retryable 时显示。
    init(
        state: FeedbackState,
        childTip: String? = nil,
        encouragement: String? = nil,
        parentDetails: String? = nil,
        onRetry: (() -> Void)? = nil,
        isParentExpanded: Binding<Bool>
    ) {
        self.state = state
        self.childTip = childTip
        self.encouragement = encouragement
        self.parentDetails = parentDetails
        self.onRetry = onRetry
        self._isParentExpanded = isParentExpanded
    }

    var body: some View {
        CardContainer {
            VStack(spacing: AppSpacing.medium) {
                childArea
                if parentDetails != nil {
                    parentArea
                }
            }
        }
    }

    @ViewBuilder
    private var childArea: some View {
        switch state {
        case .pending:
            pendingView
        case .partial:
            partialView
        case .uncertain:
            uncertainView
        case .ready:
            readyView
        case .error(let message, let retryable):
            errorView(message: message, retryable: retryable)
        }
    }

    private var pendingView: some View {
        HStack(spacing: AppSpacing.small) {
            ProgressView()
                .tint(theme.info.icon)
            Text("反馈正在路上")
                .font(AppFont.body)
                .foregroundStyle(theme.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    private var partialView: some View {
        VStack(spacing: AppSpacing.small) {
            if let childTip {
                tipText(childTip)
            }
            Text("部分反馈稍后送达")
                .font(AppFont.helper)
                .foregroundStyle(theme.info.foreground)
        }
        .frame(maxWidth: .infinity)
    }

    private var uncertainView: some View {
        Label("听得不够清楚，请回放确认", systemImage: "questionmark.circle.fill")
            .font(AppFont.body)
            .foregroundStyle(theme.warning.foreground)
            .frame(maxWidth: .infinity)
    }

    private var readyView: some View {
        VStack(spacing: AppSpacing.small) {
            if let childTip {
                tipText(childTip)
            }
            if let encouragement {
                Text(encouragement)
                    .font(AppFont.english)
                    .foregroundStyle(theme.accent)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func errorView(message: String, retryable: Bool) -> some View {
        VStack(spacing: AppSpacing.small) {
            Label(message, systemImage: "xmark.octagon.fill")
                .font(AppFont.body)
                .foregroundStyle(theme.error.foreground)
            if retryable, let onRetry {
                AppButton("重试", kind: .secondary, action: onRetry)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func tipText(_ tip: String) -> some View {
        Text(tip)
            .font(AppFont.body)
            .foregroundStyle(theme.textPrimary)
    }

    private var parentArea: some View {
        VStack(spacing: AppSpacing.small) {
            Rectangle()
                .fill(theme.divider)
                .frame(height: 1)
            Button {
                isParentExpanded.toggle()
            } label: {
                HStack(spacing: AppSpacing.xSmall) {
                    Text("家长查看详情")
                        .font(AppFont.helper)
                        .foregroundStyle(theme.link)
                    Image(systemName: isParentExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(theme.iconSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: AppLayout.minTouchTarget)
            }
            .accessibilityHint(isParentExpanded ? "收起详情" : "展开详情")
            if isParentExpanded, let parentDetails {
                Text(parentDetails)
                    .font(AppFont.helper)
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}


#Preview {
    struct PreviewHost: View {
        @State private var isExpanded = false

        var body: some View {
            VStack(spacing: AppSpacing.medium) {
                FeedbackCard(
                    state: .ready,
                    childTip: "把 apple 的 /æ/ 音再张大一点",
                    encouragement: "Great job! Keep practicing!",
                    parentDetails: "置信度 0.92，发音准确度高于上次练习。",
                    isParentExpanded: $isExpanded
                )
                FeedbackCard(state: .pending, isParentExpanded: .constant(false))
                FeedbackCard(state: .uncertain, isParentExpanded: .constant(false))
            }
            .padding(AppSpacing.medium)
        }
    }
    return PreviewHost()
}
