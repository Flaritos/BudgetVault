import XCTest
@testable import BudgetVault

final class DateHelpersTests: XCTestCase {

    // MARK: - currentBudgetPeriod

    func testCurrentBudgetPeriodDefaultResetDay() {
        // resetDay=1 should return the current calendar month
        let result = DateHelpers.currentBudgetPeriod(resetDay: 1)
        let now = Calendar.current.dateComponents([.month, .year], from: Date())
        XCTAssertEqual(result.month, now.month)
        XCTAssertEqual(result.year, now.year)
    }

    // MARK: - budgetPeriod(containing:resetDay:)

    func testResetDay1OnFirstOfMonth() {
        // resetDay=1 on Jan 1 should be January
        let date = makeDate(year: 2026, month: 1, day: 1)
        let result = DateHelpers.budgetPeriod(containing: date, resetDay: 1)
        XCTAssertEqual(result.month, 1)
        XCTAssertEqual(result.year, 2026)
    }

    func testResetDay15OnDay14ShouldBePreviousMonth() {
        // resetDay=15, on the 14th we're still in the previous month's budget
        let date = makeDate(year: 2026, month: 3, day: 14)
        let result = DateHelpers.budgetPeriod(containing: date, resetDay: 15)
        XCTAssertEqual(result.month, 2)
        XCTAssertEqual(result.year, 2026)
    }

    func testResetDay15OnDay15ShouldBeCurrentMonth() {
        // resetDay=15, on the 15th we're in the current month's budget
        let date = makeDate(year: 2026, month: 3, day: 15)
        let result = DateHelpers.budgetPeriod(containing: date, resetDay: 15)
        XCTAssertEqual(result.month, 3)
        XCTAssertEqual(result.year, 2026)
    }

    func testResetDay28InFebruary() {
        // resetDay=28, on Feb 27 should be January's budget
        let date = makeDate(year: 2026, month: 2, day: 27)
        let result = DateHelpers.budgetPeriod(containing: date, resetDay: 28)
        XCTAssertEqual(result.month, 1)
        XCTAssertEqual(result.year, 2026)

        // On Feb 28 should be February's budget
        let date2 = makeDate(year: 2026, month: 2, day: 28)
        let result2 = DateHelpers.budgetPeriod(containing: date2, resetDay: 28)
        XCTAssertEqual(result2.month, 2)
        XCTAssertEqual(result2.year, 2026)
    }

    func testYearWraparoundDecemberToJanuary() {
        // resetDay=15, on Jan 10 should be December of previous year
        let date = makeDate(year: 2026, month: 1, day: 10)
        let result = DateHelpers.budgetPeriod(containing: date, resetDay: 15)
        XCTAssertEqual(result.month, 12)
        XCTAssertEqual(result.year, 2025)
    }

    // MARK: - budgetPeriod(for:year:resetDay:)

    func testBudgetPeriodStartAndEnd() {
        let (start, nextStart) = DateHelpers.budgetPeriod(for: 3, year: 2026, resetDay: 1)
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.month, from: start), 3)
        XCTAssertEqual(cal.component(.day, from: start), 1)
        XCTAssertEqual(cal.component(.month, from: nextStart), 4)
        XCTAssertEqual(cal.component(.day, from: nextStart), 1)
    }

    func testBudgetPeriodWithResetDay15() {
        let (start, nextStart) = DateHelpers.budgetPeriod(for: 3, year: 2026, resetDay: 15)
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.day, from: start), 15)
        XCTAssertEqual(cal.component(.month, from: start), 3)
        XCTAssertEqual(cal.component(.day, from: nextStart), 15)
        XCTAssertEqual(cal.component(.month, from: nextStart), 4)
    }

    // MARK: - nextMonth / previousMonth

    func testNextMonthNormal() {
        let result = DateHelpers.nextMonth(from: 5, year: 2026)
        XCTAssertEqual(result.month, 6)
        XCTAssertEqual(result.year, 2026)
    }

    func testNextMonthDecemberWraparound() {
        let result = DateHelpers.nextMonth(from: 12, year: 2025)
        XCTAssertEqual(result.month, 1)
        XCTAssertEqual(result.year, 2026)
    }

    func testPreviousMonthNormal() {
        let result = DateHelpers.previousMonth(from: 5, year: 2026)
        XCTAssertEqual(result.month, 4)
        XCTAssertEqual(result.year, 2026)
    }

    func testPreviousMonthJanuaryWraparound() {
        let result = DateHelpers.previousMonth(from: 1, year: 2026)
        XCTAssertEqual(result.month, 12)
        XCTAssertEqual(result.year, 2025)
    }

    // MARK: - navigateMonth

    func testNavigateMonthForward() {
        let result = DateHelpers.navigateMonth(from: 6, year: 2026, delta: 1)
        XCTAssertEqual(result.month, 7)
        XCTAssertEqual(result.year, 2026)
    }

    func testNavigateMonthBackward() {
        let result = DateHelpers.navigateMonth(from: 6, year: 2026, delta: -1)
        XCTAssertEqual(result.month, 5)
        XCTAssertEqual(result.year, 2026)
    }

    func testNavigateMonthForwardYearWrap() {
        let result = DateHelpers.navigateMonth(from: 12, year: 2025, delta: 1)
        XCTAssertEqual(result.month, 1)
        XCTAssertEqual(result.year, 2026)
    }

    func testNavigateMonthBackwardYearWrap() {
        let result = DateHelpers.navigateMonth(from: 1, year: 2026, delta: -1)
        XCTAssertEqual(result.month, 12)
        XCTAssertEqual(result.year, 2025)
    }

    // MARK: - monthYearString

    func testMonthYearString() {
        let result = DateHelpers.monthYearString(month: 3, year: 2026)
        XCTAssertEqual(result, "March 2026")
    }

    func testMonthYearStringDecember() {
        let result = DateHelpers.monthYearString(month: 12, year: 2025)
        XCTAssertEqual(result, "December 2025")
    }

    // MARK: - dateString

    func testDateStringFormat() {
        let date = makeDate(year: 2026, month: 3, day: 5)
        let result = DateHelpers.dateString(date)
        XCTAssertEqual(result, "2026-03-05")
    }

    func testDateStringDoubleDigitMonth() {
        let date = makeDate(year: 2026, month: 11, day: 25)
        let result = DateHelpers.dateString(date)
        XCTAssertEqual(result, "2026-11-25")
    }

    // MARK: - Helpers

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
