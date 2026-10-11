/// 家长页视图模型。
/// 聚合儿童档案摘要（bootstrap）与本机草稿（localStore）用于展示；
/// 退出登录只清除本机会话令牌，待同步数据保留在本机，不做远端删除。
import Foundation

@Observable
final class ParentViewModel {
    /// Keychain 中 App 会话令牌的账号键。只放 App 会话令牌，厂商密钥永远不进 App。
    private static let sessionAccount = "appSession"

    private let backend: any BackendService
    private let localStore: LocalStore
    private(set) var childName: String?
    private(set) var courseEditionId: String?
    private(set) var currentLessonId: String?
    private(set) var retainRecordings: Bool?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    init(backend: any BackendService, localStore: LocalStore) {
        self.backend = backend
        self.localStore = localStore
    }

    /// 加载档案摘要；网络失败时本地草稿字段仍可展示。
    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let bootstrap = try await backend.bootstrap()
            childName = bootstrap.children.first?.displayName
        } catch {
            errorMessage = "儿童档案加载失败（当前为模拟服务）"
        }
        let draft = localStore.childProfileDraft
        courseEditionId = draft?.courseEditionId
        currentLessonId = draft?.currentLessonId
        retainRecordings = draft?.retainRecordings
        if childName == nil {
            childName = draft?.nickname
        }
        isLoading = false
    }

    /// 仅清本机会话令牌；待同步数据保留，提示由页面弹出。删除失败如实记录错误。
    func signOut() {
        do {
            try KeychainHelper.deleteToken(account: Self.sessionAccount)
        } catch {
            errorMessage = "本机会话清除失败，请重试"
        }
    }
}
