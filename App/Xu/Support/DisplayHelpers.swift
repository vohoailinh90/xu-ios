import Foundation
import XuCore

/// "Hôm nay", "Hôm qua" hoặc "Thứ Tư, 23 thg 9" / "9月23日 水曜日" theo ngôn ngữ đang chọn.
enum DayLabel {
    static func text(for date: Date, language: AppLanguage, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return language.t(.today) }
        if calendar.isDateInYesterday(date) { return language.t(.yesterday) }
        return date.formatted(.dateTime.weekday(.wide).day().month().locale(language.locale))
    }
}

/// Tổng chi theo từng loại tiền, không quy đổi (tỷ giá cần mạng — docs/08).
/// Tiền của nơi chi tiêu đứng trước: "45k · ¥1.200".
enum SpendingSummary {
    static func totals(of records: [TransactionRecord]) -> [Currency: Int64] {
        records.filter { !$0.isIncome }.reduce(into: [:]) { sums, record in
            sums[record.currency, default: 0] += record.amount
        }
    }

    static func text(for records: [TransactionRecord], primary: Currency, language: AppLanguage) -> String {
        let sums = totals(of: records)
        let order = [primary] + Currency.allCases.filter { $0 != primary }
        let parts = order.compactMap { currency -> String? in
            guard let sum = sums[currency], sum > 0 else { return nil }
            return MoneyFormatter.compact(sum, currency: currency, language: language)
        }
        return parts.isEmpty ? MoneyFormatter.compact(0, currency: primary, language: language)
                             : parts.joined(separator: " · ")
    }
}
