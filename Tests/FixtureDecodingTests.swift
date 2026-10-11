/// 契约 fixture 解码测试。
/// contracts/fixtures 下 9 个 JSON 必须能被对应模型用 ContractJSON 解码，
/// 并断言关键字段语义：无置信度（confidence 为 null、quality 为 insufficient）、
/// 重复日期不发奖（rewardGrants 为空）、计划条目类型分布等。
/// fixture 定位：测试 target 以 App 为 host，优先经 Bundle(for: MockBackendService.self)
/// 取 App bundle 内的 fixtures 子目录（folder reference 资源）；
/// 若资源在测试 bundle 不可达，回退到以 #filePath 推导仓库根的源码目录相对路径。
@testable import Sprout
import XCTest

final class FixtureDecodingTests: XCTestCase {
    /// 读取 fixture 数据：优先 App bundle 的 fixtures 子目录，回退源码目录相对路径。
    private func fixtureData(_ name: String) throws -> Data {
        let appBundle = Bundle(for: MockBackendService.self)
        if let url = appBundle.url(forResource: name, withExtension: "json", subdirectory: "fixtures") {
            return try Data(contentsOf: url)
        }
        // 回退：Tests/FixtureDecodingTests.swift → 仓库根/contracts/fixtures/<name>.json。
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repoRoot
            .appendingPathComponent("contracts")
            .appendingPathComponent("fixtures")
            .appendingPathComponent("\(name).json")
        return try Data(contentsOf: url)
    }

    /// 用契约解码器解码指定 fixture（不含扩展名）。
    private func load<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        try ContractJSON.makeDecoder().decode(T.self, from: fixtureData(name))
    }

    /// bootstrap：家长、单个儿童、音频限制、能力与同步游标齐备。
    func testBootstrapFixtureDecodes() throws {
        let bootstrap = try load(Bootstrap.self, "bootstrap")
        XCTAssertFalse(bootstrap.parentSummary.id.isEmpty)
        XCTAssertEqual(bootstrap.children.count, 1)
        XCTAssertEqual(bootstrap.children.first?.timezone, "Asia/Shanghai")
        XCTAssertEqual(bootstrap.configuration.audioLimits.maxSeconds, 60)
        XCTAssertEqual(bootstrap.configuration.makeupPolicy.allowedDaysBack, 7)
        XCTAssertTrue(bootstrap.capabilities.stt)
        XCTAssertTrue(bootstrap.capabilities.pronunciation)
        XCTAssertFalse(bootstrap.syncCursor.isEmpty)
    }

    /// plan-new：dayMode 为 new，2 个跟读 + 1 个自由表达；自由表达无 referenceText。
    func testPlanNewFixtureDecodes() throws {
        let plan = try load(Plan.self, "plan-new")
        XCTAssertEqual(plan.dayMode, .new)
        XCTAssertEqual(plan.items.count, 3)
        XCTAssertEqual(plan.items.filter { $0.type == .repeat }.count, 2)
        XCTAssertEqual(plan.items.filter { $0.type == .freeExpression }.count, 1)
        for item in plan.items where item.type == .repeat {
            XCTAssertNotNil(item.referenceText)
            XCTAssertTrue(item.required)
        }
        for item in plan.items where item.type == .freeExpression {
            XCTAssertNil(item.referenceText)
            XCTAssertFalse(item.required)
        }
        XCTAssertEqual(plan.completionPolicy.requiredItemIds.count, 2)
        XCTAssertEqual(plan.targetDate, BusinessDate(rawValue: "2026-10-11"))
    }

    /// plan-review：dayMode 为 review，全部为跟读条目。
    func testPlanReviewFixtureDecodes() throws {
        let plan = try load(Plan.self, "plan-review")
        XCTAssertEqual(plan.dayMode, .review)
        XCTAssertEqual(plan.items.count, 2)
        XCTAssertTrue(plan.items.allSatisfy { $0.type == .repeat })
        XCTAssertTrue(plan.items.allSatisfy { $0.referenceText != nil })
    }

    /// evaluation-success：整体成功，发音有分数与证据，反馈齐备。
    func testEvaluationSuccessFixtureDecodes() throws {
        let job = try load(EvaluationJob.self, "evaluation-success")
        XCTAssertEqual(job.status, .succeeded)
        XCTAssertEqual(job.components.stt?.sttResult?.quality, .usable)
        XCTAssertEqual(job.components.stt?.sttResult?.confidence, 0.93)
        XCTAssertEqual(job.components.grammar?.status, .succeeded)
        XCTAssertEqual(job.components.pronunciation?.pronunciationResult?.providerScore, 88.5)
        XCTAssertEqual(job.components.pronunciation?.pronunciationResult?.evidenceAvailable, true)
        XCTAssertNotNil(job.feedback)
        XCTAssertNil(job.nextPollAfterMs)
    }

    /// evaluation-partial：整体 partial；发音组件 failed、retryable、原因码 PROVIDER_TIMEOUT。
    func testEvaluationPartialFixtureDecodes() throws {
        let job = try load(EvaluationJob.self, "evaluation-partial")
        XCTAssertEqual(job.status, .partial)
        XCTAssertEqual(job.components.stt?.status, .succeeded)
        XCTAssertEqual(job.components.pronunciation?.status, .failed)
        XCTAssertEqual(job.components.pronunciation?.reasonCode, "PROVIDER_TIMEOUT")
        XCTAssertEqual(job.components.pronunciation?.retryable, true)
        XCTAssertNil(job.components.pronunciation?.pronunciationResult)
        XCTAssertEqual(job.nextPollAfterMs, 1500)
    }

    /// evaluation-noconfidence：转写无置信度（confidence 为 null、quality 为 insufficient），
    /// grammar 与 pronunciation 均跳过且不可重试。
    func testEvaluationNoConfidenceFixtureDecodes() throws {
        let job = try load(EvaluationJob.self, "evaluation-noconfidence")
        XCTAssertEqual(job.status, .partial)
        let sttResult = job.components.stt?.sttResult
        XCTAssertEqual(sttResult?.quality, .insufficient)
        XCTAssertNil(sttResult?.confidence)
        XCTAssertEqual(sttResult?.providerTranscript, "")
        XCTAssertEqual(job.components.grammar?.status, .skipped)
        XCTAssertEqual(job.components.grammar?.reasonCode, "TRANSCRIPT_INSUFFICIENT")
        XCTAssertEqual(job.components.grammar?.retryable, false)
        XCTAssertEqual(job.components.pronunciation?.status, .skipped)
        XCTAssertNil(job.feedback)
    }

    /// checkin-success：首次打卡发奖（1 条 part 奖励），记录已确认。
    func testCheckInSuccessFixtureDecodes() throws {
        let result = try load(CheckInResult.self, "checkin-success")
        XCTAssertEqual(result.rewardGrants.count, 1)
        XCTAssertEqual(result.rewardGrants.first?.kind, .part)
        XCTAssertEqual(result.rewardGrants.first?.sourceTargetDate, BusinessDate(rawValue: "2026-10-11"))
        XCTAssertNotNil(result.checkIn.confirmedAt)
        XCTAssertFalse(result.checkIn.isMakeup)
        XCTAssertTrue(result.calendarSummary.todayCheckedIn)
        XCTAssertEqual(result.calendarSummary.currentStreak, 3)
    }

    /// checkin-duplicate：重复日期返回已有确认状态且不再发奖（rewardGrants 为空）。
    func testCheckInDuplicateFixtureDecodes() throws {
        let result = try load(CheckInResult.self, "checkin-duplicate")
        XCTAssertTrue(result.rewardGrants.isEmpty)
        XCTAssertNotNil(result.checkIn.confirmedAt)
        XCTAssertTrue(result.calendarSummary.todayCheckedIn)
        XCTAssertEqual(result.collectionRevision, 2)
    }

    /// collection：5 个条目；未解锁条目无 unlockedAt/assetId；里程碑进度正确。
    func testCollectionFixtureDecodes() throws {
        let snapshot = try load(CollectionSnapshot.self, "collection")
        XCTAssertEqual(snapshot.items.count, 5)
        XCTAssertEqual(snapshot.revision, 2)
        for item in snapshot.items where item.unlocked {
            XCTAssertNotNil(item.unlockedAt)
            XCTAssertNotNil(item.assetId)
        }
        for item in snapshot.items where !item.unlocked {
            XCTAssertNil(item.unlockedAt)
            XCTAssertNil(item.assetId)
            XCTAssertNil(item.sourceTargetDate)
        }
        let kinds = snapshot.items.map { $0.kind }
        XCTAssertEqual(kinds, [.tank, .part, .part, .badge, .decoration])
        XCTAssertEqual(snapshot.nextMilestone?.requiredDates, 7)
        XCTAssertEqual(snapshot.nextMilestone?.currentDates, 3)
    }
}
