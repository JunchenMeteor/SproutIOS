/// 收藏馆页。
/// CollectionItem 经 RewardCard 双列网格展示（iPad 自适应更多列并按 readingMaxWidth 限宽）；
/// 顶部为下一里程碑进度卡（确定进度用真实比值），
/// 底部 helper 标注素材占位与模拟来源。
import SwiftUI

struct CollectionView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.theme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var viewModel: CollectionViewModel?

    var body: some View {
        ScrollView {
            content
                .padding(AppSpacing.medium)
        }
        .frame(maxWidth: AppLayout.readingMaxWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.page)
        .task { await prepareIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        if let viewModel {
            switch viewModel.state {
            case .loading:
                ProgressView("加载中…")
                    .padding(AppSpacing.xLarge)
            case .failed(let message):
                failedView(message)
            case .loaded(let snapshot):
                loadedView(snapshot)
            }
        } else {
            ProgressView("加载中…")
                .padding(AppSpacing.xLarge)
        }
    }

    private var columns: [GridItem] {
        if sizeClass == .regular {
            return [GridItem(.adaptive(minimum: 180), spacing: AppSpacing.medium)]
        }
        return [
            GridItem(.flexible(), spacing: AppSpacing.medium),
            GridItem(.flexible(), spacing: AppSpacing.medium),
        ]
    }

    private func loadedView(_ snapshot: CollectionSnapshot) -> some View {
        VStack(spacing: AppSpacing.medium) {
            if let milestone = snapshot.nextMilestone {
                milestoneCard(milestone)
            }
            if snapshot.items.isEmpty {
                emptyView
            } else {
                grid(snapshot.items)
            }
            Text("素材为演示占位，历史素材许可待确认；数据来自模拟服务")
                .font(AppFont.helper)
                .foregroundStyle(theme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func milestoneCard(_ milestone: NextMilestone) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text("再完成 \(milestone.requiredDates - milestone.currentDates) 天解锁：\(milestone.title)")
                    .font(AppFont.body)
                    .foregroundStyle(theme.textPrimary)
                ProgressView(value: progress(of: milestone))
                    .tint(theme.progressFill)
                Text("\(milestone.currentDates)/\(milestone.requiredDates) 天")
                    .font(AppFont.helper)
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var emptyView: some View {
        Text("收藏馆还是空的，完成打卡即可解锁第一件藏品")
            .font(AppFont.body)
            .foregroundStyle(theme.textSecondary)
            .padding(AppSpacing.large)
    }

    private func grid(_ items: [CollectionItem]) -> some View {
        LazyVGrid(columns: columns, spacing: AppSpacing.medium) {
            ForEach(items, id: \.id) { item in
                rewardCard(item)
            }
        }
    }

    private func rewardCard(_ item: CollectionItem) -> some View {
        RewardCard(
            title: item.title,
            subtitle: item.unlocked ? "已解锁" : "未解锁",
            state: item.unlocked ? .confirmed : .locked,
            assetSystemImage: symbol(for: item.kind),
            onTap: {})
    }

    /* 藏品类别暂无正式素材，统一用 SF Symbol 占位剪影；接入真实素材后替换此处映射。 */
    private func symbol(for kind: CollectionKind) -> String {
        switch kind {
        case .tank: return "shield.fill"
        case .part: return "gearshape.fill"
        case .badge: return "star.fill"
        case .decoration: return "paintpalette.fill"
        case .unknown: return "questionmark.square"
        }
    }

    private func progress(of milestone: NextMilestone) -> Double {
        let required = max(milestone.requiredDates, 1)
        return min(1, Double(milestone.currentDates) / Double(required))
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

    private func prepareIfNeeded() async {
        guard viewModel == nil else { return }
        let model = CollectionViewModel(backend: environment.backend)
        viewModel = model
        await model.load()
    }
}
