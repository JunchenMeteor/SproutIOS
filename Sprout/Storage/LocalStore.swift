/// 本地业务状态的 JSON 文件持久化。
/// 职责：管理家长草稿、每日计划快照、sync 游标与 onboarding 标记，
/// 每次变更立即整体原子写入（Data.write(options: .atomic)）。
/// 边界：只持久化本文件定义的轻量本地结构，不耦合未冻结的远端契约类型；
/// 计划条目以原始 JSON Data 透传，客户端不做强类型解析。
/// 副作用：在 Application Support/LocalState（或注入目录）读写 state.json。
/// 约束：非线程安全，调用方须在主线程或同一串行上下文使用；
/// 取舍：实体少且写入低频，选用单一大文件换实体间一致快照，
/// 避免多文件方案中部分写失败造成的草稿与快照互相矛盾。
import Foundation

/// 家长首次设置草稿。
struct ChildProfileDraft: Codable, Equatable {
    /// 孩子昵称。
    var nickname: String
    /// 教材版本 id。
    var courseEditionId: String
    /// 当前已学课次 id；未选定可为 nil。
    var currentLessonId: String?
    /// 家长是否选择长期保留录音。
    var retainRecordings: Bool

    init(nickname: String, courseEditionId: String, currentLessonId: String? = nil, retainRecordings: Bool) {
        self.nickname = nickname
        self.courseEditionId = courseEditionId
        self.currentLessonId = currentLessonId
        self.retainRecordings = retainRecordings
    }
}


/// 每日计划的本地快照；items 以原始 JSON 透传，契约未冻结期间不做强类型建模。
struct LocalPlanSnapshot: Codable, Equatable {
    /// 计划 id。
    var planId: String
    /// 业务目标日期，格式 "YYYY-MM-DD"（固定业务时区，不从设备时区推断）。
    var targetDate: String
    /// 当日模式（新课/复习/未知），按服务端取值原样保存。
    var dayMode: String
    /// 计划内容版本，用于冲突与刷新判断。
    var contentVersion: String
    /// items 数组的原始 JSON，契约冻结前透传。
    var itemsJSON: Data

    init(planId: String, targetDate: String, dayMode: String, contentVersion: String, itemsJSON: Data) {
        self.planId = planId
        self.targetDate = targetDate
        self.dayMode = dayMode
        self.contentVersion = contentVersion
        self.itemsJSON = itemsJSON
    }
}


/// LocalStore 读写失败。
enum LocalStoreError: Error {
    /// 已有状态文件无法解码；调用方决定备份重建或上报，本层不静默重置。
    case corruptedState(underlying: Error)
}


/// 落盘的聚合状态；私有以保证外部只经 LocalStore 的显式 API 访问。
private struct PersistedState: Codable {
    var childProfileDraft: ChildProfileDraft?
    var planSnapshots: [String: LocalPlanSnapshot]
    var syncCursor: String?
    var hasCompletedOnboarding: Bool

    init() {
        childProfileDraft = nil
        planSnapshots = [:]
        syncCursor = nil
        hasCompletedOnboarding = false
    }

    /* 逐字段 decodeIfPresent：旧版本状态文件缺少新增字段时可向前兼容解码，
     不会因加字段把老用户的本地状态整体判为损坏。 */
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        childProfileDraft = try container.decodeIfPresent(ChildProfileDraft.self, forKey: .childProfileDraft)
        planSnapshots = try container.decodeIfPresent([String: LocalPlanSnapshot].self, forKey: .planSnapshots) ?? [:]
        syncCursor = try container.decodeIfPresent(String.self, forKey: .syncCursor)
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
    }
}


final class LocalStore {
    /// 计划快照字典 key 由 childId 与 targetDate 组成，天然支持切账号/多孩子隔离。
    static func planSnapshotKey(childId: String, targetDate: String) -> String {
        "\(childId)#\(targetDate)"
    }

    private static let fileName = "state.json"

    private let fileURL: URL
    private var persisted: PersistedState

    /// 注入目录便于测试；默认 Application Support/LocalState。
    /// 已有状态损坏时抛 LocalStoreError.corruptedState，不吞错、不静默清空。
    init(directory: URL? = nil, fileManager: FileManager = .default) throws {
        let root: URL
        if let directory {
            root = directory
        } else {
            root = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("LocalState", isDirectory: true)
        }
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        fileURL = root.appendingPathComponent(Self.fileName)
        persisted = try Self.load(from: fileURL)
    }

    /// 当前家长草稿；未设置过为 nil。
    var childProfileDraft: ChildProfileDraft? { persisted.childProfileDraft }

    /// 保存或覆盖草稿并立即原子落盘。
    func saveChildProfileDraft(_ draft: ChildProfileDraft) throws {
        persisted.childProfileDraft = draft
        try persistNow()
    }

    /// 读取指定孩子与目标日期的计划快照；不存在返回 nil。
    func planSnapshot(childId: String, targetDate: String) -> LocalPlanSnapshot? {
        persisted.planSnapshots[Self.planSnapshotKey(childId: childId, targetDate: targetDate)]
    }

    /// 保存计划快照并立即原子落盘；同 key 覆盖。
    /// 待同步草稿不被全量刷新覆盖（合并策略由调用方保证）。
    func savePlanSnapshot(_ snapshot: LocalPlanSnapshot, childId: String, targetDate: String) throws {
        persisted.planSnapshots[Self.planSnapshotKey(childId: childId, targetDate: targetDate)] = snapshot
        try persistNow()
    }

    /// 当前 sync 游标；从未同步为 nil。
    var syncCursor: String? { persisted.syncCursor }

    /// 更新 sync 游标并立即原子落盘；传 nil 表示游标失效、下次全量重取。
    func saveSyncCursor(_ cursor: String?) throws {
        persisted.syncCursor = cursor
        try persistNow()
    }

    /// 是否已完成首次家长设置。
    var hasCompletedOnboarding: Bool { persisted.hasCompletedOnboarding }

    /// 更新 onboarding 标记并立即原子落盘。
    func setOnboardingCompleted(_ completed: Bool) throws {
        persisted.hasCompletedOnboarding = completed
        try persistNow()
    }

    private func persistNow() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(persisted)
        try data.write(to: fileURL, options: .atomic)
    }

    private static func load(from fileURL: URL) throws -> PersistedState {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return PersistedState()
        }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(PersistedState.self, from: data)
        } catch {
            throw LocalStoreError.corruptedState(underlying: error)
        }
    }
}
