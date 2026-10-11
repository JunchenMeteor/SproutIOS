/// 打卡、日历与奖励模型（EC-API-0.1 第 5.3 节）。
/// 边界：仅建模契约字段；补卡复用同一打卡端点，不另建奖励接口。
/// 副作用：无；纯值类型。
/// 约束：打卡不以评测成功为前提；重复日期返回已有确认状态且不再发奖。
import Foundation


/// 打卡时的单条目结果。
/// 离线项没有服务器 attemptId 时用 localAttemptId 关联待上传记录。
struct ItemOutcome: Codable, Sendable {
    /// 计划条目 ID。
    let itemId: String
    /// 条目结果（completed/skipped）。
    let outcome: CheckInOutcome
    /// 服务器尝试 ID（在线项）。
    let attemptId: String?
    /// 本地尝试 ID（离线待上传项，必须与后续 clientAttemptId 相同）。
    let localAttemptId: UUID?
    /// 跳过原因（仅限 completionPolicy.allowedSkipReasons）。
    let skipReason: String?
}


/// 打卡记录。
/// targetDate 必须等于 plan.targetDate；补卡明确 isMakeup。
struct CheckIn: Codable, Sendable {
    /// 打卡记录 ID（UUID 字符串）。
    let id: String
    /// 目标业务日期。
    let targetDate: BusinessDate
    /// 客户端完成时间（ISO-8601 UTC）。
    let clientCompletedAt: Date
    /// 服务端确认时间（未确认为 nil）。
    let confirmedAt: Date?
    /// 是否补卡。
    let isMakeup: Bool
    /// 是否有反馈待补齐（晚到录音/评测）。
    let feedbackPending: Bool
    /// 记录版本号。
    let revision: Int
}


/// 打卡命令返回（POST /v1/children/{childId}/check-ins）。
/// 含记录本体、日历摘要、本次奖励授予与收藏版本号。
struct CheckInResult: Codable, Sendable {
    /// 打卡记录。
    let checkIn: CheckIn
    /// 日历摘要。
    let calendarSummary: CalendarSummary
    /// 本次新授予的奖励（重复日期为空数组）。
    let rewardGrants: [RewardGrant]
    /// 收藏快照版本号。
    let collectionRevision: Int
}


/// 日历摘要。
///  streak 以服务端唯一 CheckIn 为准。
struct CalendarSummary: Codable, Sendable {
    /// 今天是否已打卡。
    let todayCheckedIn: Bool
    /// 累计完成的不同日期数。
    let uniqueCompletedDates: Int
    /// 当前连续打卡天数。
    let currentStreak: Int
    /// 历史最长连续打卡天数。
    let longestStreak: Int
}


/// 奖励授予记录。
/// ruleVersion 是审计快照，不作为唯一防重因素。
struct RewardGrant: Codable, Sendable {
    /// 授予记录 ID（UUID 字符串）。
    let id: String
    /// 奖励类别。
    let kind: RewardKind
    /// 展示标题（界面可见文案）。
    let title: String
    /// 产生奖励的来源业务日期（里程碑类可能为 nil）。
    let sourceTargetDate: BusinessDate?
    /// 授予时的奖励规则版本。
    let ruleVersion: String
}


extension CheckIn {
    /// 返回替换 targetDate/clientCompletedAt 后的副本。
    /// 仅供模拟服务把 fixture 对齐到请求参数使用。
    func alignedTo(targetDate: BusinessDate, clientCompletedAt: Date) -> CheckIn {
        CheckIn(
            id: id,
            targetDate: targetDate,
            clientCompletedAt: clientCompletedAt,
            confirmedAt: confirmedAt,
            isMakeup: isMakeup,
            feedbackPending: feedbackPending,
            revision: revision
        )
    }
}


extension CheckInResult {
    /// 返回替换 checkIn 后的副本。
    /// 仅供模拟服务对齐请求参数使用。
    func withCheckIn(_ checkIn: CheckIn) -> CheckInResult {
        CheckInResult(
            checkIn: checkIn,
            calendarSummary: calendarSummary,
            rewardGrants: rewardGrants,
            collectionRevision: collectionRevision
        )
    }
}
