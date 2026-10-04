import XCTest
@testable import XuCore

/// Bộ đếm lượt dùng miễn phí theo tháng dương lịch (docs/02): đọc ảnh chuyển khoản và tự ghi Apple Pay, mỗi thứ 5 lượt.
final class MonthlyQuotaTests: XCTestCase {
    private let october = MonthKey(year: 2026, month: 10)
    private let november = MonthKey(year: 2026, month: 11)
    private let limit = ProPlan.freeApplePayLogsPerMonth

    func testLimitsAreFivePerMonthAsTheOwnerDecided() {
        XCTAssertEqual(ProPlan.freeReceiptReadsPerMonth, 5)
        XCTAssertEqual(ProPlan.freeApplePayLogsPerMonth, 5)
    }

    func testFreeGetsTheLimitThenStops() {
        var quota = MonthlyQuota(month: october)
        XCTAssertEqual(quota.remaining(limit: limit, isPro: false, in: october), 5)
        for expected in [4, 3, 2, 1, 0] {
            XCTAssertTrue(quota.canUse(limit: limit, isPro: false, in: october))
            quota.recordUse(in: october)
            XCTAssertEqual(quota.remaining(limit: limit, isPro: false, in: october), expected)
        }
        XCTAssertFalse(quota.canUse(limit: limit, isPro: false, in: october))
        XCTAssertEqual(quota.remaining(limit: limit, isPro: false, in: october), 0, "Không bao giờ âm")
    }

    func testResetsOnTheFirstOfTheNextMonth() {
        var quota = MonthlyQuota(month: october, used: 5)
        XCTAssertFalse(quota.canUse(limit: limit, isPro: false, in: october))
        XCTAssertEqual(quota.used(in: november), 0)
        XCTAssertEqual(quota.remaining(limit: limit, isPro: false, in: november), 5)
        XCTAssertTrue(quota.canUse(limit: limit, isPro: false, in: november))
        quota.recordUse(in: november)
        XCTAssertEqual(quota.used, 1, "Sang tháng mới thì đếm lại từ đầu")
        XCTAssertEqual(quota.remaining(limit: limit, isPro: false, in: november), 4)
        XCTAssertEqual(quota.used(in: october), 0, "Bộ đếm đã chuyển sang tháng 11: hỏi lại tháng cũ không còn lượt đã dùng")
    }

    func testDecemberRollsIntoJanuaryOfTheNextYear() {
        let december = MonthKey(year: 2026, month: 12)
        let january = MonthKey(year: 2027, month: 1)
        let quota = MonthlyQuota(month: december, used: 5)
        XCTAssertFalse(quota.canUse(limit: limit, isPro: false, in: december))
        XCTAssertTrue(quota.canUse(limit: limit, isPro: false, in: january))
    }

    func testProIsUnlimitedAndNeverBlocked() {
        let quota = MonthlyQuota(month: october, used: 99)
        XCTAssertNil(quota.remaining(limit: limit, isPro: true, in: october))
        XCTAssertTrue(quota.canUse(limit: limit, isPro: true, in: october))
    }

    func testTheLimitIsNotStoredSoChangingItNeedsNoMigration() throws {
        let quota = MonthlyQuota(month: october, used: 3)
        let json = String(decoding: try JSONEncoder().encode(quota), as: UTF8.self)
        XCTAssertFalse(json.contains("limit"), "Giới hạn do nơi gọi truyền vào, không lưu cùng bộ đếm")
        XCTAssertEqual(quota.remaining(limit: 5, isPro: false, in: october), 2)
        XCTAssertEqual(quota.remaining(limit: 10, isPro: false, in: october), 7, "Đổi giới hạn thì lượt còn lại đổi theo")
    }

    func testNegativeUsedIsClampedAndCodableRoundTrips() throws {
        XCTAssertEqual(MonthlyQuota(month: october, used: -3).used, 0)
        let quota = MonthlyQuota(month: october, used: 3)
        let decoded = try JSONDecoder().decode(MonthlyQuota.self, from: JSONEncoder().encode(quota))
        XCTAssertEqual(decoded, quota)
    }
}
