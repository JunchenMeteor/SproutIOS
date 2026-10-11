/// 计划与业务日期模型（EC-API-0.1 第 5.1 节）。
/// 边界：Plan/PlanItem/CompletionPolicy 仅含契约字段；BusinessDate 承载 YYYY-MM-DD 业务日期。
/// 副作用：无；纯值类型。
/// 约束：业务日期不是时刻，禁止用 Date 表示 targetDate；
///       比较按零填充字符串字典序（等价于时间序）。
import Foundation


/// 业务日期（"YYYY-MM-DD"），表示某时区下的一天，与具体时刻无关。
/// 序列化格式固定为 YYYY-MM-DD；Calendar 运算用公历 UTC，避免夏令时偏移。
struct BusinessDate: Codable, Hashable, Comparable, Sendable {
    /// 原始字符串，格式 YYYY-MM-DD（已通过校验）。
    let rawValue: String

    /// 从字符串创建；格式非法或日期不存在时返回 nil。
    /// 采用解析+格式化往返校验，拒绝 "2026-02-31" 这类滚动日期。
    init?(rawValue: String) {
        guard BusinessDate.isValidFormat(rawValue) else {
            return nil
        }
        self.rawValue = rawValue
    }

    /// 解码：必须是合法 YYYY-MM-DD 字符串，否则抛出 DecodingError。
    /// 未知格式不允许静默降级（与未知枚举不同，日期错误必须显式失败）。
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let date = BusinessDate(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "非法业务日期: \(rawValue)")
        }
        self = date
    }

    /// 编码为 YYYY-MM-DD 字符串。
    /// 与契约 "日期 YYYY-MM-DD" 一致。
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// 指定时区下的今天。
    /// 按公历取年月日，与设备当前时刻相关。
    static func today(timeZone: TimeZone) -> BusinessDate {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: Date())
        return BusinessDate(
            year: components.year ?? 1970,
            month: components.month ?? 1,
            day: components.day ?? 1
        )
    }

    /// 日历日加减，返回新的 BusinessDate。
    /// 纯日期运算（UTC 正午锚定之外的公历日加减），不受夏令时影响。
    func adding(days: Int) -> BusinessDate {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let formatter = BusinessDate.makeFormatter()
        guard let date = formatter.date(from: rawValue),
              let shifted = calendar.date(byAdding: .day, value: days, to: date) else {
            return self
        }
        return BusinessDate(validatedRawValue: formatter.string(from: shifted))
    }

    /// 字典序比较；零填充 YYYY-MM-DD 下等价于时间先后。
    static func < (lhs: BusinessDate, rhs: BusinessDate) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// 最小占位日期（用于可选范围比较的默认值）。
    static let distantPast = BusinessDate(year: 1, month: 1, day: 1)

    /// 最大占位日期（用于可选范围比较的默认值）。
    static let distantFuture = BusinessDate(year: 9999, month: 12, day: 31)

    /*
     * 内部非失败构造：仅用于本类型内部由合法成分拼装的场景。
     * 外部必须走 init?(rawValue:) 校验入口。
     */
    private init(year: Int, month: Int, day: Int) {
        rawValue = String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// 内部非失败构造：调用方保证字符串已通过校验。
    private init(validatedRawValue: String) {
        rawValue = validatedRawValue
    }

    /// 严格格式校验：长度、分隔符、公历可解析且往返一致。
    private static func isValidFormat(_ value: String) -> Bool {
        guard value.count == 10 else {
            return false
        }
        let formatter = makeFormatter()
        guard let date = formatter.date(from: value) else {
            return false
        }
        return formatter.string(from: date) == value
    }

    /// 每次新建 formatter（DateFormatter 非线程安全，不做共享缓存）。
    private static func makeFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }
}


/// 每日练习计划（POST /v1/children/{childId}/plans 返回）。
/// 已有基础计划重请求返回原计划；不同输入返回 PLAN_CONFLICT 与 existingPlanId。
struct Plan: Codable, Sendable {
    /// 计划 ID（UUID 字符串）。
    let id: String
    /// 所属儿童 ID。
    let childId: String
    /// 目标业务日期（YYYY-MM-DD）。
    let targetDate: BusinessDate
    /// 计划版本号。
    let revision: Int
    /// 日模式（new/review/unknown）。
    let dayMode: DayMode
    /// 教材版本 ID。
    let courseEditionId: String
    /// 计划内容版本标识。
    let contentVersion: String
    /// 生成计划时基于的进度版本号。
    let progressRevision: Int
    /// 预估总耗时（秒）。
    let estimatedSeconds: Int
    /// 练习条目列表。
    let items: [PlanItem]
    /// 完成判定策略。
    let completionPolicy: CompletionPolicy
}


/// 计划条目。
/// referenceText 由计划快照给出，客户端不得自定义文本覆盖评测基准。
struct PlanItem: Codable, Sendable {
    /// 条目 ID。
    let id: String
    /// 条目类型（repeat/freeExpression）。
    let type: PlanItemType
    /// 关联知识点 ID 列表。
    let knowledgePointIds: [String]
    /// 跟读参考文本（自由表达条目为 nil）。
    let referenceText: String?
    /// 展示给儿童的引导语。
    let prompt: String
    /// 建议耗时（秒）。
    let suggestedSeconds: Int
    /// 示范音频素材 ID（可能为 nil）。
    let exampleAudioId: String?
    /// 是否为必做条目。
    let required: Bool
}


/// 完成判定策略。
/// 不以录音时长或分数门槛判打卡；跳过原因仅限 allowedSkipReasons。
struct CompletionPolicy: Codable, Sendable {
    /// 必须处理的条目 ID 列表。
    let requiredItemIds: [String]
    /// 允许跳过的原因枚举值。
    let allowedSkipReasons: [String]
    /// 完成规则版本。
    let ruleVersion: String
}


extension Plan {
    /// 返回替换 childId/targetDate/progressRevision 后的副本。
    /// 仅供模拟服务把 fixture 对齐到请求参数使用。
    func alignedTo(childId: String, targetDate: BusinessDate, progressRevision: Int) -> Plan {
        Plan(
            id: id,
            childId: childId,
            targetDate: targetDate,
            revision: revision,
            dayMode: dayMode,
            courseEditionId: courseEditionId,
            contentVersion: contentVersion,
            progressRevision: progressRevision,
            estimatedSeconds: estimatedSeconds,
            items: items,
            completionPolicy: completionPolicy
        )
    }
}
