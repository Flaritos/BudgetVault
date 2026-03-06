import AppIntents
import SwiftUI

struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Expense"
    static var description = IntentDescription("Log an expense in BudgetVault")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Amount")
    var amount: Double?

    @Parameter(title: "Category")
    var categoryName: String?

    @Parameter(title: "Note")
    var note: String?

    // TODO: DashboardPlaceholderView.onReceive(.openTransactionEntry) currently ignores userInfo.
    // Update the receiver to read amount/category/note from userInfo and pre-populate TransactionEntryView.
    func perform() async throws -> some IntentResult {
        await MainActor.run {
            var userInfo: [String: Any] = [:]
            if let amount { userInfo["amount"] = amount }
            if let categoryName { userInfo["category"] = categoryName }
            if let note { userInfo["note"] = note }
            NotificationCenter.default.post(name: .openTransactionEntry, object: nil, userInfo: userInfo)
        }
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
