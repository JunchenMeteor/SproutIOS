/// 本地存储（LocalStore）持久化测试。
/// 全部用例注入临时目录，不触碰 Application Support；
/// 覆盖草稿/计划快照/onboarding 标记/sync 游标的往返读写、key 规则与损坏文件语义。
/// 损坏语义以源码为准：已有 state.json 无法解码时 init 抛 LocalStoreError.corruptedState，
/// 不静默重置（见 LocalStore.swift 的 load(from:)）。
@testable import Sprout
import XCTest

final class LocalStoreTests: XCTestCase {
    /// 每个用例独立的临时目录。
    private var directory: URL?

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalStoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        if let directory, FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        directory = nil
    }

    /// 注入目录创建 LocalStore；目录必须由 setUp 准备好。
    private func makeStore() throws -> LocalStore {
        guard let directory else {
            throw NSError(domain: "LocalStoreTests", code: 1)
        }
        return try LocalStore(directory: directory)
    }

    /// 家长草稿往返：写入后新实例读回相等；未写入时为 nil。
    func testChildProfileDraftRoundTrip() throws {
        let store = try makeStore()
        XCTAssertNil(store.childProfileDraft)
        let draft = ChildProfileDraft(
            nickname: "小豆",
            courseEditionId: "course-demo-starter",
            currentLessonId: "lesson-demo-1",
            retainRecordings: true
        )
        try store.saveChildProfileDraft(draft)
        XCTAssertEqual(store.childProfileDraft, draft)
        XCTAssertEqual(try makeStore().childProfileDraft, draft)
    }

    /// 计划快照往返与 key 规则：key 为 "childId#targetDate"，不同孩子同日期互不覆盖。
    func testPlanSnapshotRoundTripAndKeyRule() throws {
        XCTAssertEqual(LocalStore.planSnapshotKey(childId: "c1", targetDate: "2026-10-11"), "c1#2026-10-11")
        let store = try makeStore()
        let snapshot = LocalPlanSnapshot(
            planId: "plan-1",
            targetDate: "2026-10-11",
            dayMode: "new",
            contentVersion: "demo-content-1",
            itemsJSON: Data("[]".utf8)
        )
        try store.savePlanSnapshot(snapshot, childId: "c1", targetDate: "2026-10-11")
        XCTAssertEqual(store.planSnapshot(childId: "c1", targetDate: "2026-10-11"), snapshot)
        XCTAssertNil(store.planSnapshot(childId: "c2", targetDate: "2026-10-11"))
        XCTAssertNil(store.planSnapshot(childId: "c1", targetDate: "2026-10-12"))
        let reloaded = try makeStore()
        XCTAssertEqual(reloaded.planSnapshot(childId: "c1", targetDate: "2026-10-11"), snapshot)
    }

    /// hasCompletedOnboarding 往返：默认 false，置 true 后跨实例保持，可再置回 false。
    func testHasCompletedOnboardingRoundTrip() throws {
        let store = try makeStore()
        XCTAssertFalse(store.hasCompletedOnboarding)
        try store.setOnboardingCompleted(true)
        XCTAssertTrue(try makeStore().hasCompletedOnboarding)
        try makeStore().setOnboardingCompleted(false)
        XCTAssertFalse(try makeStore().hasCompletedOnboarding)
    }

    /// syncCursor 往返：默认 nil；写入后跨实例保持；传 nil 表示失效清空。
    func testSyncCursorRoundTrip() throws {
        let store = try makeStore()
        XCTAssertNil(store.syncCursor)
        try store.saveSyncCursor("cursor-demo-20261011")
        XCTAssertEqual(try makeStore().syncCursor, "cursor-demo-20261011")
        try makeStore().saveSyncCursor(nil)
        XCTAssertNil(try makeStore().syncCursor)
    }

    /// 损坏的 state.json：init 抛 LocalStoreError.corruptedState，不吞错、不静默清空。
    func testCorruptedStateFileThrows() throws {
        guard let directory else {
            XCTFail("临时目录未准备")
            return
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{oops".utf8).write(to: directory.appendingPathComponent("state.json"))
        XCTAssertThrowsError(try LocalStore(directory: directory)) { error in
            guard case LocalStoreError.corruptedState = error else {
                XCTFail("应为 corruptedState，实得 \(error)")
                return
            }
        }
    }
}
