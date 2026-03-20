import SwiftUI
import SwiftData
import TipKit

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppStorageKeys.resetDay) private var resetDay = 1
    @AppStorage(AppStorageKeys.currentStreak) private var currentStreak = 0

    // MARK: - Scaled Metrics for Dynamic Type
    @ScaledMetric(relativeTo: .body) private var fabSize: CGFloat = 56
    @ScaledMetric(relativeTo: .body) private var envelopeCardWidth: CGFloat = 150
    @ScaledMetric(relativeTo: .body) private var envelopeCardHeight: CGFloat = 120
    @ScaledMetric(relativeTo: .body) private var billIconWidth: CGFloat = 36

    @Query(sort: [SortDescriptor(\Budget.year, order: .reverse), SortDescriptor(\Budget.month, order: .reverse)]) private var allBudgets: [Budget]
    // TODO: iOS 18 - Add @Query predicate for budget filtering to avoid loading all records
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: \RecurringExpense.nextDueDate) private var recurringExpenses: [RecurringExpense]

    @AppStorage(AppStorageKeys.lastSummaryViewed) private var lastSummaryViewed = ""
    @AppStorage(AppStorageKeys.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @AppStorage(AppStorageKeys.lastActiveDate) private var lastActiveDate: Double = 0
    @AppStorage(AppStorageKeys.catchUpDismissedDate) private var catchUpDismissedDate: Double = 0
    @AppStorage(AppStorageKeys.selectedCurrency) private var selectedCurrency = "USD"
    @AppStorage(AppStorageKeys.morningBriefingEnabled) private var morningBriefingEnabled = false
    @AppStorage(AppStorageKeys.morningBriefingHour) private var morningBriefingHour = 8
    @AppStorage(AppStorageKeys.weeklyDigestEnabled) private var weeklyDigestEnabled = false

    @State private var viewModel = DashboardViewModel()
    @State private var hasAppeared = false
    @State private var showTransactionEntry = false
    @State private var intentPrefillAmount: Double?
    @State private var intentPrefillCategory: String?
    @State private var intentPrefillNote: String?
    @State private var editingTransaction: Transaction?
    @State private var showMonthlySummary = false
    @State private var showPaywall = false
    @State private var showMonthlyWrapped = false
    @State private var showAchievements = false
    @State private var newAchievementBanner: String?
    @State private var showSettings = false
    @State private var showInsights = false

    @State private var showProactivePaywall = false
    @State private var showShareCard = false
    @State private var shareCardImage: UIImage?
    @AppStorage(AppStorageKeys.isPremium) private var isPremium = false
    @AppStorage(AppStorageKeys.transactionCount) private var transactionCount = 0
    @AppStorage(AppStorageKeys.hasSeenTransactionPaywall) private var hasSeenTransactionPaywall = false
    @AppStorage(AppStorageKeys.hasSeenStreakPaywall) private var hasSeenStreakPaywall = false

    // Cached computations (0.1 — avoid recomputing in view body)
    @State private var cachedBudget: Budget?
    @State private var cachedSpentMap: [UUID: Int64] = [:]

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
        guard let budget = currentBudget else { return false }
        let fraction = viewModel.dayProgressFraction(periodStart: budget.periodStart, nextPeriodStart: budget.nextPeriodStart)
        return fraction >= 0.8 || previousBudget != nil
    }

    private var recentTransactions: [Transaction] {
        guard let budget = currentBudget else { return [] }
        return Array(allTransactions
            .lazy
            .filter { $0.date >= budget.periodStart && $0.date < budget.nextPeriodStart }
            .prefix(5))
    }

    // MARK: - Inactivity Detection

    private var daysSinceLastActive: Int {
        guard lastActiveDate > 0 else { return 0 }
        let lastDate = Date(timeIntervalSince1970: lastActiveDate)
        return max(Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0, 0)
    }

    private var showCatchUpCard: Bool {
        guard daysSinceLastActive >= 3 else { return false }
        if catchUpDismissedDate > 0 {
            let dismissedDate = Date(timeIntervalSince1970: catchUpDismissedDate)
            if Calendar.current.isDateInToday(dismissedDate) { return false }
        }
        return true
    }

    private var autoPostedWhileAway: [RecurringExpense] {
        guard lastActiveDate > 0 else { return [] }
        let lastDate = Date(timeIntervalSince1970: lastActiveDate)
        return recurringExpenses.filter { expense in
            expense.isActive && expense.nextDueDate > lastDate && expense.nextDueDate <= Date()
        }
    }

    // MARK: - Body

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

                // FAB — Floating action button
                if currentBudget != nil {
                    Button {
                        showTransactionEntry = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .frame(width: fabSize, height: fabSize)
                            .background(Color.accentColor, in: Circle())
                            .shadow(color: Color.accentColor.opacity(0.3), radius: 12, y: 6)
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 16)
                    .accessibilityLabel("Add transaction")
                    .accessibilityHint("Opens the transaction entry form")
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showTransactionEntry, onDismiss: {
                intentPrefillAmount = nil
                intentPrefillCategory = nil
                intentPrefillNote = nil
            }) {
                if let budget = currentBudget {
                    TransactionEntryView(
                        budget: budget,
                        categories: visibleCategories,
                        prefillAmount: intentPrefillAmount,
                        prefillCategoryName: intentPrefillCategory,
                        prefillNote: intentPrefillNote
                    )
                    .presentationDragIndicator(.visible)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openTransactionEntry)) { notification in
                intentPrefillAmount = notification.userInfo?["amount"] as? Double
                intentPrefillCategory = notification.userInfo?["category"] as? String
                intentPrefillNote = notification.userInfo?["note"] as? String
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
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                }
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showInsights) {
                NavigationStack {
                    InsightsView()
                }
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showProactivePaywall) {
                PaywallView()
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showShareCard) {
                if let image = shareCardImage {
                    ShareLink(item: Image(uiImage: image), preview: SharePreview("BudgetVault Milestone", image: Image(uiImage: image))) {
                        VStack(spacing: 16) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 320)
                                .clipShape(RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusXL))

                            Text("Share your achievement!")
                                .font(.headline)
                        }
                        .padding()
                    }
                }
            }
            .task {
                refreshCachedValues()
                lastActiveDate = Date().timeIntervalSince1970

                if let budget = currentBudget {
                    NotificationService.checkAndScheduleCategoryAlerts(budget: budget)

                    if weeklyDigestEnabled {
                        schedulePersonalizedWeeklySummary(budget: budget)
                    }

                    if morningBriefingEnabled {
                        scheduleMorningBriefingWithData(budget: budget)
                    }

                    NotificationService.scheduleEndOfPeriodNotifications(
                        periodEnd: budget.nextPeriodStart,
                        remainingCents: budget.remainingCents,
                        currencyCode: selectedCurrency
                    )

                    let newBadges = AchievementService.checkAchievements(
                        budget: budget,
                        transactions: allTransactions
                    )
                    if let first = newBadges.first {
                        HapticManager.notification(.success)
                        newAchievementBanner = first.title

                        if first.id == "under_budget_1" || first.id == "streak_30" {
                            prepareShareCard(for: first, budget: budget)
                        }

                        try? await Task.sleep(for: .seconds(3))
                        newAchievementBanner = nil
                    }

                    ReviewPromptService.checkFirstMonthUnderBudget()
                    let periodTxCount = allTransactions.filter {
                        $0.date >= budget.periodStart && $0.date < budget.nextPeriodStart
                    }.count
                    ReviewPromptService.checkTransactionMilestone(transactionCount: periodTxCount)
                }

                if !isPremium {
                    let txCount = allTransactions.count
                    transactionCount = txCount

                    if txCount >= 5 && !hasSeenTransactionPaywall {
                        try? await Task.sleep(for: .seconds(1.5))
                        hasSeenTransactionPaywall = true
                        showProactivePaywall = true
                        return
                    }

                    if currentStreak >= 7 && !hasSeenStreakPaywall {
                        try? await Task.sleep(for: .seconds(1.5))
                        hasSeenStreakPaywall = true
                        showProactivePaywall = true
                    }
                }
            }
            .onChange(of: allTransactions.count) { _, _ in
                refreshCachedValues()
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

    // MARK: - Dashboard Content

    @ViewBuilder
    private func dashboardContent(budget: Budget) -> some View {
        let dailyAllowanceCents = viewModel.dailyAllowanceCents(
            remainingCents: budget.remainingCents,
            periodStart: budget.periodStart,
            nextPeriodStart: budget.nextPeriodStart
        )
        let dayProgressFrac = viewModel.dayProgressFraction(
            periodStart: budget.periodStart,
            nextPeriodStart: budget.nextPeriodStart
        )
        let dayProgressText = viewModel.budgetDayProgress(
            periodStart: budget.periodStart,
            nextPeriodStart: budget.nextPeriodStart
        )

        ScrollView {
            VStack(spacing: 0) {
                // 1. Navy Gradient Hero Section
                heroSection(
                    budget: budget,
                    dailyAllowanceCents: dailyAllowanceCents,
                    dayProgressFraction: dayProgressFrac,
                    dayProgressText: dayProgressText
                )

                VStack(spacing: BudgetVaultTheme.spacingXL) {
                    // Catch-up card for returning users
                    if showCatchUpCard {
                        catchUpCard(budget: budget)
                            .padding(.top, BudgetVaultTheme.spacingMD)
                    }

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
                            .padding(BudgetVaultTheme.spacingMD)
                            .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD))
                        }
                        .tint(.primary)
                        .padding(.horizontal)
                        .accessibilityLabel("Monthly summary for \(DateHelpers.monthYearString(month: prev.month, year: prev.year)) is ready. Tap to view.")
                    }

                    // 2. Envelope Cards (Horizontal Scroll)
                    if !visibleCategories.isEmpty {
                        envelopeCardsSection(budget: budget)
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 20)
                    }

                    // 3. Quick Insight Card
                    insightCard(budget: budget)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 20)

                    // 4. Upcoming Bills
                    upcomingBillsCard
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 20)

                    // 5. Recent Transactions
                    if !recentTransactions.isEmpty {
                        recentTransactionsCard
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 20)
                    }

                    // Siri tip
                    TipView(SiriTip())
                        .padding(.horizontal)

                    // Premium teaser
                    if !isPremium {
                        premiumTeaser
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 20)
                    }
                }
                .padding(.top, -30) // overlap the gradient slightly
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
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - 1. Hero Section

    @ViewBuilder
    private func heroSection(
        budget: Budget,
        dailyAllowanceCents: Int64,
        dayProgressFraction: Double,
        dayProgressText: String
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            // Gradient background
            LinearGradient(
                colors: [BudgetVaultTheme.navyDark, BudgetVaultTheme.electricBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // VaultDialMark watermark
            VaultDialMark(size: 24)
                .opacity(0.2)
                .padding(.top, 60)
                .padding(.trailing, 20)

            // Hero content
            VStack(spacing: BudgetVaultTheme.spacingSM) {
                // Daily allowance — THE hero number
                Text(CurrencyFormatter.format(cents: dailyAllowanceCents))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.default, value: dailyAllowanceCents)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)

                Text("per day")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))

                // Remaining of total
                Text("\(CurrencyFormatter.format(cents: budget.remainingCents)) of \(CurrencyFormatter.format(cents: budget.totalIncomeCents)) remaining")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))

                // Day progress bar
                VStack(spacing: 4) {
                    ProgressView(value: dayProgressFraction)
                        .tint(.white)
                        .background(.white.opacity(0.2), in: Capsule())

                    Text(dayProgressText)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: 240)

                // Streak badge
                if currentStreak > 0 {
                    HStack(spacing: 4) {
                        Text("\u{1F525}")
                        Text("\(currentStreak) day streak")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.15), in: Capsule())
                    .accessibilityLabel("Logging streak: \(currentStreak) days")
                }
            }
            .padding(.top, 70) // below status bar + toolbar
            .padding(.bottom, BudgetVaultTheme.spacingXL + 30) // extra room for overlap
            .frame(maxWidth: .infinity)
        }
        .frame(minHeight: 320)
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(CurrencyFormatter.format(cents: dailyAllowanceCents)) per day. \(CurrencyFormatter.format(cents: budget.remainingCents)) remaining of \(CurrencyFormatter.format(cents: budget.totalIncomeCents)). \(dayProgressText)")
    }

    // MARK: - 2. Envelope Cards

    @ViewBuilder
    private func envelopeCardsSection(budget: Budget) -> some View {
        VStack(alignment: .leading, spacing: BudgetVaultTheme.spacingSM) {
            HStack {
                Text("Envelopes")
                    .font(.headline)
                Spacer()
                Text("\(visibleCategories.count) categories")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BudgetVaultTheme.spacingMD) {
                    ForEach(visibleCategories, id: \.id) { category in
                        NavigationLink {
                            CategoryDetailView(category: category, budget: budget)
                        } label: {
                            envelopeCard(category: category, budget: budget)
                        }
                        .tint(.primary)
                        .accessibilityHint("Double tap to view category details")
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 2) // room for shadow
            }
        }
    }

    @ViewBuilder
    private func envelopeCard(category: Category, budget: Budget) -> some View {
        let spent = cachedSpent(for: category, in: budget)
        let budgeted = category.budgetedAmountCents
        let remaining = budgeted - spent
        let pct: Double = budgeted > 0 ? min(Double(spent) / Double(budgeted), 1.0) : 0
        let categoryColor = Color(hex: category.color)

        VStack(alignment: .leading, spacing: BudgetVaultTheme.spacingSM) {
            // Top: emoji + name
            HStack(spacing: BudgetVaultTheme.spacingSM) {
                Text(category.emoji)
                    .font(.title3)
                Text(category.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
            }

            Spacer()

            // Bottom: amount + progress
            VStack(alignment: .leading, spacing: BudgetVaultTheme.spacingXS) {
                Text(CurrencyFormatter.format(cents: remaining))
                    .font(BudgetVaultTheme.cardAmount)
                    .foregroundStyle(remaining >= 0 ? BudgetVaultTheme.positive : BudgetVaultTheme.negative)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text("of \(CurrencyFormatter.format(cents: budgeted))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(categoryColor.opacity(0.15))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(pct > 0.9 ? BudgetVaultTheme.negative : pct > 0.75 ? BudgetVaultTheme.caution : Color.accentColor)
                            .frame(width: geo.size.width * min(pct, 1.0), height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(BudgetVaultTheme.spacingMD)
        .frame(width: envelopeCardWidth, height: envelopeCardHeight)
        .background(
            RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG)
                .fill(BudgetVaultTheme.cardBackground)
        )
        .overlay(alignment: .top) {
            // Top accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(categoryColor)
                .frame(height: 3)
                .padding(.horizontal, BudgetVaultTheme.spacingSM)
                .padding(.top, BudgetVaultTheme.spacingXS)
        }
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category.emoji) \(category.name): \(CurrencyFormatter.format(cents: remaining)) remaining of \(CurrencyFormatter.format(cents: budgeted))")
    }

    // MARK: - 3. Quick Insight Card

    @ViewBuilder
    private func insightCard(budget: Budget) -> some View {
        let insights = InsightsEngine.generateInsights(
            budget: budget,
            previousBudget: previousBudget,
            allBudgets: allBudgets,
            currentStreak: currentStreak
        )

        if let topInsight = insights.first {
            Button {
                showInsights = true
            } label: {
                HStack(spacing: BudgetVaultTheme.spacingMD) {
                    Image(systemName: topInsight.severity.iconName)
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(topInsight.title)
                            .font(.subheadline.weight(.medium))
                        Text(topInsight.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(BudgetVaultTheme.spacingLG)
                .background(BudgetVaultTheme.cardBackground, in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
            }
            .tint(.primary)
            .padding(.horizontal)
            .accessibilityLabel("Insight: \(topInsight.title). \(topInsight.message)")
            .accessibilityHint("Double tap to view all insights")
        }
    }

    // MARK: - 4. Upcoming Bills Card

    @ViewBuilder
    private var upcomingBillsCard: some View {
        let upcoming = upcomingRecurringExpenses
        if !upcoming.isEmpty {
            VStack(alignment: .leading, spacing: BudgetVaultTheme.spacingSM) {
                Text("Upcoming Bills")
                    .font(.headline)
                    .padding(.horizontal)

                VStack(spacing: 0) {
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
                                Text(daysUntil == 0 ? "Due today" : "in \(daysUntil) day\(daysUntil == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(daysUntil == 0 ? BudgetVaultTheme.caution : .secondary)
                            }

                            Spacer()

                            Text(CurrencyFormatter.format(cents: expense.amountCents))
                                .font(BudgetVaultTheme.rowAmount)
                        }
                        .padding(.horizontal, BudgetVaultTheme.spacingLG)
                        .padding(.vertical, BudgetVaultTheme.spacingSM)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(expense.name.isEmpty ? "Unnamed" : expense.name), \(CurrencyFormatter.format(cents: expense.amountCents)), \(daysUntil == 0 ? "due today" : "due in \(daysUntil) day\(daysUntil == 1 ? "" : "s")")")
                    }
                }
                .background(BudgetVaultTheme.cardBackground, in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - 5. Recent Transactions Card

    @ViewBuilder
    private var recentTransactionsCard: some View {
        VStack(alignment: .leading, spacing: BudgetVaultTheme.spacingSM) {
            Text("Recent")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(recentTransactions, id: \.id) { transaction in
                    Button {
                        editingTransaction = transaction
                    } label: {
                        TransactionRowView(transaction: transaction)
                            .padding(.horizontal, BudgetVaultTheme.spacingLG)
                            .padding(.vertical, BudgetVaultTheme.spacingSM)
                    }
                    .tint(.primary)
                    .accessibilityHint("Double tap to edit transaction")
                }
            }
            .background(BudgetVaultTheme.cardBackground, in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
            .padding(.horizontal)
        }
    }

    // MARK: - Premium Teaser

    @ViewBuilder
    private var premiumTeaser: some View {
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
            .padding(BudgetVaultTheme.spacingMD)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD))
        }
        .tint(.primary)
        .padding(.horizontal)
        .accessibilityLabel("Unlock Premium Insights. Track trends, compare months, and more.")
    }

    // MARK: - Catch-Up Card

    @ViewBuilder
    private func catchUpCard(budget: Budget) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "hand.wave.fill")
                    .foregroundStyle(Color.accentColor)
                Text("Welcome back!")
                    .font(.subheadline.bold())
                Spacer()
                Button {
                    withAnimation {
                        catchUpDismissedDate = Date().timeIntervalSince1970
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Dismiss catch-up card")
            }

            Text("Here's what happened while you were away:")
                .font(.caption)
                .foregroundStyle(.secondary)

            let recentRecurring = recentAutoPostedExpenses(budget: budget)
            if !recentRecurring.isEmpty {
                ForEach(recentRecurring, id: \.id) { expense in
                    HStack(spacing: 8) {
                        Text(expense.category?.emoji ?? "")
                        Text(expense.name)
                            .font(.caption)
                        Spacer()
                        Text(CurrencyFormatter.format(cents: expense.amountCents))
                            .font(.caption.bold())
                    }
                }
            } else {
                Text("No auto-posted expenses while you were away.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Button {
                showTransactionEntry = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Quick add expense")
                }
                .font(.caption.bold())
                .foregroundStyle(Color.accentColor)
            }
            .padding(.top, 4)
        }
        .padding(BudgetVaultTheme.spacingMD)
        .background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD))
        .padding(.horizontal)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Helpers

    private func recentAutoPostedExpenses(budget: Budget) -> [RecurringExpense] {
        guard lastActiveDate > 0 else { return [] }
        return recurringExpenses.filter { expense in
            expense.isActive && expense.amountCents > 0
        }.prefix(5).map { $0 }
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

    private func daysRemainingInPeriod(budget: Budget) -> Int {
        let calendar = Calendar.current
        let today = Date()
        let end = budget.nextPeriodStart
        return max(calendar.dateComponents([.day], from: today, to: end).day ?? 1, 1)
    }

    /// Pre-compute spent values once and cache them (0.1 performance fix)
    private func refreshCachedValues() {
        let budget = currentBudget
        cachedBudget = budget
        guard let budget else {
            cachedSpentMap = [:]
            return
        }
        var map: [UUID: Int64] = [:]
        for cat in budget.categories ?? [] {
            map[cat.id] = cat.spentCents(in: budget)
        }
        cachedSpentMap = map
    }

    /// Look up cached spent value for a category, falling back to live computation
    private func cachedSpent(for category: Category, in budget: Budget) -> Int64 {
        cachedSpentMap[category.id] ?? category.spentCents(in: budget)
    }

    // MARK: - Notification Scheduling Helpers

    private func schedulePersonalizedWeeklySummary(budget: Budget) {
        let calendar = Calendar.current
        let today = Date()
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) else { return }

        let weekTransactions = allTransactions.filter {
            !$0.isIncome && $0.date >= weekAgo && $0.date < today
        }
        let weeklySpent = weekTransactions.reduce(Int64(0)) { $0 + $1.amountCents }

        NotificationService.scheduleWeeklySummary(
            weeklySpent: weeklySpent,
            transactionCount: weekTransactions.count,
            remaining: budget.remainingCents,
            currencyCode: selectedCurrency
        )
    }

    private func scheduleMorningBriefingWithData(budget: Budget) {
        let daysRemaining = daysRemainingInPeriod(budget: budget)
        let dailyAllowance = budget.remainingCents > 0 ? budget.remainingCents / Int64(max(daysRemaining, 1)) : 0

        let upcoming = upcomingRecurringExpenses
        NotificationService.scheduleMorningBriefing(
            dailyAllowance: dailyAllowance,
            daysRemaining: daysRemaining,
            upcomingBills: upcoming.count,
            currencyCode: selectedCurrency,
            hour: morningBriefingHour
        )
    }

    // MARK: - Share Card

    private func prepareShareCard(for achievement: AchievementService.Achievement, budget: Budget) {
        let card = ShareCardView(
            title: "Achievement Unlocked!",
            subtitle: achievement.description,
            metric: achievement.emoji,
            metricLabel: achievement.title
        )
        shareCardImage = card.renderImage()
        Task {
            try? await Task.sleep(for: .seconds(4))
            await MainActor.run { showShareCard = true }
        }
    }

}
