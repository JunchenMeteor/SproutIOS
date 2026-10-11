/// 后端服务抽象、统一错误模型与契约编解码设施（EC-API-0.1 第 5 节）。
/// 职责：定义 BackendService 协议、BackendError、契约 JSON 编解码与错误体映射。
/// 边界：协议只覆盖技术设计第 5 节已写明字段的操作；5.6 冻结缺口不新增方法或字段。
/// 副作用：无（纯抽象与映射）；实现方才进行网络/文件 IO。
/// 约束：修改命令必须携带 Idempotency-Key 并在重试时沿用；错误统一映射为 BackendError。
import Foundation


/// 后端统一错误。
/// message 面向家长/开发者，儿童提示由界面层另行映射；
/// 敏感凭据与供应商原始异常不进入错误。
enum BackendError: Error, Sendable {
    /// 400 INVALID_ARGUMENT，携带服务端 message。
    case invalidArgument(String)
    /// 401 AUTH_REQUIRED：需要登录。
    case authRequired
    /// 401 SESSION_EXPIRED：会话过期，需重新认证。
    case sessionExpired
    /// 403 FORBIDDEN：无权访问（跨账号对象也可统一用 notFound）。
    case forbidden
    /// 404 NOT_FOUND。
    case notFound
    /// 409 VERSION_CONFLICT，携带服务端当前 revision。
    case versionConflict(currentRevision: Int)
    /// 409 IDEMPOTENCY_CONFLICT：同幂等键不同请求。
    case idempotencyConflict
    /// 409 PLAN_CONFLICT，携带已有计划 ID。
    case planConflict(existingPlanId: String)
    /// 413 AUDIO_TOO_LARGE。
    case audioTooLarge
    /// 415 AUDIO_FORMAT_UNSUPPORTED。
    case audioFormatUnsupported
    /// 422 AUDIO_INVALID。
    case audioInvalid
    /// 422 DATE_NOT_ALLOWED。
    case dateNotAllowed
    /// 422 PLAN_NOT_COMPLETE。
    case planNotComplete
    /// 422 BACKUP_INVALID。
    case backupInvalid
    /// 429 QUOTA_EXCEEDED，携带 Retry-After（秒，若可知）。
    case quotaExceeded(retryAfterSeconds: Int?)
    /// 503 PROVIDER_UNAVAILABLE。
    case providerUnavailable
    /// 504 PROVIDER_TIMEOUT。
    case providerTimeout
    /// 网络不可用或首版未配置后端。
    case offline
    /// 兜底：未识别错误码或非契约错误体。
    case unknown(code: String, message: String, retryable: Bool)
}


extension BackendError {
    /// 是否可安全重试（不改变业务语义的重试）。
    /// 冲突/参数类错误重试无意义；限流/供应商/离线类可按界面策略重试。
    var retryable: Bool {
        switch self {
        case .quotaExceeded, .providerUnavailable, .providerTimeout, .offline:
            return true
        case .unknown(_, _, let flag):
            return flag
        default:
            return false
        }
    }
}


/// 契约 JSON 编解码设施。
/// Date 按 ISO-8601 UTC（兼容带/不带小数秒）；
/// BusinessDate 由自身 Codable 按 YYYY-MM-DD 字符串处理。
enum ContractJSON {
    /// 契约解码器：ISO-8601 日期自定义解码，BusinessDate 走自身单值字符串解码。
    /// 每次新建（JSONDecoder 非线程安全，不共享实例）。
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: text) {
                return date
            }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: text) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "非法 ISO-8601 时间: \(text)")
        }
        return decoder
    }

    /// 契约编码器：Date 输出 ISO-8601 UTC（带小数秒），BusinessDate 走自身编码。
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            try container.encode(formatter.string(from: date))
        }
        return encoder
    }
}


/// 成功响应统一信封：data + requestId。
/// fixtures 是裸 data 载荷，信封仅出现在真实响应中。
struct DataEnvelope<Payload: Decodable>: Decodable {
    /// 业务载荷。
    let data: Payload
    /// 请求标识（与 X-Request-Id 一致）。
    let requestId: String?
}


/// 任意 Encodable 的擦除包装。
/// 用于统一请求管线接受泛型请求体。
struct AnyEncodable: Encodable {
    /// 编码闭包。
    private let encodeClosure: (Encoder) throws -> Void

    /// 包装具体 Encodable 值。
    init<T: Encodable>(_ wrapped: T) {
        encodeClosure = { encoder in
            try wrapped.encode(to: encoder)
        }
    }

    /// 转发编码到被包装值。
    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}


/// 音频上传返回对象（POST /v1/audio）。
/// status/detectedFormat/sha256 均为服务端判定；expiresAt/retentionPolicy 待 5.6 冻结后再建模。
struct UploadedAudio: Codable, Sendable {
    /// 音频对象 ID。
    let id: String
    /// 服务端处理状态（如 received/ready/deleted）。
    let status: String
    /// 服务端探测到的实际格式。
    let detectedFormat: String
    /// 时长（毫秒），服务端未判定时为 nil。
    let durationMs: Int?
    /// 服务端计算的整文件 SHA-256。
    let sha256: String
}


/// 打卡记录分页（GET /v1/children/{childId}/check-ins 的 data）。
/// 按目标日期列记录；nextCursor 为 nil 表示没有更多。
struct CheckInPage: Codable, Sendable {
    /// 本页记录。
    let items: [CheckIn]
    /// 下一页游标（服务端不透明字符串）。
    let nextCursor: String?
}


/// 打卡详情（GET /v1/check-ins/{checkInId} 的 data）。
/// playableAudioId 可能为 nil 或指向已删除音频。
struct CheckInDetail: Codable, Sendable {
    /// 打卡记录本体。
    let checkIn: CheckIn
    /// 反馈摘要（待补齐时为 nil）。
    let feedbackSummary: Feedback?
    /// 可播放音频 ID（可能为 nil/已删除）。
    let playableAudioId: String?
}


/// 后端服务契约。
/// 所有方法 async throws；实现方包括真实 APIClient 与显式标注的 MockBackendService。
protocol BackendService: Sendable {
    /// 拉取启动引导数据（家长、儿童、配置、能力、同步游标）。
    /// 对应 GET /v1/bootstrap。
    func bootstrap() async throws -> Bootstrap

    /// 拉取可用且已获许可的教材摘要列表。
    /// 对应 GET /v1/courses；未准备的教材不能展示为可用。
    func fetchCourses() async throws -> [CourseEditionSummary]

    /// 拉取指定儿童的课程进度快照。
    /// 对应 GET /v1/children/{childId}/progress。
    func fetchProgress(childId: String) async throws -> ProgressSnapshot

    /// 创建某日计划；new 模式需家长显式确认，原子更新进度。
    /// 对应 POST /v1/children/{childId}/plans；冲突时抛 planConflict(existingPlanId:)。
    func createPlan(
        childId: String,
        targetDate: BusinessDate,
        dayMode: DayMode,
        expectedProgressRevision: Int,
        confirmedNewLessonId: String?
    ) async throws -> Plan

    /// 整文件上传录音（multipart）。
    /// 对应 POST /v1/audio；体积/格式受 configuration.audioLimits 限制。
    func uploadAudio(
        childId: String,
        planId: String,
        itemId: String,
        clientAttemptId: UUID,
        fileURL: URL,
        sha256: String,
        idempotencyKey: String
    ) async throws -> UploadedAudio

    /// 创建尝试；服务端可自动启动一次评测任务。
    /// 对应 POST /v1/attempts；referenceText/type 从计划快照读取，客户端不覆盖。
    func createAttempt(
        clientAttemptId: UUID,
        planId: String,
        itemId: String,
        audioId: String,
        clientCompletedAt: Date,
        idempotencyKey: String
    ) async throws -> Attempt

    /// 轮询评测任务。
    /// 对应 GET /v1/evaluations/{jobId}；供应商异步错误存于组件，轮询不应变成 5xx。
    func fetchEvaluation(jobId: String) async throws -> EvaluationJob

    /// 重试允许的失败组件（components 取值为 "stt"/"grammar"/"pronunciation"）。
    /// 对应 POST /v1/evaluations/{jobId}/retry；同请求去重，不能任意试刷供应商。
    func retryEvaluation(
        jobId: String,
        components: [String],
        expectedAttemptRevision: Int,
        idempotencyKey: String
    ) async throws -> EvaluationJob

    /// 家长确认转写文本，生成新分析版本，不篡改 providerTranscript。
    /// 对应 PUT /v1/attempts/{attemptId}/transcript。
    func confirmTranscript(
        attemptId: String,
        expectedRevision: Int,
        confirmedText: String,
        idempotencyKey: String
    ) async throws -> Attempt

    /// 提交打卡（补卡同端点，日期早于确认日且符合 makeupPolicy）。
    /// 对应 POST /v1/children/{childId}/check-ins；不以评测成功为前提。
    func createCheckIn(
        childId: String,
        planId: String,
        targetDate: BusinessDate,
        clientCompletionId: UUID,
        clientCompletedAt: Date,
        planRevision: Int,
        itemOutcomes: [ItemOutcome],
        idempotencyKey: String
    ) async throws -> CheckInResult

    /// 按目标日期范围分页列打卡记录。
    /// 对应 GET /v1/children/{childId}/check-ins?fromDate=&toDate=&cursor=。
    func listCheckIns(
        childId: String,
        from fromDate: BusinessDate?,
        to toDate: BusinessDate?,
        cursor: String?
    ) async throws -> CheckInPage

    /// 拉取打卡详情（反馈摘要与可播放音频）。
    /// 对应 GET /v1/check-ins/{checkInId}。
    func fetchCheckIn(checkInId: String) async throws -> CheckInDetail

    /// 拉取收藏快照。
    /// 对应 GET /v1/children/{childId}/collection；客户端不提交 unlock=true。
    func fetchCollection(childId: String) async throws -> CollectionSnapshot
}


/// EC-API-0.1 错误体到 BackendError 的映射器。
/// 边界：只做解析与映射；不发起网络、不写日志。
/// 副作用：无。
/// 约束：非 JSON 错误体安全降级为按状态码映射；未知 code 进入 unknown 而不是丢弃。
enum BackendErrorMapper {
    /// 由 HTTP 状态码与响应体映射错误。
    /// body 可解析时按 error.code 精确映射；否则按状态码降级映射。
    static func map(statusCode: Int, body: Data, retryAfterHeader: String?) -> BackendError {
        let retryAfter = retryAfterHeader.flatMap { Int($0) }
        do {
            let envelope = try ContractJSON.makeDecoder().decode(ErrorEnvelope.self, from: body)
            return mapCode(envelope.error, retryAfter: retryAfter)
        } catch {
            return fallback(statusCode: statusCode, retryAfter: retryAfter)
        }
    }

    /// URLError 到 BackendError 的映射。
    /// 断网类映射 offline；超时映射 providerTimeout；其余为可重试 unknown。
    static func map(urlError: URLError) -> BackendError {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost:
            return .offline
        case .timedOut:
            return .providerTimeout
        default:
            return .unknown(code: "NETWORK_\(urlError.code.rawValue)", message: "网络请求失败", retryable: true)
        }
    }

    /// 按契约错误码精确映射；带关联值的码单独处理，其余查表。
    private static func mapCode(_ error: ErrorEnvelope.ErrorBody, retryAfter: Int?) -> BackendError {
        switch error.code {
        case "INVALID_ARGUMENT":
            return .invalidArgument(error.message)
        case "VERSION_CONFLICT":
            return .versionConflict(currentRevision: error.details?.currentRevision ?? 0)
        case "PLAN_CONFLICT":
            return .planConflict(existingPlanId: error.details?.existingPlanId ?? "")
        case "QUOTA_EXCEEDED":
            return .quotaExceeded(retryAfterSeconds: retryAfter ?? error.details?.retryAfterSeconds)
        default:
            return simpleCodeMap[error.code]
                ?? .unknown(code: error.code, message: error.message, retryable: error.retryable ?? false)
        }
    }

    /// 非 JSON 错误体的降级映射（网关/边缘层错误可能没有契约包体）。
    private static func fallback(statusCode: Int, retryAfter: Int?) -> BackendError {
        if statusCode == 429 {
            return .quotaExceeded(retryAfterSeconds: retryAfter)
        }
        if let mapped = statusCodeMap[statusCode] {
            return mapped
        }
        return .unknown(
            code: "HTTP_\(statusCode)",
            message: "服务返回非 JSON 错误（HTTP \(statusCode)）",
            retryable: statusCode >= 500
        )
    }

    /// 无关联值错误码的查表映射。
    private static let simpleCodeMap: [String: BackendError] = [
        "AUTH_REQUIRED": .authRequired,
        "SESSION_EXPIRED": .sessionExpired,
        "FORBIDDEN": .forbidden,
        "NOT_FOUND": .notFound,
        "IDEMPOTENCY_CONFLICT": .idempotencyConflict,
        "AUDIO_TOO_LARGE": .audioTooLarge,
        "AUDIO_FORMAT_UNSUPPORTED": .audioFormatUnsupported,
        "AUDIO_INVALID": .audioInvalid,
        "DATE_NOT_ALLOWED": .dateNotAllowed,
        "PLAN_NOT_COMPLETE": .planNotComplete,
        "BACKUP_INVALID": .backupInvalid,
        "PROVIDER_UNAVAILABLE": .providerUnavailable,
        "PROVIDER_TIMEOUT": .providerTimeout
    ]

    /// 非 JSON 错误体时的状态码降级映射。
    private static let statusCodeMap: [Int: BackendError] = [
        400: .invalidArgument("请求参数非法"),
        401: .authRequired,
        403: .forbidden,
        404: .notFound,
        413: .audioTooLarge,
        415: .audioFormatUnsupported,
        503: .providerUnavailable,
        504: .providerTimeout
    ]
}


/// 契约错误信封：error { code, message, retryable, details? } + requestId。
/// 仅用于失败响应解析。
private struct ErrorEnvelope: Decodable {
    /// 错误体本体。
    struct ErrorBody: Decodable {
        /// 稳定错误码。
        let code: String
        /// 面向家长/开发者的消息。
        let message: String
        /// 服务端建议的可重试性。
        let retryable: Bool?
        /// 附加细节（尽力解析）。
        let details: ErrorDetails?
    }

    /// 错误本体。
    let error: ErrorBody
    /// 请求标识（与响应 header X-Request-Id 一致）。
    let requestId: String?
}


/// 错误 details 的尽力解析。
/// 仅提取客户端冲突恢复/限流等待所需字段；敏感信息不进入 details（契约要求）。
private struct ErrorDetails: Decodable {
    /// VERSION_CONFLICT 时服务端当前 revision。
    let currentRevision: Int?
    /// PLAN_CONFLICT 时已有计划 ID。
    let existingPlanId: String?
    /// QUOTA_EXCEEDED 时建议等待秒数。
    let retryAfterSeconds: Int?
}
