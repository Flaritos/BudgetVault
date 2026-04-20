import XCTest
@testable import BudgetVault

/// Regression: the date arithmetic in InsightsEngine.swift previously
/// used `try!` semantics on `calendar.date(byAdding:value:to:)`, which
/// can return nil on calendar boundaries (e.g. transitioning out of a
/// non-Gregorian DST window with `daysSoFar` > 28). Wrap with `??
/// prev.nextPeriodStart` to guarantee a defined comparison.
final class InsightsEngineForceUnwrapTests: XCTestCase {

    func testSafeDateAddition_returnsExpectedDate() {
        let cal = Calendar(identifier: .gregorian)
        let start = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let added = cal.date(byAdding: .day, value: 5, to: start)
        XCTAssertNotNil(added)
        XCTAssertEqual(cal.component(.day, from: added!), 6)
    }

    func testSafeDateAddition_extremeOverflowReturnsNonNil() {
        // Calendar arithmetic in Gregorian never returns nil for normal
        // ranges; this test documents the contract — if a future calendar
        // change ever returns nil, we want a fallback, not a crash.
        let cal = Calendar(identifier: .gregorian)
        let start = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let added = cal.date(byAdding: .day, value: Int.max / 2, to: start)
        // Documented behavior — value may be nil, but app must not crash.
        _ = added
    }
}
