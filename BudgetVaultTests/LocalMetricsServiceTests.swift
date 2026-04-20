import XCTest
@testable import BudgetVault

/// LocalMetricsService is the on-device-only counter store mirroring
/// FeedbackService. NEVER sends data over the network — counters surface
/// only via a user-initiated FeedbackService payload export.
final class LocalMetricsServiceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        LocalMetricsService.clearAll()
    }

    override func tearDown() {
        LocalMetricsService.clearAll()
        super.tearDown()
    }

    func testCounter_startsAtZero() {
        XCTAssertEqual(LocalMetricsService.value(for: .wrappedShareTaps), 0)
    }

    func testIncrement_addsOne() {
        LocalMetricsService.increment(.wrappedShareTaps)
        XCTAssertEqual(LocalMetricsService.value(for: .wrappedShareTaps), 1)
    }

    func testIncrement_isAdditive() {
        LocalMetricsService.increment(.wrappedShareTaps)
        LocalMetricsService.increment(.wrappedShareTaps)
        LocalMetricsService.increment(.wrappedShareTaps)
        XCTAssertEqual(LocalMetricsService.value(for: .wrappedShareTaps), 3)
    }

    func testCounters_isolatedPerKey() {
        LocalMetricsService.increment(.wrappedShareTaps)
        LocalMetricsService.increment(.paywallViews)
        LocalMetricsService.increment(.paywallViews)
        XCTAssertEqual(LocalMetricsService.value(for: .wrappedShareTaps), 1)
        XCTAssertEqual(LocalMetricsService.value(for: .paywallViews), 2)
    }

    func testCounters_persistAcrossLoad() {
        LocalMetricsService.increment(.quickAddUses)
        LocalMetricsService.increment(.quickAddUses)
        LocalMetricsService.flushForTesting()
        XCTAssertEqual(LocalMetricsService.value(for: .quickAddUses), 2)
    }

    func testPayloadString_includesAllCounters() {
        LocalMetricsService.increment(.wrappedShareTaps)
        LocalMetricsService.increment(.paywallViews)
        LocalMetricsService.increment(.paywallDismissals)
        LocalMetricsService.increment(.quickAddUses)
        let payload = LocalMetricsService.payloadString()
        XCTAssertTrue(payload.contains("wrapped_share_taps: 1"))
        XCTAssertTrue(payload.contains("paywall_views: 1"))
        XCTAssertTrue(payload.contains("paywall_dismissals: 1"))
        XCTAssertTrue(payload.contains("quick_add_uses: 1"))
    }

    func testClearAll_resetsCounters() {
        LocalMetricsService.increment(.wrappedShareTaps)
        LocalMetricsService.clearAll()
        XCTAssertEqual(LocalMetricsService.value(for: .wrappedShareTaps), 0)
    }

    func testKeyRawValues_matchSpec() {
        XCTAssertEqual(LocalMetricsService.Key.wrappedShareTaps.rawValue, "wrapped_share_taps")
        XCTAssertEqual(LocalMetricsService.Key.paywallViews.rawValue, "paywall_views")
        XCTAssertEqual(LocalMetricsService.Key.paywallDismissals.rawValue, "paywall_dismissals")
        XCTAssertEqual(LocalMetricsService.Key.quickAddUses.rawValue, "quick_add_uses")
    }
}
