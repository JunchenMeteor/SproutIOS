/// 契约枚举集合：EC-API-0.1 第 5 节已写明的全部状态/类别枚举。
/// 边界：仅承载契约已定义的取值，不补充 5.6 冻结缺口里的新状态。
/// 副作用：无；纯值类型。
/// 约束：未识别原始值统一解码为 .unknown 安全降级
/// （契约要求未知枚举不抛错、不默认为成功）。
import Foundation


/// 计划日模式。
/// 取值：new（新学）、review（复习）、unknown（未识别兜底）。
enum DayMode: String, Codable, Sendable {
    case new
    case review
    case unknown

    /// 自定义解码：未识别原始值降级为 .unknown 而不是抛错。
    /// 编码仍由编译器按 raw value 合成，不受影响。
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = DayMode(rawValue: rawValue) ?? .unknown
    }
}


/// 计划条目类型。
/// 取值：repeat（跟读，raw 值 "repeat"，关键字需反引号）、
/// freeExpression（自由表达）、unknown（兜底）。
enum PlanItemType: String, Codable, Sendable {
    case `repeat`
    case freeExpression
    case unknown

    /// 自定义解码：未识别原始值降级为 .unknown 而不是抛错。
    /// 编码仍由编译器按 raw value 合成，不受影响。
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = PlanItemType(rawValue: rawValue) ?? .unknown
    }
}


/// 评测组件状态。
/// 取值：pending/running/succeeded/failed/skipped/cancelled，加 unknown 兜底。
enum EvaluationComponentStatus: String, Codable, Sendable {
    case pending
    case running
    case succeeded
    case failed
    case skipped
    case cancelled
    case unknown

    /// 自定义解码：未识别原始值降级为 .unknown 而不是抛错。
    /// 编码仍由编译器按 raw value 合成，不受影响。
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = EvaluationComponentStatus(rawValue: rawValue) ?? .unknown
    }
}


/// 评测任务整体状态。
/// 取值：queued/running/succeeded/partial/failed/cancelled，加 unknown 兜底。
enum EvaluationJobStatus: String, Codable, Sendable {
    case queued
    case running
    case succeeded
    case partial
    case failed
    case cancelled
    case unknown

    /// 自定义解码：未识别原始值降级为 .unknown 而不是抛错。
    /// 编码仍由编译器按 raw value 合成，不受影响。
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = EvaluationJobStatus(rawValue: rawValue) ?? .unknown
    }
}


/// 转写质量评级。
/// 取值：usable（可用）、needsReview（需家长确认）、
/// insufficient（不足以评测）、unknown（兜底）。
enum TranscriptQuality: String, Codable, Sendable {
    case usable
    case needsReview
    case insufficient
    case unknown

    /// 自定义解码：未识别原始值降级为 .unknown 而不是抛错。
    /// 编码仍由编译器按 raw value 合成，不受影响。
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = TranscriptQuality(rawValue: rawValue) ?? .unknown
    }
}


/// 打卡条目结果。
/// 取值：completed（已完成）、skipped（按 completionPolicy 允许的原因跳过）、unknown（兜底）。
enum CheckInOutcome: String, Codable, Sendable {
    case completed
    case skipped
    case unknown

    /// 自定义解码：未识别原始值降级为 .unknown 而不是抛错。
    /// 编码仍由编译器按 raw value 合成，不受影响。
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = CheckInOutcome(rawValue: rawValue) ?? .unknown
    }
}


/// 收藏物类别。
/// 取值：tank（水族箱）、part（部件）、badge（徽章）、
/// decoration（装饰）、unknown（兜底）。
enum CollectionKind: String, Codable, Sendable {
    case tank
    case part
    case badge
    case decoration
    case unknown

    /// 自定义解码：未识别原始值降级为 .unknown 而不是抛错。
    /// 编码仍由编译器按 raw value 合成，不受影响。
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = CollectionKind(rawValue: rawValue) ?? .unknown
    }
}


/// 奖励类别。
/// 取值：part/badge/tank/decoration，加 unknown 兜底。
enum RewardKind: String, Codable, Sendable {
    case part
    case badge
    case tank
    case decoration
    case unknown

    /// 自定义解码：未识别原始值降级为 .unknown 而不是抛错。
    /// 编码仍由编译器按 raw value 合成，不受影响。
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = RewardKind(rawValue: rawValue) ?? .unknown
    }
}
