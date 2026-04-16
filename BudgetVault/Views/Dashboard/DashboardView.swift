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
    @ScaledMetric(relativeTo: .body) private var envelopeCardWidth: CGFloat = 160
    @ScaledMetric(relativeTo: .body) private var envelopeCardHeight: CGFloat = 130
    @ScaledMetric(relativeTo: .body) private var billIconWidth: CGFloat = 36
    @ScaledMetric(relativeTo: .title) private var dialRingSize: CGFloat = 180
    @ScaledMetric(relativeTo: .title) private var heroAmountSize: CGFloat = 36

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

    // MARK: - Consolidated Sheet Enum (Finding 29)
    enum ActiveSheet: Identifiable {
        case transactionEntry
        case monthlySummary
        case paywall
        case monthlyWrapped
        case achievements
        case insights
        case moveMoney
        case recurring
        case streakMilestone
        case shareCard
        case bufferInfo

        var id: String { String(describing: self) }
    }

    // DashboardViewModel is a static enum — call methods via DashboardViewModel.method()
    @State private var hasAppeared = false
    @State private var activeSheet: ActiveSheet?
    @State private var intentPrefillAmount: Double?
    @State private var intentPrefillCategory: String?
    @State private var intentPrefillNote: String?
    @State private var editingTransaction: Transaction?
    // Round 8: newAchievementBanner state removed with overlay banner.

    @State private var shareCardImage: UIImage?
    @State private var hasCheckedAchievements = false
    @State private var streakMilestoneValue = 0
    @AppStorage(AppStorageKeys.isPremium) private var isPremium = false
    @AppStorage(AppStorageKeys.transactionCount) private var transactionCount = 0
    // TODO: migrate to AppStorageKeys
    @AppStorage("lastWrappedViewed") private var lastWrappedViewed = ""
    // TODO: migrate to AppStorageKeys
    @AppStorage("dismissedLaunchBanner") private var hasDissmissedLaunchBanner = false
    // TODO: migrate to AppStorageKeys
    @AppStorage("lastCelebratedMilestone") private var lastCelebratedMilestone = 0
    @State private var showFreezeToast = false
    @State private var noSpendConfirmed = false
    /// Observed copy of StreakService.hasClosedToday() — plain state so
    /// mutations trigger redraws. Refreshed in refreshCachedValues().
    @State private var todayClosed = false
    /// v3.2 audit B4: visible feedback for no-spend button tap.
    @State private var showNoSpendToast = false
    /// v3.2 whimsy: "vault closes" ceremony — on no-spend tap the hero
    /// ring briefly animates from its current arc to a full green circle.
    @State private var vaultClosingAnimation = false
    /// v3.2 whimsy: hero ring draws in from 0 on every foreground.
    @State private var ringDrawnIn = false

    // Cached computations (0.1 — avoid recomputing in view body)
    @State private var cachedBudget: Budget?
    @State private var cachedSpentMap: [UUID: Int64] = [:]
    @State private var cachedInsights: [Insight] = []

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
        let key = "\(budget.year)-\(budget.month)"
        guard lastWrappedViewed != key else { return false }
        let fraction = DashboardViewModel.dayProgressFraction(periodStart: budget.periodStart, nextPeriodStart: budget.nextPeriodStart)
        return fraction >= 0.8 || previousBudget != nil
    }

    private var recentTransactions: [Transaction] {
        guard let budget = currentBudget else { return [] }
        return Array(allTransactions
            .lazy
            .filter { $0.date >= budget.periodStart && $0.date < budget.nextPeriodStart }
            .prefix(4))
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
            ZStack {
                if let budget = currentBudget {
                    if budget.totalIncomeCents == 0 {
                        EmptyStateView(
                            icon: "dollarsign.circle",
                            title: "Set Your Income",
                            message: "Set your monthly income to get started.",
                            actionLabel: "Set Income",
                            action: { hasCompletedOnboarding = false }
                        )
                    } else if visibleCategories.isEmpty && recentTransactions.isEmpty {
                        EmptyStateView(
                            icon: "plus.circle.fill",
                            title: "No Expenses Yet",
                            message: "Tap + to log your first expense.",
                            actionLabel: "Add Expense",
                            action: { activeSheet = .transactionEntry }
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
            }
            // Round 5 N3/N4/N6: moved FAB from overlay to safeAreaInset
            // so ScrollView genuinely reserves the bottom gutter. Overlay
            // was drawing on top of scroll content regardless of padding.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // FAB — Pill-shaped floating action button + no-spend day shortcut
                if currentBudget != nil {
                    HStack(spacing: BudgetVaultTheme.spacingMD) {
                        // v3.2 audit C2: persistent state instead of hiding
                        // the button after tap. Disabled + checkmark tells
                        // the user "today is closed" without losing
                        // discoverability or leaving them wondering what
                        // happened.
                        Button {
                            guard !todayClosed else { return }
                            HapticManager.notification(.success)
                            _ = StreakService.markNoSpendDay()
                            // v3.2 whimsy signature moment: "close the vault"
                            // The hero ring sweeps to full green for 600ms
                            // before the toast slides in. This is the "thunk".
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                vaultClosingAnimation = true
                                todayClosed = true
                            }
                            Task {
                                try? await Task.sleep(for: .milliseconds(700))
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    vaultClosingAnimation = false
                                    showNoSpendToast = true
                                }
                                try? await Task.sleep(for: .seconds(2.5))
                                withAnimation { showNoSpendToast = false }
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: todayClosed ? "checkmark" : "moon.zzz.fill")
                                    .font(.body.weight(.bold))
                                    .foregroundStyle(todayClosed ? BudgetVaultTheme.positive : .white)
                                    .frame(width: 48, height: 48)
                                    .background(
                                        Circle()
                                            .fill(BudgetVaultTheme.positive.opacity(todayClosed ? 0.2 : 0.15))
                                    )
                                    .overlay(
                                        Circle()
                                            .strokeBorder(BudgetVaultTheme.positive, lineWidth: 1.5)
                                    )
                                    .shadow(color: BudgetVaultTheme.positive.opacity(0.4), radius: 8, y: 4)
                                Text(todayClosed ? "Closed" : "No Spend")
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .disabled(todayClosed)
                        .accessibilityLabel(todayClosed ? "Today's vault is closed" : "Mark today as no-spend day")
                        .accessibilityHint("Closes today's vault without logging a transaction")
                        .accessibilityIdentifier("noSpendButton")

                        Button {
                            HapticManager.impact(.medium)
                            activeSheet = .transactionEntry
                        } label: {
                            HStack(spacing: BudgetVaultTheme.spacingSM) {
                                Image(systemName: "plus")
                                    .font(.body.weight(.bold))
                                Text("Log Expense")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, BudgetVaultTheme.spacingXL)
                            .padding(.vertical, BudgetVaultTheme.spacingMD)
                            .background(Color.accentColor, in: Capsule())
                            .shadow(color: Color.accentColor.opacity(0.3), radius: 12, y: 6)
                        }
                        .accessibilityLabel("Log expense")
                        .accessibilityHint("Opens the transaction entry form")
                    }
                    .padding(.bottom, BudgetVaultTheme.spacingSM)
                    .padding(.top, BudgetVaultTheme.spacingSM + 4)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onReceive(NotificationCenter.default.publisher(for: .openTransactionEntry)) { notification in
                intentPrefillAmount = notification.userInfo?["amount"] as? Double
                intentPrefillCategory = notification.userInfo?["category"] as? String
                intentPrefillNote = notification.userInfo?["note"] as? String
                activeSheet = .transactionEntry
            }
            .sheet(item: $editingTransaction, onDismiss: {
                refreshCachedValues()
            }) { transaction in
                if let budget = currentBudget {
                    TransactionEditView(transaction: transaction, budget: budget, categories: visibleCategories)
                        .presentationDragIndicator(.visible)
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .transactionEntry:
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
                case .monthlySummary:
                    if let prev = previousBudget {
                        MonthlySummaryView(budget: prev)
                            .presentationDragIndicator(.visible)
                    }
                case .paywall:
                    PaywallView()
                case .monthlyWrapped:
                    if let budget = currentBudget {
                        MonthlyWrappedView(budget: budget, allTransactions: allTransactions)
                            .presentationDragIndicator(.visible)
                    }
                case .achievements:
                    AchievementGridView()
                        .presentationDragIndicator(.visible)
                case .insights:
                    NavigationStack {
                        InsightsView()
                    }
                    .presentationDragIndicator(.visible)
                case .moveMoney:
                    if let budget = currentBudget {
                        NavigationStack {
                            MoveMoneyView(categories: visibleCategories, budget: budget)
                        }
                        .presentationDragIndicator(.visible)
                    }
                case .recurring:
                    NavigationStack {
                        RecurringExpenseListView()
                    }
                    .presentationDragIndicator(.visible)
                case .streakMilestone:
                    StreakMilestoneView(milestone: streakMilestoneValue) {
                        activeSheet = nil
                    }
                    .interactiveDismissDisabled()
                case .shareCard:
                    if let image = shareCardImage {
                        ShareLink(item: Image(uiImage: image), preview: SharePreview("BudgetVault Milestone", image: Image(uiImage: image))) {
                            VStack(spacing: BudgetVaultTheme.spacingLG) {
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
                case .bufferInfo:
                    // Buffer info is presented as an alert-style sheet
                    VStack(spacing: BudgetVaultTheme.spacingLG) {
                        Text("Buffer Days")
                            .font(.headline)
                        Text("How many extra days your budget could last at your current pace.\n\n+5d means you're ahead of schedule. -2d means you'll run out 2 days early.\n\n\u{221E} means your pace could last forever at this rate.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Got it") { activeSheet = nil }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
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

                    if !hasCheckedAchievements {
                        hasCheckedAchievements = true

                        let newBadges = AchievementService.checkAchievements(
                            budget: budget,
                            transactions: allTransactions
                        )
                        // Round 8: achievement overlay banner removed — fire
                        // only a success haptic; users discover new badges
                        // via Settings → Milestones.
                        if let first = newBadges.first {
                            HapticManager.notification(.success)
                            if first.id == "under_budget_1" || first.id == "streak_30" {
                                prepareShareCard(for: first, budget: budget)
                            }
                        }
                    }

                    // Streak freeze toast
                    if UserDefaults.standard.bool(forKey: "streakFreezeJustUsed") {
                        UserDefaults.standard.set(false, forKey: "streakFreezeJustUsed")
                        withAnimation { showFreezeToast = true }
                    }

                    // Streak milestone celebration
                    if let milestone = StreakService.checkMilestone(),
                       milestone > lastCelebratedMilestone {
                        lastCelebratedMilestone = milestone
                        streakMilestoneValue = milestone
                        try? await Task.sleep(for: .seconds(0.5))
                        activeSheet = .streakMilestone
                    }

                    ReviewPromptService.checkFirstMonthUnderBudget()
                    let periodTxCount = allTransactions.filter {
                        $0.date >= budget.periodStart && $0.date < budget.nextPeriodStart
                    }.count
                    ReviewPromptService.checkTransactionMilestone(transactionCount: periodTxCount)
                }

                // Proactive modal paywalls removed in v3.1.1 — they interrupted habit formation.
                // Premium upsell now lives in (1) the inline LaunchPricingDashboardBanner,
                // (2) intent-based triggers (tapping a Premium-locked feature), and
                // (3) a future delayed prompt at day 14 (see ROADMAP_v3.2 Sprint 1).
                if !isPremium {
                    transactionCount = allTransactions.count
                }
            }
            .onChange(of: allTransactions.count) { _, _ in
                refreshCachedValues()
            }
        }
        // Round 7 R6: toasts need to sit BELOW the safe area top so they
        // don't collide with the hero glass card. The hero ignores safe
        // area edges to extend navy gradient under the status bar, so
        // we explicitly anchor toasts ~80pt from top (well below the
        // Round 8: achievement banner DELETED entirely — it kept
        // colliding with the hero, envelope cards, Recent row, or
        // tab bar no matter where we anchored it. Users still see
        // their unlocks on Settings → Milestones; first-unlock
        // celebration now happens via the "new badge" ring pulse
        // on the dashboard hero (below) + a success haptic.
        .overlay(alignment: .bottom) {
            // v3.2 audit B4: no-spend day confirmation toast (bottom now).
            if showNoSpendToast {
                HStack(spacing: 8) {
                    Image(systemName: "moon.zzz.fill")
                        .foregroundStyle(.white)
                    Text("Today's vault is closed \u{00B7} streak saved")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(BudgetVaultTheme.positive.opacity(0.9), in: Capsule())
                .shadow(color: BudgetVaultTheme.positive.opacity(0.3), radius: 8, y: 4)
                .padding(.bottom, 120) // R8 RR1: clear FAB safeAreaInset + tab bar well below status bar, above hero card
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Freeze toast
            if showFreezeToast {
                HStack(spacing: 8) {
                    Image(systemName: "shield.fill")
                        .foregroundStyle(.white)
                    Text("Streak freeze used! Your \(currentStreak)-day streak is safe.")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(BudgetVaultTheme.info, in: Capsule())
                .shadow(color: BudgetVaultTheme.info.opacity(0.4), radius: 8, y: 4)
                .padding(.bottom, 120) // R8 RR1: clear FAB safeAreaInset + tab bar well below status bar, above hero card
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task {
                    try? await Task.sleep(for: .seconds(3))
                    withAnimation { showFreezeToast = false }
                }
            }
        }
        .onChange(of: activeSheet) { oldSheet, newSheet in
            // Handle cleanup when sheets dismiss
            if newSheet == nil {
                switch oldSheet {
                case .transactionEntry:
                    intentPrefillAmount = nil
                    intentPrefillCategory = nil
                    intentPrefillNote = nil
                case .monthlyWrapped:
                    if let budget = currentBudget {
                        lastWrappedViewed = "\(budget.year)-\(budget.month)"
                    }
                default:
                    break
                }
            }
        }
        .onChange(of: showNoSpendToast) { _, showing in
            if showing {
                UIAccessibility.post(notification: .announcement, argument: "Today's vault is closed. Streak saved.")
            }
        }
        .onChange(of: showFreezeToast) { _, showing in
            if showing {
                UIAccessibility.post(notification: .announcement, argument: "Streak freeze activated.")
            }
        }
    }

    // MARK: - Dashboard Content

    @ViewBuilder
    private func dashboardContent(budget: Budget) -> some View {
        let dailyAllowanceCents = DashboardViewModel.dailyAllowanceCents(
            remainingCents: budget.remainingCents,
            periodStart: budget.periodStart,
            nextPeriodStart: budget.nextPeriodStart
        )
        let dayProgressFrac = DashboardViewModel.dayProgressFraction(
            periodStart: budget.periodStart,
            nextPeriodStart: budget.nextPeriodStart
        )
        let dayProgressText = DashboardViewModel.budgetDayProgress(
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

                // "The Vault Contents" — slides over the hero with rounded top corners
                VStack(spacing: BudgetVaultTheme.spacingXL) {
                    Spacer().frame(height: BudgetVaultTheme.spacingXL)

                    // Quick Actions Row
                    quickActionsRow

                    // Round 5 N16: the "One-time $14.99" banner was
                    // appearing on Home + Vault tab + Paywall (3× repetition
                    // of the same anti-subscription message). Removed from
                    // Home so the dashboard stays focused on the daily loop.
                    // Monetization lives on the Vault tab and Paywall sheet.

                    // Streak progress card
                    if currentStreak > 0 {
                        streakProgressCard
                    }

                    // Catch-up card for returning users
                    if showCatchUpCard {
                        catchUpCard(budget: budget)
                    }

                    // Monthly summary banner
                    if showSummaryBanner, let prev = previousBudget {
                        Button {
                            activeSheet = .monthlySummary
                            lastSummaryViewed = "\(prev.year)-\(prev.month)"
                        } label: {
                            HStack {
                                Image(systemName: "star.circle.fill")
                                    .foregroundStyle(BudgetVaultTheme.caution)
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

                    // Monthly Wrapped card (available to all users near end of period)
                    if showWrappedCard {
                        Button {
                            activeSheet = .monthlyWrapped
                        } label: {
                            HStack(spacing: BudgetVaultTheme.spacingSM) {
                                Image(systemName: "star.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(BudgetVaultTheme.neonPurple)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Your Monthly Wrapped is ready!")
                                        .font(.subheadline.bold())
                                    Text("See your spending personality")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(BudgetVaultTheme.spacingMD)
                            .background(
                                LinearGradient(
                                    colors: [BudgetVaultTheme.neonPurple.opacity(0.08), BudgetVaultTheme.neonPurple.opacity(0.04)],
                                    startPoint: .leading, endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD)
                                    .strokeBorder(BudgetVaultTheme.neonPurple.opacity(0.15), lineWidth: 1)
                            )
                        }
                        .tint(.primary)
                        .padding(.horizontal)
                    }

                    // 2. Envelope Cards — "Vault Compartments"
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
                    // v3.2 audit L3: was the only gray tip card in an
                    // otherwise-white-surface dashboard. Wrapped in a white
                    // card so it matches the surface token.
                    TipView(SiriTip())
                        .tipBackground(Color(.systemBackground))
                        .padding(.horizontal)

                    // Premium teaser
                    if !isPremium {
                        premiumTeaser
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 20)
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedCorner(radius: BudgetVaultTheme.radiusXL, corners: [.topLeft, .topRight]))
                // v3.2 audit L7: subtle shadow at the navy → white seam
                // so the content "floats" above the hero gradient instead
                // of meeting it at a hard horizontal line.
                .shadow(color: .black.opacity(0.15), radius: 10, y: -4)
                .padding(.top, -20) // overlap the hero gradient
            }
            // Round 5 N3: FAB now uses safeAreaInset above, so we only
            // need a modest extra spacer to keep the last row breathing.
            .padding(.bottom, 24)
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
        .refreshable { refreshCachedValues() }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - 1. Hero Section — "The Vault Display"

    @ViewBuilder
    private func heroSection(
        budget: Budget,
        dailyAllowanceCents: Int64,
        dayProgressFraction: Double,
        dayProgressText: String
    ) -> some View {
        let spentFraction = 1.0 - budget.percentRemaining
        // v3.2 audit B1: when there's real spending but < 1% of budget,
        // show "<1%" instead of rounding to "0%" — which reads as
        // "nothing logged" to first-time users.
        let spentPercent = Int(min(spentFraction, 1.0) * 100)
        let spentPercentLabel: String = {
            if spentFraction > 0 && spentPercent == 0 { return "<1%" }
            return "\(spentPercent)%"
        }()
        let ringSize: CGFloat = 100

        ZStack {
            // Full-bleed navy gradient background
            LinearGradient(
                colors: [BudgetVaultTheme.navyDark.opacity(0.95), BudgetVaultTheme.navyDark, BudgetVaultTheme.navyMid],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)

            VStack(spacing: BudgetVaultTheme.spacingLG) {
                // Streak badge row
                if currentStreak > 0 {
                    HStack {
                        Spacer()
                        streakBadgeView
                    }
                    .padding(.horizontal, BudgetVaultTheme.spacingLG)
                    .padding(.top, BudgetVaultTheme.spacingSM)
                }

                // Glass card with ring + amount
                HStack(alignment: .center, spacing: BudgetVaultTheme.spacingXL - 4) {
                    // Neon ring with percentage
                    ZStack {
                        // Track
                        Circle()
                            .stroke(.white.opacity(0.06), lineWidth: 7)
                            .frame(width: ringSize, height: ringSize)

                        // Neon arc — color shifts green -> yellow -> red as spending increases.
                        // v3.2 audit L1: minimum visible arc of ~4° so real
                        // spending under 1% doesn't look like a rendering glitch.
                        // v3.2 whimsy: on no-spend "vault close" the ring
                        // sweeps to full green; on foreground it draws from 0.
                        Circle()
                            .trim(from: 0, to: vaultClosingAnimation
                                  ? 1.0
                                  : (ringDrawnIn
                                     ? (spentFraction > 0 ? max(0.015, min(spentFraction, 1.0)) : 0)
                                     : 0))
                            .stroke(
                                vaultClosingAnimation ? BudgetVaultTheme.positive : spendingArcColor(for: spentFraction),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: ringSize, height: ringSize)
                            .shadow(color: (vaultClosingAnimation ? BudgetVaultTheme.positive : spendingArcColor(for: spentFraction)).opacity(0.5), radius: 8)
                            .animation(.spring(response: 0.6, dampingFraction: 0.75), value: spentFraction)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: vaultClosingAnimation)
                            .animation(.easeOut(duration: 0.7), value: ringDrawnIn)

                        // Outer glow layer
                        Circle()
                            .trim(from: 0, to: ringDrawnIn ? min(spentFraction, 1.0) : 0)
                            .stroke(
                                spendingArcColor(for: spentFraction).opacity(0.7),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: ringSize, height: ringSize)
                            .blur(radius: 6)
                            .animation(.spring(duration: 0.8, bounce: 0.15), value: spentFraction)
                            .animation(.easeOut(duration: 0.7), value: ringDrawnIn)

                        // Vault tick marks
                        VaultDialMark(size: ringSize + 10)
                            .opacity(0.15)

                        // Percentage text
                        VStack(spacing: 0) {
                            Text(spentPercentLabel)
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(.white.opacity(0.85))
                            Text("used")
                                .font(.system(.caption2, design: .rounded).weight(.medium))
                                .foregroundStyle(.white.opacity(0.4))
                                .tracking(0.5)
                        }
                    }

                    // Amount + info
                    VStack(alignment: .leading, spacing: BudgetVaultTheme.spacingXS) {
                        Text("DAILY ALLOWANCE")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white.opacity(0.4))
                            .tracking(1.5)

                        Text(CurrencyFormatter.format(cents: dailyAllowanceCents, currencyCode: selectedCurrency))
                            .font(.system(size: heroAmountSize, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: spendingArcColor(for: spentFraction).opacity(0.3), radius: 16)
                            .contentTransition(.numericText())
                            .animation(.snappy, value: dailyAllowanceCents)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)

                        Text("per day")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.55))

                        // Status line
                        HStack(spacing: BudgetVaultTheme.spacingXS) {
                            Circle()
                                .fill(spentFraction < 0.75 ? BudgetVaultTheme.positive : spentFraction < 0.9 ? BudgetVaultTheme.caution : BudgetVaultTheme.negative)
                                .frame(width: 6, height: 6)
                            Image(systemName: spentFraction < 0.75 ? "checkmark.circle.fill" : spentFraction < 0.9 ? "exclamationmark.triangle.fill" : "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(spentFraction < 0.75 ? BudgetVaultTheme.positive : spentFraction < 0.9 ? BudgetVaultTheme.caution : BudgetVaultTheme.negative)
                            Text(spentFraction < 0.75 ? "On Track" : spentFraction < 0.9 ? "Watch It" : "Over Budget")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(spentFraction < 0.75 ? BudgetVaultTheme.positive : spentFraction < 0.9 ? BudgetVaultTheme.caution : BudgetVaultTheme.negative)
                        }
                        .padding(.top, BudgetVaultTheme.spacingXS)
                    }
                }
                .padding(.horizontal, BudgetVaultTheme.spacingLG)
                .padding(.vertical, BudgetVaultTheme.spacingXL)
                .background {
                    RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusXL)
                        .fill(.white.opacity(0.07))
                        .overlay {
                            RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusXL)
                                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                        }
                }
                .padding(.horizontal, BudgetVaultTheme.spacingLG)

                // v3.2 audit M6: persistent privacy chip above the stats
                // row. The brand's #1 pillar was whispered once in 11pt —
                // it deserves a quiet permanent presence on the hero.
                HStack(spacing: 4) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 9))
                    Text("On-device \u{00B7} No bank login")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.2)
                }
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.06), in: Capsule())
                .padding(.bottom, 4)

                // Stats row below the card
                HStack {
                    statItem(label: "REMAINING", value: CurrencyFormatter.format(cents: budget.remainingCents, currencyCode: selectedCurrency))
                    Spacer()
                    Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 28)
                    Spacer()
                    statItem(label: "SPENT", value: CurrencyFormatter.format(cents: budget.totalSpentCents(), currencyCode: selectedCurrency))
                    Spacer()
                    Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 28)
                    Spacer()
                    statItem(label: "DAY", value: dayProgressText.replacingOccurrences(of: "Day ", with: ""))
                    Spacer()
                    Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 28)
                    Spacer()
                    bufferDaysStat(budget: budget, dayProgressFraction: dayProgressFraction)
                }
                .padding(.horizontal, BudgetVaultTheme.spacingXL)
            }
            .padding(.top, BudgetVaultTheme.spacingPage + BudgetVaultTheme.spacingXL)
            .padding(.bottom, BudgetVaultTheme.spacingXL + BudgetVaultTheme.spacingLG)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(CurrencyFormatter.format(cents: dailyAllowanceCents, currencyCode: selectedCurrency)) per day. \(CurrencyFormatter.format(cents: budget.remainingCents, currencyCode: selectedCurrency)) remaining. \(dayProgressText)")
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.35))
                .tracking(0.5)
            Text(value)
                .font(.system(.callout, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
    }

    /// Buffer days stat: remainingCents / avgDailySpend. Shows how many extra days the budget could last.
    private func bufferDaysStat(budget: Budget, dayProgressFraction: Double) -> some View {
        let totalSpent = budget.totalSpentCents()
        let daysElapsed = max(Int(dayProgressFraction * Double(Calendar.current.dateComponents([.day], from: budget.periodStart, to: budget.nextPeriodStart).day ?? 30)), 1)
        let daysInPeriod = max(Calendar.current.dateComponents([.day], from: budget.periodStart, to: budget.nextPeriodStart).day ?? 30, 1)
        let daysRemaining = daysInPeriod - daysElapsed

        let bufferText: String
        let bufferColor: Color

        if totalSpent <= 0 {
            bufferText = "\u{2014}"
            bufferColor = .white
        } else {
            let avgDailySpend = totalSpent / Int64(daysElapsed)
            if avgDailySpend <= 0 {
                bufferText = "\u{2014}"
                bufferColor = .white
            } else {
                let bufferDays = Int(budget.remainingCents / avgDailySpend)
                let surplus = bufferDays - daysRemaining
                // v3.2 audit H1: cap absurd values. If the user's pace
                // would last 2x+ the period we already know they're way
                // ahead — show a clean "∞" instead of "+1370d".
                let cap = daysInPeriod * 2

                if surplus > cap {
                    bufferText = "\u{221E}"
                    // v3.2 audit M12: was positive green — now white like
                    // the other stats so it doesn't read as an accent or
                    // tappable indicator by itself.
                    bufferColor = .white
                } else if surplus > 0 {
                    bufferText = "+\(surplus)d"
                    bufferColor = BudgetVaultTheme.positive
                } else if surplus == 0 {
                    bufferText = "0d"
                    bufferColor = BudgetVaultTheme.caution
                } else {
                    bufferText = "\(surplus)d"
                    bufferColor = BudgetVaultTheme.negative
                }
            }
        }

        return VStack(spacing: 2) {
            // v3.2 audit L1/L2: tappable buffer label → info alert.
            // Added small leading space before the ⓘ glyph for breathing.
            Button { activeSheet = .bufferInfo } label: {
                HStack(spacing: 4) {
                    Text("BUFFER")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.35))
                        .tracking(0.5)
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .buttonStyle(.plain)
            Text(bufferText)
                .font(.system(.callout, design: .rounded).weight(.bold))
                .foregroundStyle(bufferColor)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .accessibilityIdentifier("bufferStat")
        }
    }

    // MARK: - Spending Arc Gradient

    private func spendingArcGradient(for fraction: Double) -> AngularGradient {
        let colors: [Color]
        if fraction > 0.9 {
            colors = [BudgetVaultTheme.negative, BudgetVaultTheme.negative]
        } else if fraction > 0.75 {
            colors = [BudgetVaultTheme.caution, BudgetVaultTheme.negative]
        } else {
            colors = [BudgetVaultTheme.positive, BudgetVaultTheme.caution]
        }
        return AngularGradient(
            gradient: Gradient(colors: colors),
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360 * fraction)
        )
    }

    /// Returns a single color representing the arc for shadow use.
    private func spendingArcColor(for fraction: Double) -> Color {
        if fraction > 0.9 {
            return BudgetVaultTheme.negative
        } else if fraction > 0.75 {
            return BudgetVaultTheme.caution
        } else {
            return BudgetVaultTheme.positive
        }
    }

    // MARK: - 2. Envelope Cards

    @ViewBuilder
    private func envelopeCardsSection(budget: Budget) -> some View {
        VStack(alignment: .leading, spacing: BudgetVaultTheme.spacingSM) {
            sectionHeader(title: "Envelopes") {
                NavigationLink {
                    BudgetView()
                } label: {
                    Text("Manage")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.accentColor)
                }
            }

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
            .accessibilityHint("Swipe left or right to see more envelopes")
            // Round 7 R1: right-edge fade mask so the horizontal
            // carousel clearly shows "more to the right" instead of
            // appearing to clip the last card at the screen edge.
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0.0),
                        .init(color: .black, location: 0.92),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
    }

    /// Vault compartment card — metallic feel with left color accent strip
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

            // Remaining amount + lock icon
            HStack {
                Text(CurrencyFormatter.format(cents: remaining))
                    .font(BudgetVaultTheme.cardAmount)
                    .foregroundStyle(remaining > 0 ? .primary : BudgetVaultTheme.negative)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Spacer()

                // Lock icon if fully spent
                if remaining <= 0 {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("left of \(CurrencyFormatter.format(cents: budgeted))")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("\(Int(pct * 100))% spent")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(categoryColor)
                        .frame(width: geo.size.width * min(pct, 1.0), height: 5)
                }
            }
            .frame(height: 5)
        }
        .padding(BudgetVaultTheme.spacingLG)
        .frame(width: envelopeCardWidth, height: envelopeCardHeight)
        .background {
            // v3.2 audit H2/M8: dropped the heavy category-color tint that
            // made cards look cream/ivory. Now a thin stroke only, so the
            // surface is consistently white across the app.
            let spendingIntensity = min(pct, 1.0)
            let tintOpacity = 0.0 + (spendingIntensity * 0.02)
            RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG)
                .fill(BudgetVaultTheme.cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG)
                        .fill(categoryColor.opacity(tintOpacity))
                }
                .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        }
        .overlay(alignment: .leading) {
            // Category color accent strip (left edge, full height)
            RoundedRectangle(cornerRadius: 2)
                .fill(categoryColor)
                .frame(width: 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category.emoji) \(category.name): \(CurrencyFormatter.format(cents: remaining)) remaining of \(CurrencyFormatter.format(cents: budgeted))\(remaining <= 0 ? ", fully spent" : "")")
    }

    // MARK: - 3. Quick Insight Card

    @ViewBuilder
    private func insightCard(budget: Budget) -> some View {
        if let topInsight = cachedInsights.first {
            Button {
                if isPremium {
                    activeSheet = .insights
                } else {
                    activeSheet = .paywall
                }
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
                sectionHeader(title: "Upcoming Bills") { EmptyView() }

                VStack(spacing: 0) {
                    ForEach(upcoming, id: \.id) { expense in
                        let daysUntil = Calendar.current.dateComponents(
                            [.day],
                            from: Calendar.current.startOfDay(for: Date()),
                            to: Calendar.current.startOfDay(for: expense.nextDueDate)
                        ).day ?? 0

                        HStack(spacing: BudgetVaultTheme.spacingMD) {
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
            sectionHeader(title: "Recent") {
                Button {
                    NotificationCenter.default.post(name: .switchToHistoryTab, object: nil)
                } label: {
                    Text("See All")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.accentColor)
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                let items = Array(recentTransactions.prefix(4))
                ForEach(Array(items.enumerated()), id: \.element.id) { index, transaction in
                    Button {
                        editingTransaction = transaction
                    } label: {
                        TransactionRowView(transaction: transaction)
                            .padding(.vertical, BudgetVaultTheme.spacingSM)
                    }
                    .tint(.primary)
                    .accessibilityHint("Double tap to edit transaction")

                    if index < items.count - 1 {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
            .padding(.horizontal, BudgetVaultTheme.spacingLG)
            .padding(.vertical, BudgetVaultTheme.spacingSM)
            .background(BudgetVaultTheme.cardBackground, in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
            .padding(.horizontal)
        }
    }

    // MARK: - Premium Teaser

    @ViewBuilder
    private var premiumTeaser: some View {
        VStack(spacing: BudgetVaultTheme.spacingMD) {
            premiumFeatureCard(
                icon: "brain.head.profile",
                title: "Vault Intelligence",
                subtitle: "AI-powered spending predictions and anomaly detection",
                gradient: [BudgetVaultTheme.electricBlue, BudgetVaultTheme.brightBlue]
            )

            premiumFeatureCard(
                icon: "lock.open.fill",
                title: "Unlock the Vault",
                subtitle: "Unlimited envelopes, debt tracker, and advanced reports",
                // Round 5 M9: was purple→indigo, off-palette. Navy cyan stays on-brand.
                gradient: [BudgetVaultTheme.navyDark, BudgetVaultTheme.electricBlue]
            )
        }
        .padding(.horizontal)
    }

    private func premiumFeatureCard(icon: String, title: String, subtitle: String, gradient: [Color]) -> some View {
        Button {
            activeSheet = .paywall
        } label: {
            HStack(spacing: BudgetVaultTheme.spacingMD) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(BudgetVaultTheme.caution)
                    }
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(BudgetVaultTheme.spacingMD)
            .background(BudgetVaultTheme.cardBackground, in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        }
        .tint(.primary)
        .accessibilityLabel("\(title). \(subtitle). Premium feature, tap to upgrade.")
    }

    // MARK: - Section Header

    private func sectionHeader<Action: View>(title: String, @ViewBuilder action: () -> Action) -> some View {
        HStack {
            Text(title)
                .font(.headline)

            Spacer()

            action()
        }
        .padding(.horizontal)
    }

    // MARK: - Streak Badge & Card

    @ViewBuilder
    private var streakBadgeView: some View {
        // Round 5 N15/M3: orange flame emoji replaced with lock.shield
        // + cyan accent. Only warm hue was on Home — now on-palette.
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(BudgetVaultTheme.accentSoft)
                Text("\(currentStreak)")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("day\(currentStreak == 1 ? "" : "s")")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )

            // Freeze indicator
            if StreakService.hasAvailableFreeze() {
                HStack(spacing: 3) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 8))
                    Text("1 freeze ready")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    @ViewBuilder
    private var streakProgressCard: some View {
        let weekDots = StreakService.thisWeekDots()

        HStack(spacing: 14) {
            // Round 5 M3: was a 🔥 emoji, Duolingo tone. Now a vault shield.
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 24))
                .foregroundStyle(BudgetVaultTheme.accentSoft)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(currentStreak)-day streak")
                    .font(.subheadline.bold())

                // v3.2 audit L2: softened preachy "Keep logging to reach X days!"
                // on 1-day streak. Just surface the next milestone as a quiet line.
                Text(nextMilestoneLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Weekly dots
                HStack(spacing: 3) {
                    let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                    ForEach(0..<7, id: \.self) { i in
                        Circle()
                            .fill(weekDots[i] == .logged ? BudgetVaultTheme.positive :
                                  weekDots[i] == .frozen ? BudgetVaultTheme.info :
                                  Color(.systemGray5))
                            .frame(width: 8, height: 8)
                            .accessibilityLabel("\(dayNames[i]): \(weekDots[i] == .logged ? "logged" : weekDots[i] == .frozen ? "freeze used" : "not logged")")
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        // v3.2 audit M5: unified card background to white with a narrow orange
        // accent stripe instead of cream — cream was the only cream surface in
        // the whole app, clashing with the envelope card and navy hero.
        .background(
            RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusButton)
                .fill(Color(.systemBackground))
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(BudgetVaultTheme.accentSoft)
                        .frame(width: 3)
                        .clipShape(RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusButton))
                }
                .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        )
        .padding(.horizontal)
    }

    private var nextStreakMilestone: Int? {
        let milestones = [7, 14, 30, 60, 90, 100]
        return milestones.first { $0 > currentStreak }
    }

    private var nextMilestoneLabel: String {
        guard let next = nextStreakMilestone else { return "You're a legend." }
        // v3.2 audit L2: toned down from "Next: X days (Week Warrior)" on
        // a 1-day streak — reads preachy. Simpler, quieter cue.
        return "Next milestone: \(next) days"
    }

    // MARK: - Quick Actions Row

    @ViewBuilder
    private var quickActionsRow: some View {
        // v3.2 audit H1: removed "Log Expense" quick-action chip — it was
        // competing with the FAB below. The FAB is the one-and-only primary
        // action; quick actions are now secondary tools (Recurring, Insights,
        // Move Money) only.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BudgetVaultTheme.spacingSM) {
                if isPremium {
                    quickActionChip(icon: "arrow.left.arrow.right", label: "Move Money") {
                        activeSheet = .moveMoney
                    }

                    quickActionChip(icon: "chart.xyaxis.line", label: "Insights") {
                        activeSheet = .insights
                    }
                }

                quickActionChip(icon: "repeat", label: "Recurring") {
                    activeSheet = .recurring
                }
            }
            .padding(.horizontal)
        }
    }

    private func quickActionChip(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: BudgetVaultTheme.spacingXS) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, BudgetVaultTheme.spacingMD)
            .padding(.vertical, BudgetVaultTheme.spacingSM)
            .frame(minHeight: 44)
            .background(Color.accentColor.opacity(0.1), in: Capsule())
            .foregroundStyle(Color.accentColor)
        }
    }

    // MARK: - Catch-Up Card

    @ViewBuilder
    private func catchUpCard(budget: Budget) -> some View {
        VStack(alignment: .leading, spacing: BudgetVaultTheme.spacingMD) {
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
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Dismiss catch-up card")
            }

            Text("Here's what happened while you were away:")
                .font(.caption)
                .foregroundStyle(.secondary)

            let recentRecurring = recentAutoPostedExpenses(budget: budget)
            if !recentRecurring.isEmpty {
                ForEach(recentRecurring, id: \.id) { expense in
                    HStack(spacing: BudgetVaultTheme.spacingSM) {
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
                activeSheet = .transactionEntry
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
        let lastDate = Date(timeIntervalSince1970: lastActiveDate)
        let now = Date()
        return recurringExpenses.filter { expense in
            expense.isActive && expense.nextDueDate > lastDate && expense.nextDueDate <= now
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
        todayClosed = StreakService.hasClosedToday()
        // v3.2 whimsy: trigger the ring draw-in animation on foreground.
        if !ringDrawnIn {
            Task {
                try? await Task.sleep(for: .milliseconds(200))
                withAnimation(.easeOut(duration: 0.7)) {
                    ringDrawnIn = true
                }
            }
        }
        let budget = currentBudget
        cachedBudget = budget
        guard let budget else {
            cachedSpentMap = [:]
            cachedInsights = []
            return
        }
        var map: [UUID: Int64] = [:]
        for cat in budget.categories ?? [] {
            map[cat.id] = cat.spentCents(in: budget)
        }
        cachedSpentMap = map
        cachedInsights = InsightsEngine.generateInsights(
            budget: budget,
            previousBudget: previousBudget,
            allBudgets: allBudgets,
            currentStreak: currentStreak
        )
        refreshLiveActivity(budget: budget)
    }

    /// v3.2 Sprint 2 wiring: keep the Lock Screen / Dynamic Island Live
    /// Activity in sync with the current budget. Starts the activity the
    /// first time we see a budget today, then pushes updates on subsequent
    /// refreshes. No-op on iOS < 16.2 or if the user has disabled activities.
    private func refreshLiveActivity(budget: Budget) {
        let remainingCents = budget.remainingCents
        let dailyAllowance = DashboardViewModel.dailyAllowanceCents(
            remainingCents: remainingCents,
            periodStart: budget.periodStart,
            nextPeriodStart: budget.nextPeriodStart
        )
        let totalDays = max(1, Calendar.current.dateComponents([.day], from: budget.periodStart, to: budget.nextPeriodStart).day ?? 30)
        let dayOfPeriod = max(1, min(totalDays, (Calendar.current.dateComponents([.day], from: budget.periodStart, to: Date()).day ?? 0) + 1))
        let spentFraction: Double = budget.totalIncomeCents > 0
            ? 1.0 - (Double(remainingCents) / Double(budget.totalIncomeCents))
            : 0
        BudgetLiveActivityService.update(
            remainingCents: remainingCents,
            dailyAllowanceCents: dailyAllowance,
            spentFraction: max(0, min(1, spentFraction)),
            dayOfPeriod: dayOfPeriod,
            totalDays: totalDays,
            currencyCode: selectedCurrency
        )
        Task {
            await BudgetLiveActivityService.start(
                remainingCents: remainingCents,
                dailyAllowanceCents: dailyAllowance,
                spentFraction: max(0, min(1, spentFraction)),
                dayOfPeriod: dayOfPeriod,
                totalDays: totalDays,
                currencyCode: selectedCurrency,
                periodEndDate: budget.nextPeriodStart
            )
        }
    }

    /// Look up cached spent value for a category, falling back to live computation
    private func cachedSpent(for category: Category, in budget: Budget) -> Int64 {
        cachedSpentMap[category.id] ?? category.spentCents(in: budget)
    }

    // MARK: - Notification Scheduling Helpers

    private func schedulePersonalizedWeeklySummary(budget: Budget) {
        let calendar = Calendar.current
        let today = Date()
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: today),
              let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: today) else { return }

        let weekTransactions = allTransactions.filter {
            !$0.isIncome && $0.date >= weekAgo && $0.date < today
        }
        let weeklySpent = weekTransactions.reduce(Int64(0)) { $0 + $1.amountCents }

        // v3.2 Sprint 3: include last week for comparative pulse copy.
        let lastWeekTransactions = allTransactions.filter {
            !$0.isIncome && $0.date >= twoWeeksAgo && $0.date < weekAgo
        }
        let lastWeekSpent = lastWeekTransactions.reduce(Int64(0)) { $0 + $1.amountCents }

        NotificationService.scheduleWeeklySummary(
            weeklySpent: weeklySpent,
            transactionCount: weekTransactions.count,
            remaining: budget.remainingCents,
            currencyCode: selectedCurrency,
            lastWeekSpent: lastWeekSpent
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
            await MainActor.run { activeSheet = .shareCard }
        }
    }

}

// MARK: - RoundedCorner Shape

/// Custom shape that rounds only specified corners, used for the
/// "vault contents" panel that overlaps the hero gradient.
private struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
