/// 收藏快照模型（EC-API-0.1 第 5.3 节）。
/// 边界：仅建模契约字段；客户端不提交 unlock=true，解锁完全由服务端奖励规则产生。
/// 副作用：无；纯值类型。
/// 约束：historySourceUrls 属于内容管理审计信息，不得返回未授权第三方图片地址。
import Foundation


/// 收藏物条目。
/// 未解锁条目的 unlockedAt/sourceTargetDate/assetId 为 nil。
struct CollectionItem: Codable, Sendable {
    /// 收藏物 ID（UUID 字符串）。
    let id: String
    /// 类别（tank/part/badge/decoration）。
    let kind: CollectionKind
    /// 是否已解锁。
    let unlocked: Bool
    /// 解锁时间（ISO-8601 UTC）。
    let unlockedAt: Date?
    /// 解锁来源业务日期。
    let sourceTargetDate: BusinessDate?
    /// 解锁时的奖励规则版本。
    let ruleVersion: String
    /// 展示标题（界面可见文案）。
    let title: String
    /// 素材 ID（未解锁或无素材时为 nil）。
    let assetId: String?
    /// 历史素材来源地址（审计用）。
    let historySourceUrls: [String]
}


/// 收藏快照（GET /v1/children/{childId}/collection 返回）。
/// 含全部条目、下一里程碑与版本号。
struct CollectionSnapshot: Codable, Sendable {
    /// 收藏物条目列表。
    let items: [CollectionItem]
    /// 下一里程碑（无里程碑时为 nil）。
    let nextMilestone: NextMilestone?
    /// 快照版本号。
    let revision: Int
}


/// 下一里程碑进度。
/// currentDates/requiredDates 由服务端按规则计算。
struct NextMilestone: Codable, Sendable {
    /// 里程碑标题（界面可见文案）。
    let title: String
    /// 达成所需日期数。
    let requiredDates: Int
    /// 当前已累计日期数。
    let currentDates: Int
}
