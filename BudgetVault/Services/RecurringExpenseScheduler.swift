import Foundation
import SwiftData

enum RecurringExpenseScheduler {

    static let maxPerLaunch = 50

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

        for expense in overdueExpenses {
            while expense.nextDueDate <= today && transactionsCreated < maxPerLaunch {
                let transaction = Transaction(
                    amountCents: expense.amountCents,
                    note: expense.name,
                    date: expense.nextDueDate,
                    isIncome: false,
                    category: expense.category
                )
                transaction.isRecurring = true
                transaction.recurringExpense = expense

                context.insert(transaction)
                expense.advanceNextDueDate()
                transactionsCreated += 1
            }
        }

        if transactionsCreated > 0 {
            try? context.save()
        }

        return transactionsCreated
    }
}
