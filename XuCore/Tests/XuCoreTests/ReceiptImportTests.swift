import XCTest
@testable import XuCore

/// Đọc nhiều ảnh một lượt (docs/11); hạn mức tháng ở `MonthlyQuotaTests`. Chuỗi biên lai là dữ liệu giả.
final class ReceiptBatchTests: XCTestCase {
    private let month = MonthKey(year: 2026, month: 10)

    func testOutcomeFromText() {
        XCTAssertEqual(ReceiptBatch.outcome(forRecognizedText: nil), .failed)
        XCTAssertEqual(ReceiptBatch.outcome(forRecognizedText: "Tài khoản\n0123456789\nNgày 26/09/2026"), .noAmount)
        XCTAssertEqual(ReceiptBatch.outcome(forRecognizedText: "Chuyển tiền thành công\n-52.000 VND"),
                       .amount(52_000, isIncome: false, isAmbiguous: false))
        XCTAssertEqual(ReceiptBatch.outcome(forRecognizedText: "Biến động số dư\n+2.500.000 VND"),
                       .amount(2_500_000, isIncome: true, isAmbiguous: false), "Dấu + là tiền vào")
        XCTAssertEqual(ReceiptBatch.outcome(forRecognizedText: "Chuyển khoản\n2.000.000 VND\n3.000.000 VND"),
                       .amount(3_000_000, isIncome: false, isAmbiguous: true))
    }

    func testOnlyReadAmountsConsumeAQuotaSlotAndAmbiguousIsNotPreselected() {
        XCTAssertTrue(ReceiptReadOutcome.amount(1, isIncome: false, isAmbiguous: false).consumesQuota)
        XCTAssertTrue(ReceiptReadOutcome.amount(1, isIncome: false, isAmbiguous: true).consumesQuota)
        for other in [ReceiptReadOutcome.noAmount, .failed, .duplicate(of: 0), .skippedNoQuota] {
            XCTAssertFalse(other.consumesQuota)
            XCTAssertFalse(other.isPreselected)
        }
        XCTAssertTrue(ReceiptReadOutcome.amount(1, isIncome: false, isAmbiguous: false).isPreselected)
        XCTAssertFalse(ReceiptReadOutcome.amount(1, isIncome: false, isAmbiguous: true).isPreselected,
                       "Thẻ không chắc không tự chọn sẵn")
    }

    /// Ba ảnh khác nhau, mỗi ảnh có số tiền rõ.
    private func texts(_ count: Int) -> [String] {
        (1...max(count, 1)).map { "Số tiền\n\($0 * 10).000 VND" }
    }

    func testFreeStopsReadingWhenOutOfQuotaAndDoesNotReadTheRest() async {
        var quota = MonthlyQuota(month: month, used: 3)   // còn 2 lượt
        let images = texts(4)
        var recognized: [Int] = []
        let outcomes = await ReceiptBatch.run(
            count: 4, isPro: false, month: month, quota: &quota,
            fingerprint: { "ảnh \($0)" },
            recognize: { recognized.append($0); return images[$0] })
        XCTAssertEqual(outcomes, [.amount(10_000, isIncome: false, isAmbiguous: false),
                                  .amount(20_000, isIncome: false, isAmbiguous: false),
                                  .skippedNoQuota, .skippedNoQuota])
        XCTAssertEqual(recognized, [0, 1], "Ảnh hết lượt không được đọc")
        XCTAssertEqual(quota.used, 5)
    }

    func testFailuresNoAmountAndDuplicatesDoNotUseQuota() async {
        var quota = MonthlyQuota(month: month, used: 3)   // còn 2 lượt
        // 0: không mở được · 1: đọc xong không thấy số · 2: ảnh tốt · 3: trùng ảnh 2 · 4: ảnh tốt · 5: hết lượt
        let fingerprints: [String?] = [nil, "b", "c", "c", "e", "f"]
        let recognizedText: [Int: String] = [1: "Mã\n123456789", 2: "Số tiền\n30.000 VND", 4: "Số tiền\n50.000 VND", 5: "Số tiền\n60.000 VND"]
        var recognized: [Int] = []
        let outcomes = await ReceiptBatch.run(
            count: 6, isPro: false, month: month, quota: &quota,
            fingerprint: { fingerprints[$0] },
            recognize: { recognized.append($0); return recognizedText[$0] })
        XCTAssertEqual(outcomes, [.failed, .noAmount,
                                  .amount(30_000, isIncome: false, isAmbiguous: false),
                                  .duplicate(of: 2),
                                  .amount(50_000, isIncome: false, isAmbiguous: false),
                                  .skippedNoQuota])
        XCTAssertEqual(recognized, [1, 2, 4], "Ảnh lỗi, ảnh trùng và ảnh hết lượt không chạy bộ đọc")
        XCTAssertEqual(quota.used, 5, "Chỉ hai ảnh đọc ra số tiền bị trừ")
    }

    func testRecognizerFailureOnAnImageThatOpenedIsFailedAndFree() async {
        var quota = MonthlyQuota(month: month)
        let outcomes = await ReceiptBatch.run(count: 1, isPro: false, month: month, quota: &quota,
                                              fingerprint: { _ in "a" }, recognize: { _ in nil })
        XCTAssertEqual(outcomes, [.failed])
        XCTAssertEqual(quota.used, 0)
    }

    func testProReadsEverythingAndIsNotCounted() async {
        var quota = MonthlyQuota(month: month, used: 5)
        let images = texts(8)
        let outcomes = await ReceiptBatch.run(count: 8, isPro: true, month: month, quota: &quota,
                                              fingerprint: { "ảnh \($0)" }, recognize: { images[$0] })
        XCTAssertEqual(outcomes.count, 8)
        XCTAssertTrue(outcomes.allSatisfy(\.consumesQuota))
        XCTAssertEqual(quota.used, 5, "Xu Pro không bị đếm")
    }

    func testNewMonthRestoresTheAllowance() async {
        var quota = MonthlyQuota(month: MonthKey(year: 2026, month: 9), used: 5)
        let images = texts(2)
        let outcomes = await ReceiptBatch.run(count: 2, isPro: false, month: month, quota: &quota,
                                              fingerprint: { "ảnh \($0)" }, recognize: { images[$0] })
        XCTAssertEqual(outcomes.filter(\.consumesQuota).count, 2)
        XCTAssertEqual(quota.used(in: month), 2)
    }

    func testEmptyBatch() async {
        var quota = MonthlyQuota(month: month)
        let outcomes = await ReceiptBatch.run(count: 0, isPro: false, month: month, quota: &quota,
                                              fingerprint: { _ in "x" }, recognize: { _ in "x" })
        XCTAssertEqual(outcomes, [])
    }
}
