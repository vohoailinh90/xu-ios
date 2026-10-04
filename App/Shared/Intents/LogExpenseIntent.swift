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
/// Phím tắt truyền Số tiền (kèm loại tiền của giao dịch) + Người bán vào đây → tự ghi, không cần mở app.
/// Luồng automation này cần thử trên máy thật (docs/06).
///
/// Bản Free tự ghi tối đa `ProPlan.freeApplePayLogsPerMonth` khoản mỗi tháng dương lịch, Xu Pro không giới hạn (docs/02, quyết định 2026-10-04).
/// Chỉ khoản **đã ghi được** mới bị trừ lượt. Hết lượt thì khoản đó không được ghi nhưng cũng **không bị bỏ mất**: Xu giữ lại trên máy
/// (`PendingPayments`) để hiện ở Home cho người dùng ghi sau, vì automation chạy nền nên lời nhắn của tác vụ và thông báo (`ApplePayLimitNotice`,
/// chỉ khi đã cho phép thông báo) không được bảo đảm hiện. Ghi tay và `LogExpenseIntent` không bao giờ bị đếm.
struct LogPaymentIntent: AppIntent {
    static let title: LocalizedStringResource = "Ghi giao dịch thẻ"
    static let description = IntentDescription("Dùng trong Tự động hóa › Giao dịch để tự ghi khi quẹt Apple Pay.")
    static let openAppWhenRun = false

    @Parameter(title: "Số tiền") var amount: IntentCurrencyAmount
    @Parameter(title: "Người bán", default: "") var merchant: String

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(SharedStore.container)
        let language = AppSettings.language
        // Loại tiền của chính giao dịch; không có thì lấy tiền của nơi chi tiêu.
        // Tiền Xu chưa hỗ trợ thì không ghi (ghi nhầm ¥1.000 thành 1.000đ còn tệ hơn bỏ sót) và nói rõ.
        let code = Self.trimmed(amount.currencyCode)
        let currency: Currency
        if code.isEmpty {
            currency = AppSettings.market.currency
        } else if let known = Currency(exactCode: code) {
            currency = known
        } else {
            return .result(dialog: "\(language.t(.unsupportedCurrency, code))")
        }
        let value = Currency.wholeUnits(amount.amount)
        guard value > 0 else { return .result(dialog: "\(language.t(.skippedZero))") }

        let month = MonthKey(DayKey(Date(), calendar: .current))
        // Luôn hỏi StoreKit trước khi đếm hay giới hạn: bản sao `AppSettings.isPro` chỉ cập nhật khi mở app nên có thể cũ — cũ theo hướng
        // chưa Pro (cài lại máy: người dùng Pro bị đếm/giới hạn nhầm) hay đã hết Pro (hoàn tiền: tự ghi không giới hạn tới lần mở app sau).
        let isPro = await ProEntitlement.verifyAndCache()
        let limit = ProPlan.freeApplePayLogsPerMonth
        var quota = AppSettings.applePayQuota ?? MonthlyQuota(month: month)
        guard quota.canUse(limit: limit, isPro: isPro, in: month) else {
            // Không ghi, nhưng giữ khoản lại trên máy để Home hiện cho người dùng ghi sau: không bao giờ bỏ mất lặng lẽ.
            // Mỗi khoản một khoá riêng nên không đè lên khoản khác hay thao tác xoá đang diễn ra trong app.
            try AppSettings.addPendingPayment(PendingPayment(amount: value, currencyCode: currency.code, merchant: merchant, date: Date()))
            let amountText = MoneyFormatter.compact(value, currency: currency, language: language)
            let what = merchant.isEmpty ? amountText : "\(amountText) · \(merchant)"
            await ApplePayLimitNotice.post(language: language)
            return .result(dialog: "\(language.t(.applePayLimitReached, what, "\(limit)"))")
        }

        let matched = Ledger.parser(in: context).matcher.match(note: merchant)
        let categoryID = (matched?.kind == .expense ? matched?.id : nil) ?? CategoryCatalog.otherExpenseID
        let result = QuickEntryResult(amount: value, currency: currency, isIncome: false,
                                      date: Date(), categoryID: categoryID, note: merchant)
        let record = try Ledger.save(result, rawInput: merchant, source: .applePay, in: context)
        if !isPro {
            // Chỉ đếm sau khi ghi được: khoản lỗi hay bị bỏ qua không mất lượt.
            quota.recordUse(in: month)
            AppSettings.applePayQuota = quota
        }
        let amountText = MoneyFormatter.compact(record.amount, currency: record.currency, language: language)
        let what = record.category.emoji + " " + merchant
        // Báo trước khi sắp hết (còn 2 lần trở xuống) để hết lượt không bất ngờ.
        if let left = quota.remaining(limit: limit, isPro: isPro, in: month), left <= 2 {
            return .result(dialog: "\(language.t(.intentSavedAllowance, amountText, what, "\(left)"))")
        }
        return .result(dialog: "\(language.t(.intentSaved, amountText, what))")
    }

    private static func trimmed(_ code: String) -> String { code.trimmingCharacters(in: .whitespaces) }
    private static func trimmed(_ code: String?) -> String { trimmed(code ?? "") }
}
