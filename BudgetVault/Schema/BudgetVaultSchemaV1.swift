import Foundation
import SwiftData

enum BudgetVaultSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Budget.self, Category.self, Transaction.self, RecurringExpense.self]
    }

    // MARK: - Budget

    @Model
    final class Budget {
        var id: UUID = UUID()
        var month: Int = 1
        var year: Int = 2026
        var totalIncomeCents: Int64 = 0
        var resetDay: Int = 1
        var createdAt: Date = Date.now
        var isAutoCreated: Bool = false

        @Relationship(deleteRule: .cascade, inverse: \Category.budget)
        var categories: [Category] = []

        init(month: Int, year: Int, totalIncomeCents: Int64 = 0, resetDay: Int = 1, isAutoCreated: Bool = false) {
            self.id = UUID()
            self.month = month
            self.year = year
            self.totalIncomeCents = totalIncomeCents
            self.resetDay = resetDay
            self.createdAt = Date.now
            self.isAutoCreated = isAutoCreated
        }

        // MARK: Computed

        var totalIncome: Decimal { Decimal(totalIncomeCents) / 100 }

        /// Budget period start date using resetDay
        var periodStart: Date {
            Calendar.current.date(from: DateComponents(year: year, month: month, day: resetDay)) ?? Date()
        }

        /// Exclusive upper bound — use `date < nextPeriodStart` (half-open interval)
        var nextPeriodStart: Date {
            Calendar.current.date(byAdding: .month, value: 1, to: periodStart) ?? Date()
        }

        /// Total spent in this budget period (non-income transactions across all categories)
        func totalSpentCents() -> Int64 {
            categories.reduce(0) { $0 + $1.spentCents(in: self) }
        }

        var remainingCents: Int64 {
            totalIncomeCents - totalSpentCents()
        }

        var remainingBudget: Decimal { Decimal(remainingCents) / 100 }

        var percentRemaining: Double {
            guard totalIncomeCents > 0 else { return 0 }
            return Double(remainingCents) / Double(totalIncomeCents)
        }
    }

    // MARK: - Category

    @Model
    final class Category {
        var id: UUID = UUID()
        var name: String = ""
        var emoji: String = "📦"
        var budgetedAmountCents: Int64 = 0
        var color: String = "#007AFF"
        var sortOrder: Int = 0
        var isHidden: Bool = false
        var rollOverUnspent: Bool = false

        @Relationship(deleteRule: .cascade, inverse: \Transaction.category)
        var transactions: [Transaction] = []

        var budget: Budget?

        @Relationship(deleteRule: .nullify, inverse: \RecurringExpense.category)
        var recurringExpenses: [RecurringExpense] = []

        init(name: String, emoji: String = "📦", budgetedAmountCents: Int64 = 0, color: String = "#007AFF", sortOrder: Int = 0) {
            self.id = UUID()
            self.name = name
            self.emoji = emoji
            self.budgetedAmountCents = budgetedAmountCents
            self.color = color
            self.sortOrder = sortOrder
        }

        // MARK: Computed

        var budgetedAmount: Decimal { Decimal(budgetedAmountCents) / 100 }

        /// CRITICAL: Half-open interval — date >= start AND date < nextStart
        func spentCents(in budget: Budget) -> Int64 {
            transactions
                .filter { !$0.isIncome && $0.date >= budget.periodStart && $0.date < budget.nextPeriodStart }
                .reduce(0) { $0 + $1.amountCents }
        }

        func spent(in budget: Budget) -> Decimal {
            Decimal(spentCents(in: budget)) / 100
        }

        func remainingCents(in budget: Budget) -> Int64 {
            budgetedAmountCents - spentCents(in: budget)
        }

        func remaining(in budget: Budget) -> Decimal {
            Decimal(remainingCents(in: budget)) / 100
        }

        func percentSpent(in budget: Budget) -> Double {
            guard budgetedAmountCents > 0 else { return 0 }
            return Double(spentCents(in: budget)) / Double(budgetedAmountCents)
        }
    }

    // MARK: - Transaction

    @Model
    final class Transaction {
        var id: UUID = UUID()
        var amountCents: Int64 = 0
        var note: String = ""
        var date: Date = Date.now
        var isIncome: Bool = false
        var isRecurring: Bool = false
        var createdAt: Date = Date.now

        var category: Category?

        @Relationship(inverse: \RecurringExpense.generatedTransactions)
        var recurringExpense: RecurringExpense?

        init(amountCents: Int64, note: String = "", date: Date = .now, isIncome: Bool = false, category: Category? = nil) {
            self.id = UUID()
            self.amountCents = amountCents
            self.note = note
            self.date = date
            self.isIncome = isIncome
            self.createdAt = Date.now
            self.category = category
        }

        // MARK: Computed

        var amount: Decimal { Decimal(amountCents) / 100 }
    }

    // MARK: - RecurringExpense

    @Model
    final class RecurringExpense {
        var id: UUID = UUID()
        var name: String = ""
        var amountCents: Int64 = 0
        var frequency: String = "monthly"
        var nextDueDate: Date = Date.now
        var isActive: Bool = true

        var category: Category?

        @Relationship(deleteRule: .nullify)
        var generatedTransactions: [Transaction] = []

        init(name: String, amountCents: Int64, frequency: Frequency = .monthly, nextDueDate: Date = .now, category: Category? = nil) {
            self.id = UUID()
            self.name = name
            self.amountCents = amountCents
            self.frequency = frequency.rawValue
            self.nextDueDate = nextDueDate
            self.category = category
        }

        // MARK: Computed

        var amount: Decimal { Decimal(amountCents) / 100 }

        var frequencyEnum: Frequency { Frequency(rawValue: frequency) ?? .monthly }

        enum Frequency: String, CaseIterable, Identifiable {
            case weekly, biweekly, monthly, yearly

            var id: String { rawValue }

            var displayName: String {
                switch self {
                case .weekly: "Weekly"
                case .biweekly: "Biweekly"
                case .monthly: "Monthly"
                case .yearly: "Yearly"
                }
            }
        }

        /// Advance nextDueDate by one frequency interval
        func advanceNextDueDate() {
            let calendar = Calendar.current
            switch frequencyEnum {
            case .weekly:
                nextDueDate = calendar.date(byAdding: .day, value: 7, to: nextDueDate) ?? nextDueDate
            case .biweekly:
                nextDueDate = calendar.date(byAdding: .day, value: 14, to: nextDueDate) ?? nextDueDate
            case .monthly:
                nextDueDate = calendar.date(byAdding: .month, value: 1, to: nextDueDate) ?? nextDueDate
            case .yearly:
                nextDueDate = calendar.date(byAdding: .year, value: 1, to: nextDueDate) ?? nextDueDate
            }
        }
    }
}

// MARK: - Migration Plan

enum BudgetVaultMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [BudgetVaultSchemaV1.self]
    }

    static var stages: [MigrationStage] { [] }
}

// MARK: - Type Aliases (convenience)

typealias Budget = BudgetVaultSchemaV1.Budget
typealias Category = BudgetVaultSchemaV1.Category
typealias Transaction = BudgetVaultSchemaV1.Transaction
typealias RecurringExpense = BudgetVaultSchemaV1.RecurringExpense
