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

    func testRoundTripsThroughJSON() throws {
        var log = EntryTimingLog()
        log.record(2.25)
        let data = try JSONEncoder().encode(log)
        XCTAssertEqual(try JSONDecoder().decode(EntryTimingLog.self, from: data), log)
    }
}
