import XCTest
@testable import XuCore

final class LocalizationTests: XCTestCase {
    // MARK: Bảng chuỗi

    func testEveryStringIsTranslatedWithSamePlaceholders() {
        let placeholder = try! NSRegularExpression(pattern: #"\{\d+\}"#)
        func placeholders(_ s: String) -> Set<String> {
            Set(placeholder.matches(in: s, range: NSRange(s.startIndex..., in: s)).compactMap { match in
                Range(match.range, in: s).map { range in String(s[range]) }
            })
        }
        for key in L10n.allCases {
            let text = key.text
            for language in AppLanguage.allCases {
                XCTAssertFalse(text[language].trimmingCharacters(in: .whitespaces).isEmpty, "\(key) thiếu \(language)")
            }
            XCTAssertEqual(placeholders(text.vi), placeholders(text.en), "\(key): chỗ trống vi/en khác nhau")
            XCTAssertEqual(placeholders(text.vi), placeholders(text.ja), "\(key): chỗ trống vi/ja khác nhau")
        }
    }

    func testFillReplacesPlaceholdersOnce() {
        XCTAssertEqual(AppLanguage.vi.t(.savedToast, "☕", "35k", "cà phê"), "☕ Đã ghi 35k · cà phê")
        XCTAssertEqual(AppLanguage.ja.t(.savedToast, "☕", "350円", "コーヒー"), "☕ 350円 を記録・コーヒー")
        // Ghi chú người dùng có "{2}" không được bị thay tiếp
        XCTAssertEqual(AppLanguage.en.t(.savedToast, "☕", "{2}", "x"), "☕ Logged {2} · x")
        XCTAssertEqual(AppLanguage.en.t(.today), "Today")
    }

    func testCSVHeaderHasSameColumnsInEveryLanguage() {
        let counts = AppLanguage.allCases.map { $0.t(.csvHeader).split(separator: ",").count }
        XCTAssertEqual(Set(counts), [7])
    }

    func testEveryCategoryAndHabitHasNames() {
        for category in CategoryCatalog.defaults {
            for language in AppLanguage.allCases {
                XCTAssertFalse(category.name(in: language).isEmpty, "\(category.id) thiếu \(language)")
            }
        }
        XCTAssertEqual(CategoryCatalog.resolve(id: "food").name(in: .ja), "食事")
        XCTAssertEqual(HabitTemplate.logDaily.defaultTitle, "Ghi chép mỗi ngày")
        XCTAssertEqual(HabitTemplate.logDaily.title(in: .en), "Log every day")
    }

    func testNoKeywordInTwoCategories() {
        var owner: [String: String] = [:]
        for category in CategoryCatalog.defaults {
            for keyword in category.keywords {
                if let other = owner[keyword] {
                    XCTFail("Từ khóa \"\(keyword)\" có ở cả \(other) và \(category.id)")
                }
                owner[keyword] = category.id
            }
        }
    }

    // MARK: Chọn ngôn ngữ, thị trường

    func testPreferredLanguage() {
        XCTAssertEqual(AppLanguage.preferred(from: ["ja-JP", "en-US"]), .ja)
        XCTAssertEqual(AppLanguage.preferred(from: ["vi-VN"]), .vi)
        XCTAssertEqual(AppLanguage.preferred(from: ["zh-Hans-JP", "ja-JP"]), .ja)
        XCTAssertEqual(AppLanguage.preferred(from: ["en-GB", "vi-VN"]), .en)
        XCTAssertEqual(AppLanguage.preferred(from: ["ko-KR"]), .vi, "Ngôn ngữ không hỗ trợ → tiếng Việt (Việt Nam trước)")
        XCTAssertEqual(AppLanguage.preferred(from: []), .vi)
    }

    func testCurrencyFromOutside() {
        XCTAssertEqual(Currency(exactCode: "JPY"), .jpy)
        XCTAssertEqual(Currency(exactCode: " vnd "), .vnd)
        XCTAssertNil(Currency(exactCode: "USD"), "Tiền chưa hỗ trợ không được ghi nhầm thành đồng")
        XCTAssertNil(Currency(exactCode: ""))
        XCTAssertEqual(Currency.wholeUnits(Decimal(string: "1000")!), 1_000)
        XCTAssertEqual(Currency.wholeUnits(Decimal(string: "1000.4")!), 1_000)
        XCTAssertEqual(Currency.wholeUnits(Decimal(string: "1000.5")!), 1_001)
        XCTAssertEqual(Currency.wholeUnits(Decimal(string: "45000")!), 45_000)
    }

    func testMarketAndCurrency() {
        XCTAssertEqual(Market.guess(regionCode: "JP"), .japan)
        XCTAssertEqual(Market.guess(regionCode: "VN"), .vietnam)
        XCTAssertEqual(Market.guess(regionCode: nil), .vietnam)
        XCTAssertEqual(Market.japan.currency, .jpy)
        XCTAssertEqual(Currency(code: "jpy"), .jpy)
        XCTAssertEqual(Currency(code: "XYZ"), .vnd, "Dữ liệu cũ không rõ mã → VND")
        XCTAssertEqual(AppLanguage.ja.entryPlaceholder(for: .japan), "コーヒー 350円、昨日 電車 220…")
    }

    // MARK: Gấp chữ

    func testFoldingKeepsKanaAndNarrowsWidth() {
        XCTAssertEqual(TextFolding.fold("バス"), "バス", "Không bỏ dấu ゛ của kana")
        XCTAssertEqual(TextFolding.fold("ＡＢＣ１２３"), "abc123")
        XCTAssertEqual(TextFolding.fold("￥３５０"), "¥350")
        XCTAssertEqual(TextFolding.fold("Cà Phê Đá"), "ca phe da")
        let text = "コーヒー３５０円"
        XCTAssertEqual(TextFolding.foldAligned(text).folded.count, Array(text).count, "Gấp phải giữ đúng số ký tự")
    }

    // MARK: Định dạng tiền

    func testMoneyFormatsPerCurrencyAndLanguage() {
        XCTAssertEqual(MoneyFormatter.full(1_250_000, currency: .vnd, language: .en), "1,250,000₫")
        XCTAssertEqual(MoneyFormatter.full(1_200, currency: .jpy, language: .ja), "1,200円")
        XCTAssertEqual(MoneyFormatter.full(1_200, currency: .jpy, language: .en), "¥1,200")
        XCTAssertEqual(MoneyFormatter.full(1_200, currency: .jpy, language: .vi), "¥1.200")
        XCTAssertEqual(MoneyFormatter.full(-1_200, currency: .jpy, language: .ja), "-1,200円")
        XCTAssertEqual(MoneyFormatter.compact(65_000, currency: .jpy, language: .ja), "65,000円")
        XCTAssertEqual(MoneyFormatter.compact(1_250_000, currency: .vnd, language: .en), "1.25M₫")
        XCTAssertEqual(MoneyFormatter.compact(35_000, currency: .vnd, language: .ja), "35K₫")
        XCTAssertEqual(MoneyFormatter.signed(35_000, isIncome: true), "+35.000đ")
        XCTAssertEqual(MoneyFormatter.signed(250_000, isIncome: true, currency: .jpy, language: .ja, compact: true), "+250,000円")
    }
}
