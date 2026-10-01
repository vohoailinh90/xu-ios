import XCTest
@testable import XuCore

/// Thị trường Nhật: yên, số kiểu Nhật, ngày tháng/ngày, câu tiếng Nhật và tiếng Anh. Đặc tả: docs/04, docs/08.
final class JapanMarketTests: XCTestCase {
    /// Thứ Sáu 25/09/2026, 12:00 giờ Tokyo
    var calendar: Calendar!
    var now: Date!
    var parser: QuickEntryParser!

    override func setUp() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        calendar = cal
        now = cal.date(from: DateComponents(year: 2026, month: 9, day: 25, hour: 12))!
        parser = QuickEntryParser(options: .init(market: .japan), calendar: cal)
    }

    private func parse(_ text: String) -> QuickEntryResult { parser.parse(text, now: now) }
    private func day(_ result: QuickEntryResult) -> String { DayKey(result.date, calendar: calendar).description }

    // MARK: Số tiền

    func testYenAndBareNumbers() {
        let r = parse("コーヒー 350円")
        XCTAssertEqual(r.amount, 350)
        XCTAssertEqual(r.currency, .jpy)
        XCTAssertEqual(r.note, "コーヒー")
        XCTAssertEqual(r.categoryID, "drinks")

        XCTAssertEqual(parse("コーヒー350円").note, "コーヒー", "Chữ Nhật đứng sát số")
        XCTAssertEqual(parse("ラーメン 980").amount, 980, "Ở Nhật số trần là yên, không nhân 1.000")
        XCTAssertEqual(parse("ラーメン 980").currency, .jpy)
        XCTAssertEqual(parse("¥1,200 ランチ").amount, 1_200)
        XCTAssertEqual(parse("¥1,200 ランチ").note, "ランチ")
    }

    func testFullWidthDigitsFromJapaneseKeyboard() {
        let r = parse("３５０円 コーヒー")
        XCTAssertEqual(r.amount, 350)
        XCTAssertEqual(r.note, "コーヒー")
        XCTAssertEqual(parse("￥１，２００ ランチ").amount, 1_200)
    }

    func testKanjiNumbers() {
        XCTAssertEqual(parse("家賃 6万5千円").amount, 65_000)
        XCTAssertEqual(parse("家賃 6万5000").amount, 65_000)
        XCTAssertEqual(parse("家賃 6万5千円").note, "家賃")
        XCTAssertEqual(parse("1万500円").amount, 10_500)
        XCTAssertEqual(parse("1万2 服").amount, 12_000, "Cách nói tắt: 1万2 = 12.000")
        XCTAssertEqual(parse("1.5万 旅行").amount, 15_000)
        XCTAssertEqual(parse("2千5百円").amount, 2_500)
        XCTAssertEqual(parse("千円 カット").amount, 1_000)
        XCTAssertEqual(parse("給料 25万").amount, 250_000)
    }

    func testKanjiInNamesIsNotAnAmount() {
        XCTAssertEqual(parse("千葉 電車 450").amount, 450)
        XCTAssertEqual(parse("千葉 電車 450").note, "千葉 電車")
        XCTAssertEqual(parse("百貨店 5000").amount, 5_000)
        XCTAssertEqual(parse("100均 330").amount, 330)
        XCTAssertEqual(parse("100均 330").categoryID, "shopping")
        XCTAssertEqual(parse("100円ショップ 550円").amount, 550)
    }

    func testVietnameseInJapanSlang() {
        XCTAssertEqual(parse("lương 25 man").amount, 250_000)
        XCTAssertEqual(parse("lương 25 man").categoryID, "income.salary")
        XCTAssertEqual(parse("cơm 1man2").amount, 12_000)
        XCTAssertEqual(parse("konbini 3 sen").amount, 3_000)
        XCTAssertEqual(parse("konbini 3 sen").categoryID, "groceries")
        XCTAssertEqual(parse("35k").amount, 35_000, "k nhân 1.000 với tiền mặc định")
        XCTAssertEqual(parse("35k").currency, .jpy)
    }

    func testVietnameseUnitsStayDong() {
        let r = parse("gửi về nhà 5tr")
        XCTAssertEqual(r.amount, 5_000_000)
        XCTAssertEqual(r.currency, .vnd)
        XCTAssertEqual(r.categoryID, "family")
        XCTAssertEqual(parse("50.000đ quà").currency, .vnd)
    }

    func testIncome() {
        let r = parse("給料 +25万")
        XCTAssertTrue(r.isIncome)
        XCTAssertEqual(r.amount, 250_000)
        XCTAssertEqual(r.categoryID, "income.salary")
        XCTAssertTrue(parse("給料 25万").isIncome)
        XCTAssertTrue(parse("salary +250000").isIncome)
    }

    // MARK: Ngày

    func testJapaneseRelativeDays() {
        XCTAssertEqual(day(parse("昨日 電車 220")), "2026-09-24")
        XCTAssertEqual(parse("昨日 電車 220").note, "電車")
        XCTAssertEqual(day(parse("一昨日 タクシー 1800")), "2026-09-23")
        XCTAssertEqual(day(parse("今日 ランチ 900")), "2026-09-25")
    }

    func testParticleAfterDate() {
        let r = parse("昨日のランチ 1200円")
        XCTAssertEqual(day(r), "2026-09-24")
        XCTAssertEqual(r.note, "ランチ")
        XCTAssertEqual(parse("昨日のり弁 500").note, "のり弁", "\"の\" là đầu từ thì giữ lại")
    }

    func testMonthFirstDatesInJapan() {
        XCTAssertEqual(day(parse("9/20 スーパー 2480")), "2026-09-20")
        XCTAssertEqual(day(parse("12/24 プレゼント 5000")), "2025-12-24", "Ngày tương lai → năm ngoái")
        XCTAssertEqual(day(parse("2026/9/1 家賃 65000")), "2026-09-01")
    }

    func testKanjiDates() {
        XCTAssertEqual(day(parse("9月20日 スーパー 2480")), "2026-09-20")
        XCTAssertEqual(day(parse("20日 スーパー 2480")), "2026-09-20")
        XCTAssertEqual(day(parse("28日 家賃 65000")), "2026-08-28", "Ngày chưa tới trong tháng → tháng trước")
        XCTAssertEqual(parse("9月20日 スーパー 2480").amount, 2_480)
        XCTAssertEqual(day(parse("3日間 定期券 5000")), "2026-09-25", "\"3日間\" là số ngày, không phải ngày")
    }

    func testJapaneseWeekdays() {
        XCTAssertEqual(day(parse("月曜 ランチ 900")), "2026-09-21")
        let r = parse("月曜日 ランチ 900")
        XCTAssertEqual(day(r), "2026-09-21")
        XCTAssertEqual(r.note, "ランチ")
        XCTAssertEqual(day(parse("金曜 カフェ 500")), "2026-09-25", "Hôm nay là thứ Sáu")
    }

    // MARK: Danh mục

    func testJapaneseCategories() {
        XCTAssertEqual(parse("電車 220").categoryID, "transport")
        XCTAssertEqual(parse("バス 230").categoryID, "transport")
        XCTAssertEqual(parse("パスタ 1200").categoryID, "food", "パスタ không được bị hiểu thành バス")
        XCTAssertEqual(parse("セブンイレブン 648円").categoryID, "groceries")
        XCTAssertEqual(parse("セブンでコーヒー 150").categoryID, "drinks", "Cụm dài nhất thắng")
        XCTAssertEqual(parse("家賃 65000").categoryID, "bills")
        XCTAssertEqual(parse("仕送り 3万").categoryID, "family")
        XCTAssertEqual(parse("ドラッグストア 1200").categoryID, "health")
    }

    func testEnglishSentences() {
        let r = parse("train 220 yesterday")
        XCTAssertEqual(r.amount, 220)
        XCTAssertEqual(day(r), "2026-09-24")
        XCTAssertEqual(r.categoryID, "transport")
        XCTAssertEqual(r.note, "train")
        XCTAssertEqual(day(parse("lunch 900 monday")), "2026-09-21")
    }

    func testLearnedJapaneseKeyword() {
        let key = CategoryMatcher.learningKey(for: "ジュンク堂")
        let learned = QuickEntryParser(options: .init(market: .japan), calendar: calendar,
                                       matcher: CategoryMatcher(learned: [key: "education"]))
        XCTAssertEqual(learned.parse("ジュンク堂で 1500円", now: now).categoryID, "education")
    }
}

/// Câu tiếng Anh và tiền yên khi đang ở thị trường Việt Nam (mặc định).
final class VietnamMarketExtrasTests: XCTestCase {
    var calendar: Calendar!
    var now: Date!
    var parser: QuickEntryParser!

    override func setUp() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        calendar = cal
        now = cal.date(from: DateComponents(year: 2026, month: 9, day: 25, hour: 12))!
        parser = QuickEntryParser(calendar: cal)
    }

    private func parse(_ text: String) -> QuickEntryResult { parser.parse(text, now: now) }
    private func day(_ result: QuickEntryResult) -> String { DayKey(result.date, calendar: calendar).description }

    func testExplicitYenWorksEverywhere() {
        XCTAssertEqual(parse("500 yên").currency, .jpy)
        XCTAssertEqual(parse("500 yên").amount, 500)
        XCTAssertEqual(parse("cơm 980円").amount, 980)
        XCTAssertEqual(parse("cơm 980円").categoryID, "food")
        XCTAssertEqual(parse("1万円 quà").amount, 10_000)
        XCTAssertEqual(parse("cà phê 35k").currency, .vnd)
    }

    func testJapanSlangIsOffInVietnam() {
        // "man" chỉ là vạn yên khi chọn thị trường Nhật (tránh nhầm "mận")
        XCTAssertEqual(parse("5 man").currency, .vnd)
    }

    func testDayFirstInVietnam() {
        XCTAssertEqual(day(parse("hoá đơn điện 12/9 650k")), "2026-09-12")
    }

    func testEnglishSentences() {
        let r = parse("coffee 35k yesterday")
        XCTAssertEqual(r.amount, 35_000)
        XCTAssertEqual(day(r), "2026-09-24")
        XCTAssertEqual(r.categoryID, "drinks")
        XCTAssertEqual(day(parse("lunch 45k monday")), "2026-09-21")
        XCTAssertEqual(day(parse("2 món 80k")), "2026-09-25", "\"món\" không phải \"mon(day)\"")
    }
}
