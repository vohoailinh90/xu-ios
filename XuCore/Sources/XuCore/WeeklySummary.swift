import Foundation

/// "Nhìn lại tuần này" (docs/02, O3): tuần từ thứ Hai tới Chủ nhật, chỉ tính các ngày tới hôm nay.
/// Không có màu đỏ hay "vượt ngân sách" — chỉ kể lại tuần đã qua (docs/05).
public struct WeeklySummary: Equatable, Sendable {
    public let weekStart: DayKey
    public let weekEnd: DayKey
    /// Tổng chi theo từng loại tiền, không quy đổi.
    public let spent: [Currency: Int64]
    /// Danh mục chi nhiều nhất, tính bằng tiền của nơi chi tiêu. `nil` nếu tuần này chưa chi gì bằng tiền đó.
    public let topCategoryID: String?
    /// Ngày đã chốt và không có khoản tiêu vặt.
    public let noSpendDays: Int
    /// Ngày có ghi chép hoặc đã chốt.
    public let loggedDays: Int
    /// Số ngày của tuần đã qua tính cả hôm nay (1…7).
    public let elapsedDays: Int

    public var isEmpty: Bool { spent.isEmpty && loggedDays == 0 }

    /// Thứ Hai của tuần chứa `day`.
    public static func weekStart(of day: DayKey, calendar: Calendar) -> DayKey {
        let calendar = calendar.gregorianSameTimeZone
        // Gregorian: 1 = Chủ nhật, 2 = thứ Hai… → lùi về thứ Hai.
        let weekday = calendar.component(.weekday, from: day.date(in: calendar))
        return day.adding(days: -((weekday + 5) % 7), calendar: calendar)
    }

    /// Một tuần bất kỳ (xem lại các tuần cũ, Xu Pro). Tuần đã qua tính đủ 7 ngày; tuần hiện tại chỉ tính tới `today`,
    /// như `compute`. `weekStart` là thứ Hai của tuần đó (`weekStart(of:calendar:)`).
    public static func compute(weekStarting weekStart: DayKey, entries: [LedgerEntry], closedDays: Set<DayKey>,
                               today: DayKey, primary: Currency, calendar: Calendar,
                               catalog: [CategoryDefinition] = CategoryCatalog.defaults) -> WeeklySummary {
        let weekEnd = weekStart.adding(days: 6, calendar: calendar)
        return compute(entries: entries, closedDays: closedDays, today: min(weekEnd, today), primary: primary,
                       calendar: calendar, catalog: catalog)
    }

    public static func compute(entries: [LedgerEntry], closedDays: Set<DayKey>, today: DayKey,
                               primary: Currency, calendar: Calendar,
                               catalog: [CategoryDefinition] = CategoryCatalog.defaults) -> WeeklySummary {
        let calendar = calendar.gregorianSameTimeZone
        let start = weekStart(of: today, calendar: calendar)
        let end = start.adding(days: 6, calendar: calendar)

        let inWeek = entries.filter { $0.day >= start && $0.day <= today }
        var spent: [Currency: Int64] = [:]
        var byCategory: [String: Int64] = [:]
        for entry in inWeek where !entry.isIncome {
            spent[entry.currency, default: 0] += entry.amount
            if entry.currency == primary { byCategory[entry.categoryID, default: 0] += entry.amount }
        }
        let top = byCategory.max { a, b in a.value == b.value ? a.key > b.key : a.value < b.value }?.key

        let byDay = Dictionary(grouping: inWeek, by: \.day)
        var noSpend = 0, logged = 0, elapsed = 0
        var day = start
        while day <= today && day <= end {
            let dayEntries = byDay[day] ?? []
            let closed = closedDays.contains(day)
            if HabitTemplate.noSpendDay.evaluate(entries: dayEntries, dayClosed: closed, catalog: catalog) == true { noSpend += 1 }
            if HabitTemplate.logDaily.evaluate(entries: dayEntries, dayClosed: closed, catalog: catalog) == true { logged += 1 }
            elapsed += 1
            day = day.adding(days: 1, calendar: calendar)
        }
        return WeeklySummary(weekStart: start, weekEnd: end, spent: spent, topCategoryID: top,
                             noSpendDays: noSpend, loggedDays: logged, elapsedDays: elapsed)
    }
}
