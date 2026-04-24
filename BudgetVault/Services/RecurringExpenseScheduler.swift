import Foundation
import SwiftData
import os
import BudgetVaultShared

enum RecurringExpenseScheduler {

    static let maxPerLaunch = 50

    // Audit 2026-04-23 Max Audit P2-12: surface truncation via log.
    // A user returning from a long sabbatical with many active
    // recurring expenses will hit the 50-cap. Prior behavior silently
    // stopped; the log gives production debuggability (no user-facing
    // banner — the next foreground picks up the rest).
    private static let logger = Logger(subsystem: "io.budgetvault.app", category: "recurring-scheduler")

    /// Process all overdue recurring expenses. Returns the number of transactions created.
    /// Call this AFTER month rollover in the scenePhase .active handler.
    @MainActor
    static func processOverdue(context: ModelContext) -> Int {
        let today = Date()
        var transactionsCreated = 0

        let descriptor = FetchDescriptor<RecurringExpense>(
            predicate: #Predicate<RecurringExpense> { $0.isActive && $0.nextDueDate <= today }
        )

        guard let overdueExpenses = try? context.fetch(descriptor) else { return 0 }

        // Fetch the current-period budget to resolve categories against
        let resetDay = max(1, min(UserDefaults.standard.integer(forKey: AppStorageKeys.resetDay), 28))
        let currentPeriod = DateHelpers.budgetPeriod(containing: today, resetDay: resetDay)
        let cm = currentPeriod.0
        let cy = currentPeriod.1
        let currentBudgetDescriptor = FetchDescriptor<Budget>(
            predicate: #Predicate<Budget> { $0.month == cm && $0.year == cy }
        )
        let currentBudget = try? context.fetch(currentBudgetDescriptor).first

        for expense in overdueExpenses {
            while expense.nextDueDate <= today && transactionsCreated < maxPerLaunch {
                // H1: Resolve category to the current budget period
                var resolvedCategory = expense.category
                if let cat = resolvedCategory, cat.budget?.id != currentBudget?.id {
                    // Category belongs to an old budget — find equivalent in current budget by name.
                    // Audit 2026-04-22 P1-32: match case-insensitively so
                    // a "Groceries" recurring expense still resolves if
                    // the user renamed the category to "groceries" in
                    // the current month. Consistent with CSVImporter
                    // (P1-31) and the learning service.
                    if let match = (currentBudget?.categories ?? []).first(where: { $0.name.caseInsensitiveCompare(cat.name) == .orderedSame }) {
                        resolvedCategory = match
                    } else {
                        // Audit 2026-04-23 Max Audit P0-2: prior
                        // behavior advanced `nextDueDate` on category
                        // mismatch and silently skipped the posting.
                        // A user who renamed the category lost every
                        // future auto-post forever with no surfaced
                        // error. Now: DO NOT advance — leave the due
                        // date in place so the Dashboard catch-up
                        // card (or the user's eventual Settings visit)
                        // can re-resolve once the category is
                        // renamed/recreated. Surface the gap via a
                        // flag the UI can display.
                        expense.needsReassignment = true
                        break
                    }
                }

                let transaction = Transaction(
                    amountCents: expense.amountCents,
                    note: expense.name,
                    date: expense.nextDueDate,
                    isIncome: false,
                    category: resolvedCategory
                )
                transaction.isRecurring = true
                transaction.recurringExpense = expense

                context.insert(transaction)
                expense.advanceNextDueDate()
                transactionsCreated += 1

                // Reschedule bill due reminder for the next occurrence
                if UserDefaults.standard.bool(forKey: AppStorageKeys.billDueReminders) {
                    NotificationService.scheduleBillDueReminder(
                        expenseName: expense.name,
                        dueDate: expense.nextDueDate,
                        id: expense.id.uuidString
                    )
                }
            }
        }

        if transactionsCreated > 0 {
            if !SafeSave.save(context) { context.rollback() }
        }

        if transactionsCreated >= maxPerLaunch {
            logger.info("RecurringExpenseScheduler hit maxPerLaunch cap (\(maxPerLaunch, privacy: .public)); remaining overdue postings deferred to next foreground.")
        }

        return transactionsCreated
    }
}
