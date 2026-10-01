import XCTest
@testable import XuCore

final class ChipSuggesterTests: XCTestCase {
    var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        return cal
    }()
    let today = DayKey(year: 2026, month: 9, day: 25)

    private func entry(_ note: String, _ amount: Int64, daysAgo: Int, category: String = "drinks",
                       currency: Currency = .vnd, income: Bool = false) -> ChipSuggester.Entry {
        ChipSuggester.Entry(note: note, amount: amount, currency: currency, categoryID: category,
                            isIncome: income, day: today.adding(days: -daysAgo, calendar: calendar))
    }

    private func suggest(_ entries: [ChipSuggester.Entry], pinned: [ChipSuggester.Pinned] = []) -> [ChipSuggester.Suggestion] {
        ChipSuggester.suggest(entries: entries, pinned: pinned, today: today, calendar: calendar)
    }

    func testRepeatedOnThreeDaysIsSuggested() {
        let result = suggest([
            entry("cà phê", 35_000, daysAgo: 0),
            entry("Cà phê", 35_000, daysAgo: 2),
            entry("ca phe ", 35_000, daysAgo: 5),
        ])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "cà phê", "Lấy cách gõ của lần gần nhất")
        XCTAssertEqual(result.first?.amount, 35_000)
        XCTAssertEqual(result.first?.days, 3)
    }

    func testSameDayRepeatsDoNotCount() {
        let result = suggest([
            entry("trà đá", 5_000, daysAgo: 1),
            entry("trà đá", 5_000, daysAgo: 1),
            entry("trà đá", 5_000, daysAgo: 1),
            entry("trà đá", 5_000, daysAgo: 4),
        ])
        XCTAssertTrue(result.isEmpty, "Ba lần trong một ngày chưa phải thói quen")
    }

    func testDifferentAmountOrCurrencyIsDifferentChip() {
        let result = suggest([
            entry("cà phê", 35_000, daysAgo: 0),
            entry("cà phê", 40_000, daysAgo: 1),
            entry("cà phê", 35_000, daysAgo: 2),
            entry("cà phê", 35, daysAgo: 3, currency: .jpy),
        ])
        XCTAssertTrue(result.isEmpty)
    }

    func testIgnoresIncomeEmptyNotesFutureAndOldEntries() {
        let result = suggest([
            entry("lương", 10_000_000, daysAgo: 0, income: true),
            entry("lương", 10_000_000, daysAgo: 1, income: true),
            entry("lương", 10_000_000, daysAgo: 2, income: true),
            entry("", 20_000, daysAgo: 0),
            entry("", 20_000, daysAgo: 1),
            entry("", 20_000, daysAgo: 2),
            entry("gửi xe", 5_000, daysAgo: -1),
            entry("gửi xe", 5_000, daysAgo: 0),
            entry("gửi xe", 5_000, daysAgo: 40),
        ])
        XCTAssertTrue(result.isEmpty)
    }

    func testAlreadyPinnedIsNotSuggested() {
        let entries = [
            entry("コーヒー", 150, daysAgo: 0, currency: .jpy),
            entry("コーヒー", 150, daysAgo: 1, currency: .jpy),
            entry("コーヒー ", 150, daysAgo: 2, currency: .jpy),
            entry("Coffee", 300, daysAgo: 0, currency: .jpy),
            entry("coffee", 300, daysAgo: 1, currency: .jpy),
            entry("ＣＯＦＦＥＥ", 300, daysAgo: 2, currency: .jpy),
        ]
        XCTAssertEqual(suggest(entries).count, 2, "Chữ toàn khổ của bàn phím Nhật và chữ thường/hoa là một")
        XCTAssertEqual(suggest(entries, pinned: [.init(title: "コーヒー", amount: 150, currency: .jpy),
                                                 .init(title: "COFFEE", amount: 300, currency: .jpy)]).count, 0)
        XCTAssertEqual(suggest(entries, pinned: [.init(title: "コーヒー", amount: 150, currency: .vnd)]).count, 2)
    }

    func testMostUsedCategoryWinsThenLatest() {
        let result = suggest([
            entry("bánh mì", 20_000, daysAgo: 0, category: "food"),
            entry("bánh mì", 20_000, daysAgo: 1, category: "other"),
            entry("bánh mì", 20_000, daysAgo: 2, category: "food"),
            entry("phở", 45_000, daysAgo: 0, category: "drinks"),
            entry("phở", 45_000, daysAgo: 1, category: "food"),
            entry("phở", 45_000, daysAgo: 2, category: "drinks"),
            entry("phở", 45_000, daysAgo: 3, category: "food"),
        ])
        XCTAssertEqual(result.first { $0.title == "bánh mì" }?.categoryID, "food")
        XCTAssertEqual(result.first { $0.title == "phở" }?.categoryID, "drinks", "Hoà 2–2 thì lấy danh mục lần gần nhất")
    }

    func testOrderedByDaysThenRecencyAndLimited() {
        var entries: [ChipSuggester.Entry] = []
        for d in 0..<5 { entries.append(entry("grab", 25_000, daysAgo: d, category: "transport")) }
        for d in 3..<6 { entries.append(entry("trà sữa", 50_000, daysAgo: d)) }
        for d in 1..<4 { entries.append(entry("bún", 40_000, daysAgo: d, category: "food")) }
        for d in 6..<9 { entries.append(entry("báo", 10_000, daysAgo: d, category: "other")) }
        let result = suggest(entries)
        XCTAssertEqual(result.map(\.title), ["grab", "bún", "trà sữa"])
    }
}
