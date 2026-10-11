/// 日历页视图模型。
/// 按月拉取打卡记录并映射为 CalendarGrid 所需的 CalendarDay（含补卡标记与月外灰显）；
/// 统计条当前展示本月打卡天数与记录条数，连续/最长连续统计待真实统计接口提供。
import Foundation

@Observable
final class CalendarViewModel {
    private enum CalendarError: Error {
        case noChild
        case noMonthRange
    }

    /* DateFormatter 创建昂贵，静态共享；
       日期键固定 yyyy-MM-dd，与 BusinessDate 协议格式一致。 */
    private static let dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }()

    private let backend: any BackendService
    private let calendar = Calendar.current
    private var childId: String?
    private var checkInIdByDateKey: [String: String] = [:]
    private(set) var month: Date
    private(set) var days: [CalendarDay] = []
    private(set) var monthCompletedCount = 0
    private(set) var monthRecordCount = 0
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    init(backend: any BackendService) {
        self.backend = backend
        let components = Calendar.current.dateComponents([.year, .month], from: Date())
        self.month = Calendar.current.date(from: components) ?? Date()
    }

    var monthTitle: String {
        Self.monthFormatter.string(from: month)
    }

    /// 加载当前月打卡记录；失败时记录错误文案供页面重试。
    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let resolvedId = try await resolveChildId()
            let checkIns = try await fetchMonthCheckIns(childId: resolvedId)
            apply(checkIns: checkIns)
        } catch {
            errorMessage = "日历数据加载失败，请稍后重试"
        }
        isLoading = false
    }

    /// 左右切换月份并重新拉取该月数据。
    func shiftMonth(by value: Int) async {
        guard let next = calendar.date(byAdding: .month, value: value, to: month) else { return }
        month = next
        await load()
    }

    /// 供点选日期时反查打卡记录 ID；无记录的日期返回 nil。
    func checkInId(for date: Date) -> String? {
        checkInIdByDateKey[Self.dateKeyFormatter.string(from: date)]
    }

    private func resolveChildId() async throws -> String {
        if let childId { return childId }
        let bootstrap = try await backend.bootstrap()
        guard let first = bootstrap.children.first else { throw CalendarError.noChild }
        childId = first.id
        return first.id
    }

    private func fetchMonthCheckIns(childId: String) async throws -> [CheckIn] {
        guard let range = monthDateRange() else { throw CalendarError.noMonthRange }
        var items: [CheckIn] = []
        var cursor: String?
        repeat {
            let page = try await backend.listCheckIns(childId: childId, from: range.from, to: range.to, cursor: cursor)
            items.append(contentsOf: page.items)
            cursor = page.nextCursor
        } while cursor != nil
        return items
    }

    private func monthDateRange() -> (from: BusinessDate, to: BusinessDate)? {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end),
              let from = BusinessDate(rawValue: Self.dateKeyFormatter.string(from: interval.start)),
              let to = BusinessDate(rawValue: Self.dateKeyFormatter.string(from: lastDay)) else {
            return nil
        }
        return (from, to)
    }

    private func apply(checkIns: [CheckIn]) {
        var recordByDateKey: [String: CheckIn] = [:]
        for checkIn in checkIns {
            recordByDateKey[checkIn.targetDate.rawValue] = checkIn
        }
        monthRecordCount = checkIns.count
        monthCompletedCount = recordByDateKey.count
        checkInIdByDateKey = recordByDateKey.mapValues { $0.id }
        days = buildDays(recordByDateKey: recordByDateKey)
    }

    /* 固定渲染 6 周 42 格，避免切换月份时网格高度跳动；
       月外日期 isInMonth=false 由网格灰显。 */
    private func buildDays(recordByDateKey: [String: CheckIn]) -> [CalendarDay] {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        let weekday = calendar.component(.weekday, from: interval.start)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var result: [CalendarDay] = []
        for offset in -leading..<(42 - leading) {
            guard let date = calendar.date(byAdding: .day, value: offset, to: interval.start) else { continue }
            let record = recordByDateKey[Self.dateKeyFormatter.string(from: date)]
            result.append(CalendarDay(
                date: date,
                isToday: calendar.isDateInToday(date),
                isSelected: false,
                isCompleted: record != nil,
                isMakeup: record?.isMakeup ?? false,
                isInMonth: calendar.isDate(date, equalTo: month, toGranularity: .month)))
        }
        return result
    }
}
