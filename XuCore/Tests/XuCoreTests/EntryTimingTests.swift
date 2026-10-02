import XCTest
@testable import XuCore

final class EntryTimingTests: XCTestCase {
    func testMedianOddAndEven() {
        XCTAssertNil(EntryTimingLog().median)
        XCTAssertEqual(EntryTimingLog(samples: [3, 1, 2]).median, 2)
        XCTAssertEqual(EntryTimingLog(samples: [4, 1, 2, 3]).median, 2.5)
    }

    func testIgnoresAbandonedAndInvalidEntries() {
        var log = EntryTimingLog()
        log.record(1.8)
        log.record(0)
        log.record(-2)
        log.record(EntryTimingLog.abandonedAfter + 1)
        XCTAssertEqual(log.samples, [1.8])
    }

    func testKeepsOnlyTheNewest() {
        var log = EntryTimingLog()
        for i in 1...(EntryTimingLog.capacity + 5) { log.record(Double(i % 50) + 0.5) }
        XCTAssertEqual(log.count, EntryTimingLog.capacity)
        XCTAssertEqual(log.samples.last, Double((EntryTimingLog.capacity + 5) % 50) + 0.5)
    }

    func testUndoRemovesItsSample() {
        var log = EntryTimingLog()
        log.record(1.5)
        let saved = log.record(2.25)
        XCTAssertEqual(saved, 2.25)
        XCTAssertNil(log.record(120), "Bỏ dở thì không lưu, không có gì để xoá")
        log.remove(2.25)
        XCTAssertEqual(log.samples, [1.5])
    }

    func testNewSentenceDetection() {
        XCTAssertTrue(EntryTimingLog.startsNewSentence(from: "", to: "p"))
        XCTAssertFalse(EntryTimingLog.startsNewSentence(from: "phở 45k", to: ""))
        XCTAssertFalse(EntryTimingLog.startsNewSentence(from: "phở 45", to: "phở 45k"), "Gõ tiếp")
        XCTAssertFalse(EntryTimingLog.startsNewSentence(from: "phở 45k", to: "phở 50k"), "Sửa số tiền")
        XCTAssertFalse(EntryTimingLog.startsNewSentence(from: "phở 45k", to: "hở 45k"), "Xoá chữ đầu")
        XCTAssertTrue(EntryTimingLog.startsNewSentence(from: "phở 45k", to: "c"), "Chọn hết rồi gõ")
        XCTAssertTrue(EntryTimingLog.startsNewSentence(from: "phở 45k", to: "cà phê 35k"), "Dán câu khác")
        XCTAssertFalse(EntryTimingLog.startsNewSentence(from: "きのう", to: "昨日"), "Bộ gõ Nhật chuyển kana sang kanji")
        XCTAssertFalse(EntryTimingLog.startsNewSentence(from: "らーめん980", to: "ラーメン980"))
        XCTAssertTrue(EntryTimingLog.startsNewSentence(from: "", to: "ら"))
        XCTAssertTrue(EntryTimingLog.startsNewSentence(from: "ラーメン980", to: "cà phê 35k"), "Một bên không có chữ Nhật: không phải IME")
        XCTAssertTrue(EntryTimingLog.startsNewSentence(from: "phở 45k", to: "ラーメン980"))
        XCTAssertTrue(EntryTimingLog.startsNewSentence(from: "ラーメン980", to: "寿司1200"), "Hai câu tiếng Nhật khác nhau")
        XCTAssertFalse(EntryTimingLog.startsNewSentence(from: "r", to: "ら"), "Romaji đang soạn thành kana")
        XCTAssertTrue(EntryTimingLog.startsNewSentence(from: "でんしゃ980", to: "家賃1200"), "Số đổi thì không phải IME")
        XCTAssertFalse(EntryTimingLog.startsNewSentence(from: "でんしゃ980", to: "電車980"))
        XCTAssertFalse(EntryTimingLog.startsNewSentence(from: "せんえん", to: "千円"), "Số chữ Hán không tính là đổi số")
        XCTAssertTrue(EntryTimingLog.startsNewSentence(from: "やちん980", to: "家賃980万"), "万 không có cách đọc trong câu cũ")
        XCTAssertTrue(EntryTimingLog.startsNewSentence(from: "でんしゃ980", to: "給料+980"), "Thêm dấu + là đổi thành thu")
        XCTAssertTrue(EntryTimingLog.startsNewSentence(from: "でんしゃ980", to: "電車980k"), "Thêm chữ Latin")
        XCTAssertTrue(EntryTimingLog.startsNewSentence(from: "やちん", to: "家賃千円"))
        XCTAssertFalse(EntryTimingLog.startsNewSentence(from: "やちん8まん", to: "家賃8万"))
        XCTAssertFalse(EntryTimingLog.startsNewSentence(from: "さんぜんえん", to: "三千円"))
        XCTAssertFalse(EntryTimingLog.startsNewSentence(from: "ひゃくえん", to: "百円"))
        XCTAssertFalse(EntryTimingLog.startsNewSentence(from: "らーめん980", to: "ラーメン９８０"), "Số đổi sang toàn khổ")
        XCTAssertFalse(EntryTimingLog.startsNewSentence(from: "昨日 らーめん980", to: "昨日 ラーメン980"))
    }

    func testRoundTripsThroughJSON() throws {
        var log = EntryTimingLog()
        log.record(2.25)
        let data = try JSONEncoder().encode(log)
        XCTAssertEqual(try JSONDecoder().decode(EntryTimingLog.self, from: data), log)
    }
}
