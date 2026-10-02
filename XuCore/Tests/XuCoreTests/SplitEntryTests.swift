import XCTest
@testable import XuCore

/// Tách câu có nhiều số tiền thành nhiều khoản (issue E8). Đặc tả: docs/04, mục "Khi có nhiều số".
final class SplitEntryTests: XCTestCase {
    /// Thứ Sáu 25/09/2026, 12:00 giờ Việt Nam
    var calendar: Calendar!
    var now: Date!
    var parser: QuickEntryParser!
    var japan: QuickEntryParser!

    override func setUp() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        calendar = cal
        now = cal.date(from: DateComponents(year: 2026, month: 9, day: 25, hour: 12))!
        parser = QuickEntryParser(calendar: cal)
        japan = QuickEntryParser(options: .init(market: .japan), calendar: cal)
    }

    private func split(_ text: String) -> [QuickEntryResult] { parser.split(text, now: now) }
    private func notes(_ parts: [QuickEntryResult]) -> [String] { parts.map(\.note) }
    private func amounts(_ parts: [QuickEntryResult]) -> [Int64?] { parts.map(\.amount) }

    func testTwoAmountsBecomeTwoEntries() {
        let parts = split("ăn trưa 45k tip 5k")
        XCTAssertEqual(amounts(parts), [45_000, 5_000])
        XCTAssertEqual(notes(parts), ["ăn trưa", "tip"])
        // "tip" không có danh mục riêng: lấy danh mục của cả câu, như thẻ xem trước đang hiện.
        XCTAssertEqual(parts.map(\.categoryID), ["food", "food"])
        XCTAssertFalse(parts.contains(where: \.hasMultipleAmounts))
    }

    func testEachPartGetsItsOwnCategory() {
        let parts = split("cà phê 35k, grab 52k, bánh mì 20k")
        XCTAssertEqual(amounts(parts), [35_000, 52_000, 20_000])
        XCTAssertEqual(notes(parts), ["cà phê", "grab", "bánh mì"])
        XCTAssertEqual(parts.map(\.categoryID), ["drinks", "transport", "food"])
    }

    func testAmountFirstSentence() {
        let parts = split("35k cà phê 20k bánh mì")
        XCTAssertEqual(amounts(parts), [35_000, 20_000])
        XCTAssertEqual(notes(parts), ["cà phê", "bánh mì"])
    }

    func testSeparatorDecidesWhereToCut() {
        XCTAssertEqual(notes(split("45k ăn trưa, tip 5k")), ["ăn trưa", "tip"])
        XCTAssertEqual(notes(split("35k cà phê và 20k bánh")), ["cà phê", "bánh"])
        XCTAssertEqual(notes(split("cà phê 35k + bánh 20k")), ["cà phê", "bánh"])
        XCTAssertEqual(notes(split("cà phê 35k, và bánh 20k")), ["cà phê", "bánh"])
        XCTAssertEqual(notes(split("cà phê 35k bánh 20k nước 10k")), ["cà phê", "bánh", "nước"])
        // Dấu câu thắng chữ nối; "với" là "cùng với", không cắt.
        XCTAssertEqual(notes(split("ăn trưa 45k với bạn, grab 20k")), ["ăn trưa với bạn", "grab"])
        XCTAssertEqual(notes(split("ăn trưa 45k và cà phê với bạn, grab 20k")), ["ăn trưa và cà phê với bạn", "grab"])
    }

    /// "va" không dấu có thể là "vá": không cắt mất chữ của người dùng.
    func testUnaccentedVaIsKept() {
        XCTAssertEqual(notes(split("gửi xe 5k vá xe 30k")), ["gửi xe", "vá xe"])
        XCTAssertEqual(notes(split("gui xe 5k va xe 30k")), ["gui xe", "va xe"])
    }

    func testDateIsSharedByAllParts() {
        let parts = split("hôm qua grab 52k và cà phê 35k")
        XCTAssertEqual(notes(parts), ["grab", "cà phê"])
        XCTAssertEqual(parts.map { DayKey($0.date, calendar: calendar).description }, ["2026-09-24", "2026-09-24"])
        XCTAssertEqual(notes(split("grab 52k hôm qua, cà phê 35k")), ["grab", "cà phê"])
    }

    func testBareNumbersStayInNotes() {
        let parts = split("2 ly trà sữa 60k, 1 bánh 20k")
        XCTAssertEqual(amounts(parts), [60_000, 20_000])
        XCTAssertEqual(notes(parts), ["2 ly trà sữa", "1 bánh"])
    }

    func testIncomeIsDecidedPerPart() {
        let both = split("lương +15tr thưởng +2tr")
        XCTAssertEqual(both.map(\.isIncome), [true, true])
        XCTAssertEqual(both.map(\.categoryID), ["income.salary", "income.bonus"])

        // Phần có "+" là khoản thu dù danh mục mượn từ cả câu là khoản chi.
        let refund = split("ăn trưa 45k, +5k")
        XCTAssertEqual(refund.map(\.isIncome), [false, true])
        XCTAssertEqual(refund.map(\.categoryID), ["food", CategoryCatalog.otherIncomeID])

        // Danh mục thu nhập của cả câu không lan sang phần không có "+".
        let mixed = split("lương 15tr, abc 50k")
        XCTAssertEqual(mixed.map(\.isIncome), [true, false])
        XCTAssertEqual(mixed.map(\.categoryID), ["income.salary", CategoryCatalog.otherExpenseID])
    }

    /// Danh mục người dùng chọn tay trên thẻ xem trước thay cho danh mục cả câu, như thẻ đang hiện.
    func testFallbackCategoryFromPreview() {
        XCTAssertEqual(split("abc 45k tip 5k").map(\.categoryID), ["other", "other"])
        let picked = parser.split("abc 45k tip 5k", now: now, fallbackCategoryID: "food")
        XCTAssertEqual(picked.map(\.categoryID), ["food", "food"])
        // Khoản tự nhận ra danh mục thì giữ danh mục của nó.
        XCTAssertEqual(parser.split("abc 45k grab 52k", now: now, fallbackCategoryID: "food").map(\.categoryID),
                       ["food", "transport"])
        // Danh mục thu nhập không lan sang khoản không có "+".
        let income = parser.split("abc 45k tip 5k", now: now, fallbackCategoryID: "income.salary")
        XCTAssertEqual(income.map(\.isIncome), [false, false])
        XCTAssertEqual(income.map(\.categoryID), ["other", "other"])
    }

    func testSingleAmountIsJustParse() {
        for text in ["trà sữa 2 ly 60k", "phở 45 trà 15", "cà phê", "Grab 52k hôm qua"] {
            XCTAssertEqual(parser.split(text, now: now), [parser.parse(text, now: now)], text)
            XCTAssertFalse(parser.parse(text, now: now).hasMultipleAmounts, text)
        }
    }

    func testFlagMatchesSplit() {
        for text in ["ăn trưa 45k tip 5k", "45k 5k", "cà phê 35k, bánh 20k"] {
            XCTAssertTrue(parser.parse(text, now: now).hasMultipleAmounts, text)
            XCTAssertEqual(split(text).count, 2, text)
        }
        // Khoản đầu của bản tách là khoản Enter sẽ lưu.
        XCTAssertEqual(split("ăn trưa 45k tip 5k").first?.amount, parser.parse("ăn trưa 45k tip 5k", now: now).amount)
    }

    func testJapanese() {
        let parts = japan.split("コーヒー350円とパン200円", now: now)
        XCTAssertEqual(amounts(parts), [350, 200])
        XCTAssertEqual(notes(parts), ["コーヒー", "パン"])
        XCTAssertEqual(parts.map(\.currency), [.jpy, .jpy])
        // と trước một từ khoá danh mục là "và"; と là chữ đầu của từ (とんかつ, とうふ) thì giữ.
        XCTAssertEqual(notes(japan.split("コーヒー350円とお茶200円", now: now)), ["コーヒー", "お茶"])
        XCTAssertEqual(notes(japan.split("ラーメン980円とうどん500円", now: now)), ["ラーメン", "うどん"])
        XCTAssertEqual(notes(japan.split("コーヒー350円とおにぎり150円", now: now)), ["コーヒー", "おにぎり"])
        XCTAssertEqual(notes(japan.split("ラーメン980円とんかつ900円", now: now)), ["ラーメン", "とんかつ"])
        XCTAssertEqual(notes(japan.split("ラーメン980円とうふ200円", now: now)), ["ラーメン", "とうふ"])
        XCTAssertEqual(notes(japan.split("コーヒー350円、パン200円", now: now)), ["コーヒー", "パン"])
        XCTAssertEqual(notes(japan.split("lunch 1200円 and coffee 400円", now: now)), ["lunch", "coffee"])
    }

    func testEachPartKeepsItsCurrency() {
        let parts = japan.split("gửi về nhà 5tr, cơm 980 yên", now: now)
        XCTAssertEqual(amounts(parts), [5_000_000, 980])
        XCTAssertEqual(parts.map(\.currency), [.vnd, .jpy])
        XCTAssertEqual(notes(parts), ["gửi về nhà", "cơm"])
    }
}
