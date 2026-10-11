/// 尝试与评测模型（EC-API-0.1 第 5.2 节）。
/// 边界：仅建模契约字段；pronunciation 的 phonemeDetails 按任务约定省略，
///       wordDetails 简化为字符串数组。
/// 副作用：无；纯值类型。
/// 约束：EvaluationComponent 分类型载荷用三个可选属性承载（契约的 result? 在客户端拆型），
///       同一组件至多一个非 nil；缺失数据不得当作低分或失败。
import Foundation


/// 练习尝试（POST /v1/attempts 返回）。
/// 创建 attempt 可自动启动一次评测任务；客户端不再额外启动重复任务。
struct Attempt: Codable, Sendable {
    /// 尝试 ID（UUID 字符串）。
    let id: String
    /// 尝试版本号（人工确认转写后递增）。
    let revision: Int
    /// 所属计划 ID。
    let planId: String
    /// 所属条目 ID。
    let itemId: String
    /// 关联音频对象 ID（可能尚未上传完成）。
    let audioId: String?
    /// 客户端生成的尝试标识（离线重放时保持不变）。
    let clientAttemptId: UUID
    /// 是否为当前选中提交（重录选择语义待 5.6 冻结，首版仅提交前本地选择）。
    let selected: Bool
    /// 关联评测任务 ID。
    let evaluationJobId: String?
    /// 评测任务状态快照（可能为 nil）。
    let evaluationState: EvaluationJobStatus?
}


/// 评测任务（GET /v1/evaluations/{jobId} 返回）。
/// 异步供应商错误通常存入组件而非让轮询返回 5xx。
struct EvaluationJob: Codable, Sendable {
    /// 任务 ID。
    let id: String
    /// 所属尝试 ID。
    let attemptId: String
    /// 任务整体状态。
    let status: EvaluationJobStatus
    /// 三个评测组件。
    let components: EvaluationComponents
    /// 汇总反馈（任务未产出时为 nil）。
    let feedback: Feedback?
    /// 建议的下一次轮询间隔（毫秒），终态为 nil。
    let nextPollAfterMs: Int?
}


/// 评测组件集合。
/// 组件可整体缺席（nil），缺席不等于失败。
struct EvaluationComponents: Codable, Sendable {
    /// 语音转写组件。
    let stt: EvaluationComponent?
    /// 语法组件。
    let grammar: EvaluationComponent?
    /// 发音组件。
    let pronunciation: EvaluationComponent?
}


/// 单个评测组件。
/// 分类型载荷以 sttResult/grammarResult/pronunciationResult 三个可选属性承载，至多一个非 nil。
struct EvaluationComponent: Codable, Sendable {
    /// 组件状态。
    let status: EvaluationComponentStatus
    /// 失败/跳过原因码（面向开发者的稳定标识）。
    let reasonCode: String?
    /// 是否允许客户端发起重试。
    let retryable: Bool
    /// 实际执行的供应商标识。
    let provider: String?
    /// 转写结果载荷（仅 stt 组件）。
    let sttResult: SttResult?
    /// 语法结果载荷（仅 grammar 组件）。
    let grammarResult: GrammarResult?
    /// 发音结果载荷（仅 pronunciation 组件）。
    let pronunciationResult: PronunciationResult?
}


/// 转写结果。
/// confidence 仅在供应商确实提供且说明尺度时存在；不篡改 providerTranscript。
struct SttResult: Codable, Sendable {
    /// 供应商原始转写文本。
    let providerTranscript: String
    /// 转写来源标识。
    let transcriptSource: String
    /// 转写版本号（人工确认生成新版本）。
    let transcriptRevision: Int
    /// 转写质量评级。
    let quality: TranscriptQuality
    /// 供应商置信度（可能为 nil）。
    let confidence: Double?
}


/// 语法结果。
/// encouragement 必填；数值不作为成功门槛。
struct GrammarResult: Codable, Sendable {
    /// 原始文本。
    let originalText: String
    /// 纠正后文本（无需纠正时为 nil）。
    let correctedText: String?
    /// 给儿童的提示（界面可见文案）。
    let childTip: String?
    /// 鼓励语（界面可见文案）。
    let encouragement: String
    /// 给家长的详细说明。
    let parentDetails: String?
}


/// 发音结果。
/// 细节字段只有供应商真实返回时才存在；未接入自由表达发音时组件应为 skipped。
struct PronunciationResult: Codable, Sendable {
    /// 供应商分数尺度说明（如 "0-100"）。
    let providerScale: String
    /// 供应商分数（可能为 nil）。
    let providerScore: Double?
    /// 逐词说明（简化为字符串数组）。
    let wordDetails: [String]?
    /// 是否有可回溯的评测证据。
    let evidenceAvailable: Bool
}


/// 汇总反馈。
/// 儿童提示与鼓励语面向界面展示；家长说明可选。
struct Feedback: Codable, Sendable {
    /// 给儿童的提示。
    let childTip: String
    /// 鼓励语。
    let encouragement: String
    /// 给家长的详细说明。
    let parentDetails: String?
}


extension EvaluationJob {
    /// 返回仅替换 id 的副本。
    /// 仅供模拟服务把 fixture 对齐到请求的 jobId 使用。
    func withId(_ id: String) -> EvaluationJob {
        EvaluationJob(
            id: id,
            attemptId: attemptId,
            status: status,
            components: components,
            feedback: feedback,
            nextPollAfterMs: nextPollAfterMs
        )
    }
}


extension Attempt {
    /// 返回仅替换 revision 的副本。
    /// 仅供模拟服务在确认转写后递增版本号使用。
    func withRevision(_ revision: Int) -> Attempt {
        Attempt(
            id: id,
            revision: revision,
            planId: planId,
            itemId: itemId,
            audioId: audioId,
            clientAttemptId: clientAttemptId,
            selected: selected,
            evaluationJobId: evaluationJobId,
            evaluationState: evaluationState
        )
    }
}
