import SwiftUI
import SwiftData

struct FinanceTabView: View {
    @AppStorage(AppStorageKeys.resetDay) private var resetDay = 1
    @AppStorage(AppStorageKeys.selectedCurrency) private var selectedCurrency = "USD"
    @AppStorage(AppStorageKeys.currentStreak) private var currentStreak = 0
    @AppStorage(AppStorageKeys.isPremium) private var isPremium = false
    @Environment(StoreKitManager.self) private var storeKit

    @Query(sort: [SortDescriptor(\Budget.year, order: .reverse), SortDescriptor(\Budget.month, order: .reverse)]) private var allBudgets: [Budget]
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(filter: #Predicate<DebtAccount> { $0.isActive }, sort: \DebtAccount.createdAt)
    private var activeDebts: [DebtAccount]

    @State private var showPaywall = false

    // MARK: - Neon Accent Colors

    private let neonBlue = Color(hex: "#60A5FA")
    private let neonGreen = Color(hex: "#34D399")
    private let neonYellow = Color(hex: "#FBBF24")
    private let neonPurple = Color(hex: "#A78BFA")
    private let neonOrange = Color(hex: "#FB923C")

    private let categoryColors: [Color] = [
        Color(hex: "#60A5FA"), Color(hex: "#34D399"), Color(hex: "#FB923C"),
        Color(hex: "#A78BFA"), Color(hex: "#FBBF24"), Color(hex: "#F87171")
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

    private var insights: [Insight] {
        guard let budget = currentBudget else { return [] }
        return Array(InsightsEngine.generateInsights(
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
    }

    // MARK: - Premium Content

    @ViewBuilder
    private var premiumContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 1. Header with Neon Ring
                vaultHeader

                // 2. Neon Divider
                neonDivider

                // 3. Intelligence Section
                if !insights.isEmpty {
                    intelligenceSection
                }

                // 4. Neon Divider
                neonDivider

                // 5. Tools Section
                toolsSection

                Spacer()
                    .frame(height: BudgetVaultTheme.spacingXL)
            }
        }
        .background(BudgetVaultTheme.navyDark)
        .navigationBarHidden(true)
    }

    // MARK: - Non-Premium Content

    @ViewBuilder
    private var nonPremiumContent: some View {
        // v3.2 audit H5: tab was a pure paywall with a countdown timer —
        // dark-pattern vibe. Now shows a teaser grid of what's inside
        // BEFORE the paywall CTA so users see the value, then decide.
        ScrollView {
            VStack(spacing: BudgetVaultTheme.spacingXL) {
                VaultDialMark(size: 72)
                    .padding(.top, BudgetVaultTheme.spacingLG)

                VStack(spacing: BudgetVaultTheme.spacingSM) {
                    Text("The Vault")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Premium features. Unlock once, keep forever.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }

                // Feature teaser grid — 4 of the premium features previewed
                // with icon + name so the tab feels like a preview, not a wall.
                VStack(spacing: BudgetVaultTheme.spacingMD) {
                    vaultFeatureRow(
                        icon: "brain.head.profile",
                        title: "Vault Intelligence",
                        blurb: "On-device ML predicts month-end spend and flags anomalies."
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
                .padding(.horizontal)

                LaunchPricingCardView()
                    .padding(.horizontal)

                Button { showPaywall = true } label: {
                    Text(storeKit.isLaunchPricing ? "Unlock Now" : "See Premium Features")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal)
                .padding(.bottom, BudgetVaultTheme.spacingXL)
            }
            .padding(BudgetVaultTheme.spacingLG)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BudgetVaultTheme.navyDark)
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
                    .foregroundStyle(.white.opacity(0.5))
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
    }

    // MARK: - Vault Header

    @ViewBuilder
    private var vaultHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            // Mini neon vault ring showing % spent
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.06), lineWidth: 3)
                    .frame(width: 44, height: 44)
                Circle()
                    .trim(from: 0, to: min(max(spentFraction, 0), 1))
                    .stroke(neonBlue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 44, height: 44)
                    .shadow(color: neonBlue.opacity(0.5), radius: 4)
                VaultDialMark(size: 50)
                    .opacity(0.12)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Vault")
                    .font(.title.weight(.heavy))
                    .foregroundStyle(.white)
                Text("\(healthStatus) \u{00B7} \(daysRemaining) days left")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 56)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Vault. \(healthStatus). \(daysRemaining) days left.")
    }

    // MARK: - Neon Divider

    @ViewBuilder
    private var neonDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(colors: [.clear, neonBlue.opacity(0.2), .clear],
                               startPoint: .leading, endPoint: .trailing)
            )
            .frame(height: 1)
            .padding(.vertical, BudgetVaultTheme.spacingLG)
    }

    // MARK: - Intelligence Section

    @ViewBuilder
    private var intelligenceSection: some View {
        VStack(alignment: .leading, spacing: BudgetVaultTheme.spacingMD) {
            Text("INTELLIGENCE")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(neonBlue.opacity(0.6))
                .tracking(1.5)
                .padding(.horizontal)

            ForEach(insights) { insight in
                insightRow(insight)
            }
        }
    }

    @ViewBuilder
    private func insightRow(_ insight: Insight) -> some View {
        HStack(spacing: BudgetVaultTheme.spacingMD) {
            // Glowing status dot
            Circle()
                .fill(insight.severity.neonColor)
                .frame(width: 8, height: 8)
                .shadow(color: insight.severity.neonColor.opacity(0.6), radius: 4)

            Text(insight.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.15))
        }
        .padding(.horizontal, BudgetVaultTheme.spacingLG)
        .padding(.vertical, BudgetVaultTheme.spacingMD)
        .background(
            RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusButton)
                .fill(.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusButton)
                        .strokeBorder(.white.opacity(0.05), lineWidth: 1)
                )
        )
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(insight.title)
    }

    // MARK: - Tools Section

    @ViewBuilder
    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: BudgetVaultTheme.spacingMD) {
            Text("TOOLS")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.35))
                .tracking(1.5)
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                vaultToolTile(
                    icon: "chart.xyaxis.line",
                    title: "Insights",
                    subtitle: "\(insights.count) findings",
                    accentColor: neonBlue
                ) {
                    InsightsView()
                } miniViz: {
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.white.opacity(0.04))
                            .frame(height: 3)
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(LinearGradient(
                                        colors: [Color(hex: "#60A5FA"), Color(hex: "#93C5FD")],
                                        startPoint: .leading, endPoint: .trailing
                                    ))
                                    .frame(width: geo.size.width * min(max(spentFraction, 0.1), 1.0), height: 3)
                                    .shadow(color: neonBlue.opacity(0.3), radius: 4)
                            }
                    }
                    .frame(height: 3)
                }

                vaultToolTile(
                    icon: "creditcard.fill",
                    title: "Debt Tracker",
                    subtitle: debtSummary,
                    accentColor: neonGreen
                ) {
                    DebtTrackingView()
                } miniViz: {
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.white.opacity(0.04))
                            .frame(height: 3)
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(LinearGradient(
                                        colors: [Color(hex: "#34D399"), Color(hex: "#6EE7B7")],
                                        startPoint: .leading, endPoint: .trailing
                                    ))
                                    .frame(width: geo.size.width * (activeDebts.isEmpty ? 0 : 0.28), height: 3)
                            }
                    }
                    .frame(height: 3)
                }

                vaultToolTile(
                    icon: "envelope.fill",
                    title: "Budget",
                    subtitle: "\(categoryCount) envelopes",
                    accentColor: neonOrange
                ) {
                    BudgetView()
                } miniViz: {
                    HStack(spacing: 3) {
                        let heights: [CGFloat] = [14, 10, 12, 6, 8, 4]
                        ForEach(0..<min(categoryCount, 6), id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(categoryColors[i % categoryColors.count])
                                .frame(width: 4, height: heights[i % heights.count])
                        }
                    }
                }

                vaultToolTile(
                    icon: "star.circle.fill",
                    title: "Wrapped",
                    subtitle: wrappedSubtitle,
                    accentColor: neonPurple
                ) {
                    MonthlyWrappedShell()
                } miniViz: {
                    Text("NEW")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(neonPurple.opacity(0.5))
                }
            }
            .padding(.horizontal)
        }
    }

    private var wrappedSubtitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return "\(formatter.string(from: Date())) ready"
    }

    // MARK: - Vault Tool Tile

    private func vaultToolTile<Dest: View, Viz: View>(
        icon: String,
        title: String,
        subtitle: String,
        accentColor: Color,
        @ViewBuilder destination: () -> Dest,
        @ViewBuilder miniViz: () -> Viz
    ) -> some View {
        NavigationLink { destination() } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(accentColor.opacity(0.7))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(accentColor.opacity(0.3))
                }
                .padding(.bottom, BudgetVaultTheme.spacingSM)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.bottom, BudgetVaultTheme.spacingSM)

                Spacer()

                miniViz()
            }
            .padding(BudgetVaultTheme.spacingLG)
            .background(
                RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG)
                    .fill(.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG)
                            .strokeBorder(.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .tint(.primary)
        .accessibilityLabel(title)
    }
}

// MARK: - Insight Severity Neon Colors

extension Insight.Severity {
    var neonColor: Color {
        switch self {
        case .success: return Color(hex: "#34D399")
        case .warning: return Color(hex: "#FBBF24")
        case .info: return Color(hex: "#60A5FA")
        case .nudge: return Color(hex: "#A78BFA")
        }
    }
}

// MARK: - Shell to load Monthly Wrapped with budget data

struct MonthlyWrappedShell: View {
    @AppStorage(AppStorageKeys.resetDay) private var resetDay = 1
    @Query(sort: [SortDescriptor(\Budget.year, order: .reverse), SortDescriptor(\Budget.month, order: .reverse)]) private var allBudgets: [Budget]
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

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
