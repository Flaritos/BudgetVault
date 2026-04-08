import XCTest
@testable import BudgetVault

/// Tests for the streak state machine — trust-critical because streaks
/// drive retention and the app has zero tolerance for silently losing a
/// user's progress.
///
/// All tests reset UserDefaults in setUp so each runs in isolation.
final class StreakServiceTests: XCTestCase {

    private let defaultsKeys = [
        AppStorageKeys.currentStreak,
        AppStorageKeys.lastLogDate,
        AppStorageKeys.streakFreezesRemaining,
        AppStorageKeys.lastFreezeReset,
        "lastNoSpendDay"
    ]

    override func setUp() {
        super.setUp()
        for key in defaultsKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        for key in defaultsKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        super.tearDown()
    }

    // MARK: - recordLogEntry

    func testRecordLogEntry_startsAtOne() {
        StreakService.recordLogEntry()
        XCTAssertEqual(UserDefaults.standard.integer(forKey: AppStorageKeys.currentStreak), 1)
    }

    func testRecordLogEntry_idempotentWithinSameDay() {
        StreakService.recordLogEntry()
        StreakService.recordLogEntry()
        StreakService.recordLogEntry()
        XCTAssertEqual(UserDefaults.standard.integer(forKey: AppStorageKeys.currentStreak), 1)
    }

    // MARK: - markNoSpendDay

    func testMarkNoSpendDay_startsStreakAtOne() {
        let result = StreakService.markNoSpendDay()
        XCTAssertEqual(result, 1)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: AppStorageKeys.currentStreak), 1)
    }

    func testMarkNoSpendDay_idempotentWithinSameDay() {
        _ = StreakService.markNoSpendDay()
        let second = StreakService.markNoSpendDay()
        XCTAssertEqual(second, 1, "Marking no-spend twice in one day should not inflate the streak")
    }

    func testMarkNoSpendDay_doesNotOverwriteExistingLog() {
        StreakService.recordLogEntry()
        XCTAssertTrue(StreakService.hasClosedToday())
        _ = StreakService.markNoSpendDay()
        XCTAssertEqual(UserDefaults.standard.integer(forKey: AppStorageKeys.currentStreak), 1,
                       "markNoSpendDay should be a no-op if today is already closed")
    }

    // MARK: - hasClosedToday

    func testHasClosedToday_falseByDefault() {
        XCTAssertFalse(StreakService.hasClosedToday())
    }

    func testHasClosedToday_trueAfterLogEntry() {
        StreakService.recordLogEntry()
        XCTAssertTrue(StreakService.hasClosedToday())
    }

    func testHasClosedToday_trueAfterNoSpendDay() {
        _ = StreakService.markNoSpendDay()
        XCTAssertTrue(StreakService.hasClosedToday())
    }

    // MARK: - checkMilestone

    func testCheckMilestone_returnsNilBelowFirstMilestone() {
        UserDefaults.standard.set(6, forKey: AppStorageKeys.currentStreak)
        XCTAssertNil(StreakService.checkMilestone())
    }

    func testCheckMilestone_returnsMilestoneAtSevenDays() {
        UserDefaults.standard.set(7, forKey: AppStorageKeys.currentStreak)
        XCTAssertEqual(StreakService.checkMilestone(), 7)
    }

    func testCheckMilestone_returnsNilBetweenMilestones() {
        UserDefaults.standard.set(15, forKey: AppStorageKeys.currentStreak)
        XCTAssertNil(StreakService.checkMilestone())
    }
}
