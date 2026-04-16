#if DEBUG
import Foundation
import SwiftData
import BudgetVaultShared

enum DebugSeedService {

    @MainActor
    static func seedSampleData(container: ModelContainer) {
        let context = container.mainContext
        let calendar = Calendar.current

        // Check if data already exists
        let check = FetchDescriptor<Budget>()
        guard (try? context.fetchCount(check)) == 0 else { return }

        // MARK: - Current Month Budget (March 2026)

        let budget = Budget(month: 3, year: 2026, totalIncomeCents: 500000, resetDay: 1)
        context.insert(budget)

        let rent = Category(name: "Rent", emoji: "\u{1F3E0}", budgetedAmountCents: 150000, color: "#5856D6", sortOrder: 0)
        let groceries = Category(name: "Groceries", emoji: "\u{1F6D2}", budgetedAmountCents: 75000, color: "#34C759", sortOrder: 1)
        let transport = Category(name: "Transport", emoji: "\u{1F697}", budgetedAmountCents: 50000, color: "#FF9500", sortOrder: 2)
        let dining = Category(name: "Dining Out", emoji: "\u{1F37D}\u{FE0F}", budgetedAmountCents: 40000, color: "#FF2D55", sortOrder: 3)
        let entertainment = Category(name: "Entertainment", emoji: "\u{1F3AC}", budgetedAmountCents: 30000, color: "#AF52DE", sortOrder: 4)
        let utilities = Category(name: "Utilities", emoji: "\u{1F4A1}", budgetedAmountCents: 15000, color: "#FFCC00", sortOrder: 5)

        let allCats = [rent, groceries, transport, dining, entertainment, utilities]
        for cat in allCats {
            cat.budget = budget
        }

        // MARK: - Transactions for current month (March 1-6, 2026)

        func date(_ day: Int, _ hour: Int = 12) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour)) ?? Date()
        }

        // Rent - big payment day 1
        addTx(context, cat: rent, cents: 150000, note: "March rent", date: date(1))

        // Groceries - spread across days
        addTx(context, cat: groceries, cents: 6532, note: "Trader Joe's", date: date(1, 18))
        addTx(context, cat: groceries, cents: 3215, note: "Corner store", date: date(2, 10))
        addTx(context, cat: groceries, cents: 8740, note: "Whole Foods", date: date(3, 14))
        addTx(context, cat: groceries, cents: 4520, note: "Weekly produce", date: date(4, 11))
        addTx(context, cat: groceries, cents: 2890, note: "Snacks", date: date(5, 16))
        addTx(context, cat: groceries, cents: 15200, note: "Costco bulk run", date: date(6, 10)) // anomaly!

        // Transport
        addTx(context, cat: transport, cents: 276, note: "Bus fare", date: date(1, 8))
        addTx(context, cat: transport, cents: 276, note: "Bus fare", date: date(2, 8))
        addTx(context, cat: transport, cents: 2450, note: "Uber to airport", date: date(3, 6))
        addTx(context, cat: transport, cents: 276, note: "Bus fare", date: date(4, 8))
        addTx(context, cat: transport, cents: 4500, note: "Gas fillup", date: date(5, 17))
        addTx(context, cat: transport, cents: 276, note: "Bus fare", date: date(6, 8))

        // Dining Out - heavier on weekends
        addTx(context, cat: dining, cents: 1850, note: "Coffee & pastry", date: date(1, 9))  // Saturday
        addTx(context, cat: dining, cents: 4200, note: "Brunch with friends", date: date(1, 13))
        addTx(context, cat: dining, cents: 6500, note: "Dinner date", date: date(1, 19))  // big weekend spend
        addTx(context, cat: dining, cents: 1250, note: "Lunch", date: date(2, 12))  // Sunday
        addTx(context, cat: dining, cents: 3800, note: "Happy hour", date: date(4, 18))
        addTx(context, cat: dining, cents: 850, note: "Coffee", date: date(5, 9))
        addTx(context, cat: dining, cents: 5200, note: "Birthday dinner", date: date(6, 20)) // anomaly

        // Entertainment
        addTx(context, cat: entertainment, cents: 1599, note: "Netflix", date: date(1))
        addTx(context, cat: entertainment, cents: 1499, note: "Spotify", date: date(1))
        addTx(context, cat: entertainment, cents: 3500, note: "Concert tickets", date: date(3, 20))
        addTx(context, cat: entertainment, cents: 1800, note: "Movie night", date: date(5, 21))

        // Utilities
        addTx(context, cat: utilities, cents: 8500, note: "Electric bill", date: date(2))
        addTx(context, cat: utilities, cents: 4500, note: "Internet", date: date(3))

        // Income
        let incomeTx = Transaction(amountCents: 500000, note: "Salary", date: date(1, 9), isIncome: true)
        context.insert(incomeTx)

        // MARK: - Previous Month Budget (February 2026)

        let prevBudget = Budget(month: 2, year: 2026, totalIncomeCents: 500000, resetDay: 1)
        context.insert(prevBudget)

        let prevRent = Category(name: "Rent", emoji: "\u{1F3E0}", budgetedAmountCents: 150000, color: "#5856D6", sortOrder: 0)
        let prevGroceries = Category(name: "Groceries", emoji: "\u{1F6D2}", budgetedAmountCents: 75000, color: "#34C759", sortOrder: 1)
        let prevTransport = Category(name: "Transport", emoji: "\u{1F697}", budgetedAmountCents: 50000, color: "#FF9500", sortOrder: 2)
        let prevDining = Category(name: "Dining Out", emoji: "\u{1F37D}\u{FE0F}", budgetedAmountCents: 40000, color: "#FF2D55", sortOrder: 3)
        let prevEntertainment = Category(name: "Entertainment", emoji: "\u{1F3AC}", budgetedAmountCents: 30000, color: "#AF52DE", sortOrder: 4)
        let prevUtilities = Category(name: "Utilities", emoji: "\u{1F4A1}", budgetedAmountCents: 15000, color: "#FFCC00", sortOrder: 5)

        let prevCats = [prevRent, prevGroceries, prevTransport, prevDining, prevEntertainment, prevUtilities]
        for cat in prevCats {
            cat.budget = prevBudget
        }

        // Feb transactions (complete month - heavier spending for comparison)
        func febDate(_ day: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 2, day: day, hour: 12)) ?? Date()
        }

        addTx(context, cat: prevRent, cents: 150000, note: "Feb rent", date: febDate(1))
        addTx(context, cat: prevGroceries, cents: 18000, note: "Weekly groceries", date: febDate(2))
        addTx(context, cat: prevGroceries, cents: 15500, note: "Weekly groceries", date: febDate(9))
        addTx(context, cat: prevGroceries, cents: 16200, note: "Weekly groceries", date: febDate(16))
        addTx(context, cat: prevGroceries, cents: 14800, note: "Weekly groceries", date: febDate(23))
        addTx(context, cat: prevTransport, cents: 4500, note: "Gas", date: febDate(5))
        addTx(context, cat: prevTransport, cents: 2800, note: "Uber", date: febDate(12))
        addTx(context, cat: prevTransport, cents: 4500, note: "Gas", date: febDate(19))
        addTx(context, cat: prevTransport, cents: 1500, note: "Parking", date: febDate(25))
        addTx(context, cat: prevDining, cents: 8500, note: "Valentine's dinner", date: febDate(14))
        addTx(context, cat: prevDining, cents: 3200, note: "Lunch", date: febDate(7))
        addTx(context, cat: prevDining, cents: 4100, note: "Takeout", date: febDate(20))
        addTx(context, cat: prevDining, cents: 2800, note: "Coffee dates", date: febDate(28))
        addTx(context, cat: prevEntertainment, cents: 1599, note: "Netflix", date: febDate(1))
        addTx(context, cat: prevEntertainment, cents: 1499, note: "Spotify", date: febDate(1))
        addTx(context, cat: prevEntertainment, cents: 6000, note: "Concert", date: febDate(15))
        addTx(context, cat: prevEntertainment, cents: 2500, note: "Movie", date: febDate(22))
        addTx(context, cat: prevUtilities, cents: 9200, note: "Electric", date: febDate(3))
        addTx(context, cat: prevUtilities, cents: 4500, note: "Internet", date: febDate(5))

        // MARK: - Debt Accounts

        let creditCard = DebtAccount(
            name: "Chase Sapphire",
            emoji: "\u{1F4B3}",
            originalBalanceCents: 850000,
            currentBalanceCents: 620000,
            interestRate: 21.99,
            minimumPaymentCents: 15000,
            dueDay: 15
        )
        context.insert(creditCard)

        let payment1 = DebtPayment(amountCents: 15000, note: "Min payment")
        payment1.date = febDate(14)
        payment1.debtAccount = creditCard
        context.insert(payment1)

        let payment2 = DebtPayment(amountCents: 50000, note: "Extra payment")
        payment2.date = febDate(28)
        payment2.debtAccount = creditCard
        context.insert(payment2)

        let studentLoan = DebtAccount(
            name: "Student Loan",
            emoji: "\u{1F393}",
            originalBalanceCents: 2500000,
            currentBalanceCents: 1800000,
            interestRate: 5.5,
            minimumPaymentCents: 25000,
            dueDay: 1
        )
        context.insert(studentLoan)

        let slPayment = DebtPayment(amountCents: 25000, note: "Monthly payment")
        slPayment.date = febDate(1)
        slPayment.debtAccount = studentLoan
        context.insert(slPayment)

        // MARK: - Net Worth Accounts

        let checking = NetWorthAccount(name: "Checking", emoji: "\u{1F3E6}", balanceCents: 350000, accountType: "asset")
        let savings = NetWorthAccount(name: "Savings", emoji: "\u{1F4B0}", balanceCents: 1200000, accountType: "asset")
        let retirement = NetWorthAccount(name: "401k", emoji: "\u{1F4C8}", balanceCents: 4500000, accountType: "asset")
        let ccDebt = NetWorthAccount(name: "Credit Card", emoji: "\u{1F4B3}", balanceCents: 620000, accountType: "liability")
        let slDebt = NetWorthAccount(name: "Student Loan", emoji: "\u{1F393}", balanceCents: 1800000, accountType: "liability")

        [checking, savings, retirement, ccDebt, slDebt].forEach { context.insert($0) }

        // Net worth snapshots (3 months of history)
        let snap1 = NetWorthSnapshot(
            date: calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!,
            totalAssetsCents: 5800000,
            totalLiabilitiesCents: 2600000
        )
        let snap2 = NetWorthSnapshot(
            date: calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!,
            totalAssetsCents: 5950000,
            totalLiabilitiesCents: 2500000
        )
        let snap3 = NetWorthSnapshot(
            date: calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))!,
            totalAssetsCents: 6050000,
            totalLiabilitiesCents: 2420000
        )
        [snap1, snap2, snap3].forEach { context.insert($0) }

        // MARK: - Streak Data

        // Enable premium for testing
        UserDefaults.standard.set(true, forKey: AppStorageKeys.isPremium)
        UserDefaults.standard.set(true, forKey: AppStorageKeys.debugPremiumOverride)
        UserDefaults.standard.set(12, forKey: AppStorageKeys.currentStreak)
        UserDefaults.standard.set(DateHelpers.dateString(calendar.startOfDay(for: Date())), forKey: AppStorageKeys.lastLogDate)
        UserDefaults.standard.set(true, forKey: AppStorageKeys.hasLoggedFirstTransaction)
        UserDefaults.standard.set(true, forKey: AppStorageKeys.hasCompletedOnboarding)

        if !SafeSave.save(context) { context.rollback() }
    }

    /// Seeds 15 days of realistic transactions into the user's existing budget
    @MainActor
    static func seed15DaysOfData(container: ModelContainer) {
        let context = container.mainContext
        let calendar = Calendar.current

        // Find the current budget
        let descriptor = FetchDescriptor<Budget>(
            sortBy: [SortDescriptor(\Budget.year, order: .reverse), SortDescriptor(\Budget.month, order: .reverse)]
        )
        guard let budget = try? context.fetch(descriptor).first else { return }
        let categories = (budget.categories ?? []).sorted { $0.sortOrder < $1.sortOrder }
        guard categories.count >= 3 else { return }

        // Check if we already seeded (avoid duplicates)
        let txCheck = FetchDescriptor<Transaction>()
        let existingCount = (try? context.fetchCount(txCheck)) ?? 0
        guard existingCount < 10 else { return } // already has data

        let today = Date()

        func dayAgo(_ days: Int, hour: Int = 12) -> Date {
            let base = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: today)) ?? today
            return base.addingTimeInterval(TimeInterval(hour * 3600))
        }

        // Map categories by name for easy access
        let catMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.name.lowercased(), $0) })
        let cat1 = categories[0] // e.g., Rent/Housing
        let cat2 = categories[1] // e.g., Groceries
        let cat3 = categories[2] // e.g., Transport
        let cat4 = categories.count > 3 ? categories[3] : cat1
        let cat5 = categories.count > 4 ? categories[4] : cat2
        let cat6 = categories.count > 5 ? categories[5] : cat3

        // Day 1 (15 days ago) — big rent/housing payment
        addTx(context, cat: cat1, cents: 125000, note: "Monthly rent", date: dayAgo(15, hour: 9))
        addTx(context, cat: cat2, cents: 6532, note: "Trader Joe's", date: dayAgo(15, hour: 18))

        // Day 2
        addTx(context, cat: cat3, cents: 2450, note: "Uber to work", date: dayAgo(14, hour: 8))
        addTx(context, cat: cat4, cents: 1850, note: "Coffee & pastry", date: dayAgo(14, hour: 9))

        // Day 3
        addTx(context, cat: cat2, cents: 8740, note: "Whole Foods", date: dayAgo(13, hour: 14))
        addTx(context, cat: cat5, cents: 1599, note: "Netflix", date: dayAgo(13, hour: 12))

        // Day 4
        addTx(context, cat: cat3, cents: 276, note: "Bus fare", date: dayAgo(12, hour: 8))
        addTx(context, cat: cat4, cents: 4200, note: "Brunch with friends", date: dayAgo(12, hour: 13))
        addTx(context, cat: cat2, cents: 3215, note: "Corner store", date: dayAgo(12, hour: 17))

        // Day 5 — no-spend day! (skip)

        // Day 6
        addTx(context, cat: cat3, cents: 4500, note: "Gas fillup", date: dayAgo(10, hour: 17))
        addTx(context, cat: cat4, cents: 850, note: "Coffee", date: dayAgo(10, hour: 9))

        // Day 7 — weekend splurge
        addTx(context, cat: cat4, cents: 6500, note: "Dinner date", date: dayAgo(9, hour: 19))
        addTx(context, cat: cat5, cents: 3500, note: "Concert tickets", date: dayAgo(9, hour: 20))

        // Day 8
        addTx(context, cat: cat2, cents: 4520, note: "Weekly produce", date: dayAgo(8, hour: 11))
        addTx(context, cat: cat6, cents: 8500, note: "Electric bill", date: dayAgo(8, hour: 12))

        // Day 9
        addTx(context, cat: cat3, cents: 276, note: "Bus fare", date: dayAgo(7, hour: 8))
        addTx(context, cat: cat4, cents: 1250, note: "Lunch", date: dayAgo(7, hour: 12))

        // Day 10
        addTx(context, cat: cat2, cents: 15200, note: "Costco bulk run", date: dayAgo(6, hour: 10))

        // Day 11
        addTx(context, cat: cat4, cents: 3800, note: "Happy hour", date: dayAgo(5, hour: 18))
        addTx(context, cat: cat3, cents: 276, note: "Bus fare", date: dayAgo(5, hour: 8))

        // Day 12 — no-spend day! (skip)

        // Day 13
        addTx(context, cat: cat5, cents: 1800, note: "Movie night", date: dayAgo(3, hour: 21))
        addTx(context, cat: cat2, cents: 2890, note: "Snacks", date: dayAgo(3, hour: 16))

        // Day 14
        addTx(context, cat: cat4, cents: 5200, note: "Birthday dinner", date: dayAgo(2, hour: 20))
        addTx(context, cat: cat6, cents: 4500, note: "Internet bill", date: dayAgo(2, hour: 12))

        // Day 15 (yesterday)
        addTx(context, cat: cat2, cents: 5680, note: "Grocery run", date: dayAgo(1, hour: 17))
        addTx(context, cat: cat3, cents: 1200, note: "Parking", date: dayAgo(1, hour: 10))
        addTx(context, cat: cat4, cents: 950, note: "Coffee", date: dayAgo(1, hour: 9))

        // Income — paycheck
        let income = Transaction(amountCents: budget.totalIncomeCents, note: "Paycheck", date: dayAgo(14, hour: 9), isIncome: true)
        context.insert(income)

        // Set streak
        UserDefaults.standard.set(12, forKey: AppStorageKeys.currentStreak)
        UserDefaults.standard.set(DateHelpers.dateString(calendar.startOfDay(for: today)), forKey: AppStorageKeys.lastLogDate)

        if !SafeSave.save(context) { context.rollback() }
    }

    private static func addTx(_ context: ModelContext, cat: Category, cents: Int64, note: String, date: Date) {
        let tx = Transaction(amountCents: cents, note: note, date: date)
        tx.category = cat
        context.insert(tx)
    }
}
#endif
