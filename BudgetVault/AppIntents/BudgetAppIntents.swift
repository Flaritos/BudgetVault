import AppIntents
import SwiftUI

struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Expense to BudgetVault"
    static var description = IntentDescription("Open BudgetVault to add a new expense.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        // Deep link handled by ContentView observing the intent
        NotificationCenter.default.post(name: .openTransactionEntry, object: nil)
        return .result()
    }
}

struct BudgetRemainingIntent: AppIntent {
    static var title: LocalizedStringResource = "How Much Budget Is Left?"
    static var description = IntentDescription("Check your remaining budget in BudgetVault.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let suiteName = "group.com.budgetvault.shared"
        let dataKey = "widgetData"

        guard let data = UserDefaults(suiteName: suiteName)?.data(forKey: dataKey),
              let decoded = try? JSONDecoder().decode(WidgetDataService.WidgetData.self, from: data) else {
            return .result(dialog: "I couldn't find your budget data. Open BudgetVault first.")
        }

        let remaining = CurrencyFormatter.format(cents: decoded.remainingBudgetCents, currencyCode: decoded.currencyCode)
        return .result(dialog: "You have \(remaining) remaining in your budget.")
    }
}

struct BudgetVaultShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Add expense to \(.applicationName)",
                "Log expense in \(.applicationName)",
                "Add to \(.applicationName)"
            ],
            shortTitle: "Add Expense",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: BudgetRemainingIntent(),
            phrases: [
                "How much budget is left in \(.applicationName)?",
                "Check \(.applicationName) budget",
                "What's my \(.applicationName) balance?"
            ],
            shortTitle: "Budget Remaining",
            systemImageName: "chart.pie"
        )
    }
}

extension Notification.Name {
    static let openTransactionEntry = Notification.Name("openTransactionEntry")
}
