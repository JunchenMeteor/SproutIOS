/// 离线队列（OfflineQueue）持久化测试。
/// 全部用例注入临时目录，不触碰 Application Support；
/// 覆盖入队持久化与幂等、失败计数、完成移除、账号隔离与损坏文件语义。
@testable import Sprout
import XCTest

final class OfflineQueueTests: XCTestCase {
    /// 每个用例独立的临时目录。
    private var directory: URL?

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OfflineQueueTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        if let directory, FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        directory = nil
    }

    /// 构造一条待同步操作（payload 为占位 JSON）。
    private func makeOperation(
        id: UUID = UUID(),
        kind: PendingOperation.Kind = .checkIn,
        createdAt: Date = Date(),
        accountID: String
    ) -> PendingOperation {
        PendingOperation(
            id: id,
            kind: kind,
            payloadJSON: Data("{}".utf8),
            createdAt: createdAt,
            accountID: accountID
        )
    }

    /// 注入目录创建队列；目录必须由 setUp 准备好。
    private func makeQueue() throws -> OfflineQueue {
        guard let directory else {
            throw NSError(domain: "OfflineQueueTests", code: 1)
        }
        return try OfflineQueue(directory: directory)
    }

    /// enqueue 立即落盘：新实例能读回同一条目。
    func testEnqueuePersistsAcrossInstances() throws {
        let operation = makeOperation(accountID: "account-a")
        try makeQueue().enqueue(operation)
        let reloaded = try makeQueue()
        let pending = reloaded.pending(forAccount: "account-a")
        XCTAssertEqual(pending.count, 1)
        assertSameOperation(pending.first, operation)
    }

    /* 队列条目按身份与状态字段等价比较；createdAt 经 ISO-8601 毫秒精度落盘，
       允许亚秒级差异（队列记账字段，契约级时间在 payload 内按契约精度处理）。 */
    private func assertSameOperation(
        _ actual: PendingOperation?,
        _ expected: PendingOperation,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actual else {
            XCTFail("条目缺失", file: file, line: line)
            return
        }
        XCTAssertEqual(actual.id, expected.id, file: file, line: line)
        XCTAssertEqual(actual.kind, expected.kind, file: file, line: line)
        XCTAssertEqual(actual.payloadJSON, expected.payloadJSON, file: file, line: line)
        XCTAssertEqual(actual.retryCount, expected.retryCount, file: file, line: line)
        XCTAssertEqual(actual.lastError, expected.lastError, file: file, line: line)
        XCTAssertEqual(actual.accountID, expected.accountID, file: file, line: line)
        XCTAssertEqual(
            actual.createdAt.timeIntervalSince1970,
            expected.createdAt.timeIntervalSince1970,
            accuracy: 1,
            file: file,
            line: line)
    }

    /// 同 id 重复 enqueue 幂等：不产生第二条，落盘内容也不重复。
    func testEnqueueSameIDIsIdempotent() throws {
        let queue = try makeQueue()
        let operation = makeOperation(accountID: "account-a")
        try queue.enqueue(operation)
        try queue.enqueue(operation)
        XCTAssertEqual(queue.pending(forAccount: "account-a").count, 1)
        let reloaded = try makeQueue()
        XCTAssertEqual(reloaded.pending(forAccount: "account-a").count, 1)
    }

    /// markFailed 递增 retryCount、记录 lastError 并落盘；id 保持不变。
    func testMarkFailedIncrementsRetryAndStoresError() throws {
        let queue = try makeQueue()
        let operation = makeOperation(accountID: "account-a")
        try queue.enqueue(operation)
        try queue.markFailed(operation.id, error: "网络不可用")
        try queue.markFailed(operation.id, error: "再次失败")
        let reloaded = try makeQueue()
        let pending = reloaded.pending(forAccount: "account-a")
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.id, operation.id)
        XCTAssertEqual(pending.first?.retryCount, 2)
        XCTAssertEqual(pending.first?.lastError, "再次失败")
    }

    /// markFailed 指向不存在的 id 时抛 operationNotFound。
    func testMarkFailedUnknownIDThrows() throws {
        let queue = try makeQueue()
        let missing = UUID()
        XCTAssertThrowsError(try queue.markFailed(missing, error: "x")) { error in
            guard case OfflineQueueError.operationNotFound(let id) = error else {
                XCTFail("应为 operationNotFound，实得 \(error)")
                return
            }
            XCTAssertEqual(id, missing)
        }
    }

    /// markCompleted 移除条目并落盘；队列只剩另一条。
    func testMarkCompletedRemovesOperation() throws {
        let queue = try makeQueue()
        let first = makeOperation(accountID: "account-a")
        let second = makeOperation(accountID: "account-a")
        try queue.enqueue(first)
        try queue.enqueue(second)
        try queue.markCompleted(first.id)
        let reloaded = try makeQueue()
        let pending = reloaded.pending(forAccount: "account-a")
        XCTAssertEqual(pending.count, 1)
        assertSameOperation(pending.first, second)
    }

    /// markCompleted 指向不存在的 id 时抛 operationNotFound。
    func testMarkCompletedUnknownIDThrows() {
        do {
            let queue = try makeQueue()
            XCTAssertThrowsError(try queue.markCompleted(UUID()))
        } catch {
            XCTFail("队列创建失败: \(error)")
        }
    }

    /// pending(forAccount:) 只返回本账号条目，且按 createdAt 升序。
    func testPendingFiltersByAccountAndSortsByCreatedAt() throws {
        let queue = try makeQueue()
        let earlier = Date(timeIntervalSince1970: 1_000)
        let later = Date(timeIntervalSince1970: 2_000)
        let oldA = makeOperation(kind: .uploadAudio, createdAt: earlier, accountID: "account-a")
        let newA = makeOperation(kind: .checkIn, createdAt: later, accountID: "account-a")
        let otherB = makeOperation(kind: .checkIn, createdAt: earlier, accountID: "account-b")
        try queue.enqueue(newA)
        try queue.enqueue(otherB)
        try queue.enqueue(oldA)
        XCTAssertEqual(queue.pending(forAccount: "account-a"), [oldA, newA])
        XCTAssertEqual(queue.pending(forAccount: "account-b"), [otherB])
        XCTAssertEqual(queue.pending(forAccount: "account-c"), [])
    }

    /// 队列文件损坏时 init 抛 corruptedState，不静默清空。
    func testCorruptedQueueFileThrows() throws {
        guard let directory else {
            XCTFail("临时目录未准备")
            return
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: directory.appendingPathComponent("queue.json"))
        XCTAssertThrowsError(try OfflineQueue(directory: directory)) { error in
            guard case OfflineQueueError.corruptedState = error else {
                XCTFail("应为 corruptedState，实得 \(error)")
                return
            }
        }
    }
}
