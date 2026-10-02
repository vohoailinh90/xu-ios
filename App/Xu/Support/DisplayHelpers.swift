import Foundation
import XuCore

/// "Hôm nay", "Hôm qua" hoặc "Thứ Tư, 23 thg 9" / "9月23日 水曜日" theo ngôn ngữ đang chọn.
/// Ngày không thuộc năm nay thì kèm năm, để "1/3/2025" không trông giống ngày 1/3 năm nay.
enum DayLabel {
    static func text(for date: Date, language: AppLanguage, calendar: Calendar = .current, now: Date = Date()) -> String {
        if calendar.isDateInToday(date) { return language.t(.today) }
        if calendar.isDateInYesterday(date) { return language.t(.yesterday) }
        let style = Date.FormatStyle.dateTime.weekday(.wide).day().month().locale(language.locale)
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        return date.formatted(sameYear ? style : style.year())
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
        text(for: totals(of: records), primary: primary, language: language)
    }

    static func text(for sums: [Currency: Int64], primary: Currency, language: AppLanguage) -> String {
        let order = [primary] + Currency.allCases.filter { $0 != primary }
        let parts = order.compactMap { currency -> String? in
            guard let sum = sums[currency], sum > 0 else { return nil }
            return MoneyFormatter.compact(sum, currency: currency, language: language)
        }
        return parts.isEmpty ? MoneyFormatter.compact(0, currency: primary, language: language)
                             : parts.joined(separator: " · ")
    }
}
