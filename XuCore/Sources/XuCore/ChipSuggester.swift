import Foundation

/// Đề xuất khoản quen (E7) từ các khoản chi lặp lại: cùng ghi chú, cùng số tiền, cùng loại tiền,
/// xuất hiện ở ít nhất `minimumDays` ngày khác nhau trong `windowDays` ngày gần nhất.
/// Chạy hoàn toàn trên máy, chỉ đọc giao dịch đã có (docs/01: riêng tư).
public enum ChipSuggester {
    /// Ghim tối đa 8 khoản quen (docs/02, E7). Widget vừa hiện 4 khoản đầu.
    public static let maxPinned = 8

    public struct Entry: Sendable {
        public let note: String
        public let amount: Int64
        public let currency: Currency
        public let categoryID: String
        public let isIncome: Bool
        public let day: DayKey

        public init(note: String, amount: Int64, currency: Currency, categoryID: String, isIncome: Bool, day: DayKey) {
            self.note = note; self.amount = amount; self.currency = currency
            self.categoryID = categoryID; self.isIncome = isIncome; self.day = day
        }
    }

    /// Khoản quen đang ghim, chỉ cần đủ để nhận ra trùng.
    public struct Pinned: Sendable {
        public let title: String
        public let amount: Int64
        public let currency: Currency

        public init(title: String, amount: Int64, currency: Currency) {
            self.title = title; self.amount = amount; self.currency = currency
        }
    }

    public struct Suggestion: Hashable, Sendable {
        /// Ghi chú như người dùng gõ lần gần nhất (giữ dấu).
        public let title: String
        public let amount: Int64
        public let currency: Currency
        /// Danh mục dùng nhiều nhất cho khoản này; hoà thì lấy lần gần nhất.
        public let categoryID: String
        /// Số ngày khác nhau đã ghi khoản này trong cửa sổ.
        public let days: Int
    }

    public static func suggest(entries: [Entry], pinned: [Pinned], today: DayKey, calendar: Calendar,
                               windowDays: Int = 30, minimumDays: Int = 3, limit: Int = 3) -> [Suggestion] {
        let start = today.adding(days: -(windowDays - 1), calendar: calendar)
        let taken = Set(pinned.map { Key(note: $0.title, amount: $0.amount, currency: $0.currency) })

        struct Group {
            var days: Set<DayKey> = []
            var latest: (day: DayKey, index: Int, note: String)?
            var categoryCounts: [String: Int] = [:]
            var categoryLatest: [String: (DayKey, Int)] = [:]
        }
        var groups: [Key: Group] = [:]

        for (index, entry) in entries.enumerated() {
            guard !entry.isIncome, entry.amount > 0, entry.day >= start, entry.day <= today else { continue }
            let key = Key(note: entry.note, amount: entry.amount, currency: entry.currency)
            guard !key.note.isEmpty, !taken.contains(key) else { continue }
            var group = groups[key] ?? Group()
            group.days.insert(entry.day)
            let stamp = (entry.day, index)
            if group.latest.map({ ($0.day, $0.index) < stamp }) ?? true {
                group.latest = (entry.day, index, entry.note.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            group.categoryCounts[entry.categoryID, default: 0] += 1
            if group.categoryLatest[entry.categoryID].map({ $0 < stamp }) ?? true {
                group.categoryLatest[entry.categoryID] = stamp
            }
            groups[key] = group
        }

        let suggestions = groups.compactMap { key, group -> (Suggestion, DayKey)? in
            guard group.days.count >= minimumDays, let latest = group.latest else { return nil }
            let categoryID = group.categoryCounts.max { a, b in
                if a.value != b.value { return a.value < b.value }
                return (group.categoryLatest[a.key] ?? (start, -1)) < (group.categoryLatest[b.key] ?? (start, -1))
            }?.key ?? CategoryCatalog.otherExpenseID
            let suggestion = Suggestion(title: latest.note, amount: key.amount, currency: key.currency,
                                        categoryID: categoryID, days: group.days.count)
            return (suggestion, latest.day)
        }
        return suggestions
            .sorted { a, b in
                if a.0.days != b.0.days { return a.0.days > b.0.days }
                if a.1 != b.1 { return a.1 > b.1 }
                return a.0.title < b.0.title
            }
            .prefix(limit)
            .map { $0.0 }
    }

    /// "Cà phê", "ca phe", "ＣＡＦＥ " là một khoản; khác số tiền hay loại tiền là khoản khác.
    private struct Key: Hashable {
        let note: String
        let amount: Int64
        let currency: Currency

        init(note: String, amount: Int64, currency: Currency) {
            let folded = TextFolding.fold(note.trimmingCharacters(in: .whitespacesAndNewlines))
            self.note = folded.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            self.amount = amount
            self.currency = currency
        }
    }
}
