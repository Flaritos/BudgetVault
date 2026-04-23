import XCTest
@testable import BudgetVault

// Audit 2026-04-22 P1-34: `StoreKitManager.launchPricingEndDate` is now
// a computed member of a `@MainActor`-isolated class. Mark the test
// case `@MainActor` so its methods can access the static property.
@MainActor
final class StoreKitManagerTests: XCTestCase {

    /// Regression test for v3.1 bug where launchPricingEndDate was set to a past
    /// epoch (July 2025), silently hiding every launch pricing UI surface.
    /// If this test fails, the launch pricing date needs to be bumped before release.
    /// Under P1-34 the date is per-install: `installDate + 30 days`. First run of
    /// this test stamps the install date if not already set; subsequent runs
    /// read back the same value, so the assertion is stable.
    func testLaunchPricingEndDateIsInFuture() {
        XCTAssertGreaterThan(
            StoreKitManager.launchPricingEndDate,
            Date(),
            "launchPricingEndDate is in the past — every launch pricing banner is silently hidden. Check the launch-pricing window in StoreKitManager.swift."
        )
    }

    /// Asserts the date is at least 7 days out, so we don't accidentally ship
    /// with a soon-to-expire launch pricing window.
    func testLaunchPricingEndDateHasReasonableHeadroom() {
        let sevenDaysOut = Date().addingTimeInterval(7 * 86400)
        XCTAssertGreaterThan(
            StoreKitManager.launchPricingEndDate,
            sevenDaysOut,
            "launchPricingEndDate is less than 7 days away — extend the launch-pricing window in StoreKitManager.swift."
        )
    }
}
