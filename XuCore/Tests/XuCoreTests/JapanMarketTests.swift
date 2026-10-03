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

    func testNumbersWrittenInKanji() {
        XCTAssertEqual(parse("千五百円 ランチ").amount, 1_500)
        XCTAssertEqual(parse("千五百円 ランチ").note, "ランチ")
        XCTAssertEqual(parse("一万二千円 服").amount, 12_000)
        XCTAssertEqual(parse("三百円 お茶").amount, 300)
        XCTAssertEqual(parse("二〇〇円 パン屋").amount, 200)
        XCTAssertEqual(parse("百円 ガム").amount, 100)
        XCTAssertNil(parse("万円").amount, "\"万\" đứng một mình không phải số")
        let greengrocer = parse("八百屋 500")
        XCTAssertEqual(greengrocer.amount, 500, "Chữ số Hán không kèm 円 không phải số tiền")
        XCTAssertEqual(greengrocer.categoryID, "groceries")
    }

    func testNumbersMixingDigitsAndKanji() {
        // Hoá đơn và bàn phím điện thoại hay trộn chữ số thường với chữ Hán: "1万五千円" = 15.000, không phải 1万 rồi 五千.
        let rent = parse("家賃 1万五千円")
        XCTAssertEqual(rent.amount, 15_000)
        XCTAssertEqual(rent.currency, .jpy)
        XCTAssertEqual(rent.note, "家賃", "円 bỏ cùng số tiền")
        XCTAssertEqual(parse("三万5千円 服").amount, 35_000)
        XCTAssertEqual(parse("三万5千円 服").note, "服")
        XCTAssertEqual(parse("2千五百円 ランチ").amount, 2_500)
        XCTAssertEqual(parse("1.5万三千円 旅行").amount, 18_000)
        XCTAssertEqual(parse("五万3千 円 服").amount, 53_000, "Có thể cách một dấu cách trước 円")
        let party = parse("5人で1万五千円")
        XCTAssertEqual(party.amount, 15_000, "Số người đứng trước không thành số tiền")
        XCTAssertEqual(party.note, "5人で")
        // Chữ số thường dính liền chữ số Hán không phải số hợp lệ: không đoán, và số thường không được đọc lại "1" trong đó.
        let invalid = parse("1五千円 ランチ")
        XCTAssertNil(invalid.amount, "Không đoán: không phải 1 yên, cũng không phải 5.000")
        XCTAssertEqual(invalid.note, "1五千円 ランチ", "Chữ ở lại trong ghi chú")
        let vietnam = QuickEntryParser(calendar: calendar).parse("1五千円 ランチ", now: now)
        XCTAssertNil(vietnam.amount, "Thị trường Việt Nam cũng không đọc thành 1.000đ")
        // Dạng cũ không đổi.
        XCTAssertEqual(parse("家賃 6万5千円").amount, 65_000)
        XCTAssertEqual(parse("1万500円").amount, 10_500)
        XCTAssertEqual(parse("一万二千円 服").amount, 12_000)
        XCTAssertEqual(parse("1万2 服").amount, 12_000)
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

    func testDatesWithJapaneseSystemCalendar() {
        // Máy đặt lịch Nhật (năm Reiwa): câu nhập vẫn là ngày Gregorian.
        var japanese = Calendar(identifier: .japanese)
        japanese.timeZone = calendar.timeZone
        let jp = QuickEntryParser(options: .init(market: .japan), calendar: japanese)
        XCTAssertEqual(day(jp.parse("2026/9/1 家賃 65000", now: now)), "2026-09-01")
        XCTAssertEqual(day(jp.parse("9月20日 スーパー 2480", now: now)), "2026-09-20")
        XCTAssertEqual(day(jp.parse("令和8年9月1日 家賃 65000", now: now)), "2026-09-01")
    }

    func testKanjiDates() {
        XCTAssertEqual(day(parse("9月20日 スーパー 2480")), "2026-09-20")
        XCTAssertEqual(day(parse("20日 スーパー 2480")), "2026-09-20")
        XCTAssertEqual(day(parse("28日 家賃 65000")), "2026-08-28", "Ngày chưa tới trong tháng → tháng trước")
        XCTAssertEqual(parse("9月20日 スーパー 2480").amount, 2_480)
        XCTAssertEqual(day(parse("3日間 定期券 5000")), "2026-09-25", "\"3日間\" là số ngày, không phải ngày")
        XCTAssertEqual(day(parse("20日のランチ 900")), "2026-09-20")
        XCTAssertEqual(parse("20日のランチ 900").note, "ランチ")
    }

    func testDayInsideCompoundWordIsNotADate() {
        let pass = parse("1日乗車券 500")
        XCTAssertEqual(day(pass), "2026-09-25", "1日乗車券 là vé đi trong ngày, không phải ngày 1")
        XCTAssertEqual(pass.amount, 500)
        XCTAssertEqual(pass.note, "1日乗車券")
        XCTAssertEqual(pass.categoryID, "transport")
        let hangover = parse("2日酔い 薬 500")
        XCTAssertEqual(day(hangover), "2026-09-25")
        XCTAssertEqual(hangover.categoryID, "health")
        XCTAssertEqual(day(parse("2日目 ホテル 8000")), "2026-09-25")
    }

    func testDayFollowedByTimeOfDayOrParticle() {
        let morning = parse("20日朝 コンビニ 500円")
        XCTAssertEqual(day(morning), "2026-09-20")
        XCTAssertEqual(morning.amount, 500)
        XCTAssertEqual(day(parse("20日午後 ランチ 900円")), "2026-09-20")
        XCTAssertEqual(day(parse("20日夜 居酒屋 3000")), "2026-09-20")
        let trip = parse("20日から 旅行 5000円")
        XCTAssertEqual(day(trip), "2026-09-20")
        XCTAssertEqual(trip.note, "旅行", "から đứng riêng sau ngày thì bỏ khỏi ghi chú")
        XCTAssertEqual(trip.categoryID, "entertainment")
        XCTAssertEqual(day(parse("20日から旅行 5000円")), "2026-09-20")
    }

    func testParticleThatStartsAWordIsKept() {
        let karaage = parse("昨日から揚げ 500円")
        XCTAssertEqual(day(karaage), "2026-09-24")
        XCTAssertEqual(karaage.note, "から揚げ", "から揚げ là tên món, không được cắt mất から")
        XCTAssertEqual(karaage.categoryID, "food")
    }

    func testDurationIsNotADate() {
        let rental = parse("レンタカー最長3日まで5000円")
        XCTAssertEqual(day(rental), "2026-09-25", "最長3日まで là tối đa 3 ngày, không phải ngày 3")
        XCTAssertEqual(rental.amount, 5_000)
        XCTAssertEqual(rental.note, "レンタカー最長3日まで")
        XCTAssertEqual(rental.categoryID, "transport")

        let threeDays = parse("レンタカー3日で5000円")
        XCTAssertEqual(day(threeDays), "2026-09-25", "3日で là 3 ngày, không phải ngày 3")
        XCTAssertEqual(threeDays.amount, 5_000)
        XCTAssertEqual(threeDays.note, "レンタカー3日で")
        let perDay = parse("駐車場1日につき500円")
        XCTAssertEqual(day(perDay), "2026-09-25", "1日につき là mỗi ngày")
        XCTAssertEqual(perDay.amount, 500)
        XCTAssertEqual(perDay.note, "駐車場1日につき")
        XCTAssertEqual(perDay.categoryID, "transport")

        let hotel = parse("ホテル3泊4日 20000円")
        XCTAssertEqual(day(hotel), "2026-09-25", "3泊4日 là 3 đêm 4 ngày, không phải ngày 4")
        XCTAssertEqual(hotel.amount, 20_000)
        XCTAssertEqual(hotel.note, "ホテル3泊4日")
        XCTAssertEqual(hotel.categoryID, "entertainment")
        let spaced = parse("ホテル 3泊 4日 20000円")
        XCTAssertEqual(day(spaced), "2026-09-25", "3泊 4日 có khoảng trắng vẫn là thời lượng")
        XCTAssertEqual(spaced.note, "ホテル 3泊 4日")
        XCTAssertEqual(day(parse("ランチ (20日) 900")), "2026-09-20", "Ngày trong ngoặc vẫn đứng riêng")
    }

    func testWeekdayInParentheses() {
        let r = parse("9/23(水) ランチ 900")
        XCTAssertEqual(day(r), "2026-09-23")
        XCTAssertEqual(r.note, "ランチ", "Thứ trong ngoặc sau ngày cũng bỏ khỏi ghi chú")
        XCTAssertEqual(parse("9/23 (水曜日) ランチ 900").note, "ランチ")
        XCTAssertEqual(day(parse("(月) ランチ 900")), "2026-09-21")
        XCTAssertEqual(day(parse("（月） ランチ 900")), "2026-09-21", "Ngoặc toàn khổ")
        XCTAssertEqual(parse("（月） ランチ 900").note, "ランチ")
    }

    func testReiwaYear() {
        XCTAssertEqual(day(parse("令和8年9月1日 家賃 65000")), "2026-09-01")
        XCTAssertEqual(day(parse("令和元年5月1日 家賃 65000")), "2019-05-01")
        XCTAssertEqual(parse("令和8年9月1日 家賃 65000").note, "家賃")
    }

    func testReiwaYearAbbreviatedLikeAReceipt() {
        // Hoá đơn in ngày kiểu "R8.9.20" (R = 令和; 令和元年 = 2019). Hôm nay là 25/09/2026.
        let r = parse("R8.9.20 ランチ 900")
        XCTAssertEqual(day(r), "2026-09-20")
        XCTAssertEqual(r.note, "ランチ", "Ngày bỏ khỏi ghi chú")
        XCTAssertEqual(r.amount, 900, "8.9 và 20 trong ngày không thành số tiền")
        XCTAssertEqual(day(parse("R08.09.01 ランチ 900")), "2026-09-01")
        XCTAssertEqual(day(parse("R8/9/20 ランチ 900")), "2026-09-20")
        XCTAssertEqual(day(parse("r8.9.20 ランチ 900")), "2026-09-20")
        XCTAssertEqual(day(parse("R1.5.1 ランチ 900")), "2019-05-01")
        XCTAssertEqual(day(parse("Ｒ８．９．２０ ランチ 900")), "2026-09-20", "Chữ toàn khổ của bàn phím Nhật")
        XCTAssertEqual(parse("ランチ 900 R8.9.20").note, "ランチ")
        // Ngày sau hôm nay (biên lai không có) hay không hợp lệ thì không phải ngày: chữ ở lại trong ghi chú.
        for text in ["R8.9.30 ランチ 900", "R8.13.20 ランチ 900", "R0.9.20 ランチ 900"] {
            let r = parse(text)
            XCTAssertEqual(day(r), "2026-09-25", text)
            XCTAssertTrue(r.note.hasPrefix("R"), "Ghi chú giữ nguyên chữ của người dùng: \(text)")
            XCTAssertEqual(r.amount, 900, text)
        }
        // Thời Reiwa bắt đầu từ 01/05/2019: ngày trước đó không phải ngày.
        for text in ["R1.1.1 ランチ 900", "R1.4.30 ランチ 900"] {
            XCTAssertEqual(day(parse(text)), "2026-09-25", text)
            XCTAssertTrue(parse(text).note.hasPrefix("R1"), text)
        }
        XCTAssertEqual(day(parse("R1.5.1 ランチ 900")), "2019-05-01")
        // Token đầu không hợp lệ thì xét tiếp token sau: ngày thật vẫn được nhận.
        let twoTokens = parse("R8.13.20 R8.9.20 ランチ 900")
        XCTAssertEqual(day(twoTokens), "2026-09-20")
        XCTAssertEqual(twoTokens.note, "R8.13.20 ランチ")
        XCTAssertEqual(day(parse("R8.9.30 R8.9.20 ランチ 900")), "2026-09-20", "Ngày tương lai đứng trước một ngày thật")
        // Mọi token "R…" đều không phải tiền, dù chỉ token hợp lệ đầu tiên được dùng làm ngày.
        XCTAssertEqual(parse("R8.13.20 R8.9.20 ガム 5").amount, 5, "Không phải 13 yên")
        XCTAssertEqual(parse("R8.9.20 R8.9.21 ガム 5").amount, 5, "Không phải 9 yên")
        XCTAssertEqual(parse("R8.9.30 ガム 5").amount, 5, "Token ở tương lai cũng không phải tiền")
        XCTAssertEqual(parse("R8.9.30 ガム 5").note, "R8.9.30 ガム")
        // Token sai độ dài (OCR, gõ nhầm: "R8.9.200", "R8.9.20.5") không phải ngày và cũng không bị che: che theo hình dạng rộng hơn từng nuốt
        // mất giá của một mã hàng ("R2-3-9,000円"). Giới hạn đã biết, ghi ở docs/04.
        XCTAssertEqual(day(parse("R8.9.200 ガム 5")), "2026-09-25", "Token sai độ dài không phải ngày")
        XCTAssertEqual(day(parse("R8.9.20.5 ガム 5")), "2026-09-25")
        // Chỉ hai nhóm số ("R2-900円": mã hàng kèm giá) không phải token ngày: số tiền giữ nguyên như trước.
        XCTAssertEqual(parse("R2-900円").amount, 900)
        XCTAssertEqual(parse("R2-900円 ガム 5").amount, 900, "Số có 円 vẫn thắng số trần")
        XCTAssertEqual(day(parse("R2-900円 ガム 5")), "2026-09-25", "Hai nhóm số không phải ngày")
        // Ba nhóm số mà nhóm cuối có đơn vị tiền ngay sau ("R2-3-900円": mã hàng kèm giá) là giá, không phải ngày hoá đơn sai độ dài.
        XCTAssertEqual(parse("R2-3-900円").amount, 900)
        XCTAssertEqual(parse("R2-3-900円 ガム 5").amount, 900)
        XCTAssertEqual(parse("R2-3-900 円 ガム 5").amount, 900, "Cách một dấu cách trước 円")
        XCTAssertEqual(QuickEntryParser(calendar: calendar).parse("R2-3-900k", now: now).amount, 900_000)
        // Nhóm cuối vừa là ngày hợp lệ (1–31) vừa có đơn vị tiền ngay sau: vẫn là giá, không phải 09/03/2020.
        let nine = parse("R2-3-9円")
        XCTAssertEqual(nine.amount, 9)
        XCTAssertEqual(day(nine), "2026-09-25")
        // Đơn vị chữ Hán của số kiểu Nhật (万/千/百) cũng là dấu hiệu tiền: "R2-3-9万円" là 90.000 yên, "R2-3-9千円" là 9.000 yên.
        XCTAssertEqual(parse("R2-3-9万円").amount, 90_000)
        XCTAssertEqual(parse("R2-3-9千円").amount, 9_000)
        XCTAssertEqual(day(parse("R2-3-9万円")), "2026-09-25")
        // "man"/"sen" chỉ là đơn vị ở thị trường Nhật: ở Việt Nam "mận", "sen" (đã gấp dấu thành "man", "sen") là một từ, không phải lý do để bỏ ngày.
        let plum = QuickEntryParser(calendar: calendar).parse("R8.9.20 mận 900", now: now)
        XCTAssertEqual(DayKey(plum.date, calendar: calendar).description, "2026-09-20")
        XCTAssertEqual(plum.amount, 900_000)
        XCTAssertEqual(plum.note, "mận")
        // Ở thị trường Nhật "9 man" là 9 vạn yên: đơn vị, nên "R2-3-9 man" là giá, không phải ngày.
        XCTAssertEqual(parse("R2-3-9 man").amount, 90_000)
        XCTAssertEqual(day(parse("R2-3-9 man")), "2026-09-25")
        // Hai khoảng trắng: `amountRegex` không gắn đơn vị vào số (chỉ một khoảng trắng), nên token cũng không coi là có đơn vị; hai bước dùng cùng quy tắc.
        // Quan trọng là không bao giờ ra "9 yên" im lặng (token bị loại khỏi ngày mà số tiền vẫn đọc thiếu đơn vị).
        XCTAssertNotEqual(parse("R2-3-9  man").amount, 9)
        // Chữ Latin dính ngay sau đơn vị thì `amountRegex` không gắn đơn vị vào số: token cũng không coi là có đơn vị (cùng ranh giới), không ra 9.000đ.
        let candy = QuickEntryParser(calendar: calendar).parse("R2-3-9円candy", now: now)
        XCTAssertEqual(DayKey(candy.date, calendar: calendar).description, "2020-03-09")
        XCTAssertNil(candy.amount, "Không phải 9.000đ")
        // Số trộn nối tiếp sau 十: "9十五円" = 95 yên, "9十万円" = 900.000 yên (cùng ngữ pháp với nhánh số trộn của `kanjiAmountRegex`), không phải ngày.
        XCTAssertEqual(parse("R2-3-9十五円").amount, 95)
        XCTAssertEqual(parse("R2-3-9十万円").amount, 900_000)
        XCTAssertEqual(parse("R2-3-9万五千円").amount, 95_000)
        XCTAssertEqual(day(parse("R2-3-9十五円")), "2026-09-25")
        // Đơn vị chữ Hán cũng theo ranh giới của `kanjiAmountRegex`: "9万candy" không đọc được "9万" nên không coi là có đơn vị; dạng `.` thì luôn là ngày.
        let manCandy = parse("R2-3-9万candy")
        XCTAssertEqual(day(manCandy), "2020-03-09")
        XCTAssertNil(manCandy.amount, "Không phải 9 yên")
        XCTAssertEqual(parse("R2-3-9千葉").amount, 9_000, "9千 đọc được (葉 không phải chữ Latin): vẫn là giá")
        let chibaTight = parse("R8.9.20千葉 電車 900")
        XCTAssertEqual(day(chibaTight), "2026-09-20")
        XCTAssertEqual(chibaTight.amount, 900)
        XCTAssertEqual(chibaTight.note, "千葉 電車")
        // Hậu tố thập phân viết tắt ("1tr2", "1k5") là một phần của giá.
        let vietnam = QuickEntryParser(calendar: calendar)
        XCTAssertEqual(vietnam.parse("R2-3-1tr2", now: now).amount, 1_200_000)
        XCTAssertEqual(vietnam.parse("R2-3-1k5", now: now).amount, 1_500)
        // Phần còn lại của giá dùng cú pháp tiền của parser (dấu nhóm, thập phân, số sau đơn vị Hán): dính liền token thì không phải ngày.
        XCTAssertEqual(parse("R2-3-9,000円").amount, 9_000)
        XCTAssertEqual(day(parse("R2-3-9,000円")), "2026-09-25")
        XCTAssertEqual(parse("R2-3-9万5000円").amount, 95_000)
        XCTAssertEqual(vietnam.parse("R2-3-1,5tr", now: now).amount, 1_500_000)
        // Dấu câu không dính chữ số vẫn kết thúc token, kể cả dấu Unicode.
        XCTAssertEqual(day(parse("R8.9.20, ランチ 900")), "2026-09-20")
        XCTAssertEqual(day(parse("ランチ 900 (R8.9.20)")), "2026-09-20")
        XCTAssertEqual(day(parse("R8.9.20！ ランチ 900")), "2026-09-20")
        XCTAssertEqual(day(parse("（R8.9.20） ランチ 900")), "2026-09-20")
        // Chữ Nhật đứng sát token vẫn là ranh giới (người dùng Nhật ghi nhanh không chèn khoảng trắng).
        let tight = parse("R8.9.20ランチ 900")
        XCTAssertEqual(day(tight), "2026-09-20")
        XCTAssertEqual(tight.note, "ランチ")
        XCTAssertEqual(tight.amount, 900)
        // Mọi chữ Nhật đứng sát token đều là ranh giới, kể cả "〆" "々" mà Unicode xếp vào script Common.
        XCTAssertEqual(day(parse("R8.9.20〆鯖 900")), "2026-09-20")
        XCTAssertEqual(day(parse("R8.9.20々 900")), "2026-09-20")
        // Chữ Hán của số tiền cách khoảng trắng là chữ đầu của một từ ("千葉", "円山公園"), không phải đơn vị: vẫn là ngày, giá giữ nguyên.
        let chiba = parse("R8.9.20 千葉 電車 900")
        XCTAssertEqual(day(chiba), "2026-09-20")
        XCTAssertEqual(chiba.amount, 900)
        XCTAssertEqual(chiba.note, "千葉 電車")
        let maruyama = parse("R8.9.20 円山公園 900")
        XCTAssertEqual(day(maruyama), "2026-09-20", "Có khoảng trắng: 円山公園 là tên")
        XCTAssertEqual(maruyama.amount, 900, "Không phải 9 yên")
        XCTAssertEqual(maruyama.note, "円山公園")
        // Dấu phân cách trước nhóm cuối quyết định cách đọc: chỉ với gạch ngang `-` thì `amountRegex` mới đọc được nhóm cuối làm giá, nên chỉ khi đó
        // 円 liền sát token mới là đơn vị ("R2-3-9円菓子" là giá 9 yên + ghi chú). Dạng `.` và `/` là cách in ngày hoá đơn quen thuộc: vẫn là ngày,
        // và "R8.9.20円山公園 900" là ngày 20/09 + 900 yên.
        let sweets = parse("R2-3-9円菓子")
        XCTAssertEqual(sweets.amount, 9)
        XCTAssertEqual(day(sweets), "2026-09-25")
        XCTAssertEqual(sweets.note, "R2-3-菓子", "Chỉ số tiền 9円 bị bỏ khỏi ghi chú")
        let adjacent = parse("R8.9.20円山公園 900")
        XCTAssertEqual(day(adjacent), "2026-09-20")
        XCTAssertEqual(adjacent.amount, 900, "Không phải 9 yên")
        // Với `.` hay `/` mà nhóm cuối có 円, `amountRegex` không đọc được nhóm cuối làm giá ("3.9円" là số thập phân 3,9; sau `/` không bắt đầu được
        // số tiền): coi là ngày, không bao giờ ra 4 yên hay 3.900 yên im lặng.
        for text in ["R2.3.9円", "R2/3/9円"] {
            let r = parse(text)
            XCTAssertEqual(day(r), "2020-03-09", text)
            XCTAssertNil(r.amount, "Không phải 4 yên: \(text)")
        }
        // Nhưng chữ Hán của số tiền sát token thì không: "R2-3-9万5000円" và "R2-3-9十円" là giá.
        XCTAssertEqual(day(parse("R2-3-9十円")), "2026-09-25")
        XCTAssertEqual(parse("R2-3-9十円").amount, 90)
        // Chữ Latin hay dấu nối dính liền không phải ranh giới.
        XCTAssertEqual(day(parse("R8.9.20abc ランチ 900")), "2026-09-25")
        XCTAssertEqual(day(parse("R2-3-9-4 ランチ 900")), "2026-09-25")
        // "R" phải đứng riêng: không đọc giữa một từ.
        XCTAssertEqual(day(parse("CAR8.9.20 ランチ 900")), "2026-09-25")
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
