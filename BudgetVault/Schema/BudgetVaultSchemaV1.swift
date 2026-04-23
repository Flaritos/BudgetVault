import Foundation
import SwiftData

// MARK: - SchemaV2 Migration Checklist (requires iOS 18 minimum)
//
// When iOS 18 becomes the minimum deployment target, create BudgetVaultSchemaV2 with:
//
// 1. Transaction Indexes (query performance):
//    - #Index<Transaction>([\.date])
//      Speeds up date-range queries in dashboard, history, and reports.
//    - #Index<Transaction>([\.category, \.date])
//      Compound index for per-category spending calculations (spentCents(in:)).
//    - #Index<Transaction>([\.isIncome, \.date])
//      Speeds up income-vs-expense filtering across date ranges.
//
// 2. Budget Indexes:
//    - #Index<Budget>([\.year, \.month])
//      Speeds up budget lookup by period (used in rollover, dedup, navigation).
//
// 3. RecurringExpense Indexes:
//    - #Index<RecurringExpense>([\.nextDueDate])
//      Speeds up overdue processing in RecurringExpenseScheduler.
//    - #Index<RecurringExpense>([\.isActive, \.nextDueDate])
//      Compound index for active-only overdue queries.
//
// 4. DebtPayment Indexes:
//    - #Index<DebtPayment>([\.date])
//      Speeds up payment history queries.
//
// 5. NetWorthSnapshot Indexes:
//    - #Index<NetWorthSnapshot>([\.date])
//      Speeds up chart/trend queries.
//
// 6. Migration Stage:
//    - Add BudgetVaultSchemaV2 to BudgetVaultMigrationPlan.schemas
//    - Add a lightweight migration stage from V1 to V2 (index-only changes
//      are additive and should not require custom migration logic).
//
// 7. Remove the inline TODO comment on Transaction.date below.

enum BudgetVaultSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Budget.self, Category.self, Transaction.self, RecurringExpense.self,
         DebtAccount.self, DebtPayment.self, NetWorthAccount.self, NetWorthSnapshot.self]
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
        var categories: [Category]? = []

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
            let day = min(self.resetDay, 28)
            return Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
        }

        /// Exclusive upper bound — use `date < nextPeriodStart` (half-open interval)
        var nextPeriodStart: Date {
            let day = min(self.resetDay, 28)
            let start = Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
            return Calendar.current.date(byAdding: .month, value: 1, to: start) ?? Date()
        }

        /// Total spent in this budget period (non-income transactions across all categories)
        func totalSpentCents() -> Int64 {
            (categories ?? []).reduce(0) { $0 + $1.spentCents(in: self) }
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
        var goalAmountCents: Int64?
        var goalDate: Date?
        var goalType: String? // "savings" or "spending" (nil = spending, the default)

        @Relationship(deleteRule: .cascade, inverse: \Transaction.category)
        var transactions: [Transaction]? = []

        // Audit 2026-04-23 DB P1: explicit `.nullify` matches inferred
        // behavior; consistent with Transaction.category (P1-30) and
        // prevents silent regression if inverse is ever re-declared.
        @Relationship(deleteRule: .nullify)
        var budget: Budget?

        @Relationship(deleteRule: .nullify, inverse: \RecurringExpense.category)
        var recurringExpenses: [RecurringExpense]? = []

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
            (transactions ?? [])
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

        // MARK: Savings Goal Computed

        var isSavingsGoal: Bool { goalType == "savings" }

        var goalProgress: Double {
            guard let goal = goalAmountCents, goal > 0 else { return 0 }
            return min(Double(budgetedAmountCents) / Double(goal), 1.0)
        }

        var monthsToGoal: Int? {
            guard let goal = goalAmountCents, let date = goalDate else { return nil }
            let remaining = goal - budgetedAmountCents
            guard remaining > 0 else { return 0 }
            let months = Calendar.current.dateComponents([.month], from: Date(), to: date).month ?? 0
            return max(months, 0)
        }

        var requiredMonthlyContribution: Int64? {
            guard let goal = goalAmountCents, let date = goalDate else { return nil }
            let remaining = goal - budgetedAmountCents
            guard remaining > 0 else { return 0 }
            let months = max(Calendar.current.dateComponents([.month], from: Date(), to: date).month ?? 1, 1)
            return remaining / Int64(months)
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
        /// v3.2: user has manually marked this transaction as reviewed/verified.
        /// Lightweight reconciliation — not a full YNAB-style flow. Defaults
        /// to false so existing rows auto-migrate cleanly.
        var isReconciled: Bool = false

        // Audit 2026-04-22 P1-30: previously a bare `Category?` relied
        // on SwiftData's implicit deleteRule inference (`.nullify` on
        // the owning side, `.cascade` on the inverse at Category.
        // transactions:124). Spelling out `.nullify` here prevents a
        // future refactor from silently inverting the intent — if a
        // category is deleted, its transactions should orphan, not
        // disappear.
        @Relationship(deleteRule: .nullify)
        var category: Category?

        // Audit 2026-04-23 DB P0: explicit `.nullify`. If a
        // RecurringExpense is deleted, its posted Transactions should
        // orphan (preserve spend history), not cascade.
        @Relationship(deleteRule: .nullify, inverse: \RecurringExpense.generatedTransactions)
        var recurringExpense: RecurringExpense?

        init(amountCents: Int64, note: String = "", date: Date = .now, isIncome: Bool = false, category: Category? = nil) {
            self.id = UUID()
            self.amountCents = amountCents
            self.note = note
            self.date = date
            self.isIncome = isIncome
            self.createdAt = Date.now
            self.category = category
            self.isReconciled = false
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

        // Audit 2026-04-23 DB P0: explicit `.nullify`. If a Category
        // is deleted, its recurring rules should orphan (user can
        // reassign), not disappear.
        @Relationship(deleteRule: .nullify)
        var category: Category?

        @Relationship(deleteRule: .nullify)
        var generatedTransactions: [Transaction]? = []

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

    // MARK: - DebtAccount

    @Model
    final class DebtAccount {
        var id: UUID = UUID()
        var name: String = ""
        var emoji: String = "💳"
        var originalBalanceCents: Int64 = 0
        var currentBalanceCents: Int64 = 0
        var interestRate: Double = 0  // APR as percentage (e.g., 19.99)
        var minimumPaymentCents: Int64 = 0
        var dueDay: Int = 1  // day of month
        var createdAt: Date = Date.now
        var isActive: Bool = true

        @Relationship(deleteRule: .cascade, inverse: \DebtPayment.debtAccount)
        var payments: [DebtPayment]? = []

        init(name: String, emoji: String = "💳", originalBalanceCents: Int64, currentBalanceCents: Int64, interestRate: Double = 0, minimumPaymentCents: Int64 = 0, dueDay: Int = 1) {
            self.id = UUID()
            self.name = name
            self.emoji = emoji
            self.originalBalanceCents = originalBalanceCents
            self.currentBalanceCents = currentBalanceCents
            self.interestRate = interestRate
            self.minimumPaymentCents = minimumPaymentCents
            self.dueDay = dueDay
            self.createdAt = Date.now
        }

        // MARK: Computed

        var paidOffPercentage: Double {
            guard originalBalanceCents > 0 else { return 0 }
            let paid = originalBalanceCents - currentBalanceCents
            return min(max(Double(paid) / Double(originalBalanceCents), 0), 1.0)
        }

        var totalPaidCents: Int64 { originalBalanceCents - currentBalanceCents }

        var originalBalance: Decimal { Decimal(originalBalanceCents) / 100 }
        var currentBalance: Decimal { Decimal(currentBalanceCents) / 100 }
        var minimumPayment: Decimal { Decimal(minimumPaymentCents) / 100 }

        /// Estimate months to payoff at minimum payment with interest
        var estimatedMonthsToPayoff: Int? {
            guard currentBalanceCents > 0, minimumPaymentCents > 0 else { return nil }
            let monthlyRate = interestRate / 100.0 / 12.0
            if monthlyRate <= 0 {
                // No interest — simple division
                return Int(ceil(Double(currentBalanceCents) / Double(minimumPaymentCents)))
            }
            // Standard amortization: n = -ln(1 - r*P/M) / ln(1+r)
            let r = monthlyRate
            let principal = Double(currentBalanceCents) / 100.0
            let payment = Double(minimumPaymentCents) / 100.0
            let factor = 1.0 - (r * principal / payment)
            guard factor > 0 else { return nil } // Payment too low to cover interest
            let months = -log(factor) / log(1.0 + r)
            return Int(ceil(months))
        }
    }

    // MARK: - DebtPayment

    @Model
    final class DebtPayment {
        var id: UUID = UUID()
        var amountCents: Int64 = 0
        var date: Date = Date.now
        var note: String = ""

        // Audit 2026-04-23 DB P0: explicit `.nullify`. If a DebtAccount
        // is deleted, its payment history should orphan (not cascade
        // — audit trail of repayments should survive).
        @Relationship(deleteRule: .nullify)
        var debtAccount: DebtAccount?

        init(amountCents: Int64, date: Date = .now, note: String = "") {
            self.id = UUID()
            self.amountCents = amountCents
            self.date = date
            self.note = note
        }

        // MARK: Computed

        var amount: Decimal { Decimal(amountCents) / 100 }
    }

    // MARK: - NetWorthAccount

    @Model
    final class NetWorthAccount {
        var id: UUID = UUID()
        var name: String = ""
        var emoji: String = "🏦"
        var balanceCents: Int64 = 0
        var accountType: String = "asset"  // "asset" or "liability"
        var lastUpdated: Date = Date.now
        var isActive: Bool = true

        init(name: String, emoji: String = "🏦", balanceCents: Int64 = 0, accountType: String = "asset") {
            self.id = UUID()
            self.name = name
            self.emoji = emoji
            self.balanceCents = balanceCents
            self.accountType = accountType
            self.lastUpdated = Date.now
        }

        // MARK: Computed

        var balance: Decimal { Decimal(balanceCents) / 100 }
        var isAsset: Bool { accountType == "asset" }
        var isLiability: Bool { accountType == "liability" }
    }

    // MARK: - NetWorthSnapshot

    @Model
    final class NetWorthSnapshot {
        var id: UUID = UUID()
        var date: Date = Date.now
        var totalAssetsCents: Int64 = 0
        var totalLiabilitiesCents: Int64 = 0
        var netWorthCents: Int64 = 0

        init(date: Date = .now, totalAssetsCents: Int64, totalLiabilitiesCents: Int64) {
            self.id = UUID()
            self.date = date
            self.totalAssetsCents = totalAssetsCents
            self.totalLiabilitiesCents = totalLiabilitiesCents
            self.netWorthCents = totalAssetsCents - totalLiabilitiesCents
        }

        // MARK: Computed

        var totalAssets: Decimal { Decimal(totalAssetsCents) / 100 }
        var totalLiabilities: Decimal { Decimal(totalLiabilitiesCents) / 100 }
        var netWorth: Decimal { Decimal(netWorthCents) / 100 }
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
typealias DebtAccount = BudgetVaultSchemaV1.DebtAccount
typealias DebtPayment = BudgetVaultSchemaV1.DebtPayment
typealias NetWorthAccount = BudgetVaultSchemaV1.NetWorthAccount
typealias NetWorthSnapshot = BudgetVaultSchemaV1.NetWorthSnapshot
