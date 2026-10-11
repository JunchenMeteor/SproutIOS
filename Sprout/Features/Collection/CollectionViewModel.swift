/// 收藏馆视图模型。
/// 拉取收藏快照（藏品列表 + 下一里程碑）；当前为模拟服务数据，
/// 页面标注素材为演示占位、历史素材许可待确认。
import Foundation

@Observable
final class CollectionViewModel {
    enum State {
        case loading
        case loaded(CollectionSnapshot)
        case failed(String)
    }

    private enum CollectionError: Error {
        case noChild
    }

    private let backend: any BackendService
    private var childId: String?
    private(set) var state: State = .loading

    init(backend: any BackendService) {
        self.backend = backend
    }

    /// 加载收藏快照；失败进入可重试的错误态。
    func load() async {
        state = .loading
        do {
            let resolvedId = try await resolveChildId()
            state = .loaded(try await backend.fetchCollection(childId: resolvedId))
        } catch {
            state = .failed("收藏馆加载失败，请稍后重试")
        }
    }

    private func resolveChildId() async throws -> String {
        if let childId { return childId }
        let bootstrap = try await backend.bootstrap()
        guard let first = bootstrap.children.first else { throw CollectionError.noChild }
        childId = first.id
        return first.id
    }
}
