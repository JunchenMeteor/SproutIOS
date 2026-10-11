/// 业务日期（BusinessDate）测试。
/// 覆盖 YYYY-MM-DD 严格解析（含滚动日期拒绝）、Comparable 字典序排序、
/// adding(days:) 跨月/跨年/闰年，以及 today(timeZone:) 的时区使用。
/// today 依赖设备当前时刻且没有时间注入入口，故只断言确定性不变量：
/// 与独立计算的同年月日一致、上海日期不早于 UTC、两地之差至多一天
/// （等价于覆盖 UTC 23:30 时北京已是次日这一类边界）。
@testable import Sprout
import XCTest

final class BusinessDateTests: XCTestCase {
    /// 合法字符串解析成功且 rawValue 原样保留。
    func testValidRawValueParses() {
        let date = BusinessDate(rawValue: "2026-10-11")
        XCTAssertEqual(date?.rawValue, "2026-10-11")
        XCTAssertEqual(BusinessDate(rawValue: "2024-02-29")?.rawValue, "2024-02-29")
        XCTAssertEqual(BusinessDate(rawValue: "0001-01-01")?.rawValue, "0001-01-01")
    }

    /// 非法格式一律返回 nil：空串、长度错误、非零填充、错误分隔符、纯文本。
    func testMalformedStringsReturnNil() {
        let invalid = ["", "2026-1-1", "2026-10-1", "2026/10/11", "not-a-date", "2026-10-110", "2026-10"]
        for value in invalid {
            XCTAssertNil(BusinessDate(rawValue: value), "应拒绝: \(value)")
        }
    }

    /// 公历不存在的滚动日期（如 2 月 31 日、非闰年 2 月 29 日、13 月）必须拒绝。
    func testNonExistentDatesReturnNil() {
        XCTAssertNil(BusinessDate(rawValue: "2026-02-31"))
        XCTAssertNil(BusinessDate(rawValue: "2025-02-29"))
        XCTAssertNil(BusinessDate(rawValue: "2026-13-01"))
        XCTAssertNil(BusinessDate(rawValue: "2026-00-10"))
    }

    /// Comparable：零填充字典序等价于时间先后，支持排序。
    func testComparableOrdersChronologically() {
        guard let a = BusinessDate(rawValue: "2026-09-30"),
              let b = BusinessDate(rawValue: "2026-10-01"),
              let c = BusinessDate(rawValue: "2027-01-01") else {
            XCTFail("合法日期解析失败")
            return
        }
        XCTAssertLessThan(a, b)
        XCTAssertLessThan(b, c)
        XCTAssertEqual([c, a, b].sorted(), [a, b, c])
    }

    /// adding(days:) 跨月：1 月 31 日 + 1 天进入 2 月。
    func testAddingDaysCrossesMonth() {
        let date = BusinessDate(rawValue: "2026-01-31")
        XCTAssertEqual(date?.adding(days: 1).rawValue, "2026-02-01")
        let march = BusinessDate(rawValue: "2026-03-01")
        XCTAssertEqual(march?.adding(days: -1).rawValue, "2026-02-28")
    }

    /// adding(days:) 跨年与闰年：年末 +1 进入次年；闰年 2 月 28 日 +1 为 29 日。
    func testAddingDaysCrossesYearAndLeapDay() {
        let yearEnd = BusinessDate(rawValue: "2025-12-31")
        XCTAssertEqual(yearEnd?.adding(days: 1).rawValue, "2026-01-01")
        let newYear = BusinessDate(rawValue: "2026-01-01")
        XCTAssertEqual(newYear?.adding(days: -1).rawValue, "2025-12-31")
        let leap = BusinessDate(rawValue: "2024-02-28")
        XCTAssertEqual(leap?.adding(days: 1).rawValue, "2024-02-29")
    }

    /// adding(days: 0) 保持不变。
    func testAddingZeroDaysKeepsDate() {
        let date = BusinessDate(rawValue: "2026-10-11")
        XCTAssertEqual(date?.adding(days: 0).rawValue, "2026-10-11")
    }

    /// Codable：编码为裸 YYYY-MM-DD 字符串；非法日期解码抛错而非降级。
    func testCodableRoundTripAndStrictDecoding() throws {
        guard let date = BusinessDate(rawValue: "2026-10-11") else {
            XCTFail("合法日期解析失败")
            return
        }
        let encoded = try JSONEncoder().encode(date)
        XCTAssertEqual(String(data: encoded, encoding: .utf8), "\"2026-10-11\"")
        let decoded = try JSONDecoder().decode(BusinessDate.self, from: encoded)
        XCTAssertEqual(decoded, date)
        let invalid = Data("\"2026-02-31\"".utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(BusinessDate.self, from: invalid))
    }

    /// today(timeZone:) 使用传入时区：结果与独立计算的该时区年月日一致。
    func testTodayUsesProvidedTimeZone() {
        guard let shanghai = TimeZone(identifier: "Asia/Shanghai") else {
            XCTFail("Asia/Shanghai 时区不可用")
            return
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = shanghai
        let components = calendar.dateComponents([.year, .month, .day], from: Date())
        let expected = String(format: "%04d-%02d-%02d",
                              components.year ?? 0, components.month ?? 0, components.day ?? 0)
        XCTAssertEqual(BusinessDate.today(timeZone: shanghai).rawValue, expected)
    }

    /// UTC 与上海（UTC+8，无夏令时）同一天至多差一天，且上海日期不早于 UTC。
    /// 覆盖"UTC 23:30 时北京已是次日"类边界的确定性部分。
    func testTodayShanghaiNeverEarlierThanUTC() {
        guard let shanghai = TimeZone(identifier: "Asia/Shanghai"),
              let utc = TimeZone(secondsFromGMT: 0) else {
            XCTFail("时区不可用")
            return
        }
        let utcDay = BusinessDate.today(timeZone: utc)
        let shanghaiDay = BusinessDate.today(timeZone: shanghai)
        XCTAssertGreaterThanOrEqual(shanghaiDay, utcDay)
        XCTAssertLessThanOrEqual(shanghaiDay, utcDay.adding(days: 1))
    }
}
