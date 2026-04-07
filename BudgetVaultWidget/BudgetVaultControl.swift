import AppIntents
import SwiftUI
import WidgetKit

/// iOS 18 Control Center Control for one-tap expense logging.
/// Surfaces BudgetVault in Control Center, the Lock Screen, and the
/// Action Button so users can log without opening the app first.
///
/// Introduced in v3.2 Sprint 2 (the daily loop).
@available(iOS 18.0, *)
struct LogExpenseControl: ControlWidget {
    static let kind = "io.budgetvault.app.controls.logExpense"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenAddExpenseIntent()) {
                Label("Log Expense", systemImage: "plus.circle.fill")
            }
        }
        .displayName("Log Expense")
        .description("Open BudgetVault to log a new expense.")
    }
}
