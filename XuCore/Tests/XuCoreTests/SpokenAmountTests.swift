import XCTest
@testable import XuCore

/// Số tiền bằng chữ, như câu đọc chính tả bằng giọng nói (issue E9). Đặc tả: docs/04.
final class SpokenAmountTests: XCTestCase {
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

    func testCommonSpokenAmounts() {
        let cases: [(String, Int64)] = [
            ("ba mươi lăm nghìn", 35_000),
            ("hai mươi nghìn", 20_000),
            ("hai mươi mốt nghìn", 21_000),
            ("mười lăm nghìn", 15_000),
            ("mười một nghìn", 11_000),
            ("chín mươi chín nghìn", 99_000),
            ("hai lăm nghìn", 25_000),       // nói tắt: hai mươi lăm
            ("ba mốt nghìn", 31_000),
            ("năm chục nghìn", 50_000),
            ("bảy trăm ngàn", 700_000),
            ("hai trăm năm mươi nghìn", 250_000),
            ("một trăm linh năm nghìn", 105_000),
            ("một triệu", 1_000_000),
            ("một triệu rưỡi", 1_500_000),
            ("hai nghìn rưỡi", 2_500),
            ("một triệu hai trăm nghìn", 1_200_000),
            ("một nghìn không trăm năm mươi đồng", 1_050)
        ]
        for (text, amount) in cases {
            let r = parse(text)
            XCTAssertEqual(r.amount, amount, text)
            XCTAssertEqual(r.currency, .vnd, text)
            XCTAssertEqual(r.note, "", text)
        }
    }

    /// "một triệu hai" = 1tr2: phần sau "triệu" là phần thập phân, như khi gõ số — chỉ khi đó là chữ cuối của cụm.
    func testMillionShorthand() {
        XCTAssertEqual(parse("tiền nhà một triệu hai").amount, 1_200_000)
        XCTAssertEqual(parse("tiền nhà một triệu hai").note, "tiền nhà")
        XCTAssertEqual(parse("một triệu hai lăm").amount, 1_250_000)
        XCTAssertEqual(parse("một triệu hai, tiền nhà").amount, 1_200_000)
        // Chữ đi sau là một từ khác: "hai ly" không phải phần lẻ của triệu.
        let r = parse("một triệu hai ly")
        XCTAssertEqual(r.amount, 1_000_000)
        XCTAssertEqual(r.note, "hai ly")
    }

    func testNoteCategoryAndCurrencyWord() {
        let r = parse("ăn trưa ba mươi lăm nghìn")
        XCTAssertEqual(r.amount, 35_000)
        XCTAssertEqual(r.note, "ăn trưa")
        XCTAssertEqual(r.categoryID, "food")
        XCTAssertEqual(parse("hai trăm năm mươi nghìn đồng tiền điện").note, "tiền điện")
    }

    func testYenAndJapanMarket() {
        let japan = QuickEntryParser(options: .init(market: .japan), calendar: calendar)
        let rice = japan.parse("cơm ba trăm năm mươi yên", now: now)
        XCTAssertEqual(rice.amount, 350)
        XCTAssertEqual(rice.currency, .jpy)
        XCTAssertEqual(rice.note, "cơm")
        // "nghìn" nhân 1.000 với tiền của nơi chi tiêu, như "3k".
        XCTAssertEqual(japan.parse("ba nghìn", now: now).currency, .jpy)
        XCTAssertEqual(japan.parse("ba nghìn", now: now).amount, 3_000)
        // "triệu" luôn là tiền đồng.
        XCTAssertEqual(japan.parse("gửi về nhà năm triệu", now: now).currency, .vnd)
    }

    /// Không có đơn vị, gõ không dấu, hay chữ trùng nghĩa: không đoán bừa thành số tiền.
    func testNotAmounts() {
        XCTAssertNil(parse("mua ba ly trà sữa").amount)
        XCTAssertNil(parse("năm nay").amount)
        XCTAssertNil(parse("ba muoi nghin").amount)          // không dấu: để người dùng gõ số
        XCTAssertNil(parse("hai đồng hồ").amount)            // "đồng" đứng một mình
        XCTAssertEqual(parse("hai củ khoai 10k").amount, 10_000)   // "củ" ở đây là củ khoai
        XCTAssertEqual(parse("hai củ khoai 10k").note, "hai củ khoai")
    }

    func testWorksWithDatesDigitsAndSplit() {
        let r = parse("hôm qua grab năm mươi nghìn")
        XCTAssertEqual(r.amount, 50_000)
        XCTAssertEqual(DayKey(r.date, calendar: calendar).description, "2026-09-24")
        XCTAssertEqual(r.note, "grab")
        // Chữ "hai" của "thứ hai" không dính vào số tiền phía sau.
        XCTAssertEqual(parse("thứ hai năm mươi nghìn").amount, 50_000)
        // Số bằng chữ là số có đơn vị: thắng số trần, và tách được như số gõ tay.
        XCTAssertEqual(parse("trà sữa 2 ly bốn mươi nghìn").amount, 40_000)
        let parts = parser.split("cà phê 35k và bánh hai mươi nghìn", now: now)
        XCTAssertEqual(parts.map(\.amount), [35_000, 20_000])
        XCTAssertEqual(parts.map(\.note), ["cà phê", "bánh"])
    }

    func testCapitalizedFromDictation() {
        XCTAssertEqual(parse("Ba mươi lăm nghìn cà phê").amount, 35_000)
        XCTAssertEqual(parse("Ba mươi lăm nghìn cà phê").note, "cà phê")
    }
}
