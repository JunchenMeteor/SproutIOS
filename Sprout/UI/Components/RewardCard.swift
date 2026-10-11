/// 收藏奖励卡片。
/// 三态展示：未解锁（剪影 + "未解锁"文字）、待确认、已确认（徽章）。
/// confirmed 出现动画仅为展示效果；reduceMotion 开启时直接静态呈现。
/// 素材许可确认前一律使用 SF Symbol 占位，不引入真实图片。
/// 本组件只做展示，不含发奖逻辑——实际发放由奖励服务与后端决定。
import SwiftUI

/// 奖励状态。
enum RewardItemState {
    /// 未解锁：剪影 + 文字标识。
    case locked
    /// 待确认：等待家长或云端确认。
    case pending
    /// 已确认：正式获得，展示徽章。
    case confirmed
}


/// 奖励卡片视图，主体居中。
struct RewardCard: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    private let title: String
    private let subtitle: String
    private let state: RewardItemState
    private let assetSystemImage: String
    private let onTap: () -> Void

    /// 创建奖励卡片。assetSystemImage 为 SF Symbol 名，作为真实素材的占位。
    init(
        title: String,
        subtitle: String,
        state: RewardItemState,
        assetSystemImage: String,
        onTap: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.state = state
        self.assetSystemImage = assetSystemImage
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: AppSpacing.small) {
                iconView
                Text(title)
                    .font(AppFont.body)
                    .foregroundStyle(titleColor)
                Text(subtitle)
                    .font(AppFont.helper)
                    .foregroundStyle(subtitleColor)
                badge
            }
            .padding(AppSpacing.medium)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(CardPressStyle(pressedBorder: theme.pressedBorder))
    }

    private var iconView: some View {
        Image(systemName: assetSystemImage)
            .font(AppFont.title)
            .symbolVariant(state == .locked ? .slash : .none)
            .foregroundStyle(iconColor)
            .opacity(isVisible ? 1 : 0)
            .animation(reduceMotion ? nil : .easeIn(duration: AppLayout.transitionAnimation), value: isVisible)
            .onAppear {
                isVisible = true
            }
    }

    @ViewBuilder
    private var badge: some View {
        switch state {
        case .locked:
            badgeView(
                text: "未解锁",
                background: theme.reward.lockedBackground,
                foreground: theme.reward.lockedForeground
            )
        case .pending:
            badgeView(
                text: "待确认",
                background: theme.reward.pending.background,
                foreground: theme.reward.pending.foreground
            )
        case .confirmed:
            badgeView(
                text: "已确认",
                background: theme.reward.badgeBackground,
                foreground: theme.reward.badgeForeground
            )
        }
    }

    private func badgeView(text: String, background: Color, foreground: Color) -> some View {
        Text(text)
            .font(AppFont.helper)
            .foregroundStyle(foreground)
            .padding(.horizontal, AppSpacing.small)
            .padding(.vertical, AppSpacing.xxSmall)
            .background(background)
            .clipShape(Capsule())
    }

    private var cardBackground: Color {
        switch state {
        case .locked: return theme.reward.lockedBackground
        case .pending: return theme.reward.pending.background
        case .confirmed: return theme.reward.surface
        }
    }

    private var iconColor: Color {
        switch state {
        case .locked: return theme.reward.lockedForeground
        case .pending: return theme.reward.pending.icon
        case .confirmed: return theme.accent
        }
    }

    private var titleColor: Color {
        state == .locked ? theme.reward.lockedForeground : theme.reward.title
    }

    private var subtitleColor: Color {
        state == .locked ? theme.reward.lockedForeground : theme.reward.subtitle
    }
}


#Preview {
    HStack(spacing: AppSpacing.medium) {
        RewardCard(
            title: "坚持之星",
            subtitle: "连续打卡 7 天",
            state: .locked,
            assetSystemImage: "star.fill"
        ) {}
        RewardCard(
            title: "朗读小达人",
            subtitle: "完成 10 次跟读",
            state: .pending,
            assetSystemImage: "mic.fill"
        ) {}
        RewardCard(
            title: "单词收藏家",
            subtitle: "收集 50 个单词",
            state: .confirmed,
            assetSystemImage: "book.fill"
        ) {}
    }
    .padding(AppSpacing.medium)
}
