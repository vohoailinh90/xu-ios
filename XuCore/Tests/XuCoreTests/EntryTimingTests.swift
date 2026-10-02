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
    }

    func testRoundTripsThroughJSON() throws {
        var log = EntryTimingLog()
        log.record(2.25)
        let data = try JSONEncoder().encode(log)
        XCTAssertEqual(try JSONDecoder().decode(EntryTimingLog.self, from: data), log)
    }
}
