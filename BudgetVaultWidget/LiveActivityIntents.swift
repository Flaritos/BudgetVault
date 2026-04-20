import AppIntents
import Foundation

/// Tapping the "Log" button in the Dynamic Island expanded leaf opens
/// BudgetVault on the transaction-entry screen. Read-only-safe v1: the
/// intent does NOT write to SwiftData from the extension process; it
/// just deep-links into the host app.
///
/// Per `docs/audit-2026-04-16/product/mobile-platform.md` "What NOT to
/// Do" — interactive-write Live Activity buttons are deferred to v3.4.
@available(iOS 17.0, *)
struct LogExpenseFromActivityIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Log Expense"
    static var description = IntentDescription("Open BudgetVault to log an expense.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
