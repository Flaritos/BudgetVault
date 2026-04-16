import XCTest
@testable import BudgetVault

/// Pure-value tests for the stale-period guard. ActivityKit cannot run
/// in a unit-test process (`Activity.request` requires a live extension
/// host), so we test the predicate in isolation rather than the side
/// effects.
final class BudgetLiveActivityServiceTests: XCTestCase {

    func testIsStale_returnsTrueWhenEndDateInPast() {
        let endDate = Date().addingTimeInterval(-60)
        XCTAssertTrue(BudgetLiveActivityService.isPeriodEndStale(endDate, now: Date()))
    }

    func testIsStale_returnsFalseWhenEndDateInFuture() {
        let endDate = Date().addingTimeInterval(60)
        XCTAssertFalse(BudgetLiveActivityService.isPeriodEndStale(endDate, now: Date()))
    }

    func testIsStale_returnsFalseAtExactEqual() {
        let now = Date()
        XCTAssertFalse(BudgetLiveActivityService.isPeriodEndStale(now, now: now),
                       "Equal-time should be treated as still-running, not stale.")
    }
}
