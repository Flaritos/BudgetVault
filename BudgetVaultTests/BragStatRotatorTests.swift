import XCTest
@testable import BudgetVault

/// BragStatRotator picks ONE of three non-financial brag stats per Wrapped
/// share so low-spend users still want to share. Spec 5.10 USER DECISION:
/// "ALL THREE rotating (streak, tx count, no-spend days)."
final class BragStatRotatorTests: XCTestCase {

    func testPick_streakSlot_rendersStreakLine() {
        let stat = BragStatRotator.pick(slot: 0, streakDays: 47, txCount: 182, zeroSpendDays: 12)
        XCTAssertEqual(stat, "47-day streak")
    }

    func testPick_txCountSlot_rendersTxLine() {
        let stat = BragStatRotator.pick(slot: 1, streakDays: 47, txCount: 182, zeroSpendDays: 12)
        XCTAssertEqual(stat, "182 logs")
    }

    func testPick_zeroSpendSlot_rendersZeroSpendLine() {
        let stat = BragStatRotator.pick(slot: 2, streakDays: 47, txCount: 182, zeroSpendDays: 12)
        XCTAssertEqual(stat, "12 no-spend days")
    }

    func testPick_streakZero_skipsToTxCountSlot() {
        let stat = BragStatRotator.pick(slot: 0, streakDays: 0, txCount: 182, zeroSpendDays: 12)
        XCTAssertEqual(stat, "182 logs", "Empty streak should fall through to next non-empty slot")
    }

    func testPick_allEmpty_returnsBudgetVaultBrand() {
        let stat = BragStatRotator.pick(slot: 0, streakDays: 0, txCount: 0, zeroSpendDays: 0)
        XCTAssertEqual(stat, "Privacy-first budgeting")
    }

    func testPick_slotWrapsModulo3() {
        let s0 = BragStatRotator.pick(slot: 3, streakDays: 47, txCount: 182, zeroSpendDays: 12)
        let s1 = BragStatRotator.pick(slot: 4, streakDays: 47, txCount: 182, zeroSpendDays: 12)
        let s2 = BragStatRotator.pick(slot: 5, streakDays: 47, txCount: 182, zeroSpendDays: 12)
        XCTAssertEqual(s0, "47-day streak")
        XCTAssertEqual(s1, "182 logs")
        XCTAssertEqual(s2, "12 no-spend days")
    }
}
