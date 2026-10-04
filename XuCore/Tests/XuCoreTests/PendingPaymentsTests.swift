import XCTest
@testable import XuCore

/// Khoản Apple Pay chờ ghi khi bản Free hết lượt (docs/02): giữ trên máy, không mất lặng lẽ, không đè nhau.
final class PendingPaymentsTests: XCTestCase {
    private func payment(_ amount: Int64, merchant: String = "Highlands", at seconds: TimeInterval = 0) -> PendingPayment {
        PendingPayment(amount: amount, currencyCode: "VND", merchant: merchant, date: Date(timeIntervalSince1970: seconds))
    }

    /// Như `AppSettings.addPendingPayment`: một khoản một khoá trong kho khoá/giá trị (`UserDefaults`).
    private func store(_ payment: PendingPayment, in values: inout [String: Any]) throws {
        values[payment.storageKey] = try payment.encoded()
    }

    func testListIsNewestFirstAndKeepsOneOfEachId() {
        let older = payment(45_000, at: 1)
        let newer = payment(30_000, merchant: "Grab", at: 2)
        let list = PendingPayments(items: [older, newer, older])
        XCTAssertEqual(list.items, [newer, older], "Mới nhất trước, trùng id chỉ giữ một")
        XCTAssertEqual(list.count, 2)
        XCTAssertTrue(PendingPayments().isEmpty)
    }

    func testSameInstantOrdersByIdSoTheOrderIsStable() {
        let first = payment(1_000, at: 5)
        let second = payment(2_000, at: 5)
        XCTAssertEqual(PendingPayments(items: [first, second]).items, PendingPayments(items: [second, first]).items)
    }

    func testPaymentRoundTripsThroughItsStoredData() throws {
        let original = payment(1_200, merchant: "", at: 200)   // người bán trống vẫn giữ nguyên
        XCTAssertEqual(PendingPayment(jsonData: try original.encoded()), original)
        XCTAssertTrue(original.storageKey.hasPrefix(PendingPayment.storageKeyPrefix))
        XCTAssertTrue(original.storageKey.hasSuffix(original.id.uuidString))
        XCTAssertNil(PendingPayment(jsonData: Data()))
        XCTAssertNil(PendingPayment(jsonData: Data("không phải JSON".utf8)))
    }

    func testListIsBuiltFromStoredValuesAndSkipsEverythingElse() throws {
        let first = payment(45_000, at: 1)
        let second = payment(30_000, merchant: "Grab", at: 2)
        var values: [String: Any] = ["appLanguage": "vi", "isPro": true]   // khoá khác của kho, không liên quan
        try store(first, in: &values)
        try store(second, in: &values)
        values[PendingPayment.storageKeyPrefix + UUID().uuidString] = Data("hỏng".utf8)
        values[PendingPayment.storageKeyPrefix + UUID().uuidString] = "không phải dữ liệu"
        // Dữ liệu đúng nhưng khoá không khớp `id` bên trong: bỏ qua, vì xoá theo `storageKey` của nó sẽ không trúng khoá này.
        values[PendingPayment.storageKeyPrefix + UUID().uuidString] = try payment(7_000, at: 3).encoded()
        values["khác." + first.storageKey] = try first.encoded()   // tiền tố khác
        XCTAssertEqual(PendingPayments(storedValues: values).items, [second, first], "Mục hỏng không làm mất khoản khác")
    }

    /// Tác vụ nền thêm khoản trong lúc danh sách trong app xoá khoản khác (docs/02, review Codex xu-ios#27): mỗi khoản một khoá nên bản đọc cũ
    /// của bên nào cũng không làm mất khoản bên kia vừa thêm, hay làm hiện lại khoản bên kia vừa xoá.
    func testAddingAndRemovingDifferentPaymentsNeverOverwriteEachOther() throws {
        let existing = payment(45_000, at: 1)
        let dismissedInApp = payment(10_000, at: 2)
        var values: [String: Any] = [:]
        try store(existing, in: &values)
        try store(dismissedInApp, in: &values)

        let staleSnapshot = PendingPayments(storedValues: values)   // danh sách trong app đọc lúc này và giữ bản đọc này
        let addedByIntent = payment(99_000, merchant: "Grab", at: 3)
        try store(addedByIntent, in: &values)                       // tác vụ nền thêm khoản mới

        let target = try XCTUnwrap(staleSnapshot.items.first { $0.id == dismissedInApp.id })
        values.removeValue(forKey: target.storageKey)               // danh sách xoá khoản của nó theo bản đọc cũ

        XCTAssertEqual(PendingPayments(storedValues: values).items, [addedByIntent, existing])
    }

    /// Khoản thứ 201 từng làm khoản cũ nhất rơi ra lặng lẽ (review Codex xu-ios#27): giờ không có giới hạn.
    func testThereIsNoLimitOnHowManyPaymentsAreKept() throws {
        var values: [String: Any] = [:]
        for index in 0..<1_000 { try store(payment(Int64(index + 1), at: TimeInterval(index)), in: &values) }
        let list = PendingPayments(storedValues: values)
        XCTAssertEqual(list.count, 1_000, "Không khoản nào bị bỏ lặng lẽ")
        XCTAssertEqual(list.items.first?.amount, 1_000, "Mới nhất trước")
        XCTAssertEqual(list.items.last?.amount, 1, "Khoản cũ nhất vẫn còn")
    }
}
