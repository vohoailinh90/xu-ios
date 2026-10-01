import Foundation

/// Một ngày lịch (không có giờ), dùng làm khóa cho check-in và chốt ngày.
public struct DayKey: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year; self.month = month; self.day = day
    }

    public init(_ date: Date, calendar: Calendar) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 1970, month: c.month ?? 1, day: c.day ?? 1)
    }

    public func date(in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date(timeIntervalSince1970: 0)
    }

    public func adding(days: Int, calendar: Calendar) -> DayKey {
        let shifted = calendar.date(byAdding: .day, value: days, to: date(in: calendar)) ?? date(in: calendar)
        return DayKey(shifted, calendar: calendar)
    }

    public static func < (a: DayKey, b: DayKey) -> Bool {
        (a.year, a.month, a.day) < (b.year, b.month, b.day)
    }

    public var description: String {
        func pad(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }
        return "\(year)-\(pad(month))-\(pad(day))"
    }
}

/// Bản ghi giao dịch tối giản để XuCore đánh giá thói quen mà không phụ thuộc SwiftData.
public struct LedgerEntry: Sendable {
    public let amount: Int64
    public let isIncome: Bool
    public let categoryID: String
    public let day: DayKey

    public init(amount: Int64, isIncome: Bool, categoryID: String, day: DayKey) {
        self.amount = amount; self.isIncome = isIncome; self.categoryID = categoryID; self.day = day
    }
}

public enum HabitTemplate: String, CaseIterable, Codable, Sendable {
    case logDaily
    case noSpendDay
    case noBubbleTea
    case cookAtHome
    case saveToday

    public var titles: LocalizedText {
        switch self {
        case .logDaily: LocalizedText(vi: "Ghi chép mỗi ngày", en: "Log every day", ja: "毎日記録する")
        case .noSpendDay: LocalizedText(vi: "Ngày không tiêu vặt", en: "No-spend day", ja: "小さな出費なしの日")
        case .noBubbleTea: LocalizedText(vi: "Không trà sữa", en: "No bubble tea", ja: "タピオカを控える")
        case .cookAtHome: LocalizedText(vi: "Nấu ăn ở nhà", en: "Cook at home", ja: "自炊する")
        case .saveToday: LocalizedText(vi: "Để dành hôm nay", en: "Save today", ja: "今日は貯金")
        }
    }

    public func title(in language: AppLanguage) -> String { titles[language] }

    /// Tên tiếng Việt (ngôn ngữ phát triển chính).
    public var defaultTitle: String { titles.vi }

    public var emoji: String {
        switch self {
        case .logDaily: "📝"
        case .noSpendDay: "🌱"
        case .noBubbleTea: "🧋"
        case .cookAtHome: "🍳"
        case .saveToday: "🐷"
        }
    }

    public var isAutomatic: Bool {
        switch self {
        case .logDaily, .noSpendDay, .noBubbleTea: true
        case .cookAtHome, .saveToday: false
        }
    }

    /// Đánh giá tự động cho một ngày. `nil` = thói quen thủ công hoặc chưa đủ dữ liệu.
    ///
    /// Các thói quen "không tiêu…" chỉ được tính khi ngày **đã chốt**, để không thưởng nhầm
    /// cho một ngày người dùng chỉ đơn giản là quên ghi.
    public func evaluate(entries: [LedgerEntry], dayClosed: Bool,
                         catalog: [CategoryDefinition] = CategoryCatalog.defaults) -> Bool? {
        let expenses = entries.filter { !$0.isIncome }
        switch self {
        case .logDaily:
            return !entries.isEmpty || dayClosed
        case .noSpendDay:
            guard dayClosed else { return nil }
            let discretionary = Set(catalog.filter(\.isDiscretionary).map(\.id))
            return !expenses.contains { discretionary.contains($0.categoryID) }
        case .noBubbleTea:
            guard dayClosed else { return nil }
            return !expenses.contains { $0.categoryID == "drinks" }
        case .cookAtHome, .saveToday:
            return nil
        }
    }
}

public enum HabitEngine {
    /// Hệ số giữ lại mỗi ngày: chu kỳ bán rã ~13 ngày (giống Loop Habit Tracker cho thói quen hằng ngày).
    public static let dailyMultiplier: Double = pow(0.5, 1.0 / 13.0)

    /// Điểm sức mạnh thói quen 0…1. Lỡ một ngày chỉ giảm ~5%, không reset về 0.
    /// Ngày nghỉ (`restDays`) được bỏ qua hoàn toàn.
    public static func strength(completed: Set<DayKey>, restDays: Set<DayKey> = [],
                                from start: DayKey, through end: DayKey, calendar: Calendar) -> Double {
        guard start <= end else { return 0 }
        let m = dailyMultiplier
        var score = 0.0
        var day = start
        var guardCounter = 0
        while day <= end && guardCounter < 3660 {
            if !restDays.contains(day) {
                score = score * m + (completed.contains(day) ? 1 : 0) * (1 - m)
            }
            day = day.adding(days: 1, calendar: calendar)
            guardCounter += 1
        }
        return min(max(score, 0), 1)
    }

    /// Chuỗi mềm: đếm số ngày hoàn thành liên tiếp tính ngược từ hôm nay.
    /// - Hôm nay chưa xong thì chưa tính là lỡ.
    /// - Ngày nghỉ không cắt chuỗi.
    /// - Mỗi cửa sổ 7 ngày được `freezesPerWeek` lần lỡ mà chuỗi không đứt.
    public static func softStreak(completed: Set<DayKey>, restDays: Set<DayKey> = [],
                                  today: DayKey, freezesPerWeek: Int = 1, calendar: Calendar) -> Int {
        guard let earliest = completed.min() else { return 0 }
        var streak = 0
        var missOffsets: [Int] = []
        var offset = completed.contains(today) ? 0 : 1
        while offset < 3660 {
            let day = today.adding(days: -offset, calendar: calendar)
            if day < earliest { break }
            if completed.contains(day) {
                streak += 1
            } else if !restDays.contains(day) {
                let recentMisses = missOffsets.filter { offset - $0 < 7 }.count
                if recentMisses >= freezesPerWeek { break }
                missOffsets.append(offset)
            }
            offset += 1
        }
        return streak
    }
}

/// Tình hình một thói quen tới hôm nay: các ngày đã xong, sức mạnh, chuỗi mềm.
public struct HabitProgress: Equatable, Sendable {
    public let completedDays: Set<DayKey>
    /// 0…1. Hôm nay chưa xong thì tính tới hôm qua, để không "trừ điểm" khi ngày chưa hết.
    public let strength: Double
    public let streak: Int
    public let isDoneToday: Bool

    /// Tính cho một thói quen bắt đầu từ `start`.
    /// - Thói quen tự động: đánh giá từng ngày bằng `HabitTemplate.evaluate` (cần giao dịch và ngày đã chốt).
    /// - Thói quen thủ công: ngày xong là ngày người dùng tự đánh dấu (`manualDays`).
    public static func compute(template: HabitTemplate,
                               entries: [LedgerEntry],
                               closedDays: Set<DayKey>,
                               manualDays: Set<DayKey> = [],
                               restDays: Set<DayKey> = [],
                               from start: DayKey,
                               today: DayKey,
                               calendar: Calendar,
                               catalog: [CategoryDefinition] = CategoryCatalog.defaults) -> HabitProgress {
        guard start <= today else {
            return HabitProgress(completedDays: [], strength: 0, streak: 0, isDoneToday: false)
        }
        var completed: Set<DayKey> = []
        if template.isAutomatic {
            let byDay = Dictionary(grouping: entries.filter { $0.day >= start && $0.day <= today }, by: \.day)
            var day = start
            var guardCounter = 0
            while day <= today && guardCounter < 3660 {
                if template.evaluate(entries: byDay[day] ?? [], dayClosed: closedDays.contains(day), catalog: catalog) == true {
                    completed.insert(day)
                }
                day = day.adding(days: 1, calendar: calendar)
                guardCounter += 1
            }
        } else {
            completed = manualDays.filter { $0 >= start && $0 <= today }
        }

        let isDoneToday = completed.contains(today)
        let through = isDoneToday ? today : today.adding(days: -1, calendar: calendar)
        let strength = through < start ? 0
            : HabitEngine.strength(completed: completed, restDays: restDays, from: start, through: through, calendar: calendar)
        let streak = HabitEngine.softStreak(completed: completed, restDays: restDays, today: today, calendar: calendar)
        return HabitProgress(completedDays: completed, strength: strength, streak: streak, isDoneToday: isDoneToday)
    }
}
