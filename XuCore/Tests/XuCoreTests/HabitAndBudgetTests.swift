import XCTest
@testable import XuCore

final class HabitAndBudgetTests: XCTestCase {
    var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        return cal
    }()
    let today = DayKey(year: 2026, month: 9, day: 25)

    private func daysAgo(_ offsets: [Int]) -> Set<DayKey> {
        Set(offsets.map { today.adding(days: -$0, calendar: calendar) })
    }

    // MARK: DayKey

    func testDayKeyArithmeticAcrossMonths() {
        XCTAssertEqual(DayKey(year: 2026, month: 9, day: 30).adding(days: 1, calendar: calendar).description, "2026-10-01")
        XCTAssertEqual(DayKey(year: 2026, month: 3, day: 1).adding(days: -1, calendar: calendar).description, "2026-02-28")
    }

    // MARK: Điểm sức mạnh

    func testStrengthGrowsAndDecaysGently() {
        let start = today.adding(days: -29, calendar: calendar)
        let all = daysAgo(Array(0...29))
        let perfect = HabitEngine.strength(completed: all, from: start, through: today, calendar: calendar)
        XCTAssertGreaterThan(perfect, 0.75)

        var missedYesterday = all
        missedYesterday.remove(today.adding(days: -1, calendar: calendar))
        let oneMiss = HabitEngine.strength(completed: missedYesterday, from: start, through: today, calendar: calendar)
        XCTAssertLessThan(oneMiss, perfect)
        XCTAssertGreaterThan(oneMiss, perfect * 0.9, "Lỡ một ngày chỉ giảm nhẹ, không reset")
    }

    func testRestDaysDoNotHurt() {
        let start = today.adding(days: -9, calendar: calendar)
        let rest = daysAgo([3, 4])
        let done = daysAgo([0, 1, 2, 5, 6, 7, 8, 9])
        let withRest = HabitEngine.strength(completed: done, restDays: rest, from: start, through: today, calendar: calendar)
        let eightPerfect = HabitEngine.strength(completed: daysAgo(Array(0...7)),
                                                from: today.adding(days: -7, calendar: calendar),
                                                through: today, calendar: calendar)
        XCTAssertEqual(withRest, eightPerfect, accuracy: 1e-9)
    }

    // MARK: Chuỗi mềm

    func testStreakCountsFromYesterdayIfTodayNotDone() {
        XCTAssertEqual(HabitEngine.softStreak(completed: daysAgo([1, 2, 3]), today: today, calendar: calendar), 3)
    }

    func testOneMissIsForgivenPerWeek() {
        XCTAssertEqual(HabitEngine.softStreak(completed: daysAgo([0, 1, 3, 4]), today: today, calendar: calendar), 4)
    }

    func testTwoMissesInAWeekEndStreak() {
        XCTAssertEqual(HabitEngine.softStreak(completed: daysAgo([0, 1, 4, 5]), today: today, calendar: calendar), 2)
    }

    func testMissesFarApartAreBothForgiven() {
        let done = daysAgo(Array(0...12).filter { $0 != 2 && $0 != 10 })
        XCTAssertEqual(HabitEngine.softStreak(completed: done, today: today, calendar: calendar), 11)
    }

    func testRestDaysKeepStreak() {
        XCTAssertEqual(HabitEngine.softStreak(completed: daysAgo([0, 3]), restDays: daysAgo([1, 2]),
                                              today: today, calendar: calendar), 2)
    }

    // MARK: Thói quen mẫu

    func testNoSpendDayRequiresClosedDay() {
        let coffee = LedgerEntry(amount: 35_000, isIncome: false, categoryID: "drinks", day: today)
        let rice = LedgerEntry(amount: 40_000, isIncome: false, categoryID: "food", day: today)

        XCTAssertNil(HabitTemplate.noSpendDay.evaluate(entries: [], dayClosed: false))
        XCTAssertEqual(HabitTemplate.noSpendDay.evaluate(entries: [rice], dayClosed: true), true)
        XCTAssertEqual(HabitTemplate.noSpendDay.evaluate(entries: [rice, coffee], dayClosed: true), false)
        XCTAssertEqual(HabitTemplate.noBubbleTea.evaluate(entries: [coffee], dayClosed: true), false)
    }

    func testLogDaily() {
        XCTAssertEqual(HabitTemplate.logDaily.evaluate(entries: [], dayClosed: false), false)
        XCTAssertEqual(HabitTemplate.logDaily.evaluate(entries: [], dayClosed: true), true)
        XCTAssertNil(HabitTemplate.cookAtHome.evaluate(entries: [], dayClosed: true))
    }

    // MARK: Còn được tiêu

    func testSafeToSpend() {
        // Ngân sách 6tr, đã tiêu 3tr trước hôm nay, còn 6 ngày (25→30/9)
        let end = SafeToSpend.endOfMonth(containing: today, calendar: calendar)
        XCTAssertEqual(end.description, "2026-09-30")

        let s = SafeToSpend.compute(flexibleBudget: 6_000_000, spentBeforeToday: 3_000_000,
                                    spentToday: 100_000, today: today, periodEnd: end, calendar: calendar)
        XCTAssertEqual(s.daysLeft, 6)
        XCTAssertEqual(s.dailyAllowance, 500_000)
        XCTAssertEqual(s.remainingToday, 400_000)
        XCTAssertFalse(s.isOverToday)
    }

    func testOverspendingTodayGivesGentleAdjustment() {
        let end = SafeToSpend.endOfMonth(containing: today, calendar: calendar)
        let s = SafeToSpend.compute(flexibleBudget: 6_000_000, spentBeforeToday: 3_000_000,
                                    spentToday: 600_000, today: today, periodEnd: end, calendar: calendar)
        XCTAssertTrue(s.isOverToday)
        XCTAssertEqual(s.remainingToday, -100_000)
        XCTAssertEqual(s.adjustedAllowanceForComingDays, 480_000) // 2,4tr / 5 ngày
        XCTAssertFalse(s.isBudgetUsedUp)
    }

    func testBudgetUsedUpDoesNotPromiseZeroPerDay() {
        let end = SafeToSpend.endOfMonth(containing: today, calendar: calendar)
        // Ngân sách 6tr, đã tiêu 5,9tr, hôm nay thêm 200k → tháng âm 100k
        let over = SafeToSpend.compute(flexibleBudget: 6_000_000, spentBeforeToday: 5_900_000,
                                       spentToday: 200_000, today: today, periodEnd: end, calendar: calendar)
        XCTAssertEqual(over.adjustedAllowanceForComingDays, 0)
        XCTAssertTrue(over.isBudgetUsedUp)
        // Tiêu vừa đúng hết ngân sách trước hôm nay
        let exact = SafeToSpend.compute(flexibleBudget: 6_000_000, spentBeforeToday: 6_000_000,
                                        spentToday: 0, today: today, periodEnd: end, calendar: calendar)
        XCTAssertTrue(exact.isBudgetUsedUp)
    }

    // MARK: Định dạng tiền

    func testCompactMoney() {
        XCTAssertEqual(MoneyFormatter.compact(35_000), "35k")
        XCTAssertEqual(MoneyFormatter.compact(1_500), "1,5k")
        XCTAssertEqual(MoneyFormatter.compact(1_200_000), "1,2tr")
        XCTAssertEqual(MoneyFormatter.compact(1_250_000), "1,25tr")
        XCTAssertEqual(MoneyFormatter.compact(1_050_000), "1,05tr")
        XCTAssertEqual(MoneyFormatter.compact(15_000_000), "15tr")
        XCTAssertEqual(MoneyFormatter.compact(999), "999đ")
        XCTAssertEqual(MoneyFormatter.compact(-40_000), "-40k")
    }

    func testFullMoney() {
        XCTAssertEqual(MoneyFormatter.full(1_250_000), "1.250.000đ")
        XCTAssertEqual(MoneyFormatter.full(35_000), "35.000đ")
        XCTAssertEqual(MoneyFormatter.full(500), "500đ")
    }
}

final class HabitProgressTests: XCTestCase {
    var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")!
        return cal
    }()
    let today = DayKey(year: 2026, month: 9, day: 25)

    private func ago(_ n: Int) -> DayKey { today.adding(days: -n, calendar: calendar) }
    private func entry(_ daysAgo: Int, _ categoryID: String = "food") -> LedgerEntry {
        LedgerEntry(amount: 10_000, isIncome: false, categoryID: categoryID, day: ago(daysAgo))
    }

    func testLogDailyCountsEntriesOrClosedDays() {
        let p = HabitProgress.compute(template: .logDaily, entries: [entry(0), entry(2)], closedDays: [ago(1)],
                                      from: ago(3), today: today, calendar: calendar)
        XCTAssertEqual(p.completedDays, [ago(0), ago(1), ago(2)])
        XCTAssertTrue(p.isDoneToday)
        XCTAssertEqual(p.streak, 3)
        XCTAssertGreaterThan(p.strength, 0)
    }

    func testNoSpendDayNeedsClosureAndNoDiscretionarySpending() {
        let entries = [entry(1, "drinks"), entry(2, "food")]
        let p = HabitProgress.compute(template: .noSpendDay, entries: entries, closedDays: [ago(1), ago(2)],
                                      from: ago(3), today: today, calendar: calendar)
        // ago(1): đã chốt nhưng có cà phê → không tính; ago(2): chỉ ăn uống → tính; ago(3): chưa chốt → không tính
        XCTAssertEqual(p.completedDays, [ago(2)])
    }

    func testManualHabitUsesCheckInsAndTodayNotDoneDoesNotHurt() {
        let manual: Set<DayKey> = [ago(1), ago(2), ago(10)]
        let p = HabitProgress.compute(template: .cookAtHome, entries: [], closedDays: [],
                                      manualDays: manual, from: ago(2), today: today, calendar: calendar)
        XCTAssertEqual(p.completedDays, [ago(1), ago(2)], "Ngày trước khi bắt đầu thói quen không tính")
        XCTAssertFalse(p.isDoneToday)
        XCTAssertEqual(p.streak, 2)
        let perfect = HabitEngine.strength(completed: [ago(1), ago(2)], from: ago(2), through: ago(1), calendar: calendar)
        XCTAssertEqual(p.strength, perfect, accuracy: 1e-9, "Hôm nay chưa xong thì chưa trừ điểm")
    }

    func testHabitStartedTodayNotDoneHasZeroStrength() {
        let p = HabitProgress.compute(template: .saveToday, entries: [], closedDays: [],
                                      from: today, today: today, calendar: calendar)
        XCTAssertEqual(p.strength, 0)
        XCTAssertEqual(p.streak, 0)
    }
}
