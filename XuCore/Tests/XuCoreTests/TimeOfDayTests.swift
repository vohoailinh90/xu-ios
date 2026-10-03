import XCTest
@testable import XuCore

/// Giờ trong câu nhập: "7h sáng", "19h30", "7:30" (docs/04, mục "Giờ").
final class TimeOfDayTests: XCTestCase {
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
    private func minutes(_ hour: Int, _ minute: Int = 0) -> Int { hour * 60 + minute }

    // MARK: Nhận giờ

    func testHourWithPeriodAfter() {
        let r = parse("cà phê 7h sáng 35k")
        XCTAssertEqual(r.minutesOfDay, minutes(7))
        XCTAssertEqual(r.amount, 35_000)
        XCTAssertEqual(r.note, "cà phê", "Buổi đứng sau giờ cũng bỏ khỏi ghi chú")
        XCTAssertEqual(day(r), "2026-09-25", "Giờ không đổi ngày")
    }

    func testPeriodBeforeTheHourStaysInTheNote() {
        // "ăn tối" là chữ của ghi chú và là từ khoá danh mục: bỏ "tối" thì mất danh mục.
        let r = parse("ăn tối 7h 80k")
        XCTAssertEqual(r.minutesOfDay, minutes(19))
        XCTAssertEqual(r.note, "ăn tối")
        XCTAssertEqual(r.categoryID, parse("ăn tối 80k").categoryID)
        XCTAssertEqual(parse("ăn sáng 7h30 35k").note, "ăn sáng")
        XCTAssertEqual(parse("ăn sáng 7h30 35k").minutesOfDay, minutes(7, 30))
    }

    func testMinutesAndFormats() {
        XCTAssertEqual(parse("19h30 grab 52k").minutesOfDay, minutes(19, 30))
        XCTAssertEqual(parse("19h30 grab 52k").note, "grab")
        XCTAssertEqual(parse("7:30 cà phê 35k").minutesOfDay, minutes(7, 30))
        XCTAssertEqual(parse("7 giờ 30 cà phê 35k").minutesOfDay, minutes(7, 30))
        XCTAssertEqual(parse("7 giờ 30 cà phê 35k").note, "cà phê")
        XCTAssertEqual(parse("0h30 xe 50k").minutesOfDay, minutes(0, 30))
        XCTAssertEqual(parse("23h grab 90k").minutesOfDay, minutes(23), "Từ 13 giờ trở lên không cần buổi")
    }

    func testPeriodsConvertToTwentyFourHour() {
        let cases: [(String, Int)] = [
            ("5h chiều 50k", minutes(17)), ("1h chiều cơm 45k", minutes(13)), ("12h trưa cơm 45k", minutes(12)),
            ("11h trưa cơm 45k", minutes(11)), ("1h trưa cơm 45k", minutes(13)), ("6h tối 90k", minutes(18)),
            ("12h tối 90k", minutes(0)), ("11h đêm nhậu 200k", minutes(23)), ("12h đêm 50k", minutes(0)),
            ("2h đêm taxi 100k", minutes(2)), ("12h sáng 20k", minutes(0)), ("9h sáng 20k", minutes(9)),
            ("19h sáng 20k", minutes(19))   // buổi mâu thuẫn với giờ: giữ 19h
        ]
        for (text, expected) in cases {
            XCTAssertEqual(parse(text).minutesOfDay, expected, text)
        }
    }

    func testPeriodsThatDoNotFitTheHourAreNotATime() {
        XCTAssertNil(parse("5h trưa cơm 45k").minutesOfDay, "5 giờ trưa không có")
        XCTAssertEqual(parse("5h trưa cơm 45k").amount, 45_000)
        XCTAssertNil(parse("7h đêm 50k").minutesOfDay)
    }

    // MARK: Ngày và giờ đi cùng nhau

    func testRelativeDayPhrasesStillWork() {
        let a = parse("7h tối qua grab 52k")
        XCTAssertEqual(a.minutesOfDay, minutes(19))
        XCTAssertEqual(day(a), "2026-09-24", "\"tối qua\" vẫn là hôm qua")
        XCTAssertEqual(a.note, "grab")

        let b = parse("chiều nay 3h trà sữa 45k")
        XCTAssertEqual(b.minutesOfDay, minutes(15))
        XCTAssertEqual(day(b), "2026-09-25")
        XCTAssertEqual(b.note, "trà sữa")

        let c = parse("23h30 hôm qua 50k")
        XCTAssertEqual(c.minutesOfDay, minutes(23, 30))
        XCTAssertEqual(day(c), "2026-09-24", "Giờ khuya vẫn thuộc đúng ngày đã nói")
    }

    func testRelativeDayPhrasesAloneHaveNoTime() {
        for text in ["tối qua nhậu 200k", "sáng nay cà phê 35k", "trưa nay cơm 45k", "chiều nay trà sữa 45k"] {
            XCTAssertNil(parse(text).minutesOfDay, text)
        }
        XCTAssertEqual(day(parse("tối qua nhậu 200k")), "2026-09-24")
    }

    // MARK: Không phải giờ

    func testBareHoursAreNotATime() {
        // "7h", "2h" trơn có thể là thời lượng: không đoán, ghi chú giữ nguyên chữ của người dùng.
        let room = parse("phòng 2h 100k")
        XCTAssertNil(room.minutesOfDay)
        XCTAssertEqual(room.amount, 100_000)
        XCTAssertEqual(room.note, "phòng 2h")

        let pass = parse("gói 24h 50k")
        XCTAssertNil(pass.minutesOfDay, "24 không phải giờ trong ngày")
        XCTAssertEqual(pass.note, "gói 24h")

        let coffee = parse("cà phê 7h 35k")
        XCTAssertNil(coffee.minutesOfDay)
        XCTAssertEqual(coffee.amount, 35_000)
        XCTAssertEqual(coffee.note, "cà phê 7h")
    }

    func testHourFollowedByAmountIsNotMinutes() {
        // "7 giờ 30k" là 7 giờ và 30k (không có buổi, không có phút: không phải giờ), không phải 7:30.
        let r = parse("cà phê 7 giờ 30k")
        XCTAssertNil(r.minutesOfDay)
        XCTAssertEqual(r.amount, 30_000)
        XCTAssertNil(parse("5h30k").minutesOfDay)
        XCTAssertNil(parse("cà phê 7h3 35k").minutesOfDay, "Phút phải đủ hai chữ số")
    }

    func testInvalidTimesAreIgnored() {
        XCTAssertNil(parse("tăng 25:61 50k").minutesOfDay)
        XCTAssertNil(parse("32h30 50k").minutesOfDay)
        XCTAssertNil(parse("wifi7h30 50k").minutesOfDay, "Dính liền chữ thì không phải giờ")
    }

    func testPlainSentencesAreUnchanged() {
        for text in ["cà phê 35k", "lương +15tr", "xăng 1k5", "1tr2 tiền nhà", "12/9 cà phê 35k", "35.000 bánh mì",
                     "phở 45", "grab 52k hôm qua", "thu 2 cà phê 35k"] {
            XCTAssertNil(parse(text).minutesOfDay, text)
        }
    }

    func testColonTimeIsNotAnAmount() {
        // "30" trong "7:30" không được thành số tiền bé (30 → 30.000đ).
        let r = parse("7:30 phở 45")
        XCTAssertEqual(r.amount, 45_000)
        XCTAssertEqual(r.minutesOfDay, minutes(7, 30))
        XCTAssertEqual(r.note, "phở")
    }

    func testJapaneseMarketColonTime() {
        let japan = QuickEntryParser(options: .init(market: .japan), calendar: calendar)
        let r = japan.parse("コーヒー 7:30 350円", now: now)
        XCTAssertEqual(r.minutesOfDay, minutes(7, 30))
        XCTAssertEqual(r.amount, 350)
        XCTAssertEqual(r.note, "コーヒー")
    }

    // MARK: Tách khoản

    func testSplitSharesTheTimeAndKeepsItOutOfNotes() {
        let parts = parser.split("19h 35k cà phê 20k bánh", now: now)
        XCTAssertEqual(parts.map(\.amount), [35_000, 20_000])
        XCTAssertEqual(parts.map(\.note), ["cà phê", "bánh"], "Giờ ở đầu câu không được tính là chữ đi trước số tiền")
        XCTAssertEqual(parts.map(\.minutesOfDay), [minutes(19), minutes(19)])

        let withPeriod = parser.split("cà phê 35k bánh 20k 7h sáng", now: now)
        XCTAssertEqual(withPeriod.map(\.minutesOfDay), [minutes(7), minutes(7)])
        XCTAssertFalse(withPeriod.contains { $0.note.contains("7h") })
    }

    func testSingleAmountSplitReturnsTheWholeWithItsTime() {
        let parts = parser.split("cà phê 7h sáng 35k", now: now)
        XCTAssertEqual(parts.count, 1)
        XCTAssertEqual(parts.first?.minutesOfDay, minutes(7))
    }

    // MARK: Tốc độ

    /// Mục tiêu trong docs/04: 10.000 lần `parse` dưới 1 giây trên iPhone đời cũ nhất hỗ trợ. Bản này chạy ở cấu hình
    /// Debug trên máy CI nên chỉ chặn hồi quy lớn (trần rộng) và in số đo; đo chính thức phải làm trên máy thật.
    func testParsingTenThousandSentencesIsNotSlow() {
        let sentences = ["cà phê 35k", "grab 52k hôm qua", "1tr2 tiền nhà", "lương +15tr", "7h sáng ăn phở 45k",
                         "ăn trưa 45k tip 5k", "thu 2 cà phê ba mươi lăm nghìn", "コーヒー 350円", "tối qua nhậu 200k"]
        let start = Date()
        for i in 0..<10_000 { _ = parser.parse(sentences[i % sentences.count], now: now) }
        let elapsed = Date().timeIntervalSince(start)
        print("[perf] 10.000 lần parse (Debug, máy CI): \(String(format: "%.2f", elapsed)) giây")
        XCTAssertLessThan(elapsed, 30, "Parse chậm bất thường: kiểm tra regex mới thêm")
    }
}
