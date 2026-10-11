/// 契约枚举解码测试（EC-API-0.1 第 5 节枚举集合）。
/// 规范：合法 raw 值解码成功；未识别字符串必须安全降级为 .unknown 而不是抛错，
/// 且不允许默认为成功态。
@testable import Sprout
import XCTest

final class ContractEnumTests: XCTestCase {
    /// 解码包装：把裸字符串包进对象，避免依赖顶层 JSON fragment 行为差异。
    private struct Box<T: Decodable>: Decodable {
        let value: T
    }

    /// 用包装对象解码单个字符串枚举值。
    private func decode<T: Decodable>(_ type: T.Type, raw: String) throws -> T {
        let json = "{\"value\":\"\(raw)\"}"
        return try JSONDecoder().decode(Box<T>.self, from: Data(json.utf8)).value
    }

    /// DayMode：new/review 合法；未识别降级 unknown。
    func testDayModeDecoding() throws {
        XCTAssertEqual(try decode(DayMode.self, raw: "new"), .new)
        XCTAssertEqual(try decode(DayMode.self, raw: "review"), .review)
        XCTAssertEqual(try decode(DayMode.self, raw: "weekly"), .unknown)
    }

    /// PlanItemType：repeat（raw 为 "repeat"）/freeExpression 合法；未识别降级 unknown。
    func testPlanItemTypeDecoding() throws {
        XCTAssertEqual(try decode(PlanItemType.self, raw: "repeat"), .repeat)
        XCTAssertEqual(try decode(PlanItemType.self, raw: "freeExpression"), .freeExpression)
        XCTAssertEqual(try decode(PlanItemType.self, raw: "shadowing"), .unknown)
    }

    /// EvaluationComponentStatus：六种合法状态；未识别降级 unknown。
    func testEvaluationComponentStatusDecoding() throws {
        let valid: [String: EvaluationComponentStatus] = [
            "pending": .pending, "running": .running, "succeeded": .succeeded,
            "failed": .failed, "skipped": .skipped, "cancelled": .cancelled
        ]
        for (raw, expected) in valid {
            XCTAssertEqual(try decode(EvaluationComponentStatus.self, raw: raw), expected, "raw: \(raw)")
        }
        XCTAssertEqual(try decode(EvaluationComponentStatus.self, raw: "exploded"), .unknown)
    }

    /// EvaluationJobStatus：六种合法状态；未识别降级 unknown 而非默认为成功。
    func testEvaluationJobStatusDecoding() throws {
        let valid: [String: EvaluationJobStatus] = [
            "queued": .queued, "running": .running, "succeeded": .succeeded,
            "partial": .partial, "failed": .failed, "cancelled": .cancelled
        ]
        for (raw, expected) in valid {
            XCTAssertEqual(try decode(EvaluationJobStatus.self, raw: raw), expected, "raw: \(raw)")
        }
        XCTAssertEqual(try decode(EvaluationJobStatus.self, raw: "done"), .unknown)
    }

    /// TranscriptQuality：usable/needsReview/insufficient 合法；未识别降级 unknown。
    func testTranscriptQualityDecoding() throws {
        XCTAssertEqual(try decode(TranscriptQuality.self, raw: "usable"), .usable)
        XCTAssertEqual(try decode(TranscriptQuality.self, raw: "needsReview"), .needsReview)
        XCTAssertEqual(try decode(TranscriptQuality.self, raw: "insufficient"), .insufficient)
        XCTAssertEqual(try decode(TranscriptQuality.self, raw: "perfect"), .unknown)
    }

    /// CheckInOutcome：completed/skipped 合法；未识别降级 unknown。
    func testCheckInOutcomeDecoding() throws {
        XCTAssertEqual(try decode(CheckInOutcome.self, raw: "completed"), .completed)
        XCTAssertEqual(try decode(CheckInOutcome.self, raw: "skipped"), .skipped)
        XCTAssertEqual(try decode(CheckInOutcome.self, raw: "missed"), .unknown)
    }

    /// CollectionKind：tank/part/badge/decoration 合法；未识别降级 unknown。
    func testCollectionKindDecoding() throws {
        XCTAssertEqual(try decode(CollectionKind.self, raw: "tank"), .tank)
        XCTAssertEqual(try decode(CollectionKind.self, raw: "part"), .part)
        XCTAssertEqual(try decode(CollectionKind.self, raw: "badge"), .badge)
        XCTAssertEqual(try decode(CollectionKind.self, raw: "decoration"), .decoration)
        XCTAssertEqual(try decode(CollectionKind.self, raw: "pet"), .unknown)
    }

    /// RewardKind：part/badge/tank/decoration 合法；未识别降级 unknown。
    func testRewardKindDecoding() throws {
        XCTAssertEqual(try decode(RewardKind.self, raw: "part"), .part)
        XCTAssertEqual(try decode(RewardKind.self, raw: "badge"), .badge)
        XCTAssertEqual(try decode(RewardKind.self, raw: "tank"), .tank)
        XCTAssertEqual(try decode(RewardKind.self, raw: "decoration"), .decoration)
        XCTAssertEqual(try decode(RewardKind.self, raw: "sticker"), .unknown)
    }

    /// 未识别值编码时保持 .unknown 的 raw 值（编码由编译器合成）。
    func testUnknownEncodesAsUnknownRawValue() throws {
        let json = "{\"value\":\"mystery\"}"
        let mode = try JSONDecoder().decode(Box<DayMode>.self, from: Data(json.utf8)).value
        XCTAssertEqual(mode, .unknown)
        XCTAssertEqual(mode.rawValue, "unknown")
    }
}
