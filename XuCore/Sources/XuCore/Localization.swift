import Foundation

/// Ngôn ngữ giao diện, chọn trong app (không phụ thuộc ngôn ngữ của máy) và đổi ngay không cần mở lại app.
/// Lý do không dùng String Catalog cho giao diện: xem docs/03-kien-truc.md, mục "Ngôn ngữ".
public enum AppLanguage: String, CaseIterable, Codable, Sendable, Identifiable {
    case vi
    case en
    case ja

    public var id: String { rawValue }

    /// Tên ngôn ngữ viết bằng chính nó, để ai cũng nhận ra ngôn ngữ của mình trong danh sách.
    public var nativeName: String {
        switch self {
        case .vi: "Tiếng Việt"
        case .en: "English"
        case .ja: "日本語"
        }
    }

    /// Dùng để định dạng ngày ("Thứ Sáu, 25 thg 9", "9月25日 金曜日").
    public var locale: Locale {
        switch self {
        case .vi: Locale(identifier: "vi_VN")
        case .en: Locale(identifier: "en_US")
        case .ja: Locale(identifier: "ja_JP")
        }
    }

    /// Ngôn ngữ đầu tiên Xu hỗ trợ trong danh sách ngôn ngữ ưa thích của máy
    /// (`Locale.preferredLanguages`, ví dụ "ja-JP", "vi-VN"). Không có thì dùng tiếng Việt (Việt Nam trước):
    /// máy đặt tiếng Hàn, tiếng Pháp… của người Việt ở nước ngoài vẫn mở ra tiếng Việt.
    public static func preferred(from languageTags: [String]) -> AppLanguage {
        for tag in languageTags {
            let code = tag.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init)
            if let code, let language = AppLanguage(rawValue: code) { return language }
        }
        return .vi
    }

    /// Chuỗi đã dịch, thay `{0}`, `{1}`… bằng `arguments` theo thứ tự.
    public func t(_ key: L10n, _ arguments: String...) -> String {
        LocalizedText.fill(key.text[self], with: arguments)
    }
}

/// Một câu đủ cả 3 thứ tiếng. Thiếu một thứ tiếng là lỗi biên dịch, không phải lỗi lúc chạy.
public struct LocalizedText: Hashable, Sendable {
    public let vi: String
    public let en: String
    public let ja: String

    public init(vi: String, en: String, ja: String) {
        self.vi = vi
        self.en = en
        self.ja = ja
    }

    public subscript(language: AppLanguage) -> String {
        switch language {
        case .vi: vi
        case .en: en
        case .ja: ja
        }
    }

    /// Thay `{0}`, `{1}`… trong một lượt, để nội dung người dùng gõ có chứa "{1}" không bị thay tiếp.
    static func fill(_ template: String, with arguments: [String]) -> String {
        guard !arguments.isEmpty else { return template }
        var result = ""
        var rest = Substring(template)
        while let open = rest.firstIndex(of: "{") {
            result += rest[..<open]
            let afterOpen = rest.index(after: open)
            if let close = rest[afterOpen...].firstIndex(of: "}"),
               let index = Int(rest[afterOpen..<close]), arguments.indices.contains(index) {
                result += arguments[index]
                rest = rest[rest.index(after: close)...]
            } else {
                result.append("{")
                rest = rest[afterOpen...]
            }
        }
        return result + rest
    }
}

/// Mọi chuỗi hiển thị của app, widget và Phím tắt. Giọng văn "mình – bạn", không tội lỗi (docs/05).
/// Thêm chuỗi mới: thêm case + đủ 3 thứ tiếng; test kiểm tra các bản dịch có cùng chỗ trống `{n}`.
public enum L10n: String, CaseIterable, Sendable {
    // Home
    case today, yesterday, quickChips, spentToday, remainingToday, overToday, budgetUsedUp, otherCurrencies
    case exportCSV, csvPreviewTitle, settings, done
    // Ô nhập nhanh
    case save, undo, changeCategory, noAmountYet, savedToast, missingAmount
    case exampleVietnam, exampleJapan, placeholderVietnam, placeholderJapan
    // Onboarding
    case onboardingWelcome, onboardingIntro, onboardingTry, onboardingSaveFirst, onboardingSaved
    case onboardingBudgetTitle, onboardingHabitTitle, onboardingHabitHint, next, skip, getStarted
    // Nhìn lại tuần
    case weekTitle, weekSpent, weekTop, weekNoSpend, weekLogged
    // Sửa giao dịch
    case editEntry, noteField, amountField, currencyField, incomeToggle, categoryField, dateField, cancel, deleteEntry
    // Khoản quen
    case editChips, chipsFooter, noChipsYet, addChip, newChip, chipTitleField, chipEmojiField
    case chipSuggestions, chipSuggestionDays, pinChip, chipLimitReached, unpinChip
    // Thói quen & chốt ngày
    case habitsTitle, closeDay, dayClosed, closeDayFooter, strength, streakDays, streakRestart, streakNone
    case markDone, doneToday, restToday, restingToday, addHabit, automaticHabitHint
    // Nhắc buổi tối
    case reminderToggle, reminderTime, reminderFooter, reminderDenied, reminderTitle, reminderBody
    case actionAllLogged, actionLogMore
    // Cài đặt
    case language, languageFooter, market, marketFooter
    case budgetHeader, budgetPlaceholder, budgetFooter, smallNumbersToggle
    case fasterEntry, tipWidget, tipActionButton, tipApplePay, entryTimingSummary
    // Hướng dẫn Apple Pay (automation "Giao dịch" trong app Phím tắt)
    case applePayGuideTitle, applePayGuideIntro, applePayStep1, applePayStep2, applePayStep3, applePayStep4, applePayStep5
    case applePayNotes, openShortcuts
    // Xu Pro
    case proTitle, proSubtitle, proBenefitHabits, proBenefitWidget, proAlwaysFree, proBuy, proRestore, proOwned
    case proPriceUnavailable, proHabitLimit, proWidgetNote
    case proPurchaseFailed, proPurchasePending, proRestoreFailed, proNothingToRestore
    // Quyền riêng tư (docs/09) — sửa ở đây thì sửa cả docs/privacy-policy.md
    case privacyTitle, privacyHeadline, privacyOnDevice, privacyNoTracking, privacyPurchases, privacyShortcuts
    case privacyNotifications, privacyExport, privacyDelete, privacyUpdated
    // CSV
    case csvHeader, csvIncome, csvExpense
    // Phím tắt
    case intentSaved, skippedZero, unsupportedCurrency
    // Widget
    case widgetChipsDescription, widgetTodayLine, logSomethingElse, widgetTodayDescription, widgetInline, tapToLog

    public var text: LocalizedText {
        switch self {
        case .today:
            LocalizedText(vi: "Hôm nay", en: "Today", ja: "今日")
        case .yesterday:
            LocalizedText(vi: "Hôm qua", en: "Yesterday", ja: "昨日")
        case .quickChips:
            LocalizedText(vi: "Khoản quen", en: "Quick picks", ja: "いつもの")
        case .spentToday:
            LocalizedText(vi: "Hôm nay đã tiêu", en: "Spent today", ja: "今日の支出")
        case .remainingToday:
            LocalizedText(vi: "Còn được tiêu hôm nay:", en: "Left to spend today:", ja: "今日あと使える額:")
        case .overToday:
            LocalizedText(
                vi: "Hôm nay hơi quá tay một chút. Những ngày tới mỗi ngày khoảng {0} là cân lại được 🌱",
                en: "A little over today. About {0} a day from here and you're back in balance 🌱",
                ja: "今日はちょっと使いすぎたかも。これから1日{0}くらいにすれば大丈夫 🌱")
        case .budgetUsedUp:
            LocalizedText(
                vi: "Ngân sách tiêu vặt tháng này đã dùng hết. Không sao cả, tháng sau mình bắt đầu lại nhé 🌱",
                en: "This month's flexible budget is used up. That's okay, next month is a fresh start 🌱",
                ja: "今月の自由に使える予算は使い切りました。大丈夫、来月またリセットされます 🌱")
        case .otherCurrencies:
            LocalizedText(vi: "Tiền khác: {0}", en: "Other currencies: {0}", ja: "ほかの通貨: {0}")
        case .exportCSV:
            LocalizedText(vi: "Xuất CSV", en: "Export CSV", ja: "CSVを書き出す")
        case .csvPreviewTitle:
            LocalizedText(vi: "Xu — giao dịch.csv", en: "Xu — transactions.csv", ja: "Xu — 記録.csv")
        case .settings:
            LocalizedText(vi: "Cài đặt", en: "Settings", ja: "設定")
        case .done:
            LocalizedText(vi: "Xong", en: "Done", ja: "完了")

        case .save:
            LocalizedText(vi: "Lưu", en: "Save", ja: "保存")
        case .undo:
            LocalizedText(vi: "Hoàn tác", en: "Undo", ja: "取り消す")
        case .changeCategory:
            LocalizedText(vi: "Đổi danh mục", en: "Change category", ja: "カテゴリを変更")
        case .noAmountYet:
            LocalizedText(vi: "Chưa có số tiền", en: "No amount yet", ja: "金額がまだありません")
        case .savedToast:
            // {0} emoji danh mục · {1} số tiền · {2} ghi chú
            LocalizedText(vi: "{0} Đã ghi {1} · {2}", en: "{0} Logged {1} · {2}", ja: "{0} {1} を記録・{2}")
        case .missingAmount:
            LocalizedText(
                vi: "Mình chưa thấy số tiền. Thử lại, ví dụ: {0}",
                en: "I don't see an amount yet. Try something like: {0}",
                ja: "金額が見つかりませんでした。「{0}」のように入れてみてください")
        case .exampleVietnam:
            LocalizedText(vi: "phở 45k", en: "lunch 45k", ja: "ランチ 45k")
        case .exampleJapan:
            LocalizedText(vi: "cơm 980 yên", en: "ramen 980", ja: "ラーメン 980円")
        case .placeholderVietnam:
            LocalizedText(vi: "cà phê 35k, grab 52k hôm qua…", en: "coffee 35k, grab 52k yesterday…",
                          ja: "コーヒー 35k、昨日 grab 52k…")
        case .placeholderJapan:
            LocalizedText(vi: "konbini 500, cơm 980 yên hôm qua…", en: "coffee 350, train 220 yesterday…",
                          ja: "コーヒー 350円、昨日 電車 220…")

        case .onboardingWelcome:
            LocalizedText(vi: "Chào bạn 👋", en: "Welcome 👋", ja: "ようこそ 👋")
        case .onboardingIntro:
            LocalizedText(vi: "Xu giúp bạn ghi chi tiêu trong 2 giây: gõ một câu là xong. Không cần tài khoản, dữ liệu nằm trên máy bạn.",
                          en: "Xu logs your spending in 2 seconds: type one sentence and you're done. No account, your data stays on your phone.",
                          ja: "Xuなら、ひと言入力するだけで2秒で支出を記録できます。アカウント不要、データはこの端末の中だけ。")
        case .onboardingTry:
            LocalizedText(vi: "Gõ thử một câu", en: "Try a sentence", ja: "試しに入力してみよう")
        case .onboardingSaveFirst:
            LocalizedText(vi: "Ghi luôn khoản này", en: "Log this one", ja: "これを記録する")
        case .onboardingSaved:
            LocalizedText(vi: "Đã ghi khoản đầu tiên 🎉", en: "Your first entry is logged 🎉", ja: "最初の記録ができました 🎉")
        case .onboardingBudgetTitle:
            LocalizedText(vi: "Mỗi tháng bạn muốn tiêu vặt khoảng bao nhiêu?", en: "How much do you want for everyday treats each month?",
                          ja: "毎月、自由に使いたいお金はどれくらい?")
        case .onboardingHabitTitle:
            LocalizedText(vi: "Chọn một thói quen nhỏ", en: "Pick one small habit", ja: "小さな習慣をひとつ選ぼう")
        case .onboardingHabitHint:
            LocalizedText(vi: "\"Ghi chép mỗi ngày\" đã bật sẵn. Thêm một thói quen nữa nếu bạn muốn, đổi lúc nào cũng được.",
                          en: "\"Log every day\" is already on. Add one more if you like; you can change it anytime.",
                          ja: "「毎日記録する」はオンになっています。よければもうひとつ追加しましょう。いつでも変えられます。")
        case .next:
            LocalizedText(vi: "Tiếp", en: "Next", ja: "次へ")
        case .skip:
            LocalizedText(vi: "Bỏ qua", en: "Skip", ja: "スキップ")
        case .getStarted:
            LocalizedText(vi: "Bắt đầu", en: "Get started", ja: "はじめる")

        case .weekTitle:
            LocalizedText(vi: "Nhìn lại tuần này", en: "This week", ja: "今週のふり返り")
        case .weekSpent:
            LocalizedText(vi: "Tuần này đã tiêu {0}", en: "Spent this week: {0}", ja: "今週の支出 {0}")
        case .weekTop:
            LocalizedText(vi: "Nhiều nhất: {0}", en: "Most on: {0}", ja: "いちばん多いのは {0}")
        case .weekNoSpend:
            LocalizedText(vi: "🌱 {0} ngày không tiêu vặt", en: "🌱 {0} no-spend days", ja: "🌱 小さな出費なしの日 {0}日")
        case .weekLogged:
            LocalizedText(vi: "📝 Có ghi chép {0}/{1} ngày", en: "📝 Logged on {0} of {1} days", ja: "📝 記録した日 {0}/{1}日")

        case .editEntry:
            LocalizedText(vi: "Sửa khoản", en: "Edit entry", ja: "記録を編集")
        case .noteField:
            LocalizedText(vi: "Ghi chú", en: "Note", ja: "メモ")
        case .amountField:
            LocalizedText(vi: "Số tiền", en: "Amount", ja: "金額")
        case .currencyField:
            LocalizedText(vi: "Loại tiền", en: "Currency", ja: "通貨")
        case .incomeToggle:
            LocalizedText(vi: "Đây là khoản thu", en: "This is income", ja: "収入として記録")
        case .categoryField:
            LocalizedText(vi: "Danh mục", en: "Category", ja: "カテゴリ")
        case .dateField:
            LocalizedText(vi: "Ngày", en: "Date", ja: "日付")
        case .cancel:
            LocalizedText(vi: "Huỷ", en: "Cancel", ja: "キャンセル")
        case .deleteEntry:
            LocalizedText(vi: "Xoá khoản này", en: "Delete entry", ja: "この記録を削除")

        case .editChips:
            LocalizedText(vi: "Sửa", en: "Edit", ja: "編集")
        case .chipsFooter:
            LocalizedText(
                vi: "Kéo để sắp xếp. Widget vừa hiện 4 khoản đầu, widget nhỏ hiện 2 khoản đầu. Ghim tối đa {0} khoản.",
                en: "Drag to reorder. The medium widget shows the first 4, the small one the first 2. Pin up to {0}.",
                ja: "ドラッグで並べ替え。ウィジェット(中)は上から4つ、(小)は2つを表示します。最大{0}件。")
        case .noChipsYet:
            LocalizedText(vi: "Chưa có khoản quen. Ghi cùng một khoản vài ngày, Xu sẽ gợi ý ở đây.",
                          en: "No quick picks yet. Log the same thing on a few days and Xu will suggest it here.",
                          ja: "まだありません。同じものを何日か記録すると、ここに候補が出ます。")
        case .addChip:
            LocalizedText(vi: "Thêm khoản quen", en: "Add a quick pick", ja: "いつものを追加")
        case .newChip:
            LocalizedText(vi: "Khoản quen mới", en: "New quick pick", ja: "新しいいつもの")
        case .chipTitleField:
            LocalizedText(vi: "Tên", en: "Name", ja: "名前")
        case .chipEmojiField:
            LocalizedText(vi: "Emoji", en: "Emoji", ja: "絵文字")
        case .chipSuggestions:
            LocalizedText(vi: "Bạn hay ghi", en: "You often log", ja: "よく記録するもの")
        case .chipSuggestionDays:
            LocalizedText(vi: "{0} ngày trong 30 ngày qua", en: "{0} days in the last 30", ja: "過去30日で{0}日")
        case .pinChip:
            LocalizedText(vi: "Ghim", en: "Pin", ja: "追加")
        case .chipLimitReached:
            LocalizedText(vi: "Đã đủ {0} khoản quen. Bỏ ghim một khoản để thêm khoản khác.",
                          en: "You have {0} quick picks. Unpin one to add another.",
                          ja: "いつものは{0}件までです。どれかを外すと追加できます。")
        case .unpinChip:
            LocalizedText(vi: "Bỏ ghim", en: "Unpin", ja: "外す")

        case .habitsTitle:
            LocalizedText(vi: "Thói quen", en: "Habits", ja: "習慣")
        case .closeDay:
            LocalizedText(vi: "Hôm nay mình đã ghi đủ", en: "I've logged everything today", ja: "今日の記録はこれで全部")
        case .dayClosed:
            LocalizedText(vi: "Đã chốt hôm nay ✓", en: "Today is closed ✓", ja: "今日は締めました ✓")
        case .closeDayFooter:
            LocalizedText(
                vi: "Chốt ngày giúp Xu biết hôm nay bạn không tiêu gì thêm, chứ không phải quên ghi. Chạm lần nữa để mở lại.",
                en: "Closing the day tells Xu you didn't spend anything else, rather than forgot to log it. Tap again to reopen.",
                ja: "締めると、記録し忘れではなく本当に使わなかった日だと分かります。もう一度タップで取り消せます。")
        case .strength:
            LocalizedText(vi: "Sức mạnh {0}", en: "Strength {0}", ja: "定着度 {0}")
        case .streakDays:
            LocalizedText(vi: "Chuỗi {0} ngày", en: "{0}-day streak", ja: "{0}日連続")
        case .streakRestart:
            LocalizedText(vi: "Chuỗi mới bắt đầu. Sức mạnh thói quen vẫn còn {0}.",
                          en: "A new streak starts. Your habit strength is still {0}.",
                          ja: "新しい連続記録のスタート。定着度は{0}のままです。")
        case .streakNone:
            LocalizedText(vi: "Bắt đầu từ hôm nay", en: "Starting today", ja: "今日から始めよう")
        case .markDone:
            LocalizedText(vi: "Hôm nay xong", en: "Done today", ja: "今日はできた")
        case .doneToday:
            LocalizedText(vi: "Đã xong ✓", en: "Done ✓", ja: "できた ✓")
        case .restToday:
            LocalizedText(vi: "Hôm nay nghỉ", en: "Rest today", ja: "今日は休み")
        case .restingToday:
            LocalizedText(vi: "Hôm nay nghỉ — không tính", en: "Resting today — doesn't count", ja: "今日は休み — 数えません")
        case .addHabit:
            LocalizedText(vi: "Thêm thói quen", en: "Add a habit", ja: "習慣を追加")
        case .automaticHabitHint:
            LocalizedText(vi: "Tự tính từ khoản đã ghi và chốt ngày", en: "Counted from your entries and day close",
                          ja: "記録と締めから自動で判定")

        case .reminderToggle:
            LocalizedText(vi: "Nhắc chốt ngày buổi tối", en: "Evening reminder to close the day", ja: "夜の締めリマインダー")
        case .reminderTime:
            LocalizedText(vi: "Giờ nhắc", en: "Time", ja: "時刻")
        case .reminderFooter:
            LocalizedText(
                vi: "Mỗi tối một thông báo: \"Đã ghi đủ\" để chốt ngày, \"Ghi thêm\" để mở ô nhập. Chỉ đặt lịch trên máy.",
                en: "One notification each evening: \"All logged\" closes the day, \"Log more\" opens the input. Scheduled on this device only.",
                ja: "毎晩1回通知します。「全部記録した」で締め、「もっと記録」で入力欄を開きます。通知はこの端末内だけで設定されます。")
        case .reminderDenied:
            LocalizedText(vi: "Thông báo của Xu đang tắt. Bật lại trong Cài đặt của iPhone › Xu › Thông báo.",
                          en: "Notifications for Xu are off. Turn them on in iPhone Settings › Xu › Notifications.",
                          ja: "Xuの通知がオフになっています。iPhoneの設定 › Xu › 通知 でオンにできます。")
        case .reminderTitle:
            LocalizedText(vi: "Chốt ngày", en: "Close the day", ja: "今日の締め")
        case .reminderBody:
            LocalizedText(vi: "Hôm nay có khoản nào chưa ghi không?", en: "Anything left to log today?",
                          ja: "今日、まだ記録していない出費はありますか?")
        case .actionAllLogged:
            LocalizedText(vi: "Đã ghi đủ", en: "All logged", ja: "全部記録した")
        case .actionLogMore:
            LocalizedText(vi: "Ghi thêm", en: "Log more", ja: "もっと記録")

        case .language:
            LocalizedText(vi: "Ngôn ngữ", en: "Language", ja: "言語")
        case .languageFooter:
            LocalizedText(vi: "Đổi ngay, không cần mở lại app.", en: "Switches right away.", ja: "すぐに切り替わります。")
        case .market:
            LocalizedText(vi: "Nơi bạn chi tiêu", en: "Where you spend", ja: "お金を使う国")
        case .marketFooter:
            LocalizedText(
                vi: "Số không kèm đơn vị được tính bằng tiền ở đây, và ngày như \"9/12\" được đọc theo cách ghi ở đây. Muốn ghi tiền kia thì gõ kèm đơn vị: \"500 yên\", \"1tr\", \"50.000đ\".",
                en: "Plain numbers use this currency, and dates like \"9/12\" follow the local order. For the other currency, add a unit: \"500 yen\", \"1tr\", \"50,000đ\".",
                ja: "単位のない数字はこの国の通貨として記録し、「9/12」のような日付もこの国の書き方で読みます。もう一方の通貨は単位を付けて入力:「500円」「1tr」「50,000đ」。")
        case .budgetHeader:
            LocalizedText(vi: "Ngân sách tiêu vặt mỗi tháng ({0})", en: "Monthly flexible budget ({0})",
                          ja: "1か月の自由に使える予算({0})")
        case .budgetPlaceholder:
            LocalizedText(vi: "Ví dụ: {0}", en: "e.g. {0}", ja: "例: {0}")
        case .budgetFooter:
            LocalizedText(
                vi: "Chỉ tính cà phê, mua sắm, giải trí… Xu chia đều cho những ngày còn lại. Để 0 nếu chưa muốn dùng.",
                en: "Only coffee, shopping, fun… count toward it. Xu spreads what's left evenly over the remaining days. Leave 0 to skip.",
                ja: "カフェ・買い物・娯楽などだけが対象です。残りの日数で均等に割ります。使わないときは0のままで。")
        case .smallNumbersToggle:
            LocalizedText(vi: "Hiểu \"phở 45\" là 45.000đ", en: "Read \"pho 45\" as 45,000₫",
                          ja: "「フォー 45」を45,000ドンと読む")
        case .fasterEntry:
            LocalizedText(vi: "Nhập nhanh hơn", en: "Log even faster", ja: "もっと速く記録")
        case .tipWidget:
            LocalizedText(vi: "Thêm widget Xu ra màn hình chính", en: "Add the Xu widget to your Home Screen",
                          ja: "ホーム画面にXuのウィジェットを追加")
        case .tipActionButton:
            LocalizedText(
                vi: "Gán \"Ghi chi tiêu\" vào Action Button (Cài đặt › Nút Tác vụ › Phím tắt)",
                en: "Assign \"Log expense\" to the Action Button (Settings › Action Button › Shortcut)",
                ja: "「支出を記録」をアクションボタンに割り当てる(設定 › アクションボタン › ショートカット)")
        case .entryTimingSummary:
            // {0} số giây (một chữ số lẻ) · {1} số lần đã đo
            LocalizedText(vi: "Bạn ghi một khoản mất khoảng {0} giây (trung vị {1} lần gần nhất, chỉ lưu trên máy).",
                          en: "Logging takes you about {0} seconds (median of your last {1} entries, stored only on this phone).",
                          ja: "1件の記録にかかる時間は約{0}秒です(直近{1}件の中央値。この端末にのみ保存)。")
        case .tipApplePay:
            LocalizedText(
                vi: "Tự ghi khi quẹt Apple Pay (Phím tắt › Tự động hóa › Giao dịch)",
                en: "Log automatically when you pay with Apple Pay (Shortcuts › Automation › Transaction)",
                ja: "Apple Payで払ったら自動で記録(ショートカット › オートメーション)")

        case .applePayGuideTitle:
            LocalizedText(vi: "Tự ghi khi trả Apple Pay", en: "Auto-log Apple Pay", ja: "Apple Payを自動記録")
        case .applePayGuideIntro:
            LocalizedText(
                vi: "Bạn có thể cài một tự động hóa trong app Phím tắt để khi trả bằng thẻ trong Ví, Phím tắt gửi số tiền và tên cửa hàng cho Xu ghi lại. Mọi thứ chạy trên máy; Xu không kết nối ngân hàng.",
                en: "You can set up an automation in the Shortcuts app so that when you pay with a card in Wallet, Shortcuts sends the amount and merchant to Xu to log. It all runs on your phone; Xu never connects to your bank.",
                ja: "ショートカットAppでオートメーションを作ると、ウォレットのカードで払ったときに金額と支払先がXuに送られ、記録されます。すべて端末内で動き、Xuは銀行に接続しません。")
        case .applePayStep1:
            LocalizedText(vi: "Mở app Phím tắt › Tự động hóa › nút +.",
                          en: "Open the Shortcuts app › Automation › the + button.",
                          ja: "ショートカットAppを開き、オートメーション › 「+」をタップ。")
        case .applePayStep2:
            LocalizedText(vi: "Chọn Giao dịch (Ví), chọn thẻ bạn hay dùng, rồi chọn chạy ngay không cần xác nhận.",
                          en: "Choose Transaction (Wallet), pick the cards you use, then choose to run immediately.",
                          ja: "「取引」(ウォレット)を選び、よく使うカードを選んで、すぐに実行する設定にします。")
        case .applePayStep3:
            LocalizedText(vi: "Thêm tác vụ \"Ghi giao dịch thẻ\" của Xu.",
                          en: "Add Xu's \"Log card payment\" action.",
                          ja: "Xuのアクション「カード払いを記録」を追加。")
        case .applePayStep4:
            LocalizedText(vi: "Ở ô Số tiền chọn biến số tiền của giao dịch, ở ô Người bán chọn biến tên cửa hàng.",
                          en: "Set Amount to the transaction's amount and Merchant to the transaction's merchant.",
                          ja: "「金額」に取引の金額、「支払先」に取引の店舗名を入れます。")
        case .applePayStep5:
            LocalizedText(vi: "Quẹt thử một lần rồi mở Xu xem khoản đó đã có trong danh sách chưa. Chưa thấy thì kiểm tra lại tự động hóa.",
                          en: "Make one test payment, then open Xu and check that it appears in the list. If not, check the automation again.",
                          ja: "一度試しに払ってから、Xuの一覧に記録されたか確認しましょう。なければオートメーションを見直してください。")
        case .applePayNotes:
            // {0} tên loại tiền của nơi chi tiêu
            LocalizedText(
                vi: "Chỉ chạy với thẻ đã thêm vào Ví. Tên các mục trong app Phím tắt có thể khác một chút tuỳ phiên bản iOS. Số tiền được ghi theo loại tiền của giao dịch (đồng hoặc yên); nếu Phím tắt không gửi loại tiền thì ghi bằng {0}. Sửa được trong danh sách như mọi khoản khác.",
                en: "Only works with cards added to Wallet. Labels in the Shortcuts app may differ slightly between iOS versions. Amounts are logged in the transaction's currency (dong or yen); if Shortcuts doesn't pass a currency, they're logged in {0}. You can edit them in the list like any entry.",
                ja: "ウォレットに追加したカードのみ対象です。ショートカットAppの項目名はiOSのバージョンによって少し異なる場合があります。金額は取引の通貨(ドンまたは円)で記録し、通貨が渡されない場合は{0}で記録します。一覧からいつでも修正できます。")
        case .openShortcuts:
            LocalizedText(vi: "Mở app Phím tắt", en: "Open Shortcuts", ja: "ショートカットAppを開く")

        case .proTitle:
            LocalizedText(vi: "Xu Pro", en: "Xu Pro", ja: "Xu Pro")
        case .proSubtitle:
            LocalizedText(vi: "Mua một lần, dùng mãi. Không thuê bao.", en: "Pay once, keep it forever. No subscription.",
                          ja: "一度の購入でずっと使えます。サブスクなし。")
        case .proBenefitHabits:
            // {0} giới hạn bản miễn phí
            LocalizedText(vi: "Theo dõi bao nhiêu thói quen cũng được (bản miễn phí: {0})",
                          en: "Track as many habits as you like (free: {0})",
                          ja: "習慣をいくつでも続けられます(無料版: {0}つ)")
        case .proBenefitWidget:
            // {0} số nút với Pro · {1} số nút bản miễn phí
            LocalizedText(vi: "Widget hiện tới {0} khoản quen (bản miễn phí: {1})",
                          en: "The widget shows up to {0} quick picks (free: {1})",
                          ja: "ウィジェットにいつものを最大{0}件表示(無料版: {1}件)")
        case .proAlwaysFree:
            LocalizedText(vi: "Ghi chép, khoản quen trong app, Phím tắt và xuất CSV luôn miễn phí.",
                          en: "Logging, quick picks in the app, Shortcuts and CSV export are always free.",
                          ja: "記録、アプリ内のいつもの、ショートカット、CSV書き出しはずっと無料です。")
        case .proBuy:
            // {0} giá do App Store trả về
            LocalizedText(vi: "Mua {0}", en: "Buy for {0}", ja: "{0}で購入")
        case .proRestore:
            LocalizedText(vi: "Khôi phục giao dịch đã mua", en: "Restore purchase", ja: "購入を復元")
        case .proOwned:
            LocalizedText(vi: "Đã mở khoá Xu Pro ✓", en: "Xu Pro unlocked ✓", ja: "Xu Pro 利用中 ✓")
        case .proPriceUnavailable:
            LocalizedText(vi: "Chưa tải được giá. Kiểm tra kết nối rồi thử lại.",
                          en: "Couldn't load the price. Check your connection and try again.",
                          ja: "価格を読み込めませんでした。接続を確認してもう一度お試しください。")
        case .proPurchaseFailed:
            LocalizedText(vi: "Chưa mua được. Kiểm tra kết nối rồi thử lại.",
                          en: "The purchase didn't go through. Check your connection and try again.",
                          ja: "購入できませんでした。接続を確認してもう一度お試しください。")
        case .proPurchasePending:
            LocalizedText(vi: "Giao dịch đang chờ duyệt. Khi được duyệt, Xu Pro sẽ tự mở khoá.",
                          en: "Your purchase is waiting for approval. Xu Pro will unlock automatically once it's approved.",
                          ja: "購入は承認待ちです。承認されるとXu Proが自動で使えるようになります。")
        case .proRestoreFailed:
            LocalizedText(vi: "Chưa khôi phục được. Kiểm tra kết nối và tài khoản Apple rồi thử lại.",
                          en: "Couldn't restore. Check your connection and Apple Account, then try again.",
                          ja: "復元できませんでした。接続とApple Accountを確認してもう一度お試しください。")
        case .proNothingToRestore:
            LocalizedText(vi: "Tài khoản Apple này chưa mua Xu Pro.",
                          en: "This Apple Account hasn't purchased Xu Pro.",
                          ja: "このApple AccountではXu Proは購入されていません。")
        case .proHabitLimit:
            LocalizedText(vi: "Bản miễn phí theo dõi {0} thói quen cùng lúc. Bỏ bớt một thói quen hoặc mở Xu Pro để thêm.",
                          en: "The free version tracks {0} habits at a time. Remove one or get Xu Pro to add more.",
                          ja: "無料版で同時に続けられる習慣は{0}つまでです。1つ外すか、Xu Proで追加できます。")
        case .proWidgetNote:
            LocalizedText(vi: "Bản miễn phí: widget hiện {0} khoản quen đầu tiên.",
                          en: "Free version: the widget shows the first {0} quick picks.",
                          ja: "無料版: ウィジェットには上から{0}件を表示します。")

        case .privacyTitle:
            LocalizedText(vi: "Quyền riêng tư", en: "Privacy", ja: "プライバシー")
        case .privacyHeadline:
            LocalizedText(vi: "Dữ liệu của bạn nằm trên iPhone này.", en: "Your data stays on this iPhone.",
                          ja: "データはこのiPhoneの中にあります。")
        case .privacyOnDevice:
            LocalizedText(
                vi: "Các khoản bạn ghi (cả câu gốc bạn gõ), khoản quen, thói quen, cài đặt và thời gian ghi đều lưu trên máy này; widget của Xu đọc chung phần nó cần hiển thị. Xu không có máy chủ, không cần tài khoản và không gửi những dữ liệu này đi đâu.",
                en: "Your entries (including the text you typed), quick picks, habits, settings and entry times are stored on this device; Xu's widgets read the parts they display. Xu has no server, needs no account and doesn't send this data anywhere.",
                ja: "記録(入力した文そのものを含む)、いつもの、習慣、設定、記録にかかった時間はすべてこの端末に保存されます。Xuのウィジェットは表示に必要な部分だけを読み取ります。Xuにはサーバーがなく、アカウントも不要で、これらのデータをどこにも送信しません。")
        case .privacyNoTracking:
            LocalizedText(vi: "Không quảng cáo, không theo dõi, không công cụ phân tích.", en: "No ads, no tracking, no analytics.",
                          ja: "広告、トラッキング、アクセス解析はありません。")
        case .privacyPurchases:
            LocalizedText(
                vi: "Mua hay khôi phục Xu Pro là do Apple xử lý thanh toán. Xu chỉ hỏi App Store xem bạn đã mua chưa và không nhận thông tin thẻ hay tài khoản Apple của bạn.",
                en: "Apple handles the payment when you buy or restore Xu Pro. Xu only asks the App Store whether you own it and never receives your card or Apple Account details.",
                ja: "Xu Proの購入・復元の支払いはAppleが処理します。XuはApp Storeに購入済みかどうかを確認するだけで、カード情報やApple Accountの情報は受け取りません。")
        case .privacyShortcuts:
            LocalizedText(
                vi: "Phím tắt và tự động hoá Apple Pay do bạn tự cài chỉ chuyển cho Xu câu bạn nhập, hoặc số tiền (kèm loại tiền) và tên cửa hàng, ngay trên máy.",
                en: "Shortcuts and Apple Pay automations you set up pass Xu only the sentence you typed, or the amount (with its currency) and merchant name, on the device.",
                ja: "ご自身で設定したショートカットやApple Payのオートメーションは、入力した文、または金額(通貨を含む)と店舗名だけを端末内でXuに渡します。")
        case .privacyNotifications:
            LocalizedText(vi: "Nhắc chốt ngày là thông báo đặt lịch ngay trên máy, không qua máy chủ nào.",
                          en: "The evening reminder is a notification scheduled on the device, not sent from a server.",
                          ja: "夜の締めリマインダーは端末内で予約される通知で、サーバーを経由しません。")
        case .privacyExport:
            LocalizedText(vi: "Xuất CSV bất cứ lúc nào, miễn phí. Tệp đi đâu là do bạn chọn trong bảng chia sẻ.",
                          en: "Export CSV any time, for free. You choose where the file goes in the share sheet.",
                          ja: "CSVはいつでも無料で書き出せます。ファイルの送り先は共有シートであなたが選びます。")
        case .privacyDelete:
            LocalizedText(
                vi: "Xoá từng khoản ngay trong danh sách. Xoá app là xoá dữ liệu Xu khỏi máy này. Nếu bạn bật sao lưu iPhone (iCloud hoặc máy tính), dữ liệu Xu có thể nằm trong bản sao lưu đó như mọi app khác.",
                en: "Delete any entry from the list. Deleting the app removes Xu's data from this device. If you back up your iPhone (to iCloud or a computer), Xu's data may be included in that backup like any other app's.",
                ja: "記録は一覧からいつでも削除できます。アプリを削除すると、この端末からXuのデータが消えます。iPhoneのバックアップ(iCloudまたはコンピュータ)を有効にしている場合、ほかのアプリと同様にXuのデータも含まれることがあります。")
        case .privacyUpdated:
            LocalizedText(vi: "Cập nhật: 02/10/2026", en: "Updated: October 2, 2026", ja: "更新日: 2026年10月2日")

        case .csvHeader:
            LocalizedText(vi: "ngay,loai,so_tien,don_vi,danh_muc,ghi_chu,nguon",
                          en: "date,type,amount,currency,category,note,source",
                          ja: "日付,種類,金額,通貨,カテゴリ,メモ,入力方法")
        case .csvIncome:
            LocalizedText(vi: "thu", en: "income", ja: "収入")
        case .csvExpense:
            LocalizedText(vi: "chi", en: "expense", ja: "支出")

        case .intentSaved:
            // {0} số tiền · {1} emoji + danh mục hoặc người bán
            LocalizedText(vi: "Đã ghi {0} · {1}", en: "Logged {0} · {1}", ja: "{0} を記録しました・{1}")
        case .skippedZero:
            LocalizedText(vi: "Bỏ qua giao dịch 0 đồng", en: "Skipped a zero-amount transaction",
                          ja: "金額0の取引はスキップしました")
        case .unsupportedCurrency:
            // {0} mã tiền tệ, ví dụ "USD"
            LocalizedText(vi: "Xu chưa ghi được tiền {0}, khoản này chưa được ghi. Bạn ghi tay giúp nhé.",
                          en: "Xu can't log {0} yet, so this payment wasn't logged. Please add it by hand.",
                          ja: "Xuは{0}にまだ対応していないため、記録していません。手入力で追加してください。")

        case .widgetChipsDescription:
            LocalizedText(vi: "Chạm để ghi ngay, không cần mở app.", en: "Tap to log instantly, no need to open the app.",
                          ja: "タップするだけで記録。アプリを開かなくてOK。")
        case .widgetTodayLine:
            LocalizedText(vi: "Hôm nay {0}", en: "Today {0}", ja: "今日 {0}")
        case .logSomethingElse:
            LocalizedText(vi: "Ghi khoản khác", en: "Log something else", ja: "ほかの支出を記録")
        case .widgetTodayDescription:
            LocalizedText(vi: "Số đã tiêu hôm nay. Chạm để ghi.", en: "What you've spent today. Tap to log.",
                          ja: "今日の支出。タップして記録。")
        case .widgetInline:
            LocalizedText(vi: "Xu · hôm nay {0}", en: "Xu · today {0}", ja: "Xu・今日 {0}")
        case .tapToLog:
            LocalizedText(vi: "Chạm để ghi", en: "Tap to log", ja: "タップして記録")
        }
    }
}

extension AppLanguage {
    /// Câu ví dụ hợp với nơi tiêu tiền, dùng cho lời nhắc "chưa thấy số tiền".
    public func exampleEntry(for market: Market) -> String {
        t(market == .japan ? .exampleJapan : .exampleVietnam)
    }

    /// Chữ mờ trong ô nhập.
    public func entryPlaceholder(for market: Market) -> String {
        t(market == .japan ? .placeholderJapan : .placeholderVietnam)
    }
}
