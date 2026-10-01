import Foundation
import SwiftData
import XuCore

// Quy tắc cho mọi @Model (để bật CloudKit ở v1.1 không phải migrate):
// - mọi thuộc tính có giá trị mặc định
// - không dùng @Attribute(.unique)
// - quan hệ luôn optional

enum EntrySource: String, Codable, CaseIterable {
    case quickText, voice, widgetChip, shortcut, applePay, screenshot, manual
}

@Model
final class TransactionRecord {
    var id: UUID = UUID()
    var amount: Int64 = 0
    var currencyCode: String = "VND"
    var isIncome: Bool = false
    var categoryID: String = CategoryCatalog.otherExpenseID
    var note: String = ""
    var occurredAt: Date = Date()
    var createdAt: Date = Date()
    var sourceRaw: String = EntrySource.manual.rawValue
    /// Câu gốc người dùng gõ. Chỉ lưu trên máy để cải thiện parser — không bao giờ gửi đi.
    var rawInput: String = ""

    init(amount: Int64, isIncome: Bool, categoryID: String, note: String,
         occurredAt: Date, source: EntrySource, rawInput: String = "") {
        self.amount = amount
        self.isIncome = isIncome
        self.categoryID = categoryID
        self.note = note
        self.occurredAt = occurredAt
        self.sourceRaw = source.rawValue
        self.rawInput = rawInput
    }

    var source: EntrySource { EntrySource(rawValue: sourceRaw) ?? .manual }
    var category: CategoryDefinition { CategoryCatalog.resolve(id: categoryID) }
}

/// Khoản quen, hiển thị thành nút trên widget.
@Model
final class QuickChip {
    var id: UUID = UUID()
    var title: String = ""
    var emoji: String = "💸"
    var amount: Int64 = 0
    var categoryID: String = CategoryCatalog.otherExpenseID
    var sortOrder: Int = 0

    init(title: String, emoji: String, amount: Int64, categoryID: String, sortOrder: Int) {
        self.title = title
        self.emoji = emoji
        self.amount = amount
        self.categoryID = categoryID
        self.sortOrder = sortOrder
    }
}

/// Từ khóa học được khi người dùng sửa danh mục.
@Model
final class LearnedKeyword {
    var phrase: String = ""
    var categoryID: String = CategoryCatalog.otherExpenseID
    var updatedAt: Date = Date()

    init(phrase: String, categoryID: String) {
        self.phrase = phrase
        self.categoryID = categoryID
    }
}

@Model
final class MoneyHabit {
    var id: UUID = UUID()
    var templateRaw: String = HabitTemplate.logDaily.rawValue
    var title: String = ""
    var emoji: String = ""
    var createdAt: Date = Date()
    var isArchived: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \HabitCheckIn.habit)
    var checkIns: [HabitCheckIn]? = []

    init(template: HabitTemplate) {
        self.templateRaw = template.rawValue
        self.title = template.defaultTitle
        self.emoji = template.emoji
    }

    var template: HabitTemplate { HabitTemplate(rawValue: templateRaw) ?? .logDaily }
}

@Model
final class HabitCheckIn {
    var year: Int = 1970
    var month: Int = 1
    var day: Int = 1
    var isRest: Bool = false
    var habit: MoneyHabit?

    init(day key: DayKey, isRest: Bool = false, habit: MoneyHabit) {
        self.year = key.year
        self.month = key.month
        self.day = key.day
        self.isRest = isRest
        self.habit = habit
    }

    var dayKey: DayKey { DayKey(year: year, month: month, day: day) }
}

/// "Chốt ngày" — người dùng xác nhận đã ghi đủ cho ngày đó.
@Model
final class DayClosure {
    var year: Int = 1970
    var month: Int = 1
    var day: Int = 1
    var closedAt: Date = Date()

    init(day key: DayKey) {
        self.year = key.year
        self.month = key.month
        self.day = key.day
    }

    var dayKey: DayKey { DayKey(year: year, month: month, day: day) }
}
