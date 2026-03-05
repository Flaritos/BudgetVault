import SwiftUI
import SwiftData

struct DashboardPlaceholderView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("resetDay") private var resetDay = 1
    @AppStorage("currentStreak") private var currentStreak = 0

    @Query(sort: \Budget.year, order: .reverse) private var allBudgets: [Budget]
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    @AppStorage("lastSummaryViewed") private var lastSummaryViewed = ""

    @State private var viewModel = DashboardViewModel()
    @State private var showTransactionEntry = false
    @State private var editingTransaction: Transaction?
    @State private var showMonthlySummary = false

    private var currentBudget: Budget? {
        let (month, year) = DateHelpers.currentBudgetPeriod(resetDay: resetDay)
        return allBudgets.first { $0.month == month && $0.year == year }
    }

    private var visibleCategories: [Category] {
        guard let budget = currentBudget else { return [] }
        return budget.categories
            .filter { !$0.isHidden }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var previousBudget: Budget? {
        let (m, y) = DateHelpers.currentBudgetPeriod(resetDay: resetDay)
        let (pm, py) = DateHelpers.previousMonth(from: m, year: y)
        return allBudgets.first { $0.month == pm && $0.year == py }
    }

    private var showSummaryBanner: Bool {
        guard let prev = previousBudget else { return false }
        let key = "\(prev.year)-\(prev.month)"
        return lastSummaryViewed != key
    }

    private var recentTransactions: [Transaction] {
        guard let budget = currentBudget else { return [] }
        return allTransactions
            .filter { $0.date >= budget.periodStart && $0.date < budget.nextPeriodStart }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                if let budget = currentBudget {
                    if budget.totalIncomeCents == 0 {
                        EmptyStateView(
                            icon: "dollarsign.circle",
                            title: "Set Your Income",
                            message: "Set your monthly income in the Budget tab to get started."
                        )
                    } else if visibleCategories.isEmpty && recentTransactions.isEmpty {
                        EmptyStateView(
                            icon: "plus.circle.fill",
                            title: "No Expenses Yet",
                            message: "Tap + to log your first expense."
                        )
                    } else {
                        dashboardContent(budget: budget)
                    }
                } else {
                    EmptyStateView(
                        icon: "calendar.badge.exclamationmark",
                        title: "No Budget",
                        message: "Something went wrong. Try restarting the app."
                    )
                }

                // Floating + button
                if currentBudget != nil {
                    Button {
                        showTransactionEntry = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.accentColor, in: Circle())
                            .shadow(radius: 4, y: 2)
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 16)
                    .accessibilityLabel("Add transaction")
                    .accessibilityHint("Opens the transaction entry form")
                }
            }
            .navigationTitle(headerTitle)
            .sheet(isPresented: $showTransactionEntry) {
                if let budget = currentBudget {
                    TransactionEntryView(budget: budget, categories: visibleCategories)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openTransactionEntry)) { _ in
                showTransactionEntry = true
            }
            .sheet(item: $editingTransaction) { transaction in
                if let budget = currentBudget {
                    TransactionEditView(transaction: transaction, budget: budget, categories: visibleCategories)
                }
            }
            .sheet(isPresented: $showMonthlySummary) {
                if let prev = previousBudget {
                    MonthlySummaryView(budget: prev)
                }
            }
        }
    }

    // MARK: - Header

    private var headerTitle: String {
        guard let budget = currentBudget else { return "Dashboard" }
        return DateHelpers.monthYearString(month: budget.month, year: budget.year)
    }

    // MARK: - Dashboard Content

    @ViewBuilder
    private func dashboardContent(budget: Budget) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Monthly summary banner
                if showSummaryBanner, let prev = previousBudget {
                    Button {
                        showMonthlySummary = true
                        lastSummaryViewed = "\(prev.year)-\(prev.month)"
                    } label: {
                        HStack {
                            Image(systemName: "star.circle.fill")
                                .foregroundStyle(.yellow)
                            Text("Your \(DateHelpers.monthYearString(month: prev.month, year: prev.year)) summary is ready!")
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .padding(12)
                        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .tint(.primary)
                    .padding(.horizontal)
                }

                // Remaining budget header
                remainingHeader(budget: budget)

                // Envelope cards
                if !visibleCategories.isEmpty {
                    envelopeCards(budget: budget)
                }

                // Recent transactions
                if !recentTransactions.isEmpty {
                    recentTransactionsSection
                }
            }
            .padding(.bottom, 80) // space for FAB
        }
    }

    // MARK: - Remaining Budget Header

    @ViewBuilder
    private func remainingHeader(budget: Budget) -> some View {
        let pct = budget.percentRemaining
        let status = viewModel.statusText(for: pct)
        let colorName = viewModel.statusColor(for: pct)

        VStack(spacing: 8) {
            HStack {
                Text(CurrencyFormatter.format(cents: budget.remainingCents))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(statusSwiftUIColor(colorName))

                if currentStreak > 0 {
                    Spacer()
                    HStack(spacing: 2) {
                        Text("🔥")
                        Text("\(currentStreak)")
                            .font(.headline)
                    }
                    .accessibilityLabel("Logging streak: \(currentStreak) days")
                }
            }

            Text("remaining")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(status)
                .font(.caption.bold())
                .foregroundStyle(statusSwiftUIColor(colorName))
        }
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(CurrencyFormatter.format(cents: budget.remainingCents)) remaining, \(status)")
    }

    // MARK: - Envelope Cards

    @ViewBuilder
    private func envelopeCards(budget: Budget) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(visibleCategories, id: \.id) { category in
                    NavigationLink {
                        CategoryDetailView(category: category, budget: budget)
                    } label: {
                        envelopeCard(category: category, budget: budget)
                    }
                    .tint(.primary)
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func envelopeCard(category: Category, budget: Budget) -> some View {
        let spent = category.spentCents(in: budget)
        let budgeted = category.budgetedAmountCents

        VStack(spacing: 8) {
            Text(category.emoji)
                .font(.title2)
            Text(category.name)
                .font(.caption.bold())
                .lineLimit(1)

            BudgetRingView(spent: spent, budgeted: budgeted)
                .frame(width: 40, height: 40)

            Text(CurrencyFormatter.format(cents: spent))
                .font(.caption2)
            Text("of \(CurrencyFormatter.format(cents: budgeted))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 120, height: 160)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category.emoji) \(category.name): spent \(CurrencyFormatter.format(cents: spent)) of \(CurrencyFormatter.format(cents: budgeted))")
    }

    // MARK: - Recent Transactions

    @ViewBuilder
    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent")
                .font(.headline)
                .padding(.horizontal)

            ForEach(recentTransactions, id: \.id) { transaction in
                Button {
                    editingTransaction = transaction
                } label: {
                    TransactionRowView(transaction: transaction)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                }
                .tint(.primary)
            }
        }
    }

    // MARK: - Helpers

    private func statusSwiftUIColor(_ name: String) -> Color {
        switch name {
        case "green": .green
        case "yellow": .yellow
        default: .red
        }
    }
}
