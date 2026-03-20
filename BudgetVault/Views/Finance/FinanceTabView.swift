import SwiftUI
import SwiftData

struct FinanceTabView: View {
    @AppStorage(AppStorageKeys.resetDay) private var resetDay = 1
    @AppStorage(AppStorageKeys.selectedCurrency) private var selectedCurrency = "USD"
    @AppStorage(AppStorageKeys.currentStreak) private var currentStreak = 0
    @AppStorage(AppStorageKeys.isPremium) private var isPremium = false

    @Query(sort: [SortDescriptor(\Budget.year, order: .reverse), SortDescriptor(\Budget.month, order: .reverse)]) private var allBudgets: [Budget]
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    @State private var showPaywall = false

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

    var body: some View {
        NavigationStack {
            if isPremium {
                ScrollView {
                    VStack(spacing: 0) {
                        // 1. Hero Snapshot Card
                        snapshotCard

                        VStack(spacing: BudgetVaultTheme.spacingXL) {
                            // 2. Vault Intelligence Section
                            if !insights.isEmpty {
                                intelligenceSection
                            }

                            // 3. Tools Grid
                            toolsSection
                        }
                        .padding(.top, BudgetVaultTheme.spacingXL)
                        .padding(.bottom, BudgetVaultTheme.spacingXL)
                    }
                }
                .ignoresSafeArea(edges: .top)
            } else {
                VStack(spacing: BudgetVaultTheme.spacingXL) {
                    VaultDialMark(size: 80)
                    Text("Unlock the Vault")
                        .font(.title2.weight(.bold))
                    Text("Premium features including budget management, insights, and debt tracking.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button { showPaywall = true } label: {
                        Text("See Premium Features")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(BudgetVaultTheme.spacingXL)
            }
        }
        .navigationTitle("Vault")
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Snapshot Card

    @ViewBuilder
    private var snapshotCard: some View {
        ZStack {
            LinearGradient(
                colors: healthGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VaultDialMark(size: 20)
                .opacity(0.15)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 50)
                .padding(.trailing, 16)

            VStack(spacing: BudgetVaultTheme.spacingSM) {
                Text("Budget Health")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))

                Text(healthStatus)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                HStack(spacing: BudgetVaultTheme.spacingXL) {
                    VStack(spacing: 2) {
                        Text(CurrencyFormatter.format(cents: remainingCents))
                            .font(BudgetVaultTheme.cardAmount)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text("Remaining")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    VStack(spacing: 2) {
                        Text("\(daysRemaining)")
                            .font(BudgetVaultTheme.cardAmount)
                            .foregroundStyle(.white)
                        Text("Days Left")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    VStack(spacing: 2) {
                        Text("\(currentStreak)")
                            .font(BudgetVaultTheme.cardAmount)
                            .foregroundStyle(.white)
                        Text("Day Streak")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .padding(.top, BudgetVaultTheme.spacingLG)
            .padding(.bottom, BudgetVaultTheme.spacingXL)
        }
        .frame(minHeight: 200)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Budget health: \(healthStatus). \(CurrencyFormatter.format(cents: remainingCents)) remaining. \(daysRemaining) days left. \(currentStreak) day streak.")
    }

    // MARK: - Vault Intelligence Section

    @ViewBuilder
    private var intelligenceSection: some View {
        VStack(alignment: .leading, spacing: BudgetVaultTheme.spacingSM) {
            Text("Vault Intelligence")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BudgetVaultTheme.spacingMD) {
                    ForEach(insights) { insight in
                        insightCard(insight)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private func insightCard(_ insight: Insight) -> some View {
        VStack(alignment: .leading, spacing: BudgetVaultTheme.spacingSM) {
            Image(systemName: insight.severity.iconName)
                .font(.title3)
                .foregroundStyle(.white)
            Text(insight.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text(insight.message)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(3)
        }
        .padding(BudgetVaultTheme.spacingLG)
        .frame(width: 200, height: 140, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [BudgetVaultTheme.navyDark, BudgetVaultTheme.navyMid],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(insight.title). \(insight.message)")
    }

    // MARK: - Tools Section

    @ViewBuilder
    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: BudgetVaultTheme.spacingSM) {
            Text("Tools")
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BudgetVaultTheme.spacingMD) {
                toolCard(icon: "envelope.fill", title: "Manage Budget") {
                    BudgetView()
                }
                toolCard(icon: "chart.xyaxis.line", title: "Full Insights") {
                    InsightsView()
                }
                toolCard(icon: "creditcard.fill", title: "Debt Tracker") {
                    DebtTrackingView()
                }
                toolCard(icon: "star.circle.fill", title: "Monthly Wrapped") {
                    MonthlyWrappedShell()
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func toolCard<Destination: View>(icon: String, title: String, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            VStack(spacing: BudgetVaultTheme.spacingSM) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, BudgetVaultTheme.spacingXL)
            .background(BudgetVaultTheme.cardBackground, in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        }
        .tint(.primary)
        .accessibilityLabel(title)
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
