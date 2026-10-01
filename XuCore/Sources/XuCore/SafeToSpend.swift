import Foundation

/// "Hôm nay còn được tiêu bao nhiêu" — thay cho ngân sách theo danh mục với màu đỏ.
public struct SafeToSpend: Equatable, Sendable {
    /// Mức được tiêu mỗi ngày, chia đều số tiền còn lại (tính từ đầu hôm nay) cho các ngày còn lại.
    public let dailyAllowance: Int64
    /// Còn được tiêu hôm nay. Có thể âm khi hôm nay tiêu quá.
    public let remainingToday: Int64
    /// Còn lại cả kỳ sau khi trừ cả khoản hôm nay. Có thể âm.
    public let remainingInPeriod: Int64
    /// Số ngày còn lại tính cả hôm nay (≥ 1).
    public let daysLeft: Int

    /// Nếu hôm nay tiêu quá: mức mỗi ngày cho các ngày *sau* hôm nay. `nil` nếu hôm nay là ngày cuối kỳ.
    public var adjustedAllowanceForComingDays: Int64? {
        guard daysLeft > 1 else { return nil }
        return max(0, remainingInPeriod) / Int64(daysLeft - 1)
    }

    public var isOverToday: Bool { remainingToday < 0 }

    /// Kỳ này không còn gì để chia cho những ngày tới (hết hẳn, hoặc chỉ còn lẻ chia ra 0 mỗi ngày).
    /// Khi đó đừng hứa "mỗi ngày khoảng 0 là cân lại được" — nói nhẹ nhàng là đã dùng hết.
    public var isBudgetUsedUp: Bool {
        remainingInPeriod <= 0 || (isOverToday && (adjustedAllowanceForComingDays ?? 0) == 0)
    }

    public static func compute(flexibleBudget: Int64,
                               spentBeforeToday: Int64,
                               spentToday: Int64,
                               today: DayKey,
                               periodEnd: DayKey,
                               calendar: Calendar) -> SafeToSpend {
        let from = today.date(in: calendar)
        let to = periodEnd.date(in: calendar)
        let diff = calendar.dateComponents([.day], from: from, to: to).day ?? 0
        let daysLeft = max(1, diff + 1)

        let availableFromToday = max(0, flexibleBudget - spentBeforeToday)
        let daily = availableFromToday / Int64(daysLeft)
        return SafeToSpend(dailyAllowance: daily,
                           remainingToday: daily - spentToday,
                           remainingInPeriod: flexibleBudget - spentBeforeToday - spentToday,
                           daysLeft: daysLeft)
    }

    /// Ngày cuối của tháng chứa `day`.
    public static func endOfMonth(containing day: DayKey, calendar: Calendar) -> DayKey {
        let date = day.date(in: calendar)
        guard let range = calendar.range(of: .day, in: .month, for: date) else { return day }
        return DayKey(year: day.year, month: day.month, day: range.upperBound - 1)
    }
}
