import Foundation

extension Calendar {
    /// Lịch Gregorian cùng múi giờ với lịch này.
    ///
    /// Xu luôn tính ngày/tháng/năm theo Gregorian: câu nhập ("9/12", "2026年"), `DayKey`, cuối tháng của
    /// ngân sách, tuần. Máy có thể đặt lịch khác (lịch Nhật cho năm Reiwa 8, lịch Hồi giáo có tháng 29–30 ngày),
    /// khi đó `Calendar.current` cho năm/tháng không khớp với những gì người dùng gõ và thấy trong app.
    public var gregorianSameTimeZone: Calendar {
        guard identifier != .gregorian else { return self }
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = timeZone
        gregorian.locale = locale
        return gregorian
    }
}
