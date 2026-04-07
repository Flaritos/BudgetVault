import XCTest
@testable import BudgetVault

final class StoreKitManagerTests: XCTestCase {

    /// Regression test for v3.1 bug where launchPricingEndDate was set to a past
    /// epoch (July 2025), silently hiding every launch pricing UI surface.
    /// If this test fails, the launch pricing date needs to be bumped before release.
    func testLaunchPricingEndDateIsInFuture() {
        XCTAssertGreaterThan(
            StoreKitManager.launchPricingEndDate,
            Date(),
            "launchPricingEndDate is in the past — every launch pricing banner is silently hidden. Bump the epoch in StoreKitManager.swift."
        )
    }

    /// Asserts the date is at least 7 days out, so we don't accidentally ship
    /// with a soon-to-expire launch pricing window.
    func testLaunchPricingEndDateHasReasonableHeadroom() {
        let sevenDaysOut = Date().addingTimeInterval(7 * 86400)
        XCTAssertGreaterThan(
            StoreKitManager.launchPricingEndDate,
            sevenDaysOut,
            "launchPricingEndDate is less than 7 days away — extend the launch pricing window before release."
        )
    }
}
