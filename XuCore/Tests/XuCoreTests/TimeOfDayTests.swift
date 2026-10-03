import XCTest
@testable import XuCore

/// Giờ trong câu nhập: "7h sáng", "sáng 7h", "lúc 19h30" (docs/04, mục "Giờ").
/// Nguyên tắc: chỉ nhận giờ khi người dùng nói rõ đó là một thời điểm; mọi dạng khác giữ nguyên chữ của người dùng.
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

    // MARK: Cách 1: buổi đứng ngay sau giờ

    func testPeriodAfterTheHour() {
        let r = parse("cà phê 7h sáng 35k")
        XCTAssertEqual(r.minutesOfDay, minutes(7))
        XCTAssertEqual(r.amount, 35_000)
        XCTAssertEqual(r.note, "cà phê", "Cụm giờ bỏ khỏi ghi chú")
        XCTAssertEqual(day(r), "2026-09-25", "Giờ không đổi ngày")

        XCTAssertEqual(parse("cà phê 7h30 sáng 35k").minutesOfDay, minutes(7, 30))
        let b = parse("7 giờ 30 sáng cà phê 35k")
        XCTAssertEqual(b.minutesOfDay, minutes(7, 30))
        XCTAssertEqual(b.note, "cà phê")
        let c = parse("8h15 tối xem phim 120k")
        XCTAssertEqual(c.minutesOfDay, minutes(20, 15))
        XCTAssertEqual(c.note, "xem phim")
        XCTAssertEqual(parse("19h tối grab 52k").minutesOfDay, minutes(19), "Giờ 24h đi với buổi vẫn là giờ")
        XCTAssertEqual(parse("14h chiều họp 50k").minutesOfDay, minutes(14))
    }

    // MARK: Cách 2: buổi đứng đầu câu hoặc kèm "nay"/"qua"

    func testPeriodAtTheStartOrWithNayQua() {
        let a = parse("sáng 7h cà phê 35k")
        XCTAssertEqual(a.minutesOfDay, minutes(7))
        XCTAssertEqual(a.note, "cà phê", "Buổi mở đầu câu là một phần của cụm giờ")
        let b = parse("tối 7h grab 52k")
        XCTAssertEqual(b.minutesOfDay, minutes(19))
        XCTAssertEqual(b.note, "grab")

        let c = parse("chiều nay 3h trà sữa 45k")
        XCTAssertEqual(c.minutesOfDay, minutes(15))
        XCTAssertEqual(day(c), "2026-09-25")
        XCTAssertEqual(c.note, "trà sữa")
        let d = parse("tối qua 7h taxi 100k")
        XCTAssertEqual(d.minutesOfDay, minutes(19))
        XCTAssertEqual(day(d), "2026-09-24", "\"tối qua\" vẫn là hôm qua")
        XCTAssertEqual(d.note, "taxi")
        let e = parse("cà phê chiều nay 3h 45k")
        XCTAssertEqual(e.minutesOfDay, minutes(15))
        XCTAssertEqual(e.note, "cà phê")
    }

    // MARK: Cách 3: "lúc"

    func testLeadWordLucMarksATimePoint() {
        let a = parse("đi chợ lúc 7h30 100k")
        XCTAssertEqual(a.minutesOfDay, minutes(7, 30))
        XCTAssertEqual(a.note, "đi chợ", "\"lúc\" bỏ cùng giờ")
        let b = parse("lúc 19h30 grab 52k")
        XCTAssertEqual(b.minutesOfDay, minutes(19, 30))
        XCTAssertEqual(b.note, "grab")
        let c = parse("vào lúc 7:30 phở 45")
        XCTAssertEqual(c.minutesOfDay, minutes(7, 30), "Dạng dấu hai chấm chỉ nhận khi có \"lúc\"")
        XCTAssertEqual(c.amount, 45_000, "30 trong 7:30 không phải số tiền")
        XCTAssertEqual(c.note, "phở", "\"vào lúc\" bỏ cùng giờ")
        XCTAssertEqual(parse("lúc 0:30 xe 50k").minutesOfDay, minutes(0, 30))
        XCTAssertEqual(parse("lúc 23h grab 90k").minutesOfDay, minutes(23))
        XCTAssertEqual(parse("lúc 7 giờ 30 cà phê 35k").minutesOfDay, minutes(7, 30))
        XCTAssertEqual(parse("lúc 7h tối grab 52k").minutesOfDay, minutes(19), "\"lúc\" kèm buổi thì đổi theo buổi")
        let d = parse("lúc 7h tối qua grab 52k")
        XCTAssertEqual(d.minutesOfDay, minutes(19), "Có \"lúc\" thì giờ đã nói rõ: \"tối qua\" là ngày")
        XCTAssertEqual(day(d), "2026-09-24")
        XCTAssertEqual(d.note, "grab")
        XCTAssertNil(parse("lúc 25h 50k").minutesOfDay)
        XCTAssertNil(parse("lúc 24:00 50k").minutesOfDay)
        XCTAssertNil(parse("lúc nào cũng 35k").minutesOfDay)
    }

    // MARK: Buổi và giờ phải đi với nhau

    func testPeriodsConvertToTwentyFourHour() {
        let cases: [(String, Int)] = [
            ("5h chiều 50k", minutes(17)), ("1h chiều cơm 45k", minutes(13)), ("7h chiều 50k", minutes(19)),
            ("12h trưa cơm 45k", minutes(12)), ("11h trưa cơm 45k", minutes(11)), ("1h trưa cơm 45k", minutes(13)),
            ("13h trưa cơm 45k", minutes(13)), ("5h tối 90k", minutes(17)), ("6h tối 90k", minutes(18)),
            ("11h tối 90k", minutes(23)), ("22h tối 90k", minutes(22)), ("11h đêm nhậu 200k", minutes(23)),
            ("12h đêm 50k", minutes(0)), ("2h đêm taxi 100k", minutes(2)), ("23h đêm 50k", minutes(23)),
            ("1h sáng 20k", minutes(1)), ("9h sáng 20k", minutes(9))
        ]
        for (text, expected) in cases {
            XCTAssertEqual(parse(text).minutesOfDay, expected, text)
        }
    }

    func testPeriodsThatDoNotFitTheHourAreNotATime() {
        // Mỗi buổi chỉ nhận khoảng giờ người ta thật sự nói với nó; ngoài khoảng đó không đoán (không cộng 12 bừa).
        for text in ["5h trưa cơm 45k", "7h đêm 50k", "11h chiều 50k", "8h chiều 50k", "1h tối 90k", "12h tối 90k",
                     "12h sáng 20k", "19h sáng 20k", "20h chiều 50k", "14h tối 50k"] {
            XCTAssertNil(parse(text).minutesOfDay, text)
            XCTAssertNotNil(parse(text).amount, text)
        }
    }

    func testAfterMidnightPhrasingIsLeftAlone() {
        // "tối qua 1h" có thể là 1 giờ sáng nay: mơ hồ nên không đoán. Ngày vẫn là hôm qua, "1h" ở lại trong ghi chú.
        let r = parse("tối qua 1h taxi 100k")
        XCTAssertNil(r.minutesOfDay)
        XCTAssertEqual(day(r), "2026-09-24")
        XCTAssertEqual(r.note, "1h taxi")
    }

    // MARK: Không nói rõ là thời điểm → không phải giờ

    func testPeriodThatOpensADatePhraseDoesNotBelongToTheNumber() {
        // "sáng nay", "tối qua" là cụm ngày: "2h30" đứng ngay trước nó có thể là thời lượng, nên không phải giờ.
        let room = parse("thuê phòng trong 2h30 sáng nay 100k")
        XCTAssertNil(room.minutesOfDay)
        XCTAssertEqual(day(room), "2026-09-25", "\"sáng nay\" vẫn là ngày hôm nay")
        XCTAssertEqual(room.note, "thuê phòng trong 2h30", "Thời lượng ở lại trong ghi chú, cụm ngày bỏ như thường")
        XCTAssertEqual(room.amount, 100_000)

        // Về chữ, "7h tối qua" (giờ + ngày) giống "2h30 sáng nay" (thời lượng + ngày): không đoán. "tối qua 7h" thì rõ.
        let ambiguous = parse("7h tối qua grab 52k")
        XCTAssertNil(ambiguous.minutesOfDay)
        XCTAssertEqual(day(ambiguous), "2026-09-24")
        XCTAssertEqual(ambiguous.note, "7h grab")
        XCTAssertEqual(parse("tối qua 7h grab 52k").minutesOfDay, minutes(19))

        for text in ["thuê phòng 2h sáng nay 100k", "học 3h chiều qua 50k"] {
            XCTAssertNil(parse(text).minutesOfDay, text)
        }
    }

    func testPeriodInTheMiddleOfTheSentenceIsNotEvidence() {
        // Buổi nằm giữa câu là chữ của ghi chú ("ăn tối", "đèn sáng", "cà phê sáng"); con số cạnh nó có thể là thời lượng.
        let notes: [(String, String)] = [
            ("ăn tối 7h 80k", "ăn tối 7h"), ("ăn sáng 7h30 35k", "ăn sáng 7h30"),
            ("đèn sáng 20h giá 500k", "đèn sáng 20h giá"), ("cà phê sáng 7h 35k", "cà phê sáng 7h")
        ]
        for (text, note) in notes {
            let r = parse(text)
            XCTAssertNil(r.minutesOfDay, text)
            XCTAssertEqual(r.note, note, "Ghi chú giữ nguyên chữ của người dùng: \(text)")
            XCTAssertNotNil(r.amount, text)
        }
        XCTAssertEqual(parse("ăn tối 7h 80k").amount, 80_000)
    }

    func testClockStyleNeedsLuc() {
        // "1:20" có thể là tỷ lệ, thời lượng... Chỉ "lúc 7:30" mới là giờ; buổi cạnh nó không đủ.
        let ratio = parse("in bản đồ tỷ lệ 1:20 sáng nay 50k")
        XCTAssertNil(ratio.minutesOfDay)
        XCTAssertEqual(day(ratio), "2026-09-25", "\"sáng nay\" vẫn là ngày hôm nay")
        XCTAssertEqual(ratio.note, "in bản đồ tỷ lệ 1:20")
        for text in ["7:30 sáng cà phê 35k", "sáng 7:30 cà phê 35k", "7:30 phở 45", "0:30 xe 50k",
                     "thuê phòng trong 2:30 100k", "tỷ lệ 1:20 phí 50k"] {
            XCTAssertNil(parse(text).minutesOfDay, text)
            XCTAssertNotNil(parse(text).amount, text)
        }
        XCTAssertEqual(parse("tỷ lệ 1:20 phí 50k").note, "tỷ lệ 1:20 phí")
        XCTAssertEqual(parse("7:30 phở 45").amount, 45_000, "Câu cũ không đổi kết quả")
    }

    func testBareClockFormsAreNotATime() {
        // Dạng trần cũng là thời lượng ("thuê phòng 2h30", "pin dùng được 20h") hay số khác: giữ nguyên chữ của người dùng.
        let notes: [(String, String)] = [
            ("thuê phòng 2h30 100k", "thuê phòng 2h30"), ("thuê xe 1h15 80k", "thuê xe 1h15"),
            ("pin dùng được 20h giá 500k", "pin dùng được 20h giá"), ("0h30 xe 50k", "0h30 xe"),
            ("7 giờ 30 cà phê 35k", "7 giờ 30 cà phê"), ("19h30 grab 52k", "19h30 grab"), ("23h grab 90k", "23h grab")
        ]
        for (text, note) in notes {
            let r = parse(text)
            XCTAssertNil(r.minutesOfDay, text)
            XCTAssertEqual(r.note, note, "Ghi chú giữ nguyên chữ của người dùng: \(text)")
            XCTAssertNotNil(r.amount, text)
        }
        XCTAssertEqual(parse("thuê phòng 2h30 100k").amount, 100_000)
    }

    func testBareHoursAreNotATime() {
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
        // "7 giờ 30k" là 7 giờ và 30k, không phải 7:30.
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

    // MARK: Ngày và giờ đi cùng nhau

    func testRelativeDayPhrasesStillWork() {
        let a = parse("tối qua 7h grab 52k")
        XCTAssertEqual(a.minutesOfDay, minutes(19))
        XCTAssertEqual(day(a), "2026-09-24", "\"tối qua\" vẫn là hôm qua")
        XCTAssertEqual(a.note, "grab")

        let c = parse("lúc 23h30 hôm qua 50k")
        XCTAssertEqual(c.minutesOfDay, minutes(23, 30))
        XCTAssertEqual(day(c), "2026-09-24", "Giờ khuya vẫn thuộc đúng ngày đã nói")
        XCTAssertEqual(c.note, "")
    }

    func testRelativeDayPhrasesAloneHaveNoTime() {
        for text in ["tối qua nhậu 200k", "sáng nay cà phê 35k", "trưa nay cơm 45k", "chiều nay trà sữa 45k"] {
            XCTAssertNil(parse(text).minutesOfDay, text)
        }
        XCTAssertEqual(day(parse("tối qua nhậu 200k")), "2026-09-24")
    }

    func testPlainSentencesAreUnchanged() {
        for text in ["cà phê 35k", "lương +15tr", "xăng 1k5", "1tr2 tiền nhà", "12/9 cà phê 35k", "35.000 bánh mì",
                     "phở 45", "grab 52k hôm qua", "thu 2 cà phê 35k"] {
            XCTAssertNil(parse(text).minutesOfDay, text)
        }
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
        let withLead = parser.split("lúc 19h 35k cà phê 20k bánh", now: now)
        XCTAssertEqual(withLead.map(\.amount), [35_000, 20_000])
        XCTAssertEqual(withLead.map(\.note), ["cà phê", "bánh"], "Cụm giờ ở đầu câu không phải chữ đi trước số tiền")
        XCTAssertEqual(withLead.map(\.minutesOfDay), [minutes(19), minutes(19)])

        // Buổi mở đầu câu cũng là một phần của cụm giờ: không được tính là ghi chú đứng trước số tiền đầu tiên.
        let periodFirst = parser.split("sáng 7h 35k cà phê 20k bánh", now: now)
        XCTAssertEqual(periodFirst.map(\.amount), [35_000, 20_000])
        XCTAssertEqual(periodFirst.map(\.note), ["cà phê", "bánh"])
        XCTAssertEqual(periodFirst.map(\.minutesOfDay), [minutes(7), minutes(7)])

        let atTheEnd = parser.split("cà phê 35k bánh 20k 7h sáng", now: now)
        XCTAssertEqual(atTheEnd.map(\.minutesOfDay), [minutes(7), minutes(7)])
        XCTAssertEqual(atTheEnd.map(\.note), ["cà phê", "bánh"])
    }

    func testSingleAmountSplitReturnsTheWholeWithItsTime() {
        let parts = parser.split("cà phê 7h sáng 35k", now: now)
        XCTAssertEqual(parts.count, 1)
        XCTAssertEqual(parts.first?.minutesOfDay, minutes(7))
    }
}
