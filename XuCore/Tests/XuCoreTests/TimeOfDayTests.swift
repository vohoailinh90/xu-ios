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

    func testLeadWordLucMarksATimePoint() {
        let a = parse("đi chợ lúc 7h30 100k")
        XCTAssertEqual(a.minutesOfDay, minutes(7, 30))
        XCTAssertEqual(a.note, "đi chợ", "\"lúc\" bỏ cùng giờ")
        let b = parse("lúc 19h30 grab 52k")
        XCTAssertEqual(b.minutesOfDay, minutes(19, 30))
        XCTAssertEqual(b.note, "grab")
        let c = parse("vào lúc 7:30 phở 45")
        XCTAssertEqual(c.minutesOfDay, minutes(7, 30))
        XCTAssertEqual(c.amount, 45_000, "30 trong 7:30 không phải số tiền")
        XCTAssertEqual(c.note, "phở", "\"vào lúc\" bỏ cùng giờ")
        XCTAssertEqual(parse("lúc 0:30 xe 50k").minutesOfDay, minutes(0, 30))
        XCTAssertEqual(parse("lúc 23h grab 90k").minutesOfDay, minutes(23))
        XCTAssertEqual(parse("lúc 7 giờ 30 cà phê 35k").minutesOfDay, minutes(7, 30))
        XCTAssertNil(parse("lúc 25h 50k").minutesOfDay)
        XCTAssertNil(parse("lúc nào cũng 35k").minutesOfDay)
    }

    func testPeriodWithMinutes() {
        XCTAssertEqual(parse("7 giờ 30 sáng cà phê 35k").minutesOfDay, minutes(7, 30))
        XCTAssertEqual(parse("7 giờ 30 sáng cà phê 35k").note, "cà phê")
        XCTAssertEqual(parse("8h15 tối xem phim 120k").minutesOfDay, minutes(20, 15))
    }

    func testPeriodsConvertToTwentyFourHour() {
        let cases: [(String, Int)] = [
            ("5h chiều 50k", minutes(17)), ("1h chiều cơm 45k", minutes(13)), ("7h chiều 50k", minutes(19)),
            ("12h trưa cơm 45k", minutes(12)), ("11h trưa cơm 45k", minutes(11)), ("1h trưa cơm 45k", minutes(13)),
            ("5h tối 90k", minutes(17)), ("6h tối 90k", minutes(18)), ("11h tối 90k", minutes(23)),
            ("11h đêm nhậu 200k", minutes(23)), ("12h đêm 50k", minutes(0)), ("2h đêm taxi 100k", minutes(2)),
            ("1h sáng 20k", minutes(1)), ("9h sáng 20k", minutes(9)),
            ("19h sáng 20k", minutes(19))   // buổi mâu thuẫn với giờ: giữ 19h
        ]
        for (text, expected) in cases {
            XCTAssertEqual(parse(text).minutesOfDay, expected, text)
        }
    }

    func testPeriodsThatDoNotFitTheHourAreNotATime() {
        // Mỗi buổi chỉ nhận khoảng giờ người ta thật sự nói với nó; ngoài khoảng đó không đoán (không cộng 12 bừa).
        for text in ["5h trưa cơm 45k", "7h đêm 50k", "11h chiều 50k", "8h chiều 50k", "1h tối 90k", "12h tối 90k",
                     "12h sáng 20k"] {
            XCTAssertNil(parse(text).minutesOfDay, text)
            XCTAssertNotNil(parse(text).amount, text)
        }
        XCTAssertEqual(parse("5h trưa cơm 45k").amount, 45_000)
    }

    func testAfterMidnightPhrasingIsLeftAlone() {
        // "tối qua 1h" có thể là 1 giờ sáng nay: mơ hồ nên không đoán. Ngày vẫn là hôm qua, "1h" ở lại trong ghi chú.
        let r = parse("tối qua 1h taxi 100k")
        XCTAssertNil(r.minutesOfDay)
        XCTAssertEqual(day(r), "2026-09-24")
        XCTAssertEqual(r.note, "1h taxi")
    }

    func testBareClockFormsAreNotATime() {
        // Dạng trần cũng là thời lượng ("thuê phòng 2h30", "pin dùng được 20h"), tỷ lệ ("1:20") hay số khác: không nói rõ
        // là một thời điểm (buổi hoặc "lúc") thì không đoán, vì nhầm làm mất chữ trong ghi chú và đặt sai `occurredAt`.
        let notes: [(String, String)] = [
            ("thuê phòng 2h30 100k", "thuê phòng 2h30"), ("thuê xe 1h15 80k", "thuê xe 1h15"),
            ("thuê phòng trong 2:30 100k", "thuê phòng trong 2:30"), ("pin dùng được 20h giá 500k", "pin dùng được 20h giá"),
            ("tỷ lệ 1:20 phí 50k", "tỷ lệ 1:20 phí"), ("0h30 xe 50k", "0h30 xe"), ("7 giờ 30 cà phê 35k", "7 giờ 30 cà phê"),
            ("19h30 grab 52k", "19h30 grab"), ("7:30 phở 45", "7:30 phở"), ("23h grab 90k", "23h grab")
        ]
        for (text, note) in notes {
            let r = parse(text)
            XCTAssertNil(r.minutesOfDay, text)
            XCTAssertEqual(r.note, note, "Ghi chú giữ nguyên chữ của người dùng: \(text)")
            XCTAssertNotNil(r.amount, text)
        }
        XCTAssertEqual(parse("thuê phòng 2h30 100k").amount, 100_000)
        XCTAssertEqual(parse("7:30 phở 45").amount, 45_000)
    }

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
        XCTAssertNil(parse("lúc 24:00 50k").minutesOfDay)
        XCTAssertNil(parse("32h30 50k").minutesOfDay)
        XCTAssertNil(parse("wifi7h30 50k").minutesOfDay, "Dính liền chữ thì không phải giờ")
    }

    func testPlainSentencesAreUnchanged() {
        for text in ["cà phê 35k", "lương +15tr", "xăng 1k5", "1tr2 tiền nhà", "12/9 cà phê 35k", "35.000 bánh mì",
                     "phở 45", "grab 52k hôm qua", "thu 2 cà phê 35k"] {
            XCTAssertNil(parse(text).minutesOfDay, text)
        }
    }

    func testNumbersInsideTheTimeAreNeverAnAmount() {
        // "30" trong "lúc 7:30" không được thành số tiền bé (30 → 30.000đ); và ngược lại, dạng trần không bị mất số.
        let withTime = parse("lúc 7:30 phở 45")
        XCTAssertEqual(withTime.amount, 45_000)
        XCTAssertEqual(withTime.minutesOfDay, minutes(7, 30))
        XCTAssertEqual(withTime.note, "phở")
        XCTAssertEqual(parse("7:30 phở 45").amount, 45_000, "Câu cũ không đổi kết quả")
    }

    func testJapaneseMarketHasNoTimeYet() {
        // Giờ kiểu Nhật ("7時30分") chưa hỗ trợ; dạng trần "7:30" không đoán, nên câu tiếng Nhật không đổi.
        let japan = QuickEntryParser(options: .init(market: .japan), calendar: calendar)
        let r = japan.parse("コーヒー 7:30 350円", now: now)
        XCTAssertNil(r.minutesOfDay)
        XCTAssertEqual(r.amount, 350)
        XCTAssertEqual(r.note, "コーヒー 7:30")
    }

    // MARK: Tách khoản

    func testSplitSharesTheTimeAndKeepsItOutOfNotes() {
        let parts = parser.split("lúc 19h 35k cà phê 20k bánh", now: now)
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
}
