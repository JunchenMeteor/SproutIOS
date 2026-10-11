/// 启动引导、身份档案、配置、能力与课程进度模型（EC-API-0.1 第 5.1 节）。
/// 边界：仅建模契约已写明的字段；账户恢复信息不置于 Child，5.6 缺口不补字段。
/// 副作用：无；纯值类型。
/// 约束：JSON 字段 camelCase；时间为 ISO-8601 UTC，由 ContractJSON 的解码策略处理。
import Foundation


/// GET /v1/bootstrap 的 data 载荷。
/// 一次性返回家长摘要、儿童列表、配置、能力与同步游标。
struct Bootstrap: Codable, Sendable {
    /// 家长账号摘要。
    let parentSummary: ParentSummary
    /// 当前家长名下的儿童档案列表。
    let children: [ChildSummary]
    /// 服务端配置（时区、音频限制、幂等保留期、补卡策略、奖励规则版本）。
    let configuration: ContractConfiguration
    /// 真实可用的能力开关，不是营销列表。
    let capabilities: Capabilities
    /// 服务端不透明同步游标。
    let syncCursor: String
}


/// 家长账号摘要。
/// 仅含展示所需最小字段。
struct ParentSummary: Codable, Sendable {
    /// 家长账号 ID（UUID 字符串）。
    let id: String
    /// 展示名。
    let displayName: String
}


/// 儿童档案摘要。
/// revision 用于乐观并发控制；retentionPolicy 为服务端策略标识。
struct ChildSummary: Codable, Sendable {
    /// 儿童档案 ID（UUID 字符串）。
    let id: String
    /// 昵称。
    let displayName: String
    /// 档案版本号。
    let revision: Int
    /// 档案时区（IANA 标识）。
    let timezone: String
    /// 录音保留策略标识。
    let retentionPolicy: String
}


/// 服务端配置。
/// idempotencyRetentionSeconds 覆盖离线重放期；rewardRuleVersion 是审计快照，不作唯一防重。
/// 命名为 ContractConfiguration 以避免与 SwiftUI ButtonStyle.Configuration 等同名类型冲突。
struct ContractConfiguration: Codable, Sendable {
    /// 服务端默认时区（IANA 标识）。
    let timezone: String
    /// 音频上传限制。
    let audioLimits: AudioLimits
    /// 幂等键服务端保存期限（秒）。
    let idempotencyRetentionSeconds: Int
    /// 补卡策略。
    let makeupPolicy: MakeupPolicy
    /// 奖励规则版本（审计快照）。
    let rewardRuleVersion: String
}


/// 音频上传限制。
/// 超出限制服务端返回 413/415。
struct AudioLimits: Codable, Sendable {
    /// 单条录音最长秒数。
    let maxSeconds: Int
    /// 单条录音最大字节数。
    let maxBytes: Int
    /// 接受的容器/编码格式列表。
    let formats: [String]
}


/// 补卡策略。
/// 补卡使用同一打卡端点，日期早于确认日且在允许范围内。
struct MakeupPolicy: Codable, Sendable {
    /// 允许向前补卡的天数。
    let allowedDaysBack: Int
}


/// 能力开关。
/// 仅表达真实可用能力；false 时界面必须隐藏或降级对应功能。
struct Capabilities: Codable, Sendable {
    /// 语音转写可用。
    let stt: Bool
    /// 发音评测可用。
    let pronunciation: Bool
    /// 语音合成可用。
    let tts: Bool
    /// 报告导出可用。
    let report: Bool
}


/// 教材版本摘要（GET /v1/courses）。
/// 仅已获许可且准备好的教材可展示为可用。
struct CourseEditionSummary: Codable, Sendable {
    /// 教材版本 ID（内容标识，按 schema 定义，非自有 UUID）。
    let id: String
    /// 教材标题。
    let title: String
    /// 出版方备注。
    let publisherNote: String
    /// 是否已获许可。
    let licensed: Bool
}


/// 课程进度快照（GET /v1/children/{childId}/progress）。
/// confirmedKnowledgePointIds 由后端根据课次生成，客户端不任意提交。
struct ProgressSnapshot: Codable, Sendable {
    /// 当前教材版本 ID。
    let courseEditionId: String
    /// 家长已确认的课次 ID 列表。
    let confirmedLessonIds: [String]
    /// 已学知识点 ID 列表（服务端生成）。
    let confirmedKnowledgePointIds: [String]
    /// 进度版本号。
    let revision: Int
    /// 最近确认时间（ISO-8601 UTC），从未确认为 nil。
    let confirmedAt: Date?
}
