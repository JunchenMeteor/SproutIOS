/// 模拟后端服务：基于 contracts/fixtures 的演示数据，支持多场景切换。
/// 职责：在无后端阶段支撑界面联调与离线流程演示；界面与报告必须标注"模拟服务"。
/// 边界：不产生真实网络请求；数据全部来自 fixture 或内存构造的演示值，
///       不自称云端评测通过。
/// 副作用：0.3–0.8 秒随机延迟模拟网络；内存缓存 plan/attempt/checkIn（随进程结束消失）。
/// 约束：遵循 BackendService 契约形状；不发明 5.6 冻结缺口中的接口；重复日期不发奖。
import Foundation


/// 显式标注的模拟服务实现（serviceLabel = "模拟服务"，isMock 恒为 true）。
/// 内部状态由 NSLock 保护，类标注 @unchecked Sendable。
final class MockBackendService: BackendService, @unchecked Sendable {
    /// 恒为 true：标识这是模拟服务，界面据此展示"模拟服务"标注。
    static let isMock = true

    /// 界面可见的模拟服务标注文案。
    let serviceLabel = "模拟服务"

    /// fixture 所在 Bundle（默认 .main，测试可注入）。
    private let bundle: Bundle
    /// 契约解码器。
    private let decoder = ContractJSON.makeDecoder()
    /// 状态锁。
    private let lock = NSLock()
    /// 可变内存状态（场景、已创建实体缓存）。
    private var state = MockState()

    /// 创建模拟服务。
    /// bundle 默认 .main；fixtures 需以文件夹引用形式打入资源（fixtures 子目录）。
    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    /// 当前场景；切换立即生效（线程安全）。
    var scenario: MockScenario {
        get { withState { $0.scenario } }
        set { withState { $0.scenario = newValue } }
    }

    /// 拉取启动引导数据（bootstrap.json）。
    func bootstrap() async throws -> Bootstrap {
        try await prepare()
        return try FixtureLoader.load("bootstrap", bundle: bundle, decoder: decoder)
    }

    /// 拉取教材摘要（无对应 fixture，返回内存演示值）。
    func fetchCourses() async throws -> [CourseEditionSummary] {
        try await prepare()
        return [DemoCatalog.course]
    }

    /// 拉取课程进度（无对应 fixture，返回内存演示值）。
    func fetchProgress(childId _: String) async throws -> ProgressSnapshot {
        try await prepare()
        return DemoCatalog.progress
    }

    /// 创建计划：按 dayMode 取 plan-new/plan-review fixture，对齐请求参数后缓存。
    /// 携带 expectedProgressRevision，versionConflict 场景下抛 versionConflict。
    func createPlan(
        childId: String,
        targetDate: BusinessDate,
        dayMode: DayMode,
        expectedProgressRevision: Int,
        confirmedNewLessonId _: String?
    ) async throws -> Plan {
        try await prepare(versionConflictAllowed: true)
        let name = dayMode == .review ? "plan-review" : "plan-new"
        let fixture: Plan = try FixtureLoader.load(name, bundle: bundle, decoder: decoder)
        let plan = fixture.alignedTo(
            childId: childId, targetDate: targetDate, progressRevision: expectedProgressRevision
        )
        withState { $0.plans[plan.id] = plan }
        return plan
    }

    /// 模拟音频上传：不读取文件内容，直接返回服务端已接收的演示对象。
    /// 真实哈希校验、体积/格式限制由后端负责，模拟服务不伪造校验失败。
    func uploadAudio(
        childId _: String, planId _: String, itemId _: String, clientAttemptId _: UUID,
        fileURL _: URL, sha256: String, idempotencyKey _: String
    ) async throws -> UploadedAudio {
        try await prepare()
        return UploadedAudio(
            id: UUID().uuidString, status: "ready", detectedFormat: "m4a",
            durationMs: 4_200, sha256: sha256
        )
    }

    /// 创建尝试并缓存；同一 clientAttemptId 重放返回原尝试（幂等语义）。
    func createAttempt(
        clientAttemptId: UUID,
        planId: String,
        itemId: String,
        audioId: String,
        clientCompletedAt _: Date,
        idempotencyKey _: String
    ) async throws -> Attempt {
        try await prepare()
        let existing = withState { $0.attempts.values.first { $0.clientAttemptId == clientAttemptId } }
        if let existing {
            return existing
        }
        let attempt = Attempt(
            id: UUID().uuidString, revision: 1, planId: planId, itemId: itemId, audioId: audioId,
            clientAttemptId: clientAttemptId, selected: true,
            evaluationJobId: UUID().uuidString, evaluationState: .queued
        )
        withState { $0.attempts[attempt.id] = attempt }
        return attempt
    }

    /// 轮询评测：按场景取 success/partial/noConfidence fixture，并对齐请求的 jobId。
    func fetchEvaluation(jobId: String) async throws -> EvaluationJob {
        try await prepare()
        let name = withState { $0.scenario }.evaluationFixtureName
        let fixture: EvaluationJob = try FixtureLoader.load(name, bundle: bundle, decoder: decoder)
        return fixture.withId(jobId)
    }

    /// 重试评测：versionConflict 场景抛 versionConflict，否则返回成功 fixture（演示重试恢复）。
    func retryEvaluation(
        jobId: String,
        components _: [String],
        expectedAttemptRevision _: Int,
        idempotencyKey _: String
    ) async throws -> EvaluationJob {
        try await prepare(versionConflictAllowed: true)
        let fixture: EvaluationJob = try FixtureLoader.load("evaluation-success", bundle: bundle, decoder: decoder)
        return fixture.withId(jobId)
    }

    /// 确认转写：内存中查找尝试并递增 revision；未找到抛 notFound。
    func confirmTranscript(
        attemptId: String,
        expectedRevision: Int,
        confirmedText _: String,
        idempotencyKey _: String
    ) async throws -> Attempt {
        try await prepare(versionConflictAllowed: true)
        guard let attempt = withState({ $0.attempts[attemptId] }) else {
            throw BackendError.notFound
        }
        let confirmed = attempt.withRevision(expectedRevision + 1)
        withState { $0.attempts[attemptId] = confirmed }
        return confirmed
    }

    /// 提交打卡：同一 childId+targetDate 重复提交返回 checkin-duplicate 语义（不再发奖）。
    /// duplicateDate 场景强制走重复分支；成功后缓存记录供 listCheckIns/fetchCheckIn 使用。
    func createCheckIn(
        childId: String,
        planId _: String,
        targetDate: BusinessDate,
        clientCompletionId _: UUID,
        clientCompletedAt: Date,
        planRevision _: Int,
        itemOutcomes _: [ItemOutcome],
        idempotencyKey _: String
    ) async throws -> CheckInResult {
        try await prepare(versionConflictAllowed: true)
        let key = "\(childId)|\(targetDate.rawValue)"
        let isDuplicate = withState { $0.checkInKeys.contains(key) }
        if isDuplicate || withState({ $0.scenario }) == .duplicateDate {
            return try FixtureLoader.load("checkin-duplicate", bundle: bundle, decoder: decoder)
        }
        let result: CheckInResult = try FixtureLoader.load("checkin-success", bundle: bundle, decoder: decoder)
        let checkIn = result.checkIn.alignedTo(targetDate: targetDate, clientCompletedAt: clientCompletedAt)
        withState {
            $0.checkInKeys.insert(key)
            $0.checkIns.append(checkIn)
        }
        return result.withCheckIn(checkIn)
    }

    /// 分页列打卡：基于内存已创建记录，按目标日期倒序，cursor 为偏移量字符串。
    func listCheckIns(
        childId _: String,
        from fromDate: BusinessDate?,
        to toDate: BusinessDate?,
        cursor: String?
    ) async throws -> CheckInPage {
        try await prepare()
        let lowerBound = fromDate ?? .distantPast
        let upperBound = toDate ?? .distantFuture
        let filtered = withState { state in
            state.checkIns
                .filter { $0.targetDate >= lowerBound && $0.targetDate <= upperBound }
                .sorted { $0.targetDate > $1.targetDate }
        }
        let offset = cursor.flatMap { Int($0) } ?? 0
        let slice = filtered.dropFirst(offset).prefix(20)
        let nextOffset = offset + slice.count
        let nextCursor = nextOffset < filtered.count ? String(nextOffset) : nil
        return CheckInPage(items: Array(slice), nextCursor: nextCursor)
    }

    /// 打卡详情：仅 success 场景附带 evaluation-success 的反馈摘要，
    /// 其余场景为 nil（演示反馈待补）。
    func fetchCheckIn(checkInId: String) async throws -> CheckInDetail {
        try await prepare()
        guard let checkIn = withState({ state in state.checkIns.first { $0.id == checkInId } }) else {
            throw BackendError.notFound
        }
        var feedback: Feedback?
        if withState({ $0.scenario }) == .success {
            let job: EvaluationJob = try FixtureLoader.load("evaluation-success", bundle: bundle, decoder: decoder)
            feedback = job.feedback
        }
        return CheckInDetail(checkIn: checkIn, feedbackSummary: feedback, playableAudioId: nil)
    }

    /// 拉取收藏快照（collection.json）。
    func fetchCollection(childId _: String) async throws -> CollectionSnapshot {
        try await prepare()
        return try FixtureLoader.load("collection", bundle: bundle, decoder: decoder)
    }

    /*
     * 模拟网络延迟（0.3–0.8 秒随机）后应用场景闸门；
     * versionConflict 只对携带 revision 的修改命令生效（调用方传 true）。
     */
    private func prepare(versionConflictAllowed: Bool = false) async throws {
        try await Task.sleep(for: .milliseconds(Int.random(in: 300...800)))
        if let error = withState({ $0.scenario }).immediateError(versionConflictAllowed: versionConflictAllowed) {
            throw error
        }
    }

    /// 在锁内读写内存状态。
    private func withState<T>(_ body: (inout MockState) -> T) -> T {
        lock.withLock { body(&state) }
    }
}


/// 模拟场景。
/// 覆盖契约要求的演示路径：
/// 成功/部分失败/无置信度/超时/权限失效/版本冲突/重复日期/离线。
enum MockScenario: String, CaseIterable, Sendable {
    /// 全部成功。
    case success
    /// 评测部分失败（发音组件 failed + retryable）。
    case partialFailure
    /// 转写无置信度（quality: insufficient，grammar 跳过）。
    case noConfidence
    /// 所有调用抛 providerTimeout。
    case timeout
    /// 权限失效：所有调用抛 forbidden。
    case permissionRevoked
    /// 携带 revision 的修改命令抛 versionConflict(currentRevision: 2)。
    case versionConflict
    /// 打卡强制返回重复日期语义（不再发奖）。
    case duplicateDate
    /// 所有调用抛 offline。
    case offline
}


extension MockScenario {
    /// 场景对应的立即失败错误；返回 nil 表示放行。
    /// versionConflict 仅在命令携带 revision 时触发。
    func immediateError(versionConflictAllowed: Bool) -> BackendError? {
        switch self {
        case .offline: return .offline
        case .timeout: return .providerTimeout
        case .permissionRevoked: return .forbidden
        case .versionConflict where versionConflictAllowed: return .versionConflict(currentRevision: 2)
        default: return nil
        }
    }

    /// 当前场景下 fetchEvaluation 使用的 fixture 名。
    var evaluationFixtureName: String {
        switch self {
        case .partialFailure: return "evaluation-partial"
        case .noConfidence: return "evaluation-noconfidence"
        default: return "evaluation-success"
        }
    }
}


/// 模拟服务可变内存状态。
/// 由 MockBackendService 的锁保护，不直接对外暴露。
private struct MockState {
    /// 当前场景。
    var scenario: MockScenario = .success
    /// 已创建计划（按 planId）。
    var plans: [String: Plan] = [:]
    /// 已创建尝试（按 attemptId）。
    var attempts: [String: Attempt] = [:]
    /// 已确认打卡记录。
    var checkIns: [CheckIn] = []
    /// 已打卡的 childId|targetDate 键集合（重复日期判定）。
    var checkInKeys: Set<String> = []
}


/// fixture 加载器：从 Bundle 读取 JSON 并解码。
/// 边界：仅供模拟服务使用；找不到 fixture 时抛 unknown，不静默成功。
/// 副作用：文件 IO。
/// 约束：fixtures 需以文件夹引用（folder reference）打入资源；
///       找不到子目录时回退 Bundle 根目录。
private enum FixtureLoader {
    /// 读取并解码指定 fixture（不含扩展名）。
    /// 优先 fixtures 子目录，回退 Bundle 根目录；缺失或解析失败抛 unknown。
    static func load<T: Decodable>(_ name: String, bundle: Bundle, decoder: JSONDecoder) throws -> T {
        let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "fixtures")
            ?? bundle.url(forResource: name, withExtension: "json")
        guard let url else {
            throw BackendError.unknown(
                code: "FIXTURE_MISSING",
                message: "缺少 fixture: \(name).json",
                retryable: false
            )
        }
        do {
            return try decoder.decode(T.self, from: Data(contentsOf: url))
        } catch {
            throw BackendError.unknown(
                code: "FIXTURE_INVALID",
                message: "fixture 解析失败: \(name).json",
                retryable: false
            )
        }
    }
}


/// 演示数据常量：fetchCourses/fetchProgress 无对应 fixture，用内存演示值保持界面流程连贯。
/// 约束：虚构教材与进度，仅用于模拟服务，不得展示为真实课程。
private enum DemoCatalog {
    /// 虚构演示教材（与 plan fixture 的 courseEditionId 一致）。
    static let course = CourseEditionSummary(
        id: "course-demo-starter",
        title: "Demo English Starter",
        publisherNote: "虚构演示教材，仅用于界面联调。",
        licensed: true
    )

    /// 虚构演示进度快照。
    static let progress = ProgressSnapshot(
        courseEditionId: "course-demo-starter",
        confirmedLessonIds: ["lesson-demo-1"],
        confirmedKnowledgePointIds: ["kp-demo-greeting"],
        revision: 1,
        confirmedAt: nil
    )
}
