/// 打卡日历网格。
/// 7 列 LazyVGrid 展示当月及前后补位日期；完成/补卡/选中/今天用
/// 颜色 + 图标或文字 + 描边三重标识，不只靠颜色；
/// 非当月单元格降低存在感且禁用选择。
import SwiftUI

/// 单日数据输入。id 即日期（按当日零点对齐）。
struct CalendarDay: Identifiable, Equatable {
    let date: Date
    var isToday: Bool = false
    var isSelected: Bool = false
    var isCompleted: Bool = false
    var isMakeup: Bool = false
    var isInMonth: Bool = true

    var id: Date {
        date
    }
}


/// 日历网格视图。
/// 输入 month 与 days（只需提供有数据的日期），组件自行用 Calendar 计算
/// 网格位置与缺失日期的默认单元格；点选经 onSelect 透出。
struct CalendarGrid: View {
    /// 中文星期标题，周一开头。
    private static let weekdaySymbols = ["一", "二", "三", "四", "五", "六", "日"]

    @Environment(\.theme) private var theme

    private let month: Date
    private let days: [CalendarDay]
    private let onSelect: (CalendarDay) -> Void

    /// 创建日历网格。month 取年月部分，日部分忽略。
    init(month: Date, days: [CalendarDay], onSelect: @escaping (CalendarDay) -> Void) {
        self.month = month
        self.days = days
        self.onSelect = onSelect
    }

    var body: some View {
        VStack(spacing: AppSpacing.small) {
            Text(monthTitle)
                .font(AppFont.section)
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            weekdayHeader
            LazyVGrid(columns: columns, spacing: AppSpacing.xSmall) {
                ForEach(gridDates, id: \.self) { date in
                    CalendarDayCell(
                        day: day(for: date),
                        dayNumber: calendar.component(.day, from: date),
                        onSelect: onSelect
                    )
                }
            }
        }
    }

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: AppSpacing.xSmall), count: 7)
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: month)
    }

    private var weekdayHeader: some View {
        HStack(spacing: AppSpacing.xSmall) {
            ForEach(Self.weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(AppFont.helper)
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var daysByDate: [Date: CalendarDay] {
        /* 输入可能含重复日期，后到的覆盖先到的，避免 uniqueKeysWithValues 崩溃。 */
        Dictionary(days.map { (calendar.startOfDay(for: $0.date), $0) }, uniquingKeysWith: { _, later in later })
    }

    /*
     网格从月首所在周的周一开始，铺满完整周。
     输入缺失的日期用默认 CalendarDay 渲染，isInMonth 由组件按 month 计算。
     */
    private var gridDates: [Date] {
        let components = calendar.dateComponents([.year, .month], from: month)
        guard let firstOfMonth = calendar.date(from: components),
              let dayRange = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
            return []
        }
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        let totalCells = ((leading + dayRange.count + 6) / 7) * 7
        return (0..<totalCells).compactMap { offset in
            calendar.date(byAdding: .day, value: offset - leading, to: firstOfMonth)
        }
    }

    private func day(for date: Date) -> CalendarDay {
        let key = calendar.startOfDay(for: date)
        if let existing = daysByDate[key] {
            return existing
        }
        return CalendarDay(
            date: date,
            isInMonth: calendar.isDate(date, equalTo: month, toGranularity: .month)
        )
    }
}


/// 单日单元格：数字 + 状态标识，圆角 12，触控高度 48。
private struct CalendarDayCell: View {
    @Environment(\.theme) private var theme

    let day: CalendarDay
    let dayNumber: Int
    let onSelect: (CalendarDay) -> Void

    var body: some View {
        Button {
            onSelect(day)
        } label: {
            VStack(spacing: AppSpacing.xxSmall) {
                Text("\(dayNumber)")
                    .font(AppFont.body)
                    .foregroundStyle(foreground)
                statusMark
            }
            .frame(maxWidth: .infinity, minHeight: AppLayout.minTouchTarget)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
            .overlay(cellBorder)
        }
        .disabled(!day.isInMonth)
        .accessibilityLabel(accessibilityText)
    }

    private var background: Color {
        if day.isSelected { return theme.calendar.selectedBackground }
        if day.isCompleted { return theme.calendar.complete.background }
        if day.isMakeup { return theme.calendar.makeup.background }
        return theme.calendar.cellBackground
    }

    private var foreground: Color {
        if !day.isInMonth { return theme.textTertiary }
        if day.isSelected { return theme.calendar.selectedForeground }
        if day.isCompleted { return theme.calendar.complete.foreground }
        if day.isMakeup { return theme.calendar.makeup.foreground }
        return theme.calendar.cellForeground
    }

    @ViewBuilder
    private var cellBorder: some View {
        if day.isToday {
            RoundedRectangle(cornerRadius: AppRadius.button)
                .stroke(theme.calendar.todayRing, lineWidth: 2)
        } else if day.isSelected {
            RoundedRectangle(cornerRadius: AppRadius.button)
                .stroke(theme.calendar.selectedBorder, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var statusMark: some View {
        if day.isCompleted {
            Image(systemName: "checkmark")
                .font(AppFont.helper)
                .foregroundStyle(theme.calendar.complete.icon)
        } else if day.isMakeup {
            Text("补")
                .font(AppFont.helper)
                .foregroundStyle(theme.calendar.makeup.foreground)
        } else {
            Text(" ")
                .font(AppFont.helper)
        }
    }

    private var accessibilityText: String {
        var result = "\(dayNumber)日"
        if day.isToday { result += "，今天" }
        if day.isSelected { result += "，已选中" }
        if day.isCompleted { result += "，已完成打卡" }
        if day.isMakeup { result += "，补卡" }
        if !day.isInMonth { result += "，非当月" }
        return result
    }
}


#Preview {
    CalendarGrid(
        month: Date(),
        days: [CalendarDay(date: Date(), isToday: true, isSelected: true)],
        onSelect: { _ in }
    )
    .padding(AppSpacing.medium)
}
