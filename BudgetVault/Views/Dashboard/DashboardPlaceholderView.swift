import SwiftUI
import SwiftData

struct DashboardPlaceholderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppStorageKeys.resetDay) private var resetDay = 1
    @AppStorage(AppStorageKeys.currentStreak) private var currentStreak = 0

    // MARK: - Scaled Metrics for Dynamic Type
    @ScaledMetric(relativeTo: .body) private var fabSize: CGFloat = 56
    @ScaledMetric(relativeTo: .body) private var envelopeCardWidth: CGFloat = 150
    @ScaledMetric(relativeTo: .body) private var envelopeCardHeight: CGFloat = 185
    @ScaledMetric(relativeTo: .body) private var envelopeCardHeightTall: CGFloat = 200
    @ScaledMetric(relativeTo: .body) private var ringSize: CGFloat = 56
    @ScaledMetric(relativeTo: .body) private var billIconWidth: CGFloat = 36

    @Query(sort: [SortDescriptor(\Budget.year, order: .reverse), SortDescriptor(\Budget.month, order: .reverse)]) private var allBudgets: [Budget]
    // TODO: iOS 18 - Add @Query predicate for budget filtering to avoid loading all records
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: \RecurringExpense.nextDueDate) private var recurringExpenses: [RecurringExpense]

    @AppStorage(AppStorageKeys.lastSummaryViewed) private var lastSummaryViewed = ""
    @AppStorage(AppStorageKeys.hasCompletedOnboarding) private var hasCompletedOnboarding = true

    @State private var viewModel = DashboardViewModel()
    @State private var hasAppeared = false
    @State private var showTransactionEntry = false
    @State private var editingTransaction: Transaction?
    @State private var showMonthlySummary = false
    @State private var showPaywall = false
    @State private var showMonthlyWrapped = false
    @State private var showAchievements = false
    @State private var newAchievementBanner: String?
    @AppStorage(AppStorageKeys.isPremium) private var isPremium = false

    private var currentBudget: Budget? {
        let (month, year) = DateHelpers.currentBudgetPeriod(resetDay: resetDay)
        return allBudgets.first { $0.month == month && $0.year == year }
    }

    private var visibleCategories: [Category] {
        guard let budget = currentBudget else { return [] }
        return (budget.categories ?? [])
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

    private var showWrappedCard: Bool {
        // Show when month is >= 80% complete or when viewing a completed month
        guard let budget = currentBudget else { return false }
        let fraction = dayProgressFraction(budget: budget)
        return fraction >= 0.8 || previousBudget != nil
    }

    private var recentTransactions: [Transaction] {
        guard let budget = currentBudget else { return [] }
        return Array(allTransactions
            .lazy
            .filter { $0.date >= budget.periodStart && $0.date < budget.nextPeriodStart }
            .prefix(5))
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
                            message: "Tap + to log your first expense.",
                            actionLabel: "Add Expense",
                            action: { showTransactionEntry = true }
                        )
                    } else {
                        dashboardContent(budget: budget)
                    }
                } else {
                    EmptyStateView(
                        icon: "calendar.badge.exclamationmark",
                        title: "No Budget for This Period",
                        message: "Create a new budget to start tracking your spending.",
                        actionLabel: "Create Budget",
                        action: { hasCompletedOnboarding = false }
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
                            .frame(width: fabSize, height: fabSize)
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
                        .presentationDragIndicator(.visible)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openTransactionEntry)) { _ in
                showTransactionEntry = true
            }
            .sheet(item: $editingTransaction) { transaction in
                if let budget = currentBudget {
                    TransactionEditView(transaction: transaction, budget: budget, categories: visibleCategories)
                        .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showMonthlySummary) {
                if let prev = previousBudget {
                    MonthlySummaryView(budget: prev)
                        .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showMonthlyWrapped) {
                if let budget = currentBudget {
                    MonthlyWrappedView(budget: budget, allTransactions: allTransactions)
                        .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showAchievements) {
                AchievementGridView()
                    .presentationDragIndicator(.visible)
            }
            .task {
                // Check spending alerts
                if let budget = currentBudget {
                    NotificationService.checkAndScheduleCategoryAlerts(budget: budget)

                    // Check achievements
                    let newBadges = AchievementService.checkAchievements(
                        budget: budget,
                        transactions: allTransactions
                    )
                    if let first = newBadges.first {
                        HapticManager.notification(.success)
                        newAchievementBanner = first.title
                        try? await Task.sleep(for: .seconds(3))
                        newAchievementBanner = nil
                    }
                }
            }
        }
        .overlay(alignment: .top) {
            if let badge = newAchievementBanner {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.yellow)
                    Text("Achievement Unlocked: \(badge)")
                        .font(.subheadline.bold())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .shadow(radius: 4, y: 2)
                .scaleEffect(newAchievementBanner != nil ? 1.0 : 0.5)
                .padding(.top, 8)
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                .animation(reduceMotion ? .default : .spring(response: 0.4, dampingFraction: 0.6), value: newAchievementBanner)
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
                        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .tint(.primary)
                    .padding(.horizontal)
                    .accessibilityLabel("Monthly summary for \(DateHelpers.monthYearString(month: prev.month, year: prev.year)) is ready. Tap to view.")
                }

                // Hero budget card
                heroCard(budget: budget)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)

                // Spending velocity
                spendingVelocity(budget: budget)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)

                // Envelope cards
                if !visibleCategories.isEmpty {
                    envelopeCards(budget: budget)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 20)
                }

                // Savings goals
                if !goalCategories.isEmpty {
                    savingsGoalsSection
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 20)
                }

                // Monthly Wrapped card (premium)
                if showWrappedCard {
                    wrappedCard
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 20)
                }

                // Recent achievements
                achievementsPreview
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)

                // Upcoming bills
                upcomingBills
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)

                // Recent transactions
                if !recentTransactions.isEmpty {
                    recentTransactionsSection
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 20)
                }

                // Premium teaser
                if !isPremium {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.yellow)
                            VStack(alignment: .leading) {
                                Text("Unlock Premium Insights")
                                    .font(.subheadline.bold())
                                Text("Track trends, compare months, and more")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .tint(.primary)
                    .padding(.horizontal)
                    .accessibilityLabel("Unlock Premium Insights. Track trends, compare months, and more.")
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                }
            }
            .padding(.bottom, 80) // space for FAB
            .onAppear {
                guard !hasAppeared else { return }
                if reduceMotion {
                    hasAppeared = true
                } else {
                    withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                        hasAppeared = true
                    }
                }
            }
        }
    }

    // MARK: - Hero Budget Card

    @ViewBuilder
    private func heroCard(budget: Budget) -> some View {
        let pct = budget.percentRemaining
        let status = viewModel.statusText(for: pct)
        let daysRemaining = daysRemainingInPeriod(budget: budget)
        let dailyAllowanceCents = budget.remainingCents > 0 ? budget.remainingCents / Int64(max(daysRemaining, 1)) : 0

        ZStack(alignment: .topTrailing) {
            VaultDialMark(size: 24)
                .opacity(0.3)
                .padding(12)

            VStack(spacing: 12) {
            // Streak badge row
            if currentStreak > 0 {
                HStack {
                    Spacer()
                    HStack(spacing: 2) {
                        Text("\u{1F525}")
                        Text("\(currentStreak)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.2), in: Capsule())
                    .accessibilityLabel("Logging streak: \(currentStreak) days")
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            Text(CurrencyFormatter.format(cents: budget.remainingCents))
                .font(BudgetVaultTheme.heroAmount)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.default, value: budget.remainingCents)
                .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                .padding(.top, currentStreak > 0 ? 0 : 24)

            Text("of \(CurrencyFormatter.format(cents: budget.totalIncomeCents)) remaining")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))

            Text("You can spend \(CurrencyFormatter.format(cents: dailyAllowanceCents))/day")
                .font(.callout.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))

            ProgressView(value: dayProgressFraction(budget: budget))
                .tint(.white)
                .padding(.horizontal, 24)

            Text(budgetDayProgress(budget: budget))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            // Status badge
            Text(status)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(.white.opacity(0.2), in: Capsule())
                .padding(.bottom, 24)
        }
        }
        .frame(maxWidth: .infinity)
        .background(BudgetVaultTheme.budgetGradient(for: pct))
        .clipShape(RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusXL, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 16, y: 8)
        .padding(.horizontal, BudgetVaultTheme.spacingLG)
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(CurrencyFormatter.format(cents: budget.remainingCents)) remaining of \(CurrencyFormatter.format(cents: budget.totalIncomeCents)), \(status)")
    }

    // MARK: - Spending Velocity

    @ViewBuilder
    private func spendingVelocity(budget: Budget) -> some View {
        let calendar = Calendar.current
        let today = Date()
        let start = budget.periodStart
        let end = budget.nextPeriodStart
        let totalDays = max(calendar.dateComponents([.day], from: start, to: end).day ?? 30, 1)
        let elapsed = max(calendar.dateComponents([.day], from: start, to: today).day ?? 0, 1)
        let totalSpent = budget.totalSpentCents()

        if totalSpent > 0 && elapsed > 0 {
            let dailyRate = Double(totalSpent) / Double(elapsed)
            let projectedCents = Int64(dailyRate * Double(totalDays))
            let overBudget = projectedCents > budget.totalIncomeCents

            HStack(spacing: 6) {
                Image(systemName: overBudget ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(overBudget ? BudgetVaultTheme.negative : BudgetVaultTheme.positive)

                Text("At this pace, you'll spend \(CurrencyFormatter.format(cents: projectedCents)) this month")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, BudgetVaultTheme.spacingMD)
            .padding(.vertical, BudgetVaultTheme.spacingSM)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusSM))
            .padding(.horizontal, BudgetVaultTheme.spacingLG)
        }
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

    @Environment(\.colorScheme) private var colorScheme

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
                .frame(width: ringSize, height: ringSize)

            Text(CurrencyFormatter.format(cents: spent))
                .font(.caption)
            Text("of \(CurrencyFormatter.format(cents: budgeted))")
                .font(.caption)
                .foregroundStyle(.secondary)

            if category.rollOverUnspent {
                Text("Rolls over")
                    .font(.caption2)
                    .foregroundStyle(BudgetVaultTheme.info)
            }
        }
        .frame(width: envelopeCardWidth, height: category.rollOverUnspent ? envelopeCardHeightTall : envelopeCardHeight)
        .background(
            RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD)
                .fill(Color(hex: category.color).opacity(colorScheme == .dark ? 0.15 : 0.08))
        )
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        .overlay(RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD).strokeBorder(.secondary.opacity(0.1)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category.emoji) \(category.name): spent \(CurrencyFormatter.format(cents: spent)) of \(CurrencyFormatter.format(cents: budgeted))")
    }

    // MARK: - Upcoming Bills

    @ViewBuilder
    private var upcomingBills: some View {
        let upcoming = upcomingRecurringExpenses
        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Upcoming")
                    .font(.headline)
                    .padding(.horizontal)

                ForEach(upcoming, id: \.id) { expense in
                    let daysUntil = Calendar.current.dateComponents(
                        [.day],
                        from: Calendar.current.startOfDay(for: Date()),
                        to: Calendar.current.startOfDay(for: expense.nextDueDate)
                    ).day ?? 0

                    HStack(spacing: 12) {
                        Text(expense.category?.emoji ?? "\u{1F4E6}")
                            .font(.title3)
                            .frame(width: billIconWidth)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(expense.name.isEmpty ? "Unnamed" : expense.name)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                            Text(daysUntil == 0 ? "Due today" : "Due in \(daysUntil) day\(daysUntil == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(daysUntil == 0 ? BudgetVaultTheme.caution : .secondary)
                        }

                        Spacer()

                        Text(CurrencyFormatter.format(cents: expense.amountCents))
                            .font(BudgetVaultTheme.rowAmount)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var upcomingRecurringExpenses: [RecurringExpense] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let sevenDaysLater = calendar.date(byAdding: .day, value: 7, to: today) else { return [] }

        return recurringExpenses
            .filter { $0.isActive && $0.nextDueDate >= today && $0.nextDueDate <= sevenDaysLater }
            .prefix(3)
            .map { $0 }
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

    // MARK: - Savings Goals

    private var goalCategories: [Category] {
        visibleCategories.filter { $0.isSavingsGoal && $0.goalAmountCents != nil }
    }

    @ViewBuilder
    private var savingsGoalsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Savings Goals")
                .font(.headline)
                .padding(.horizontal)

            ForEach(goalCategories, id: \.id) { category in
                HStack {
                    Text(category.emoji)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.name)
                            .font(.subheadline.bold())
                        ProgressView(value: category.goalProgress)
                            .tint(Color.accentColor)
                    }
                    VStack(alignment: .trailing) {
                        Text(CurrencyFormatter.format(cents: category.budgetedAmountCents))
                            .font(.caption.bold())
                        Text("of \(CurrencyFormatter.format(cents: category.goalAmountCents ?? 0))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: - Monthly Wrapped Card

    @ViewBuilder
    private var wrappedCard: some View {
        Button {
            if isPremium {
                showMonthlyWrapped = true
            } else {
                showPaywall = true
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "party.popper.fill")
                    .font(.title3)
                    .foregroundStyle(BudgetVaultTheme.electricBlue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Monthly Wrapped")
                        .font(.subheadline.bold())
                    Text("See your spending highlights")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !isPremium {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD))
        }
        .tint(.primary)
        .padding(.horizontal)
        .accessibilityLabel("Monthly Wrapped\(isPremium ? "" : ", premium required")")
    }

    // MARK: - Achievements Preview

    @ViewBuilder
    private var achievementsPreview: some View {
        Button {
            showAchievements = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "trophy.fill")
                    .font(.title3)
                    .foregroundStyle(.yellow)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Achievements")
                        .font(.subheadline.bold())
                    Text("View your badges")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD))
        }
        .tint(.primary)
        .padding(.horizontal)
        .accessibilityLabel("Achievements. View your badges.")
    }

    // MARK: - Helpers

    private func budgetDayProgress(budget: Budget) -> String {
        let calendar = Calendar.current
        let today = Date()
        let start = budget.periodStart
        let end = budget.nextPeriodStart
        let totalDays = max(calendar.dateComponents([.day], from: start, to: end).day ?? 30, 1)
        let elapsed = max(calendar.dateComponents([.day], from: start, to: today).day ?? 0, 0)
        let dayNumber = min(elapsed + 1, totalDays)
        return "Day \(dayNumber) of \(totalDays)"
    }

    private func dayProgressFraction(budget: Budget) -> Double {
        let calendar = Calendar.current
        let today = Date()
        let start = budget.periodStart
        let end = budget.nextPeriodStart
        let totalDays = max(calendar.dateComponents([.day], from: start, to: end).day ?? 30, 1)
        let elapsed = max(calendar.dateComponents([.day], from: start, to: today).day ?? 0, 0)
        return min(Double(elapsed) / Double(totalDays), 1.0)
    }

    private func daysRemainingInPeriod(budget: Budget) -> Int {
        let calendar = Calendar.current
        let today = Date()
        let end = budget.nextPeriodStart
        return max(calendar.dateComponents([.day], from: today, to: end).day ?? 1, 1)
    }

}
