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

final class ProInviteTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private let today = DayKey(year: 2026, month: 10, day: 8)

    private func days(_ offsets: ClosedRange<Int>) -> Set<DayKey> {
        Set(offsets.map { today.adding(days: -$0, calendar: calendar) })
    }

    func testDueTheDayAfterSevenDaysInARow() {
        XCTAssertTrue(ProInvite.isVisible(usedDays: days(1...7), today: today, shownOn: nil, dismissed: false,
                                          isPro: false, calendar: calendar))
        XCTAssertTrue(ProInvite.isVisible(usedDays: days(0...30), today: today, shownOn: nil, dismissed: false,
                                          isPro: false, calendar: calendar))
    }

    func testNotWhileLoggingTheSeventhDay() {
        // Hôm nay mới là ngày thứ 7: chưa mời, để thẻ không bật ra ngay sau khi lưu.
        XCTAssertFalse(ProInvite.isVisible(usedDays: days(0...6), today: today, shownOn: nil, dismissed: false,
                                           isPro: false, calendar: calendar))
    }

    func testGapMeansNoInvite() {
        var used = days(1...7)
        used.remove(today.adding(days: -4, calendar: calendar))
        XCTAssertFalse(ProInvite.isVisible(usedDays: used, today: today, shownOn: nil, dismissed: false,
                                           isPro: false, calendar: calendar))
    }

    func testOnlyOnce() {
        XCTAssertTrue(ProInvite.isVisible(usedDays: [], today: today, shownOn: today, dismissed: false,
                                          isPro: false, calendar: calendar), "Ở lại trong ngày đã hiện")
        XCTAssertFalse(ProInvite.isVisible(usedDays: days(1...7), today: today,
                                           shownOn: today.adding(days: -1, calendar: calendar), dismissed: false,
                                           isPro: false, calendar: calendar), "Sang ngày khác là thôi")
        XCTAssertFalse(ProInvite.isVisible(usedDays: days(1...7), today: today, shownOn: today, dismissed: true,
                                           isPro: false, calendar: calendar))
    }

    func testProNeverSeesItAndSkipsTheWork() {
        var evaluated = false
        func used() -> Set<DayKey> { evaluated = true; return days(1...7) }
        XCTAssertFalse(ProInvite.isVisible(usedDays: used(), today: today, shownOn: nil, dismissed: false,
                                           isPro: true, calendar: calendar))
        XCTAssertFalse(evaluated)
    }
}
