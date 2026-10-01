import AppIntents
import SwiftData
import XuCore

/// "Ghi chi tiêu" — dùng cho app Phím tắt, Action Button, Spotlight.
/// Gợi ý phím tắt cho Action Button: [Đọc chính tả văn bản (Tiếng Việt)] → [Ghi chi tiêu].
struct LogExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Ghi chi tiêu"
    static let description = IntentDescription("Ghi một khoản chi bằng một câu, ví dụ \"cà phê 35k\".")
    static let openAppWhenRun = false

    @Parameter(title: "Nội dung", requestValueDialog: "Bạn vừa tiêu gì?")
    var text: String

    init() {}
    init(text: String) { self.text = text }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(SharedStore.container)
        let language = AppSettings.language
        let result = Ledger.parser(in: context).parse(text)
        guard result.isComplete else {
            let message = language.t(.missingAmount, language.exampleEntry(for: AppSettings.market))
            throw $text.needsValueError("\(message)")
        }
        let record = try Ledger.save(result, rawInput: text, source: .shortcut, in: context)
        let amount = MoneyFormatter.signed(record.amount, isIncome: record.isIncome, currency: record.currency,
                                           language: language, compact: true)
        let message = language.t(.intentSaved, amount, record.category.emoji + " " + record.category.name(in: language))
        return .result(dialog: "\(message)")
    }
}

/// Dành cho automation "Giao dịch" của Ví (Wallet) trong app Phím tắt:
/// Phím tắt truyền Số tiền + Người bán vào đây → tự ghi, không cần mở app.
struct LogPaymentIntent: AppIntent {
    static let title: LocalizedStringResource = "Ghi giao dịch thẻ"
    static let description = IntentDescription("Dùng trong Tự động hóa › Giao dịch để tự ghi khi quẹt Apple Pay.")
    static let openAppWhenRun = false

    @Parameter(title: "Số tiền") var amount: Double
    @Parameter(title: "Người bán", default: "") var merchant: String

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(SharedStore.container)
        let language = AppSettings.language
        let value = Int64(amount.rounded())
        guard value > 0 else { return .result(dialog: "\(language.t(.skippedZero))") }
        let matched = Ledger.parser(in: context).matcher.match(note: merchant)
        let categoryID = (matched?.kind == .expense ? matched?.id : nil) ?? CategoryCatalog.otherExpenseID
        // Thẻ trong Ví thường thanh toán bằng tiền của nơi đang sống, nên lấy tiền của nơi chi tiêu.
        let result = QuickEntryResult(amount: value, currency: AppSettings.market.currency, isIncome: false,
                                      date: Date(), categoryID: categoryID, note: merchant)
        let record = try Ledger.save(result, rawInput: merchant, source: .applePay, in: context)
        let amountText = MoneyFormatter.compact(record.amount, currency: record.currency, language: language)
        return .result(dialog: "\(language.t(.intentSaved, amountText, record.category.emoji + " " + merchant))")
    }
}
