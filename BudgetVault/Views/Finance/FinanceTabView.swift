import SwiftUI
import SwiftData
import BudgetVaultShared

struct FinanceTabView: View {
    @AppStorage(AppStorageKeys.resetDay) private var resetDay = 1
    @AppStorage(AppStorageKeys.selectedCurrency) private var selectedCurrency = "USD"
    @AppStorage(AppStorageKeys.currentStreak) private var currentStreak = 0
    @AppStorage(AppStorageKeys.isPremium) private var isPremium = false
    @AppStorage(AppStorageKeys.lastWrappedViewed) private var lastWrappedViewed = ""
    @Environment(StoreKitManager.self) private var storeKit

    @Query(sort: [SortDescriptor(\Budget.year, order: .reverse), SortDescriptor(\Budget.month, order: .reverse)]) private var allBudgets: [Budget]
    // Audit 2026-04-22 P0-7: bounded to last 13 months (current + MoM +
    // 12mo seasonal).
    @Query private var allTransactions: [Transaction]
    @Query(filter: #Predicate<DebtAccount> { $0.isActive }, sort: \DebtAccount.createdAt)
    private var activeDebts: [DebtAccount]

    init() {
        let cutoff = Calendar.current.date(byAdding: .month, value: -13, to: Date()) ?? .distantPast
        _allTransactions = Query(
            filter: #Predicate<Transaction> { $0.date >= cutoff },
            sort: [SortDescriptor(\Transaction.date, order: .reverse)]
        )
    }

    @State private var showPaywall = false
    @State private var navigateToBudgetSetup = false
    // Audit 2026-04-22 P0-8 + P1-33: the old `insights` computed property
    // re-ran InsightsEngine on every body eval. Now cached and refreshed
    // only when the currentBudget identity changes (mirrors DashboardView
    // + InsightsView patterns).
    @State private var cachedInsights: [Insight] = []

    // MARK: - Neon Accent Colors

    private let neonBlue = BudgetVaultTheme.accentSoft
    private let neonGreen = BudgetVaultTheme.neonGreen
    private let neonYellow = BudgetVaultTheme.neonYellow
    private let neonPurple = BudgetVaultTheme.neonPurple
    private let neonOrange = BudgetVaultTheme.neonOrange

    private let categoryColors: [Color] = [
        BudgetVaultTheme.accentSoft, BudgetVaultTheme.neonGreen, BudgetVaultTheme.neonOrange,
        BudgetVaultTheme.neonPurple, BudgetVaultTheme.neonYellow, BudgetVaultTheme.negative
    ]

    // MARK: - Computed Properties

    private var currentBudget: Budget? {
        let (m, y) = DateHelpers.currentBudgetPeriod(resetDay: max(resetDay, 1))
        return allBudgets.first { $0.month == m && $0.year == y }
    }

    private var previousBudget: Budget? {
        let (m, y) = DateHelpers.currentBudgetPeriod(resetDay: max(resetDay, 1))
        let (pm, py) = DateHelpers.previousMonth(from: m, year: y)
        return allBudgets.first { $0.month == pm && $0.year == py }
    }

    private var remainingCents: Int64 {
        currentBudget?.remainingCents ?? 0
    }

    private var daysRemaining: Int {
        guard let budget = currentBudget else { return 0 }
        return max(Calendar.current.dateComponents([.day], from: Date(), to: budget.nextPeriodStart).day ?? 0, 0)
    }

    private var healthStatus: String {
        guard let budget = currentBudget else { return "No Budget" }
        let totalIncome = budget.totalIncomeCents
        guard totalIncome > 0 else { return "Set Income" }
        let pct = Double(remainingCents) / Double(totalIncome)
        if pct > 0.3 { return "On Track" }
        else if pct > 0.1 { return "Watch It" }
        else { return "Over Budget" }
    }

    private var healthGradient: [Color] {
        guard let budget = currentBudget else { return BudgetVaultTheme.healthyGradient }
        let totalIncome = budget.totalIncomeCents
        guard totalIncome > 0 else { return BudgetVaultTheme.healthyGradient }
        let pct = Double(remainingCents) / Double(totalIncome)
        if pct > 0.3 { return BudgetVaultTheme.healthyGradient }
        else if pct > 0.1 { return BudgetVaultTheme.warningGradient }
        else { return BudgetVaultTheme.dangerGradient }
    }

    private func refreshCachedInsights() {
        guard let budget = currentBudget else {
            cachedInsights = []
            return
        }
        cachedInsights = Array(InsightsEngine.generateInsights(
            budget: budget,
            previousBudget: previousBudget,
            allBudgets: allBudgets,
            currentStreak: currentStreak
        ).prefix(6))
    }

    private var spentFraction: CGFloat {
        CGFloat(1.0 - (currentBudget?.percentRemaining ?? 1.0))
    }

    private var categoryCount: Int {
        (currentBudget?.categories ?? []).filter { !$0.isHidden }.count
    }

    private var debtSummary: String {
        if activeDebts.isEmpty { return "Track debts" }
        let totalCents = activeDebts.reduce(Int64(0)) { $0 + $1.currentBalanceCents }
        return "\(CurrencyFormatter.format(cents: totalCents)) total"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            if isPremium {
                premiumContent
            } else {
                nonPremiumContent
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .presentationDragIndicator(.visible)
        }
        .task(id: currentBudget?.id) {
            refreshCachedInsights()
        }
        .onChange(of: allTransactions.count) { _, _ in
            refreshCachedInsights()
        }
    }

    // MARK: - Premium Content — VaultRevamp v2.1 §7.9
    //
    // The "inner sanctum" — you're looking at the vault's interior back
    // wall. Large faint VaultDial watermark behind content at 10% opacity
    // anchors the view. Patterns chamber + Tools 2×2 grid.

    @ViewBuilder
    private var premiumContent: some View {
        ZStack {
            // Radial gradient background — from spec: inner chamber,
            // lighter at top (ambient light from above) fading to near-black.
            RadialGradient(
                colors: [BudgetVaultTheme.navyElevated, Color(hex: "#0F1B33"), Color(hex: "#070E1F")],
                center: UnitPoint(x: 0.5, y: 0.1),
                startRadius: 40,
                endRadius: 500
            )
            .ignoresSafeArea()

            // Dial watermark — positioned absolutely behind content,
            // 400pt wide at 10% opacity. "Back wall of the vault."
            VaultDial(size: .watermark, state: .locked)
                .scaleEffect(2.0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 40)
                .allowsHitTesting(false)

            ScrollView {
                VStack(spacing: 0) {
                    HingeRule(weight: .heavy)
                        .padding(.bottom, BudgetVaultTheme.spacingLG)

                    vaultHeaderV2
                        .padding(.horizontal, BudgetVaultTheme.spacingLG)
                        .padding(.bottom, BudgetVaultTheme.spacingXL)

                    patternsChamber
                        .padding(.horizontal, BudgetVaultTheme.spacingLG)
                        .padding(.bottom, BudgetVaultTheme.spacingLG)

                    toolsGrid
                        .padding(.horizontal, BudgetVaultTheme.spacingLG)

                    Spacer(minLength: BudgetVaultTheme.spacingXL)
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $navigateToBudgetSetup) {
            BudgetView()
        }
    }

    // MARK: - VaultRevamp v2.1 Header — dial + "Vault" + "Day X of Y · Status"

    @ViewBuilder
    private var vaultHeaderV2: some View {
        let progress = min(max(spentFraction, 0), 1)
        HStack(alignment: .center, spacing: 16) {
            VaultDial(
                size: .medium,
                state: currentBudget == nil ? .locked : .progress(progress)
            )
            .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 6) {
                Text("Vault")
                    .font(.system(size: 44, weight: .bold))
                    .tracking(-1.3)
                    .foregroundStyle(.white)
                    .lineSpacing(0)

                Text(headerSubtitle)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(BudgetVaultTheme.titanium300)
            }
            Spacer(minLength: 0)
        }
    }

    /// "DAY 23 OF 31 · ON TRACK" — engraved label style.
    private var headerSubtitle: String {
        guard let budget = currentBudget else { return "SET UP YOUR VAULT" }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.startOfDay(for: budget.periodStart)
        let end = cal.startOfDay(for: budget.nextPeriodStart)
        let totalDays = cal.dateComponents([.day], from: start, to: end).day ?? 30
        let elapsedDays = max(1, (cal.dateComponents([.day], from: start, to: today).day ?? 0) + 1)
        let dayLabel = "DAY \(min(elapsedDays, totalDays)) OF \(totalDays)"
        return "\(dayLabel) · \(healthStatus.uppercased())"
    }

    // MARK: - Patterns Chamber (renamed from "Intelligence" per spec)

    @ViewBuilder
    private var patternsChamber: some View {
        ChamberCard(padding: 18) {
            VStack(spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Patterns")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Text("ON-DEVICE")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.3)
                        .foregroundStyle(BudgetVaultTheme.titanium300)
                }

                patternRow(
                    value: "\(currentStreak)",
                    label: "Day streak",
                    subtitle: patternsStreakSubtitle,
                    accent: BudgetVaultTheme.positive
                )

                patternRow(
                    value: "\(noSpendDaysThisPeriod)",
                    label: "No-spend days",
                    subtitle: patternsNoSpendSubtitle,
                    accent: BudgetVaultTheme.titanium100
                )
            }
        }
    }

    @ViewBuilder
    private func patternRow(value: String, label: String, subtitle: String, accent: Color) -> some View {
        HStack(spacing: 14) {
            Text(value)
                .font(.system(size: 26, weight: .medium, design: .monospaced))
                .foregroundStyle(accent)
                .frame(minWidth: 38, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(BudgetVaultTheme.titanium300)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(accent.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(accent.opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value). \(subtitle)")
    }

    private var patternsStreakSubtitle: String {
        if currentStreak == 0 { return "THIS MONTH" }
        if currentStreak >= 7 { return "THIS MONTH · BEST YET" }
        return "THIS MONTH"
    }

    private var patternsNoSpendSubtitle: String {
        let count = noSpendDaysThisPeriod
        if count == 0 { return "THIS MONTH" }
        if count >= 10 { return "THIS MONTH · PERSONAL BEST" }
        return "THIS MONTH"
    }

    /// Days in the current budget period up to today that had zero
    /// expense transactions. Computed on the fly — no separate storage.
    private var noSpendDaysThisPeriod: Int {
        guard let budget = currentBudget else { return 0 }
        let cal = Calendar.current
        let start = cal.startOfDay(for: budget.periodStart)
        let today = cal.startOfDay(for: Date())
        let end = min(today, cal.startOfDay(for: budget.nextPeriodStart.addingTimeInterval(-1)))
        guard end >= start else { return 0 }

        // Collect distinct days with at least one expense.
        let spendingDays = Set(allTransactions
            .filter { !$0.isIncome && $0.date >= start && $0.date < cal.date(byAdding: .day, value: 1, to: end) ?? end }
            .map { cal.startOfDay(for: $0.date) })

        // Count days from start through end (inclusive).
        let totalDays = (cal.dateComponents([.day], from: start, to: end).day ?? 0) + 1
        return max(0, totalDays - spendingDays.count)
    }

    // MARK: - Non-Premium Content

    @ViewBuilder
    private var nonPremiumContent: some View {
        // Round 5 N5: ScrollView now has a safeAreaInset(.bottom)
        // that pins the pricing card + Unlock CTA above the tab bar,
        // so the CTA is never hidden behind the floating tab bar on
        // initial viewport. Scrollable content stays above.
        ScrollView {
            VStack(spacing: BudgetVaultTheme.spacingXL) {
                VaultDial(size: .medium, state: .locked)
                    .frame(width: 72, height: 72)
                    .padding(.top, BudgetVaultTheme.spacingLG)

                VStack(spacing: BudgetVaultTheme.spacingSM) {
                    Text("The Vault")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Premium features. Unlock once, keep forever.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                }

                // Feature teaser grid — 4 of the premium features previewed
                // with icon + name so the tab feels like a preview, not a wall.
                VStack(spacing: BudgetVaultTheme.spacingMD) {
                    vaultFeatureRow(
                        icon: "brain.head.profile",
                        title: "Vault Patterns",
                        // Audit 2026-04-23 Brand: swapped "ML" → "patterns"
                        // for canonical on-device noun (Insights agrees).
                        blurb: "On-device patterns predict month-end spend and flag anomalies."
                    )
                    vaultFeatureRow(
                        icon: "creditcard.trianglebadge.exclamationmark",
                        title: "Debt Tracker",
                        blurb: "Track payoff progress with avalanche and snowball strategies."
                    )
                    vaultFeatureRow(
                        icon: "sparkles.rectangle.stack.fill",
                        title: "Monthly Wrapped",
                        blurb: "A Spotify-style look at your month. Yours to share."
                    )
                    vaultFeatureRow(
                        icon: "infinity",
                        title: "Unlimited Categories",
                        blurb: "Build the budget you actually need, no limits."
                    )
                }
                .padding(.bottom, 40)
            }
            .padding(BudgetVaultTheme.spacingLG)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BudgetVaultTheme.navyDark)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: BudgetVaultTheme.spacingMD) {
                LaunchPricingCardView()

                Button { showPaywall = true } label: {
                    Text(storeKit.isLaunchPricing ? "Unlock Now" : "See Premium Features")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, BudgetVaultTheme.spacingLG)
            .padding(.top, BudgetVaultTheme.spacingMD)
            .padding(.bottom, BudgetVaultTheme.spacingSM)
            .background(
                LinearGradient(
                    colors: [BudgetVaultTheme.navyDark.opacity(0), BudgetVaultTheme.navyDark, BudgetVaultTheme.navyDark],
                    startPoint: .top, endPoint: .bottom
                )
                .allowsHitTesting(false)
            )
        }
    }

    @ViewBuilder
    private func vaultFeatureRow(icon: String, title: String, blurb: String) -> some View {
        HStack(alignment: .top, spacing: BudgetVaultTheme.spacingMD) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(neonBlue)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(neonBlue.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(blurb)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9, weight: .bold))
                Text("Premium")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(.white.opacity(0.65))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(0.08), in: Capsule())
            .padding(10)
        }
    }

    // MARK: - Tools grid (VaultRevamp v2.1 §7.9)

    @ViewBuilder
    private var toolsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tools")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.85))

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                spacing: 8
            ) {
                toolChamber(
                    icon: "chart.xyaxis.line",
                    iconColor: BudgetVaultTheme.accentSoft,
                    title: "Insights",
                    subtitle: insightsSubtitle,
                    subtitleColor: BudgetVaultTheme.titanium300,
                    borderTint: nil
                ) {
                    InsightsView()
                }

                toolChamber(
                    icon: "wallet.bifold.fill",
                    iconColor: BudgetVaultTheme.neonYellow,
                    title: "Debt tracker",
                    subtitle: debtSubtitle,
                    subtitleColor: BudgetVaultTheme.neonYellow,
                    borderTint: BudgetVaultTheme.neonYellow.opacity(0.3)
                ) {
                    DebtTrackingView()
                }

                toolChamber(
                    icon: "envelope.fill",
                    iconColor: BudgetVaultTheme.titanium100,
                    title: "Envelopes",
                    subtitle: envelopeSubtitle,
                    subtitleColor: BudgetVaultTheme.titanium300,
                    borderTint: nil
                ) {
                    BudgetView()
                }

                toolChamber(
                    icon: "star.fill",
                    iconColor: BudgetVaultTheme.neonPurple,
                    title: "Wrapped",
                    subtitle: wrappedSubtitle,
                    subtitleColor: BudgetVaultTheme.neonPurple,
                    borderTint: BudgetVaultTheme.neonPurple.opacity(0.3)
                ) {
                    MonthlyWrappedShell()
                }
            }
        }
    }

    private func toolChamber<Dest: View>(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        subtitleColor: Color,
        borderTint: Color?,
        @ViewBuilder destination: () -> Dest
    ) -> some View {
        NavigationLink { destination() } label: {
            ChamberCard(padding: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(iconColor)
                        .frame(height: 20)
                    Spacer(minLength: 4)
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.0)
                        .foregroundStyle(subtitleColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .aspectRatio(1.0, contentMode: .fit)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(borderTint ?? Color.clear, lineWidth: borderTint == nil ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(subtitle)")
    }

    // MARK: - Tool subtitles

    private var insightsSubtitle: String {
        let count = cachedInsights.count
        return count == 1 ? "1 FINDING" : "\(count) FINDINGS"
    }

    private var debtSubtitle: String {
        if activeDebts.isEmpty { return "TRACK DEBTS" }
        let count = activeDebts.count
        return count == 1 ? "1 ACTIVE" : "\(count) ACTIVE"
    }

    private var envelopeSubtitle: String {
        let count = categoryCount
        return count == 1 ? "1 ACTIVE" : "\(count) ACTIVE"
    }

    // Audit 2026-04-23 Perf P1: hoisted DateFormatter.
    private static let wrappedSubtitleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f
    }()

    private var wrappedSubtitle: String {
        let month = Self.wrappedSubtitleFormatter.string(from: Date()).uppercased()
        return wrappedIsNew ? "\(month) READY" : "\(month)"
    }

    private var wrappedIsNew: Bool {
        guard let budget = currentBudget else { return false }
        let key = "\(budget.year)-\(budget.month)"
        return lastWrappedViewed != key
    }
}

// MARK: - Insight Severity Neon Colors

extension Insight.Severity {
    var neonColor: Color {
        switch self {
        case .success: return BudgetVaultTheme.neonGreen
        case .warning: return BudgetVaultTheme.neonYellow
        case .info: return BudgetVaultTheme.accentSoft
        case .nudge: return BudgetVaultTheme.neonPurple
        }
    }

    var vaultIconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .nudge: return "lightbulb.fill"
        }
    }
}

// MARK: - Shell to load Monthly Wrapped with budget data

struct MonthlyWrappedShell: View {
    @AppStorage(AppStorageKeys.resetDay) private var resetDay = 1
    @Query(sort: [SortDescriptor(\Budget.year, order: .reverse), SortDescriptor(\Budget.month, order: .reverse)]) private var allBudgets: [Budget]
    // Audit 2026-04-22 P0-7: Wrapped only renders the most recent period;
    // 2-month cutoff is ample (covers period boundary rollovers).
    @Query private var allTransactions: [Transaction]

    init() {
        let cutoff = Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? .distantPast
        _allTransactions = Query(
            filter: #Predicate<Transaction> { $0.date >= cutoff },
            sort: [SortDescriptor(\Transaction.date, order: .reverse)]
        )
    }

    private var currentBudget: Budget? {
        let (m, y) = DateHelpers.currentBudgetPeriod(resetDay: max(resetDay, 1))
        return allBudgets.first { $0.month == m && $0.year == y }
    }

    var body: some View {
        if let budget = currentBudget {
            MonthlyWrappedView(budget: budget, allTransactions: allTransactions)
        } else {
            ContentUnavailableView(
                "No Budget",
                systemImage: "calendar.badge.exclamationmark",
                description: Text("Create a budget first to see your monthly wrapped.")
            )
        }
    }
}
