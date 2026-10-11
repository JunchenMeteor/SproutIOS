/// 练习完成页。
/// 基础题完成即打卡的结果展示：插画占位、英语鼓励、奖励列表、下一目标与离线提示；
/// 提供「再玩一关」额外练习与「回到今天」出口。
import SwiftUI


/// 完成页。离线态只作 pending 奖励预览，不展示 confirmed 奖励。
struct CompletionView: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    let rewardGrants: [RewardGrant]
    let calendarSummary: CalendarSummary?
    let isOfflineSaved: Bool
    let onExtraPractice: () -> Void
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                illustration
                encouragementText
                if isOfflineSaved {
                    offlineNotice
                }
                rewardSection
                if let calendarSummary {
                    milestoneRow(calendarSummary)
                }
                actionButtons
            }
            .padding(AppSpacing.large)
            .frame(maxWidth: AppLayout.readingMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(theme.page)
        .navigationBarBackButtonHidden(true)
        .onAppear(perform: playEntrance)
    }

    private var illustration: some View {
        Image(systemName: "trophy.fill")
            .font(AppFont.title)
            .foregroundStyle(theme.accent)
            .frame(width: AppLayout.minTouchTarget * 2, height: AppLayout.minTouchTarget * 2)
            .background(theme.highlightBackground)
            .clipShape(Circle())
            .scaleEffect(hasAppeared || reduceMotion ? 1 : 0.8)
    }

    private var encouragementText: some View {
        VStack(spacing: AppSpacing.xSmall) {
            Text("Great job today! Keep going!")
                .font(AppFont.english)
                .foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.center)
            Text("完成今天的练习啦")
                .font(AppFont.body)
                .foregroundStyle(theme.textSecondary)
        }
    }

    private var offlineNotice: some View {
        Label("已在这台设备保存，联网后确认", systemImage: "arrow.triangle.2.circlepath")
            .font(AppFont.helper)
            .foregroundStyle(theme.info.foreground)
            .padding(AppSpacing.small)
            .frame(maxWidth: .infinity)
            .background(theme.info.background)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
    }

    /* 离线未确认时奖励只作 pending 预览，不展示 confirmed 状态。 */
    @ViewBuilder
    private var rewardSection: some View {
        if !rewardGrants.isEmpty {
            VStack(spacing: AppSpacing.small) {
                ForEach(rewardGrants, id: \.id) { grant in
                    RewardCard(
                        title: grant.title,
                        subtitle: Self.kindText(grant.kind),
                        state: isOfflineSaved ? .pending : .confirmed,
                        assetSystemImage: Self.kindIcon(grant.kind),
                        onTap: {}
                    )
                }
            }
        }
    }

    /* 契约暂无下一里程碑文案字段，由连续打卡天数推导下一目标。 */
    private func milestoneRow(_ summary: CalendarSummary) -> some View {
        Label("已连续打卡 \(summary.currentStreak) 天，明天继续就是 \(summary.currentStreak + 1) 天",
              systemImage: "flag.checkered")
            .font(AppFont.helper)
            .foregroundStyle(theme.textSecondary)
    }

    private var actionButtons: some View {
        VStack(spacing: AppSpacing.small) {
            AppButton("回到今天", action: onDone)
            AppButton("再玩一关", kind: .secondary, action: onExtraPractice)
        }
    }

    private static func kindText(_ kind: RewardKind) -> String {
        switch kind {
        case .badge:
            return "徽章"
        case .part:
            return "部件"
        case .tank:
            return "水族箱"
        case .decoration:
            return "装饰"
        case .unknown:
            return "奖励"
        }
    }

    private static func kindIcon(_ kind: RewardKind) -> String {
        switch kind {
        case .badge:
            return "rosette"
        case .part:
            return "puzzlepiece.fill"
        case .tank:
            return "fish.fill"
        case .decoration:
            return "star.fill"
        case .unknown:
            return "gift.fill"
        }
    }

    /* 入场缩放动画不超过 1s，开启减弱动态效果时直接跳过。 */
    private func playEntrance() {
        guard !reduceMotion, !hasAppeared else { return }
        withAnimation(.easeOut(duration: 0.6)) {
            hasAppeared = true
        }
    }
}
