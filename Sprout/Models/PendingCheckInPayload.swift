/// 离线打卡的队列载荷（PendingOperation.kind == .checkIn 的 payloadJSON 解码目标）。
/// 契约未冻结期间以 JSON 透传，重放时按字段重建 createCheckIn 请求；
/// 字段与编码自练习页迁入时保持不变，入队（PracticeViewModel）与重放（SyncCoordinator）共用。
/// 约束：字段不得擅自增删，避免已落盘的队列数据无法解码。
import Foundation


/// 离线打卡载荷；编码沿用 ContractJSON（Date 为 ISO-8601 UTC，BusinessDate 为 YYYY-MM-DD）。
struct PendingCheckInPayload: Codable {
    /// 所属儿童 ID。
    let childId: String
    /// 计划 ID。
    let planId: String
    /// 目标业务日期。
    let targetDate: BusinessDate
    /// 客户端完成幂等 ID（与队列条目 id 同值，重放沿用）。
    let clientCompletionId: UUID
    /// 客户端完成时间。
    let clientCompletedAt: Date
    /// 计划版本号。
    let planRevision: Int
    /// 条目结果列表。
    let itemOutcomes: [ItemOutcome]
}
