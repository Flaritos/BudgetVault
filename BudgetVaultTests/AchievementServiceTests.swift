import XCTest
import SwiftData
@testable import BudgetVault

/// v3.3 P0 fix: `saved_100/500/1000` previously fired on day 1 of a
/// $100 budget when no spending had been logged yet. Gate behind
/// `isCompletedMonth` (Date >= budget.nextPeriodStart) like
/// `under_budget_*` already does at AchievementService.swift:89.
final class AchievementServiceTests: XCTestCase {

    private let savedKeys = ["unlockedAchievements", "underBudgetMonthCount"]

    override func setUp() {
        super.setUp()
        for k in savedKeys {
            UserDefaults.standard.removeObject(forKey: k)
        }
    }

    override func tearDown() {
        for k in savedKeys {
            UserDefaults.standard.removeObject(forKey: k)
        }
        super.tearDown()
    }

    // MARK: - Helpers

    private func inMemoryContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Budget.self, Category.self, Transaction.self, RecurringExpense.self,
            configurations: config
        )
        return ModelContext(container)
    }

    /// Build a Budget for a month offset from now. `monthsAgo: 0` = current
    /// in-progress month; `monthsAgo: 1` = last month (completed).
    /// Note: schema uses `totalIncomeCents` (not `totalAmountCents`) — that
    /// is the value `remainingCents` subtracts spending from.
    private func makeBudget(monthsAgo: Int, totalCents: Int64) throws -> Budget {
        let cal = Calendar.current
        let now = Date()
        let target = cal.date(byAdding: .month, value: -monthsAgo, to: now)!
        let comps = cal.dateComponents([.year, .month], from: target)
        let budget = Budget(
            month: comps.month!,
            year: comps.year!,
            totalIncomeCents: totalCents,
            resetDay: 1
        )
        return budget
    }

    // MARK: - saved_100 gate

    func testSaved100_doesNotUnlockMidMonth() throws {
        let budget = try makeBudget(monthsAgo: 0, totalCents: 100_000) // current month
        let unlocked = AchievementService.checkAchievements(budget: budget, transactions: [])
        XCTAssertFalse(unlocked.contains(where: { $0.id == "saved_100" }),
                       "saved_100 must NOT unlock during in-progress month")
    }

    func testSaved100_unlocksOnCompletedMonthWith100Saved() throws {
        let budget = try makeBudget(monthsAgo: 1, totalCents: 100_000) // last month, completed
        let unlocked = AchievementService.checkAchievements(budget: budget, transactions: [])
        XCTAssertTrue(unlocked.contains(where: { $0.id == "saved_100" }),
                      "saved_100 must unlock when remaining >= $100 on completed month")
    }

    func testSaved500_doesNotUnlockMidMonth() throws {
        let budget = try makeBudget(monthsAgo: 0, totalCents: 100_000)
        let unlocked = AchievementService.checkAchievements(budget: budget, transactions: [])
        XCTAssertFalse(unlocked.contains(where: { $0.id == "saved_500" }))
    }

    func testSaved1000_doesNotUnlockMidMonth() throws {
        let budget = try makeBudget(monthsAgo: 0, totalCents: 200_000)
        let unlocked = AchievementService.checkAchievements(budget: budget, transactions: [])
        XCTAssertFalse(unlocked.contains(where: { $0.id == "saved_1000" }))
    }
}
