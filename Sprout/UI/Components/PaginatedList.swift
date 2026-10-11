/// 分页列表容器。
/// mobile 语义：滚动到底自动触发加载更多；loading/empty/error 三态分离——
/// 加载中只在底部显示 ProgressView、不遮蔽已有内容；
/// 空态由调用方提供 emptyView；错误展示文案与重试按钮（AppButton secondary）。
import SwiftUI

/// 通用分页列表。
/// 输入为已加载数据与三态标记，输出为 onLoadMore / onRetry 回调；
/// 组件不访问网络，只按状态渲染并透出用户意图。
struct PaginatedList<Item: Identifiable, RowContent: View, EmptyContent: View>: View {
    @Environment(\.theme) private var theme

    private let items: [Item]
    private let isLoading: Bool
    private let errorMessage: String?
    private let hasMore: Bool
    private let onRetry: () -> Void
    private let onLoadMore: () -> Void
    private let rowBuilder: (Item) -> RowContent
    private let emptyView: EmptyContent

    /// 创建分页列表。hasMore 为 true 且滚动到底时回调 onLoadMore。
    init(
        items: [Item],
        isLoading: Bool,
        errorMessage: String? = nil,
        hasMore: Bool,
        onRetry: @escaping () -> Void,
        onLoadMore: @escaping () -> Void,
        @ViewBuilder rowBuilder: @escaping (Item) -> RowContent,
        @ViewBuilder emptyView: () -> EmptyContent
    ) {
        self.items = items
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.hasMore = hasMore
        self.onRetry = onRetry
        self.onLoadMore = onLoadMore
        self.rowBuilder = rowBuilder
        self.emptyView = emptyView()
    }

    var body: some View {
        Group {
            if items.isEmpty && isLoading {
                initialLoadingView
            } else if items.isEmpty, let errorMessage {
                fullErrorView(errorMessage)
            } else if items.isEmpty {
                emptyView
            } else {
                listView
            }
        }
    }

    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.small) {
                ForEach(items) { item in
                    rowBuilder(item)
                        .onAppear {
                            triggerLoadMoreIfNeeded(for: item)
                        }
                }
                listFooter
            }
            .padding(AppSpacing.medium)
            .frame(maxWidth: AppLayout.readingMaxWidth)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var listFooter: some View {
        if isLoading {
            ProgressView()
                .padding(AppSpacing.medium)
        } else if let errorMessage {
            VStack(spacing: AppSpacing.small) {
                Text(errorMessage)
                    .font(AppFont.helper)
                    .foregroundStyle(theme.error.foreground)
                AppButton("重试", kind: .secondary, action: onRetry)
            }
            .padding(AppSpacing.medium)
        } else if !hasMore {
            Text("已经到底啦")
                .font(AppFont.helper)
                .foregroundStyle(theme.textTertiary)
                .padding(AppSpacing.small)
        }
    }

    private var initialLoadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func fullErrorView(_ message: String) -> some View {
        VStack(spacing: AppSpacing.medium) {
            Image(systemName: "exclamationmark.triangle")
                .font(AppFont.section)
                .foregroundStyle(theme.error.icon)
            Text(message)
                .font(AppFont.body)
                .foregroundStyle(theme.textSecondary)
            AppButton("重试", kind: .secondary, action: onRetry)
        }
        .padding(AppSpacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /* 末行出现时触发加载更多；加载中、无更多或出错时不重复触发。 */
    private func triggerLoadMoreIfNeeded(for item: Item) {
        guard hasMore, !isLoading, errorMessage == nil else { return }
        guard item.id == items.last?.id else { return }
        onLoadMore()
    }
}


#Preview {
    struct PreviewItem: Identifiable {
        let id: Int
    }
    return PaginatedList(
        items: [PreviewItem(id: 1), PreviewItem(id: 2), PreviewItem(id: 3)],
        isLoading: false,
        hasMore: true,
        onRetry: {},
        onLoadMore: {},
        rowBuilder: { item in
            CardContainer {
                Text("记录 \(item.id)")
                    .font(AppFont.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        },
        emptyView: {
            Text("还没有记录")
                .font(AppFont.body)
        }
    )
}
