import XCTest
@testable import XuCore

/// Màn "Tháng này" (O4): tổng chi theo danh mục của một tháng, và giới hạn xem lại tháng cũ của bản Free.
final class MonthlySummaryTests: XCTestCase {
    private func entry(_ amount: Int64, _ category: String, _ day: String, income: Bool = false,
                       currency: Currency = .vnd) -> LedgerEntry {
        LedgerEntry(amount: amount, isIncome: income, categoryID: category, day: DayKey(day)!, currency: currency)
    }

    func testMonthKeyWrapsAcrossYears() {
        let september = MonthKey(year: 2026, month: 9)
        XCTAssertEqual(september.adding(months: 4), MonthKey(year: 2027, month: 1))
        XCTAssertEqual(september.adding(months: -9), MonthKey(year: 2025, month: 12))
        XCTAssertEqual(september.adding(months: -21), MonthKey(year: 2024, month: 12))
        XCTAssertEqual(MonthKey(DayKey("2026-09-25")!), september)
        XCTAssertTrue(MonthKey(year: 2025, month: 12) < september)
        XCTAssertTrue(september.contains(DayKey("2026-09-01")!))
        XCTAssertFalse(september.contains(DayKey("2025-09-30")!))
    }

    func testSpendingByCategoryInThatMonthOnly() {
        let entries = [
            entry(45_000, "food", "2026-09-01"),
            entry(35_000, "drinks", "2026-09-10"),
            entry(20_000, "food", "2026-09-25"),
            entry(99_000, "food", "2026-08-31"),               // tháng trước
            entry(15_000_000, "income.salary", "2026-09-05", income: true),
            entry(1_200, "food", "2026-09-12", currency: .jpy)  // tiền khác: chỉ vào tổng, không vào biểu đồ
        ]
        let summary = MonthlySummary.compute(entries: entries, month: MonthKey(year: 2026, month: 9), primary: .vnd)
        XCTAssertEqual(summary.spent, [.vnd: 100_000, .jpy: 1_200])
        XCTAssertEqual(summary.byCategory, [.init(categoryID: "food", amount: 65_000),
                                            .init(categoryID: "drinks", amount: 35_000)])
        XCTAssertFalse(summary.isEmpty)
    }

    func testPrimaryCurrencyDecidesTheChart() {
        let entries = [entry(35_000, "drinks", "2026-09-10"), entry(1_200, "food", "2026-09-12", currency: .jpy)]
        let japan = MonthlySummary.compute(entries: entries, month: MonthKey(year: 2026, month: 9), primary: .jpy)
        XCTAssertEqual(japan.byCategory, [.init(categoryID: "food", amount: 1_200)])
    }

    func testUnknownCategoryCountsAsOther() {
        let entries = [entry(10_000, "removed.category", "2026-09-01"),
                       entry(5_000, CategoryCatalog.otherExpenseID, "2026-09-02")]
        let summary = MonthlySummary.compute(entries: entries, month: MonthKey(year: 2026, month: 9), primary: .vnd)
        XCTAssertEqual(summary.byCategory, [.init(categoryID: CategoryCatalog.otherExpenseID, amount: 15_000)])
    }

    func testTiesAreStable() {
        let entries = [entry(10_000, "transport", "2026-09-01"), entry(10_000, "drinks", "2026-09-02")]
        let summary = MonthlySummary.compute(entries: entries, month: MonthKey(year: 2026, month: 9), primary: .vnd)
        XCTAssertEqual(summary.byCategory.map(\.categoryID), ["drinks", "transport"])
    }

    func testIncomeOnlyMonthIsEmpty() {
        let entries = [entry(15_000_000, "income.salary", "2026-09-05", income: true)]
        let summary = MonthlySummary.compute(entries: entries, month: MonthKey(year: 2026, month: 9), primary: .vnd)
        XCTAssertTrue(summary.isEmpty)
        XCTAssertTrue(summary.byCategory.isEmpty)
    }

    func testFreePlanSeesThisMonthOnly() {
        let current = MonthKey(year: 2026, month: 9)
        XCTAssertTrue(ProPlan.canViewMonth(current, current: current, isPro: false))
        XCTAssertFalse(ProPlan.canViewMonth(current.adding(months: -1), current: current, isPro: false))
        XCTAssertTrue(ProPlan.canViewMonth(current.adding(months: -1), current: current, isPro: true))
        XCTAssertTrue(ProPlan.canViewMonth(current.adding(months: -24), current: current, isPro: true))
    }
}
