/// 真实 HTTP 客户端骨架（EC-API-0.1）。
/// 职责：按契约路径发起 JSON 请求，
///       统一注入 ClientContext 诊断 headers、Authorization 与 Idempotency-Key。
/// 边界：首版 baseURL 为 nil，所有调用抛 BackendError.offline，由模拟服务接管；
///       multipart 上传未实现。
/// 副作用：网络 IO；读取 tokenProvider；更新 lastRequestId。
/// 约束：仅向 baseURL 同源请求注入 Authorization；
///       修改命令幂等键由调用方传入并在重试时沿用；
///       Date 按 ISO-8601 UTC 编解码，BusinessDate 依赖自身 Codable 按 "YYYY-MM-DD" 字符串处理。
import Foundation


/// 基于 URLSession 的契约客户端；actor 隔离保证并发安全与 Sendable。
/// 设计路径统一 /v1；传输细节委托 ContractTransport，本类型只维护会话级状态。
actor APIClient: BackendService {
    /// 传输层；nil 表示首版未配置后端，所有调用抛 offline。
    private let transport: ContractTransport?
    /// 最近一次响应的 requestId（X-Request-Id header）。
    private(set) var lastRequestId: String?

    /// 创建客户端。
    /// baseURL 为 nil 时所有调用抛 BackendError.offline（首版默认，由模拟服务接管）。
    init(
        baseURL: URL?,
        session: URLSession = .shared,
        context: ClientContext,
        tokenProvider: @escaping @Sendable () -> String?
    ) {
        transport = baseURL.map {
            ContractTransport(baseURL: $0, session: session, context: context, tokenProvider: tokenProvider)
        }
    }

    /// 拉取启动引导数据（GET /v1/bootstrap）。
    func bootstrap() async throws -> Bootstrap {
        try await call(method: "GET", path: "/v1/bootstrap")
    }

    /// 拉取教材摘要列表（GET /v1/courses）。
    func fetchCourses() async throws -> [CourseEditionSummary] {
        try await call(method: "GET", path: "/v1/courses")
    }

    /// 拉取课程进度（GET /v1/children/{childId}/progress）。
    func fetchProgress(childId: String) async throws -> ProgressSnapshot {
        try await call(method: "GET", path: "/v1/children/\(childId)/progress")
    }

    /// 创建计划（POST /v1/children/{childId}/plans）。
    /// 协议未暴露幂等键参数，首版自动生成；
    /// 已有计划重请求由服务端去重或返回 PLAN_CONFLICT。
    func createPlan(
        childId: String, targetDate: BusinessDate, dayMode: DayMode,
        expectedProgressRevision: Int, confirmedNewLessonId: String?
    ) async throws -> Plan {
        let body = CreatePlanBody(
            targetDate: targetDate, dayMode: dayMode,
            expectedProgressRevision: expectedProgressRevision, confirmedNewLessonId: confirmedNewLessonId
        )
        return try await call(
            method: "POST", path: "/v1/children/\(childId)/plans",
            body: body, idempotencyKey: UUID().uuidString
        )
    }

    /// 整文件上传录音（POST /v1/audio，multipart）。
    /// 待真实后端联调时实现：multipart 边界由平台库生成，
    /// 幂等摘要按解析字段与文件哈希计算。
    /// 首版由模拟服务接管，这里显式抛错而不是伪造成功。
    func uploadAudio(
        childId _: String, planId _: String, itemId _: String, clientAttemptId _: UUID,
        fileURL _: URL, sha256 _: String, idempotencyKey _: String
    ) async throws -> UploadedAudio {
        throw BackendError.unknown(
            code: "NOT_IMPLEMENTED", message: "multipart 上传未实现（模拟服务接管）", retryable: false
        )
    }

    /// 创建尝试（POST /v1/attempts）。
    /// 服务端可自动启动评测任务；客户端不再额外启动重复任务。
    func createAttempt(
        clientAttemptId: UUID, planId: String, itemId: String, audioId: String,
        clientCompletedAt: Date, idempotencyKey: String
    ) async throws -> Attempt {
        let body = CreateAttemptBody(
            clientAttemptId: clientAttemptId, planId: planId, itemId: itemId,
            audioId: audioId, clientCompletedAt: clientCompletedAt
        )
        return try await call(method: "POST", path: "/v1/attempts", body: body, idempotencyKey: idempotencyKey)
    }

    /// 轮询评测任务（GET /v1/evaluations/{jobId}）。
    func fetchEvaluation(jobId: String) async throws -> EvaluationJob {
        try await call(method: "GET", path: "/v1/evaluations/\(jobId)")
    }

    /// 重试允许的失败组件（POST /v1/evaluations/{jobId}/retry）。
    /// 重试沿用同一 Idempotency-Key 由调用方保证。
    func retryEvaluation(
        jobId: String, components: [String], expectedAttemptRevision: Int, idempotencyKey: String
    ) async throws -> EvaluationJob {
        let body = RetryEvaluationBody(components: components, expectedAttemptRevision: expectedAttemptRevision)
        return try await call(
            method: "POST", path: "/v1/evaluations/\(jobId)/retry", body: body, idempotencyKey: idempotencyKey
        )
    }

    /// 家长确认转写（PUT /v1/attempts/{attemptId}/transcript）。
    /// parentConfirmed 恒为 true；不篡改 providerTranscript。
    func confirmTranscript(
        attemptId: String, expectedRevision: Int, confirmedText: String, idempotencyKey: String
    ) async throws -> Attempt {
        let body = ConfirmTranscriptBody(
            expectedRevision: expectedRevision, confirmedText: confirmedText, parentConfirmed: true
        )
        return try await call(
            method: "PUT", path: "/v1/attempts/\(attemptId)/transcript", body: body, idempotencyKey: idempotencyKey
        )
    }

    /// 提交打卡（POST /v1/children/{childId}/check-ins）。
    /// 补卡同端点；重复日期由服务端返回已有确认状态。
    func createCheckIn(
        childId: String, planId: String, targetDate: BusinessDate, clientCompletionId: UUID,
        clientCompletedAt: Date, planRevision: Int, itemOutcomes: [ItemOutcome], idempotencyKey: String
    ) async throws -> CheckInResult {
        let body = CreateCheckInBody(
            planId: planId, targetDate: targetDate, clientCompletionId: clientCompletionId,
            clientCompletedAt: clientCompletedAt, planRevision: planRevision, itemOutcomes: itemOutcomes
        )
        return try await call(
            method: "POST", path: "/v1/children/\(childId)/check-ins", body: body, idempotencyKey: idempotencyKey
        )
    }

    /// 分页列打卡记录（GET /v1/children/{childId}/check-ins）。
    /// from/to 按 YYYY-MM-DD 业务日期传递；cursor 为服务端不透明字符串。
    func listCheckIns(
        childId: String, from fromDate: BusinessDate?, to toDate: BusinessDate?, cursor: String?
    ) async throws -> CheckInPage {
        var queryItems: [URLQueryItem] = []
        if let fromDate {
            queryItems.append(URLQueryItem(name: "fromDate", value: fromDate.rawValue))
        }
        if let toDate {
            queryItems.append(URLQueryItem(name: "toDate", value: toDate.rawValue))
        }
        if let cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return try await call(method: "GET", path: "/v1/children/\(childId)/check-ins", queryItems: queryItems)
    }

    /// 拉取打卡详情（GET /v1/check-ins/{checkInId}）。
    func fetchCheckIn(checkInId: String) async throws -> CheckInDetail {
        try await call(method: "GET", path: "/v1/check-ins/\(checkInId)")
    }

    /// 拉取收藏快照（GET /v1/children/{childId}/collection）。
    func fetchCollection(childId: String) async throws -> CollectionSnapshot {
        try await call(method: "GET", path: "/v1/children/\(childId)/collection")
    }

    /// 统一入口：未配置后端时抛 offline；成功时记录 requestId。
    private func call<Response: Decodable>(
        method: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        body: (any Encodable)? = nil,
        idempotencyKey: String? = nil
    ) async throws -> Response {
        guard let transport else {
            throw BackendError.offline
        }
        let (payload, requestId): (Response, String?) = try await transport.request(
            method: method, path: path, queryItems: queryItems, body: body, idempotencyKey: idempotencyKey
        )
        lastRequestId = requestId
        return payload
    }
}


/// 契约传输层：URL 拼装、header 注入、发送与错误映射（仅供 APIClient 使用）。
/// 边界：无会话状态；每次调用独立。
/// 副作用：网络 IO。
/// 约束：仅向 baseURL 同源请求注入 Authorization；非 2xx 统一走 BackendErrorMapper。
struct ContractTransport: Sendable {
    /// App API 基址。
    let baseURL: URL
    /// 网络会话。
    let session: URLSession
    /// 客户端上下文（诊断 headers 来源）。
    let context: ClientContext
    /// 会话令牌提供者；返回 nil 则不带 Authorization。
    let tokenProvider: @Sendable () -> String?

    /*
     * 统一请求管线：拼 URL → 注入诊断/认证/幂等 headers → 编码 body → 发送 →
     * 非 2xx 走错误映射 → 按 data 信封解码。返回载荷与 X-Request-Id。
     */
    func request<Response: Decodable>(
        method: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        body: (any Encodable)? = nil,
        idempotencyKey: String? = nil
    ) async throws -> (Response, String?) {
        let url = try makeURL(path: path, queryItems: queryItems)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        for (name, value) in context.makeHeaders() {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }
        if let token = tokenProvider(), isSameOrigin(url) {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let idempotencyKey {
            urlRequest.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }
        if let body {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                urlRequest.httpBody = try ContractJSON.makeEncoder().encode(AnyEncodable(body))
            } catch {
                throw BackendError.unknown(code: "ENCODE_FAILED", message: "请求体编码失败", retryable: false)
            }
        }
        let (data, httpResponse) = try await perform(urlRequest)
        guard (200..<300).contains(httpResponse.statusCode) else {
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
            throw BackendErrorMapper.map(statusCode: httpResponse.statusCode, body: data, retryAfterHeader: retryAfter)
        }
        do {
            let payload = try ContractJSON.makeDecoder().decode(DataEnvelope<Response>.self, from: data).data
            return (payload, httpResponse.value(forHTTPHeaderField: "X-Request-Id"))
        } catch {
            throw BackendError.unknown(code: "DECODE_FAILED", message: "响应解析失败", retryable: false)
        }
    }

    /// 发送请求并返回数据与 HTTP 响应；URLError 统一映射为 BackendError。
    private func perform(_ urlRequest: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw BackendError.unknown(code: "INVALID_RESPONSE", message: "非 HTTP 响应", retryable: true)
            }
            return (data, httpResponse)
        } catch let error as BackendError {
            throw error
        } catch let urlError as URLError {
            throw BackendErrorMapper.map(urlError: urlError)
        }
    }

    /// 拼接请求 URL：基址 + /v1 路径 + 查询项。
    private func makeURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw BackendError.invalidArgument("baseURL 无法解析")
        }
        components.path = components.path + path
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else {
            throw BackendError.invalidArgument("请求路径非法: \(path)")
        }
        return url
    }

    /// 判断目标 URL 是否与 baseURL 同源（scheme + host）。
    /// Authorization 仅在同源时注入，防止重定向透传到其他域名。
    private func isSameOrigin(_ url: URL) -> Bool {
        let target = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let base = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        return target?.host != nil && target?.scheme == base?.scheme && target?.host == base?.host
    }
}


/// 创建计划请求体（POST /v1/children/{childId}/plans）。
private struct CreatePlanBody: Encodable {
    /// 目标业务日期。
    let targetDate: BusinessDate
    /// 日模式。
    let dayMode: DayMode
    /// 基于的进度版本号。
    let expectedProgressRevision: Int
    /// new 模式家长确认的新课次 ID。
    let confirmedNewLessonId: String?
}


/// 创建尝试请求体（POST /v1/attempts）。
private struct CreateAttemptBody: Encodable {
    /// 客户端尝试标识。
    let clientAttemptId: UUID
    /// 计划 ID。
    let planId: String
    /// 条目 ID。
    let itemId: String
    /// 音频对象 ID。
    let audioId: String
    /// 客户端完成时间。
    let clientCompletedAt: Date
}


/// 评测重试请求体（POST /v1/evaluations/{jobId}/retry）。
private struct RetryEvaluationBody: Encodable {
    /// 待重试组件名列表。
    let components: [String]
    /// 期望的尝试版本号。
    let expectedAttemptRevision: Int
}


/// 转写确认请求体（PUT /v1/attempts/{attemptId}/transcript）。
private struct ConfirmTranscriptBody: Encodable {
    /// 期望的尝试版本号。
    let expectedRevision: Int
    /// 家长确认后的文本。
    let confirmedText: String
    /// 家长确认标记（恒 true）。
    let parentConfirmed: Bool
}


/// 打卡请求体（POST /v1/children/{childId}/check-ins）。
private struct CreateCheckInBody: Encodable {
    /// 计划 ID。
    let planId: String
    /// 目标业务日期（必须等于 plan.targetDate）。
    let targetDate: BusinessDate
    /// 客户端完成标识（晚到录音关联用）。
    let clientCompletionId: UUID
    /// 客户端完成时间。
    let clientCompletedAt: Date
    /// 提交基于的计划版本号。
    let planRevision: Int
    /// 各条目结果。
    let itemOutcomes: [ItemOutcome]
}
