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

    private let vietnam = QuickEntryParser()
    private let japan = QuickEntryParser(options: .init(market: .japan))

    /// Kết quả phải như nhau dù ô nhập đang ở nơi chi tiêu nào.
    private func isNew(_ old: String, _ new: String, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let result = EntryTimingLog.startsNewSentence(from: old, to: new, parser: vietnam)
        XCTAssertEqual(result, EntryTimingLog.startsNewSentence(from: old, to: new, parser: japan),
                       "\(old) → \(new): Việt Nam và Nhật khác nhau", file: file, line: line)
        return result
    }

    func testNewSentenceDetection() {
        XCTAssertTrue(isNew("", "p"))
        XCTAssertFalse(isNew("phở 45k", ""))
        XCTAssertFalse(isNew("phở 45", "phở 45k"), "Gõ tiếp")
        XCTAssertFalse(isNew("phở 45k", "phở 50k"), "Sửa số tiền")
        XCTAssertFalse(isNew("phở 45k", "hở 45k"), "Xoá chữ đầu")
        XCTAssertTrue(isNew("phở 45k", "c"), "Chọn hết rồi gõ")
        XCTAssertTrue(isNew("phở 45k", "cà phê 35k"), "Dán câu khác")
        XCTAssertFalse(isNew("きのう", "昨日"), "Bộ gõ Nhật chuyển kana sang kanji")
        XCTAssertFalse(isNew("らーめん980", "ラーメン980"))
        XCTAssertTrue(isNew("", "ら"))
        XCTAssertTrue(isNew("ラーメン980", "cà phê 35k"), "Một bên không có chữ Nhật: không phải IME")
        XCTAssertTrue(isNew("phở 45k", "ラーメン980"))
        XCTAssertTrue(isNew("ラーメン980", "寿司1200"), "Hai câu tiếng Nhật khác nhau")
        XCTAssertFalse(isNew("r", "ら"), "Romaji đang soạn thành kana")
        XCTAssertTrue(isNew("でんしゃ980", "家賃1200"), "Số đổi thì không phải IME")
        XCTAssertFalse(isNew("でんしゃ980", "電車980"))
        XCTAssertFalse(isNew("せんえん", "千円"), "Vẫn là ¥1.000")
        XCTAssertTrue(isNew("やちん980", "家賃980万"), "Số tiền đổi từ ¥980 thành ¥9.800.000")
        XCTAssertTrue(isNew("でんしゃ980", "給料+980"), "Thêm dấu + là đổi thành thu")
        XCTAssertTrue(isNew("でんしゃ980", "電車980k"), "Thêm chữ Latin")
        XCTAssertTrue(isNew("やちん", "家賃千円"))
        XCTAssertFalse(isNew("やちん8まん", "家賃8万"))
        XCTAssertFalse(isNew("さんぜんえん", "三千円"))
        XCTAssertFalse(isNew("ひゃくえん", "百円"))
        XCTAssertFalse(isNew("らーめん980", "ラーメン９８０"), "Số đổi sang toàn khổ")
        XCTAssertFalse(isNew("昨日 らーめん980", "昨日 ラーメン980"))
        XCTAssertTrue(isNew("せんえん", "百円"), "¥1.000 thành ¥100")
        XCTAssertTrue(isNew("さんぜんえん", "五千円"))
        XCTAssertFalse(isNew("いちまんえん", "1万円"), "IME gợi ý số Ả Rập")
        XCTAssertFalse(isNew("ろっぴゃくえん", "六百円"))
        XCTAssertFalse(isNew("ぎゅうにく980", "牛肉980"))
        // Giới hạn đã biết: dán cụm chữ Hán khác cùng số tiền trông như IME chuyển đổi (xem chú thích của hàm).
        XCTAssertFalse(isNew("らーめん980", "寿司980"))
    }

    func testNoteReplacedMeansNewEntry() {
        XCTAssertTrue(isNew("phở 45k", "grab 45k"), "Chọn hết rồi dán khoản khác cùng số tiền")
        XCTAssertTrue(isNew("phở 45k hôm qua", "grab 45k hôm qua"))
        XCTAssertFalse(isNew("cơm gà 45k", "cơm vịt 45k"), "Sửa một từ")
        XCTAssertFalse(isNew("grba 45k", "grab 45k"), "Sửa lỗi gõ")
        XCTAssertFalse(isNew("strabucks 60k", "starbucks 60k"))
        XCTAssertTrue(isNew("bún 45k", "bánh 45k"))
        XCTAssertTrue(isNew("taxi 120k", "grab 120k"))
        XCTAssertFalse(isNew("cà phe 35k", "cà phê 35k"), "Sửa dấu")
        XCTAssertFalse(isNew("ca", "cá"), "Bộ gõ tiếng Việt thêm dấu")
        XCTAssertFalse(isNew("phở 45k", "phở bò 45k"), "Thêm từ")
        XCTAssertFalse(isNew("grab 45k", "grab 52k"), "Sửa số tiền")
        XCTAssertFalse(isNew("lương +15tr", "lương +16tr"))
    }

    func testRoundTripsThroughJSON() throws {
        var log = EntryTimingLog()
        log.record(2.25)
        let data = try JSONEncoder().encode(log)
        XCTAssertEqual(try JSONDecoder().decode(EntryTimingLog.self, from: data), log)
    }
}
