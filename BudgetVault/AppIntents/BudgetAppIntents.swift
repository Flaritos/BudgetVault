import AppIntents
import SwiftUI
import BudgetVaultShared

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

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            var userInfo: [String: Any] = [:]
            // Audit 2026-04-22 P1-35: Siri / Shortcuts can pass NaN,
            // negative, or astronomically large Doubles (1e308) into a
            // Double parameter. Validate before forwarding to the entry
            // sheet so garbage input doesn't round-trip into a
            // `Decimal(Double.nan)` which traps at runtime.
            if let amount, amount.isFinite, amount > 0, amount < 10_000_000 {
                userInfo["amount"] = amount
            }
            if let categoryName, !categoryName.isEmpty, categoryName.count <= 100 {
                userInfo["category"] = Self.stripControlAndBidi(categoryName)
            }
            if let note, note.count <= 500 {
                userInfo["note"] = Self.stripControlAndBidi(note)
            }
            NotificationCenter.default.post(name: .openTransactionEntry, object: nil, userInfo: userInfo)
        }
        return .result()
    }

    /// Audit 2026-04-23 Security P2: strip control characters + bidi
    /// overrides (U+202A–U+202E, U+2066–U+2069, U+200E/U+200F) from
    /// Siri-provided text. Note text flows to CSV export where a
    /// `<RLO>=cmd` payload could disguise a CSV-injection attempt
    /// past the formula-prefix guard (which only checks the FIRST
    /// visible character). Blocking bidi upstream stops that class
    /// of attack at the source.
    private static func stripControlAndBidi(_ input: String) -> String {
        input.unicodeScalars.filter { scalar in
            let value = scalar.value
            if scalar.properties.generalCategory == .control { return false }
            // Bidi / embedding controls: LRE, RLE, PDF, LRO, RLO, LRI, RLI, FSI, PDI, LRM, RLM
            let bidiRanges: [ClosedRange<UInt32>] = [
                0x202A...0x202E,
                0x2066...0x2069,
                0x200E...0x200F,
            ]
            return !bidiRanges.contains { $0.contains(value) }
        }.reduce(into: "") { $0.append(Character($1)) }
    }
}

struct BudgetRemainingIntent: AppIntent {
    static var title: LocalizedStringResource = "How Much Budget Is Left?"
    static var description = IntentDescription("Check your remaining budget in BudgetVault.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let suiteName = "group.io.budgetvault.shared"
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
    static let switchToHistoryTab = Notification.Name("switchToHistoryTab")
    /// Posted by BiometricLockView when authService.isAuthenticated
    /// flips true. Subscribers: BudgetVaultApp runs deferred month
    /// rollover + recurring expense posting after this fires.
    static let biometricUnlocked = Notification.Name("biometricUnlocked")
}
