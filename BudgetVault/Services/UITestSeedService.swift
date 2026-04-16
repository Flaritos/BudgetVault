#if DEBUG
import Foundation
import SwiftData
import BudgetVaultShared

/// Deterministic seeding for XCUITest runs. Triggered by the `-uitest 1`
/// launch argument in `BudgetVaultApp.init`. Keeps test runs hermetic so
/// UI assertions don't depend on persisted state from prior sessions.
///
/// Supported flags:
/// - `-uitest 1`                 — full wipe + seed baseline fixture
/// - `-uitest-closed 1`          — additionally mark today as closed
/// - `-uitest-today-empty 1`     — skip today's transaction in the fixture
/// - `-uitest-glitch-buffer 1`   — tiny spending / huge budget to trigger H1
@MainActor
enum UITestSeedService {

    static func applyLaunchArguments(container: ModelContainer) {
        let args = ProcessInfo.processInfo.arguments

        resetUserDefaults()
        wipeSwiftData(container: container)

        // Round 7: explicitly disable biometric lock for UI tests. Real
        // users get Face ID default-ON from the onboarding toggle; tests
        // can't enter a passcode prompt so we force it off here.
        UserDefaults.standard.set(false, forKey: AppStorageKeys.biometricLockEnabled)

        // -uitest-wipe-only: just clean state and exit. Used for end-to-end
        // smoke tests that drive the real onboarding flow manually.
        if args.contains("-uitest-wipe-only") {
            // Explicitly ensure onboarding shows — belt + suspenders since
            // resetUserDefaults should already leave the key absent.
            UserDefaults.standard.set(false, forKey: AppStorageKeys.hasCompletedOnboarding)
            UserDefaults.standard.synchronize()
            return
        }

        seedBaseline(
            container: container,
            includeToday: !args.contains("-uitest-today-empty"),
            glitchBuffer: args.contains("-uitest-glitch-buffer")
        )

        // Mark onboarding completed so we land directly on the dashboard.
        UserDefaults.standard.set(true, forKey: AppStorageKeys.hasCompletedOnboarding)

        if args.contains("-uitest-closed") {
            let today = Calendar.current.startOfDay(for: Date())
            let todayStr = DateHelpers.dateString(today)
            UserDefaults.standard.set(todayStr, forKey: AppStorageKeys.lastLogDate)
            UserDefaults.standard.set(1, forKey: AppStorageKeys.currentStreak)
        }
    }

    // MARK: - Reset

    private static func resetUserDefaults() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys {
            defaults.removeObject(forKey: key)
        }
    }

    private static func wipeSwiftData(container: ModelContainer) {
        let context = container.mainContext
        let types: [any PersistentModel.Type] = [
            Transaction.self, Category.self, Budget.self,
            RecurringExpense.self, DebtAccount.self, DebtPayment.self
        ]
        for type in types {
            try? context.delete(model: type)
        }
        try? context.save()
    }

    // MARK: - Seed

    private static func seedBaseline(container: ModelContainer, includeToday: Bool, glitchBuffer: Bool) {
        let context = container.mainContext
        let (month, year) = DateHelpers.currentBudgetPeriod(resetDay: 1)

        // Use a huge income + tiny transaction to intentionally reproduce
        // the +1370d buffer glitch when the -uitest-glitch-buffer flag is set.
        let income: Int64 = glitchBuffer ? 1_000_000_00 : 500_000
        let budget = Budget(month: month, year: year, totalIncomeCents: income, resetDay: 1)
        context.insert(budget)

        let groceries = Category(name: "Groceries", emoji: "\u{1F6D2}", budgetedAmountCents: 75000, color: "#34C759", sortOrder: 0)
        let transport = Category(name: "Transport", emoji: "\u{1F697}", budgetedAmountCents: 50000, color: "#FF9500", sortOrder: 1)
        groceries.budget = budget
        transport.budget = budget

        // Two prior-day transactions — one reconciled, one not
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        let reconciledTx = Transaction(amountCents: 1250, note: "Coffee", date: yesterday, isIncome: false, category: groceries)
        reconciledTx.isReconciled = true
        context.insert(reconciledTx)

        let olderTx = Transaction(amountCents: 4500, note: "Gas", date: yesterday, isIncome: false, category: transport)
        context.insert(olderTx)

        if includeToday {
            let todayTx = Transaction(amountCents: 850, note: "Lunch", date: Date(), isIncome: false, category: groceries)
            context.insert(todayTx)
        }

        try? context.save()
    }
}
#endif
