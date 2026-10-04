import XCTest
@testable import XuCore

/// Khoản Apple Pay chờ ghi khi bản Free hết lượt (docs/02): giữ trên máy, không mất lặng lẽ.
final class PendingPaymentsTests: XCTestCase {
    private func payment(_ amount: Int64, merchant: String = "Highlands", at seconds: TimeInterval = 0) -> PendingPayment {
        PendingPayment(amount: amount, currencyCode: "VND", merchant: merchant, date: Date(timeIntervalSince1970: seconds))
    }

    func testAddsNewestFirstAndRemovesById() {
        var list = PendingPayments()
        XCTAssertTrue(list.isEmpty)
        let first = payment(45_000, at: 1)
        let second = payment(30_000, merchant: "Grab", at: 2)
        list.add(first)
        list.add(second)
        XCTAssertEqual(list.items.map(\.amount), [30_000, 45_000], "Mới nhất trước")
        XCTAssertEqual(list.count, 2)
        list.remove(id: first.id)
        XCTAssertEqual(list.items, [second])
        list.remove(id: UUID())
        XCTAssertEqual(list.count, 1, "Bỏ mã không có thì không đổi gì")
    }

    func testCapacityDropsTheOldestNotTheNewest() {
        var list = PendingPayments()
        for index in 0..<(PendingPayments.capacity + 5) { list.add(payment(Int64(index + 1), at: TimeInterval(index))) }
        XCTAssertEqual(list.count, PendingPayments.capacity)
        XCTAssertEqual(list.items.first?.amount, Int64(PendingPayments.capacity + 5), "Khoản mới nhất còn")
        XCTAssertEqual(list.items.last?.amount, 6, "Năm khoản cũ nhất đã rơi ra")
    }

    func testJSONRoundTripKeepsEverythingIncludingEmptyMerchant() {
        var list = PendingPayments()
        list.add(payment(45_000, at: 100))
        list.add(payment(1_200, merchant: "", at: 200))
        XCTAssertEqual(PendingPayments(jsonData: list.jsonData), list)
    }

    func testEmptyOrBrokenDataIsAnEmptyList() {
        XCTAssertTrue(PendingPayments(jsonData: Data()).isEmpty)
        XCTAssertTrue(PendingPayments(jsonData: Data("không phải JSON".utf8)).isEmpty)
        XCTAssertTrue(PendingPayments().jsonData.count > 0, "Danh sách trống vẫn mã hoá được")
    }

    func testInitTrimsToCapacity() {
        let many = (0..<(PendingPayments.capacity + 3)).map { payment(Int64($0 + 1), at: TimeInterval($0)) }
        XCTAssertEqual(PendingPayments(items: many).count, PendingPayments.capacity)
    }
}
