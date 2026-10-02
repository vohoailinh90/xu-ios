import Foundation
import SwiftData
import XuCore
#if canImport(WidgetKit)
import WidgetKit
#endif

enum SharedStore {
    /// Đổi thành App Group của bạn (phải khớp với project.yml).
    static let appGroupID = "group.com.example.xu"

    static let schema = Schema([
        TransactionRecord.self,
        QuickChip.self,
        LearnedKeyword.self,
        MoneyHabit.self,
        HabitCheckIn.self,
        DayClosure.self
    ])

    /// Một container dùng chung cho app, widget và App Intents.
    /// CloudKit tắt ở MVP; bật ở v1.1 bằng `.automatic` + entitlement iCloud.
    static let container: ModelContainer = {
        let configuration = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(appGroupID),
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Không tạo được ModelContainer: \(error)")
        }
    }()
}

/// Cửa ngõ duy nhất để ghi giao dịch — app, widget và Shortcuts đều đi qua đây.
@MainActor
enum Ledger {
    @discardableResult
    static func save(_ result: QuickEntryResult, rawInput: String, source: EntrySource,
                     in context: ModelContext) throws -> TransactionRecord {
        guard let record = try save([result], rawInput: rawInput, source: source, in: context).first else {
            throw LedgerError.missingAmount
        }
        return record
    }

    /// Lưu nhiều khoản tách từ một câu (E8) trong một lần lưu: được cả, hoặc không khoản nào.
    @discardableResult
    static func save(_ results: [QuickEntryResult], rawInput: String, source: EntrySource,
                     in context: ModelContext) throws -> [TransactionRecord] {
        let records = results.compactMap { result in
            result.amount.map { amount in
                TransactionRecord(amount: amount, currency: result.currency, isIncome: result.isIncome,
                                  categoryID: result.categoryID, note: result.note,
                                  occurredAt: occurredAt(for: result.date),
                                  day: DayKey(result.date, calendar: .current), source: source, rawInput: rawInput)
            }
        }
        guard !records.isEmpty, records.count == results.count else { throw LedgerError.missingAmount }
        for record in records { context.insert(record) }
        do {
            try context.save()
        } catch {
            // Không để khoản chưa lưu được nằm lại trong context rồi bị tự lưu sau.
            for record in records { context.delete(record) }
            throw error
        }
        reloadWidgets()
        return records
    }

    static func save(chip: QuickChip, in context: ModelContext) throws {
        let record = TransactionRecord(amount: chip.amount, currency: chip.currency, isIncome: false,
                                       categoryID: chip.categoryID, note: chip.title,
                                       occurredAt: Date(), source: .widgetChip)
        context.insert(record)
        try context.save()
        reloadWidgets()
    }

    /// Sửa một giao dịch trong danh sách. Đổi sang ngày khác thì đặt giờ như khi ghi mới (12:00 hoặc bây giờ); giữ nguyên
    /// ngày thì giữ nguyên giờ lúc ghi. Ngày trên màn sửa luôn được chốt vào `storedDay`, kể cả khoản cũ chưa có.
    static func update(_ record: TransactionRecord, amount: Int64, currency: Currency, isIncome: Bool,
                       categoryID: String, note: String, day: Date, in context: ModelContext) throws {
        guard amount > 0 else { throw LedgerError.missingAmount }
        let newDay = DayKey(day, calendar: .current)
        if newDay != record.day() {
            record.occurredAt = occurredAt(for: day)
        }
        record.storedDay = newDay.description
        record.amount = amount
        record.currencyCode = currency.code
        record.isIncome = isIncome
        record.categoryID = categoryID
        record.note = note
        try context.save()
        reloadWidgets()
    }

    static func delete(_ record: TransactionRecord, in context: ModelContext) throws {
        try delete([record], in: context)
    }

    static func delete(_ records: [TransactionRecord], in context: ModelContext) throws {
        for record in records { context.delete(record) }
        try context.save()
        reloadWidgets()
    }

    /// "Chốt ngày": người dùng xác nhận đã ghi đủ (hoặc mở lại). Thói quen "không tiêu…" chỉ tính ngày đã chốt.
    static func setDayClosed(_ day: DayKey, closed: Bool, in context: ModelContext) throws {
        let (year, month, dayOfMonth) = (day.year, day.month, day.day)
        let existing = try context.fetch(FetchDescriptor<DayClosure>(
            predicate: #Predicate { $0.year == year && $0.month == month && $0.day == dayOfMonth }
        ))
        if closed, existing.isEmpty {
            context.insert(DayClosure(day: day))
        } else if !closed {
            for closure in existing { context.delete(closure) }
        }
        try context.save()
    }

    /// Người dùng sửa danh mục → lưu từ khóa để lần sau đoán đúng.
    static func learn(note: String, categoryID: String, in context: ModelContext) throws {
        let phrase = CategoryMatcher.learningKey(for: note)
        guard !phrase.isEmpty else { return }
        let existing = try context.fetch(FetchDescriptor<LearnedKeyword>(
            predicate: #Predicate { $0.phrase == phrase }
        ))
        if let keyword = existing.first {
            keyword.categoryID = categoryID
            keyword.updatedAt = Date()
        } else {
            context.insert(LearnedKeyword(phrase: phrase, categoryID: categoryID))
        }
        try context.save()
    }

    /// Parser có kèm từ khóa người dùng đã dạy và nơi chi tiêu đang chọn.
    static func parser(in context: ModelContext) -> QuickEntryParser {
        let learned = (try? context.fetch(FetchDescriptor<LearnedKeyword>())) ?? []
        let map = Dictionary(learned.map { ($0.phrase, $0.categoryID) }, uniquingKeysWith: { first, _ in first })
        let thousands = UserDefaults.standard.object(forKey: "smallNumbersAreThousands") as? Bool ?? true
        return QuickEntryParser(options: .init(smallNumbersAreThousands: thousands, market: AppSettings.market),
                                matcher: CategoryMatcher(learned: map))
    }

    /// Ngày hôm nay → giữ giờ hiện tại; ngày khác → đặt 12:00 trưa để tránh lệch ngày khi đổi múi giờ.
    private static func occurredAt(for day: Date) -> Date {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return Date() }
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    }

    private static func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}

enum LedgerError: LocalizedError {
    case missingAmount

    var errorDescription: String? {
        switch self {
        case .missingAmount:
            let language = AppSettings.language
            return language.t(.missingAmount, language.exampleEntry(for: AppSettings.market))
        }
    }
}
