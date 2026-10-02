import XCTest
@testable import XuCore

final class ProPlanTests: XCTestCase {
    func testFreeCanAddUpToTwoHabits() {
        XCTAssertTrue(ProPlan.canAddHabit(activeHabits: 0, isPro: false))
        XCTAssertTrue(ProPlan.canAddHabit(activeHabits: 1, isPro: false))
        XCTAssertFalse(ProPlan.canAddHabit(activeHabits: 2, isPro: false))
        XCTAssertFalse(ProPlan.canAddHabit(activeHabits: 3, isPro: false), "Có sẵn nhiều hơn thì giữ, nhưng không thêm")
        XCTAssertTrue(ProPlan.canAddHabit(activeHabits: 5, isPro: true))
    }

    func testWidgetChips() {
        XCTAssertEqual(ProPlan.widgetChipLimit(isPro: false), 2)
        XCTAssertEqual(ProPlan.widgetChipLimit(isPro: true), 4)
    }
}
