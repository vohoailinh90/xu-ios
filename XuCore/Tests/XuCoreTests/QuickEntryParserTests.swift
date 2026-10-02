import XCTest
@testable import XuCore

final class QuickEntryParserTests: XCTestCase {
    /// Thứ Sáu 25/09/2026, 12:00 giờ Việt Nam
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

    // MARK: Số tiền

    func testThousandsSuffixes() {
        XCTAssertEqual(parse("cà phê 35k").amount, 35_000)
        XCTAssertEqual(parse("cà phê 35K").amount, 35_000)
        XCTAssertEqual(parse("bún 35 nghìn").amount, 35_000)
        XCTAssertEqual(parse("bún 35 ngàn").amount, 35_000)
        XCTAssertEqual(parse("xăng 1k5").amount, 1_500)
    }

    func testMillions() {
        XCTAssertEqual(parse("1tr tiền nhà").amount, 1_000_000)
        XCTAssertEqual(parse("1tr2 tiền nhà").amount, 1_200_000)
        XCTAssertEqual(parse("1tr25 tiền nhà").amount, 1_250_000)
        XCTAssertEqual(parse("1tr250 tiền nhà").amount, 1_250_000)
        XCTAssertEqual(parse("1,5 triệu đi chợ").amount, 1_500_000)
        XCTAssertEqual(parse("1.5tr đi chợ").amount, 1_500_000)
        XCTAssertEqual(parse("điện thoại 2 củ").amount, 2_000_000)
    }

    func testSeparatorsAndCurrency() {
        XCTAssertEqual(parse("35.000 bánh mì").amount, 35_000)
        XCTAssertEqual(parse("35,000 bánh mì").amount, 35_000)
        XCTAssertEqual(parse("siêu thị 1.250.000đ").amount, 1_250_000)
        XCTAssertEqual(parse("xem phim 120000").amount, 120_000)
        XCTAssertEqual(parse("35000 vnd").amount, 35_000)
    }

    func testSmallBareNumbersAreThousands() {
        XCTAssertEqual(parse("phở 45").amount, 45_000)
        let strict = QuickEntryParser(options: .init(smallNumbersAreThousands: false), calendar: calendar)
        XCTAssertEqual(strict.parse("phở 45", now: now).amount, 45)
    }

    func testExplicitUnitWinsOverBareNumber() {
        let r = parse("trà sữa 2 ly 60k")
        XCTAssertEqual(r.amount, 60_000)
        XCTAssertEqual(r.note, "trà sữa 2 ly")
        XCTAssertFalse(r.hasMultipleAmounts)
    }

    func testMultipleExplicitAmountsFlagged() {
        let r = parse("ăn trưa 45k tip 5k")
        XCTAssertEqual(r.amount, 45_000)
        XCTAssertTrue(r.hasMultipleAmounts)
    }

    func testNoAmount() {
        let r = parse("cà phê")
        XCTAssertNil(r.amount)
        XCTAssertFalse(r.isComplete)
        XCTAssertEqual(r.note, "cà phê")
    }

    // MARK: Ngày

    func testDefaultIsToday() { XCTAssertEqual(day(parse("cà phê 35k")), "2026-09-25") }

    func testRelativeDays() {
        XCTAssertEqual(day(parse("Grab 52k hôm qua")), "2026-09-24")
        XCTAssertEqual(day(parse("đổ xăng 80k tối qua")), "2026-09-24")
        XCTAssertEqual(day(parse("lẩu 300k hôm kia")), "2026-09-23")
        XCTAssertEqual(day(parse("sáng nay bánh mì 20k")), "2026-09-25")
    }

    func testWeekdays() {
        XCTAssertEqual(day(parse("thứ 2 cafe 30k")), "2026-09-21")
        XCTAssertEqual(day(parse("t7 xem phim 120000")), "2026-09-19")
        XCTAssertEqual(day(parse("CN đi siêu thị 500k")), "2026-09-20")
        XCTAssertEqual(day(parse("chủ nhật đi siêu thị 500k")), "2026-09-20")
        XCTAssertEqual(day(parse("thứ 6 cơm 40k")), "2026-09-25", "Hôm nay là thứ Sáu")
    }

    func testThuFollowedByMoneyIsNotWeekday() {
        let r = parse("thu 5 triệu tiền thưởng")
        XCTAssertEqual(r.amount, 5_000_000)
        XCTAssertEqual(day(r), "2026-09-25")
        XCTAssertTrue(r.isIncome)
    }

    func testExplicitDates() {
        XCTAssertEqual(day(parse("hoá đơn điện 12/9 650k")), "2026-09-12")
        XCTAssertEqual(day(parse("quà 28/12 500k")), "2025-12-28", "Ngày tương lai → năm ngoái")
        XCTAssertEqual(day(parse("quà 1/3/2026 500k")), "2026-03-01")
        XCTAssertEqual(parse("hoá đơn điện 12/9 650k").amount, 650_000)
    }

    func testDatesAreGregorianEvenWithJapaneseSystemCalendar() {
        var japanese = Calendar(identifier: .japanese)
        japanese.timeZone = calendar.timeZone
        let jp = QuickEntryParser(calendar: japanese)
        XCTAssertEqual(day(jp.parse("hoá đơn điện 12/9 650k", now: now)), "2026-09-12")
        XCTAssertEqual(day(jp.parse("quà 1/3/2026 500k", now: now)), "2026-03-01")
        XCTAssertEqual(day(jp.parse("Grab 52k hôm qua", now: now)), "2026-09-24")
    }

    // MARK: Ghi chú & danh mục

    func testNoteKeepsDiacritics() {
        let r = parse("Grab 52k hôm qua")
        XCTAssertEqual(r.note, "Grab")
        XCTAssertEqual(parse("1tr2 tiền nhà").note, "tiền nhà")
        XCTAssertEqual(parse("CN đi siêu thị 1.250.000đ").note, "đi siêu thị")
    }

    func testCategories() {
        XCTAssertEqual(parse("cà phê 35k").categoryID, "drinks")
        XCTAssertEqual(parse("Grab 52k").categoryID, "transport")
        XCTAssertEqual(parse("phở 45k").categoryID, "food")
        XCTAssertEqual(parse("tiền nước 120k").categoryID, "bills", "Cụm dài 'tiền nước' thắng 'nước'")
        XCTAssertEqual(parse("nước 10k").categoryID, "drinks")
        XCTAssertEqual(parse("nước mắm 30k").categoryID, "groceries", "Cụm dài 'nước mắm' thắng 'nước'")
        XCTAssertEqual(parse("shopee 199k").categoryID, "shopping")
        XCTAssertEqual(parse("abcxyz 10k").categoryID, CategoryCatalog.otherExpenseID)
    }

    /// Từ trùng nghĩa khi bỏ dấu không kéo khoản chi sang danh mục sai.
    func testCategoriesWithAmbiguousSyllables() {
        XCTAssertEqual(parse("túi xách 500k").categoryID, "shopping")
        XCTAssertEqual(parse("trung tâm tiếng Anh 2tr").categoryID, "education", "\"trung tâm\" không phải \"trứng\"")
        XCTAssertEqual(parse("trứng gà 30k").categoryID, "groceries")
        XCTAssertNotEqual(parse("mùng 1 đi chùa 100k").categoryID, "family", "\"mùng\" không phải \"mừng\"")
        XCTAssertEqual(parse("mừng cưới 500k").categoryID, "family")
        XCTAssertEqual(parse("mua cá 50k").categoryID, "groceries")
        XCTAssertEqual(parse("cá 50k").categoryID, "groceries", "Câu ngắn có dấu vẫn đúng")
        XCTAssertEqual(parse("cà chua 20k").categoryID, "groceries")
        XCTAssertEqual(parse("cà rốt 15k").categoryID, "groceries")
        XCTAssertEqual(parse("cà na 30k").categoryID, "groceries")
        XCTAssertEqual(parse("bột cà ri 20k").categoryID, "groceries")
        XCTAssertEqual(parse("cà tím nướng 40k").categoryID, "food", "Cụm dài \"nuong\" thắng âm tiết \"ca\"")
        XCTAssertEqual(parse("ăn cà rốt 15k").categoryID, "food")
        XCTAssertEqual(parse("bánh trung thu 100k").categoryID, "food", "\"trung thu\" không phải \"trứng\"")
        XCTAssertEqual(parse("ăn cá 50k").categoryID, "food", "Cụm \"ăn cá\" thuộc ăn uống")
        XCTAssertEqual(parse("ăn trứng 30k").categoryID, "food")
        XCTAssertEqual(parse("bánh mì trứng 20k").categoryID, "food")
        XCTAssertEqual(parse("mua túi đi học 200k").categoryID, "shopping", "\"túi\" và \"học\" dài bằng nhau: mua sắm đứng trước")
        XCTAssertEqual(parse("trứng 30k").categoryID, "groceries")
        XCTAssertEqual(parse("túi 200k").categoryID, "shopping")
        XCTAssertEqual(parse("mua cà phê 35k").categoryID, "drinks", "\"cà phê\" không phải \"cá\"")
        XCTAssertEqual(parse("mua cả sách 200k").categoryID, "education", "\"cả\" không phải \"cá\"")
        XCTAssertEqual(parse("quà cho cả hội 500k").categoryID, "family")
        XCTAssertEqual(parse("giấy vệ sinh 50k").categoryID, "groceries", "Cụm dài thắng \"giay\" (giày)")
        XCTAssertEqual(parse("son môi 300k").categoryID, "shopping")
        XCTAssertEqual(parse("son 300k").categoryID, "shopping")
        XCTAssertEqual(parse("son dưỡng 150k").categoryID, "shopping")
        XCTAssertNotEqual(parse("trả Sơn 200k").categoryID, "shopping", "\"Sơn\" là tên người")
        // Chữ toàn khổ của bàn phím Nhật không phải dấu tiếng Việt: vẫn khớp như gõ không dấu.
        XCTAssertEqual(parse("ｃａ 50k").categoryID, "groceries")
        XCTAssertEqual(parse("ｓｏｎ 300k").categoryID, "shopping")
        XCTAssertEqual(parse("ｔｕｉ 200k").categoryID, "shopping")
        // Quên dấu một từ: âm tiết gõ không dấu vẫn khớp như cũ.
        XCTAssertEqual(parse("trung gà 30k").categoryID, "groceries")
        XCTAssertEqual(parse("tui xách 500k").categoryID, "shopping")
    }

    func testIncome() {
        let salary = parse("lương +15tr")
        XCTAssertTrue(salary.isIncome)
        XCTAssertEqual(salary.amount, 15_000_000)
        XCTAssertEqual(salary.categoryID, "income.salary")

        let plus = parse("+200k")
        XCTAssertTrue(plus.isIncome)
        XCTAssertEqual(plus.categoryID, CategoryCatalog.otherIncomeID)

        let plusWithExpenseWord = parse("cà phê +35k")
        XCTAssertTrue(plusWithExpenseWord.isIncome)
        XCTAssertEqual(plusWithExpenseWord.categoryID, CategoryCatalog.otherIncomeID)
    }

    func testLearnedKeywordOverridesDefault() {
        let key = CategoryMatcher.learningKey(for: "Bánh tráng trộn")
        XCTAssertEqual(key, "banh trang tron")
        let learned = QuickEntryParser(calendar: calendar,
                                       matcher: CategoryMatcher(learned: [key: "food"]))
        XCTAssertEqual(learned.parse("bánh tráng trộn 25k", now: now).categoryID, "food")
    }

    func testDecomposedUnicodeInput() {
        // "cà phê" viết ở dạng tổ hợp (NFD) — vẫn phải hiểu được
        let nfd = "cà phê 35k".decomposedStringWithCanonicalMapping
        let r = parse(nfd)
        XCTAssertEqual(r.amount, 35_000)
        XCTAssertEqual(r.categoryID, "drinks")
    }

    func testPerformance() {
        measure {
            for _ in 0..<1_000 { _ = parse("grab 52k hôm qua về nhà") }
        }
    }
}
