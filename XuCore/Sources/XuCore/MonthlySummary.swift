import Foundation

/// Một tháng dương lịch, để chuyển qua lại giữa các tháng trên màn "Tháng này".
public struct MonthKey: Hashable, Comparable, Sendable {
    public let year: Int
    /// 1…12
    public let month: Int

    public init(year: Int, month: Int) {
        // Đưa về 1…12, mang phần dư sang năm: (2026, 13) → (2027, 1), (2026, 0) → (2025, 12).
        let index = year * 12 + (month - 1)
        self.year = index >= 0 ? index / 12 : (index + 1) / 12 - 1
        self.month = index - self.year * 12 + 1
    }

    public init(_ day: DayKey) {
        self.init(year: day.year, month: day.month)
    }

    public func adding(months: Int) -> MonthKey {
        MonthKey(year: year, month: month + months)
    }

    public func contains(_ day: DayKey) -> Bool {
        day.year == year && day.month == month
    }

    public static func < (lhs: MonthKey, rhs: MonthKey) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }
}

/// "Tháng này theo danh mục" (docs/02, O4): chi bao nhiêu, vào những danh mục nào. Chỉ kể lại, không có màu đỏ hay
/// "vượt ngân sách" (docs/05).
public struct MonthlySummary: Equatable, Sendable {
    public struct Slice: Equatable, Sendable {
        public let categoryID: String
        public let amount: Int64
    }

    public let month: MonthKey
    /// Tổng chi theo từng loại tiền, không quy đổi (tỷ giá cần mạng — docs/08).
    public let spent: [Currency: Int64]
    /// Chi theo danh mục bằng tiền của nơi chi tiêu, nhiều nhất trước; bằng nhau thì theo mã danh mục.
    /// Mã không còn trong danh mục gộp vào "Khác", để mỗi danh mục chỉ có một thanh.
    public let byCategory: [Slice]

    public var isEmpty: Bool { spent.isEmpty }

    public static func compute(entries: [LedgerEntry], month: MonthKey, primary: Currency) -> MonthlySummary {
        var spent: [Currency: Int64] = [:]
        var byCategory: [String: Int64] = [:]
        for entry in entries where !entry.isIncome && month.contains(entry.day) {
            spent[entry.currency, default: 0] += entry.amount
            if entry.currency == primary {
                byCategory[CategoryCatalog.resolve(id: entry.categoryID).id, default: 0] += entry.amount
            }
        }
        let slices = byCategory.map { Slice(categoryID: $0.key, amount: $0.value) }
            .sorted { $0.amount == $1.amount ? $0.categoryID < $1.categoryID : $0.amount > $1.amount }
        return MonthlySummary(month: month, spent: spent, byCategory: slices)
    }
}
