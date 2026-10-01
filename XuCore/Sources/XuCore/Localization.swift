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
    case today, yesterday, quickChips, spentToday, remainingToday, overToday, otherCurrencies
    case exportCSV, csvPreviewTitle, settings, done
    // Ô nhập nhanh
    case save, undo, changeCategory, noAmountYet, savedToast, missingAmount
    case exampleVietnam, exampleJapan, placeholderVietnam, placeholderJapan
    // Cài đặt
    case language, languageFooter, market, marketFooter
    case budgetHeader, budgetPlaceholder, budgetFooter, smallNumbersToggle
    case fasterEntry, tipWidget, tipActionButton, tipApplePay
    // CSV
    case csvHeader, csvIncome, csvExpense
    // Phím tắt
    case intentSaved, skippedZero
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
        case .tipApplePay:
            LocalizedText(
                vi: "Tự ghi khi quẹt Apple Pay (Phím tắt › Tự động hóa › Giao dịch)",
                en: "Log automatically when you pay with Apple Pay (Shortcuts › Automation › Transaction)",
                ja: "Apple Payで払ったら自動で記録(ショートカット › オートメーション)")

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
