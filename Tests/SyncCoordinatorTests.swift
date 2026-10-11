/// SyncCoordinator 联网恢复编排测试。
/// 用 MockBackendService（注入场景）+ 临时目录 OfflineQueue 验证：
/// 成功 drain 清空队列并调用后端、离线保留条目并递增 retryCount、
/// 重试沿用稳定幂等键、不可重试错误进入人工处理、非 checkIn 条目跳过、账号隔离。
/// 幂等键观测：MockBackendService 不记录入参，经 RecordingBackend 转发层断言。
@testable import Sprout
import XCTest

@MainActor
final class SyncCoordinatorTests: XCTestCase {
    /// 每个用例独立的临时目录。
    private var directory: URL?

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SyncCoordinatorTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        if let directory, FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        directory = nil
    }

    /// 注入临时目录创建队列；目录由 setUp 准备好。
    private func makeQueue() throws -> OfflineQueue {
        guard let directory else {
            throw NSError(domain: "SyncCoordinatorTests", code: 1)
        }
        return try OfflineQueue(directory: directory)
    }

    /// 构造一条 checkIn 待同步操作（载荷与练习页入队编码一致）。
    private func makeCheckInOperation(
        id: UUID = UUID(),
        accountID: String
    ) throws -> PendingOperation {
        guard let date = BusinessDate(rawValue: "2026-10-11") else {
            throw NSError(domain: "SyncCoordinatorTests", code: 2)
        }
        let payload = PendingCheckInPayload(
            childId: accountID, planId: "plan-demo", targetDate: date,
            clientCompletionId: id, clientCompletedAt: Date(), planRevision: 1,
            itemOutcomes: [ItemOutcome(
                itemId: "item-1", outcome: .completed,
                attemptId: nil, localAttemptId: UUID(), skipReason: nil)])
        return PendingOperation(
            id: id, kind: .checkIn,
            payloadJSON: try ContractJSON.makeEncoder().encode(payload),
            accountID: accountID)
    }

    /// 成功场景：drain 后队列清空、后端被调用一次、幂等键即条目 id、摘要中文可见。
    func testDrainSuccessClearsQueueAndCallsBackend() async throws {
        let queue = try makeQueue()
        let backend = RecordingBackend(scenario: .success)
        let coordinator = SyncCoordinator(queue: queue, backend: backend)
        let operation = try makeCheckInOperation(accountID: "account-a")
        try queue.enqueue(operation)
        await coordinator.drainPending(forAccount: "account-a")
        XCTAssertTrue(queue.pending(forAccount: "account-a").isEmpty)
        XCTAssertEqual(backend.checkInIdempotencyKeys, [operation.id.uuidString])
        XCTAssertFalse(coordinator.isDraining)
        XCTAssertEqual(coordinator.lastDrainSummary, "本轮离线同步：成功 1 条")
    }

    /// 离线场景：drain 后条目保留、retryCount 递增、lastError 记录，摘要提示下轮重试。
    func testDrainOfflineKeepsEntryAndIncrementsRetry() async throws {
        let queue = try makeQueue()
        let coordinator = SyncCoordinator(queue: queue, backend: RecordingBackend(scenario: .offline))
        let operation = try makeCheckInOperation(accountID: "account-a")
        try queue.enqueue(operation)
        await coordinator.drainPending(forAccount: "account-a")
        let pending = queue.pending(forAccount: "account-a")
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.retryCount, 1)
        XCTAssertEqual(pending.first?.lastError, "网络不可用")
        XCTAssertEqual(coordinator.lastDrainSummary?.contains("待下轮重试"), true)
    }

    /// 重试沿用稳定幂等键：先离线失败，恢复后再 drain，两次 Idempotency-Key 相同且不生成新业务 ID。
    func testDrainReusesStableIdempotencyKeyAcrossRetries() async throws {
        let queue = try makeQueue()
        let backend = RecordingBackend(scenario: .offline)
        let coordinator = SyncCoordinator(queue: queue, backend: backend)
        let operation = try makeCheckInOperation(accountID: "account-a")
        try queue.enqueue(operation)
        await coordinator.drainPending(forAccount: "account-a")
        backend.setScenario(.success)
        await coordinator.drainPending(forAccount: "account-a")
        XCTAssertEqual(
            backend.checkInIdempotencyKeys,
            [operation.id.uuidString, operation.id.uuidString])
        XCTAssertTrue(queue.pending(forAccount: "account-a").isEmpty)
    }

    /// 不可重试错误（versionConflict）：条目保留并计数，摘要列出需人工处理。
    func testDrainVersionConflictNeedsManualHandling() async throws {
        let queue = try makeQueue()
        let backend = RecordingBackend(scenario: .versionConflict)
        let coordinator = SyncCoordinator(queue: queue, backend: backend)
        try queue.enqueue(makeCheckInOperation(accountID: "account-a"))
        await coordinator.drainPending(forAccount: "account-a")
        let pending = queue.pending(forAccount: "account-a")
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.retryCount, 1)
        XCTAssertEqual(coordinator.lastDrainSummary?.contains("需人工处理"), true)
    }

    /// uploadAudio/createAttempt 首版无编排：存在则跳过且不计失败，摘要注明等待上传编排层。
    func testDrainSkipsUploadKindsPendingOrchestration() async throws {
        let queue = try makeQueue()
        let backend = RecordingBackend(scenario: .success)
        let coordinator = SyncCoordinator(queue: queue, backend: backend)
        let upload = PendingOperation(
            id: UUID(), kind: .uploadAudio, payloadJSON: Data("{}".utf8), accountID: "account-a")
        try queue.enqueue(upload)
        try queue.enqueue(makeCheckInOperation(accountID: "account-a"))
        await coordinator.drainPending(forAccount: "account-a")
        let pending = queue.pending(forAccount: "account-a")
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.id, upload.id)
        XCTAssertEqual(pending.first?.retryCount, 0)
        XCTAssertEqual(backend.checkInIdempotencyKeys.count, 1)
        XCTAssertEqual(coordinator.lastDrainSummary?.contains("等待上传编排层"), true)
    }

    /// 账号隔离：drain account-a 只清本账号条目，account-b 保留且未计数。
    func testDrainIsolatesAccounts() async throws {
        let queue = try makeQueue()
        let coordinator = SyncCoordinator(queue: queue, backend: RecordingBackend(scenario: .success))
        try queue.enqueue(makeCheckInOperation(accountID: "account-a"))
        let other = try makeCheckInOperation(accountID: "account-b")
        try queue.enqueue(other)
        await coordinator.drainPending(forAccount: "account-a")
        XCTAssertTrue(queue.pending(forAccount: "account-a").isEmpty)
        let pendingB = queue.pending(forAccount: "account-b")
        XCTAssertEqual(pendingB.count, 1)
        XCTAssertEqual(pendingB.first?.id, other.id)
        XCTAssertEqual(pendingB.first?.retryCount, 0)
    }
}


/// 记录 checkIn 幂等键的转发后端：包装 MockBackendService，使幂等键沿用可断言。
/// 其余方法逐字转发，不改变模拟语义。
private final class RecordingBackend: BackendService, @unchecked Sendable {
    private let inner: MockBackendService
    private let lock = NSLock()
    private var keys: [String] = []

    init(scenario: MockScenario) {
        inner = MockBackendService(bundle: Bundle(for: MockBackendService.self))
        inner.scenario = scenario
    }

    /// 已观测到的 checkIn Idempotency-Key 序列（线程安全）。
    var checkInIdempotencyKeys: [String] {
        lock.withLock { keys }
    }

    /// 切换场景（线程安全），用于先离线后恢复的重试测试。
    func setScenario(_ scenario: MockScenario) {
        inner.scenario = scenario
    }

    func createCheckIn(
        childId: String, planId: String, targetDate: BusinessDate,
        clientCompletionId: UUID, clientCompletedAt: Date, planRevision: Int,
        itemOutcomes: [ItemOutcome], idempotencyKey: String
    ) async throws -> CheckInResult {
        lock.withLock { keys.append(idempotencyKey) }
        return try await inner.createCheckIn(
            childId: childId, planId: planId, targetDate: targetDate,
            clientCompletionId: clientCompletionId, clientCompletedAt: clientCompletedAt,
            planRevision: planRevision, itemOutcomes: itemOutcomes, idempotencyKey: idempotencyKey)
    }

    func bootstrap() async throws -> Bootstrap { try await inner.bootstrap() }

    func fetchCourses() async throws -> [CourseEditionSummary] { try await inner.fetchCourses() }

    func fetchProgress(childId: String) async throws -> ProgressSnapshot {
        try await inner.fetchProgress(childId: childId)
    }

    func createPlan(
        childId: String, targetDate: BusinessDate, dayMode: DayMode,
        expectedProgressRevision: Int, confirmedNewLessonId: String?
    ) async throws -> Plan {
        try await inner.createPlan(
            childId: childId, targetDate: targetDate, dayMode: dayMode,
            expectedProgressRevision: expectedProgressRevision,
            confirmedNewLessonId: confirmedNewLessonId)
    }

    func uploadAudio(
        childId: String, planId: String, itemId: String, clientAttemptId: UUID,
        fileURL: URL, sha256: String, idempotencyKey: String
    ) async throws -> UploadedAudio {
        try await inner.uploadAudio(
            childId: childId, planId: planId, itemId: itemId, clientAttemptId: clientAttemptId,
            fileURL: fileURL, sha256: sha256, idempotencyKey: idempotencyKey)
    }

    func createAttempt(
        clientAttemptId: UUID, planId: String, itemId: String, audioId: String,
        clientCompletedAt: Date, idempotencyKey: String
    ) async throws -> Attempt {
        try await inner.createAttempt(
            clientAttemptId: clientAttemptId, planId: planId, itemId: itemId, audioId: audioId,
            clientCompletedAt: clientCompletedAt, idempotencyKey: idempotencyKey)
    }

    func fetchEvaluation(jobId: String) async throws -> EvaluationJob {
        try await inner.fetchEvaluation(jobId: jobId)
    }

    func retryEvaluation(
        jobId: String, components: [String], expectedAttemptRevision: Int, idempotencyKey: String
    ) async throws -> EvaluationJob {
        try await inner.retryEvaluation(
            jobId: jobId, components: components,
            expectedAttemptRevision: expectedAttemptRevision, idempotencyKey: idempotencyKey)
    }

    func confirmTranscript(
        attemptId: String, expectedRevision: Int, confirmedText: String, idempotencyKey: String
    ) async throws -> Attempt {
        try await inner.confirmTranscript(
            attemptId: attemptId, expectedRevision: expectedRevision,
            confirmedText: confirmedText, idempotencyKey: idempotencyKey)
    }

    func listCheckIns(
        childId: String, from fromDate: BusinessDate?, to toDate: BusinessDate?, cursor: String?
    ) async throws -> CheckInPage {
        try await inner.listCheckIns(childId: childId, from: fromDate, to: toDate, cursor: cursor)
    }

    func fetchCheckIn(checkInId: String) async throws -> CheckInDetail {
        try await inner.fetchCheckIn(checkInId: checkInId)
    }

    func fetchCollection(childId: String) async throws -> CollectionSnapshot {
        try await inner.fetchCollection(childId: childId)
    }
}
