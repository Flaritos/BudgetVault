import SwiftUI
import SwiftData

struct InsightsPlaceholderView: View {
    @AppStorage("resetDay") private var resetDay = 1
    @AppStorage("isPremium") private var isPremium = false

    @Query(sort: \Budget.year, order: .reverse) private var allBudgets: [Budget]
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    @State private var showPaywall = false

    private var currentBudget: Budget? {
        let (m, y) = DateHelpers.currentBudgetPeriod(resetDay: resetDay)
        return allBudgets.first { $0.month == m && $0.year == y }
    }

    private var previousBudget: Budget? {
        let (m, y) = DateHelpers.currentBudgetPeriod(resetDay: resetDay)
        let (pm, py) = DateHelpers.previousMonth(from: m, year: y)
        return allBudgets.first { $0.month == pm && $0.year == py }
    }

    private var periodTransactions: [Transaction] {
        guard let budget = currentBudget else { return [] }
        return allTransactions.filter { $0.date >= budget.periodStart && $0.date < budget.nextPeriodStart }
    }

    private var insights: [Insight] {
        guard let budget = currentBudget else { return [] }
        return InsightsEngine.generateInsights(budget: budget, previousBudget: previousBudget)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let budget = currentBudget {
                        // FREE: Trend chart
                        TrendChartView(budget: budget, transactions: periodTransactions)

                        // FREE: Category breakdown
                        CategoryBreakdownChart(budget: budget)

                        // PREMIUM: vs Last Month
                        premiumSection("vs. Last Month") {
                            comparisonCards(budget: budget)
                        }

                        // PREMIUM: Insights
                        premiumSection("AI Insights") {
                            insightCards
                        }

                        // PREMIUM: Top spending days
                        premiumSection("Top Spending Days") {
                            topSpendingDays(budget: budget)
                        }
                    } else {
                        EmptyStateView(
                            icon: "lightbulb.fill",
                            title: "No Data",
                            message: "Start logging expenses to see insights."
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Insights")
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Premium Section Wrapper

    @ViewBuilder
    private func premiumSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        if isPremium {
            content()
        } else {
            ZStack {
                content()
                    .blur(radius: 8)

                VStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.title2)
                    Text("Unlock Premium Insights")
                        .font(.subheadline.bold())
                    Button("Upgrade") {
                        showPaywall = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Premium feature. Tap to learn about upgrading.")
            .accessibilityAddTraits(.isButton)
            .onTapGesture { showPaywall = true }
        }
    }

    // MARK: - Comparison Cards

    @ViewBuilder
    private func comparisonCards(budget: Budget) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("vs. Last Month")
                .font(.headline)

            if let prev = previousBudget {
                let categories = budget.categories.filter { !$0.isHidden }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(categories, id: \.id) { cat in
                        let current = cat.spentCents(in: budget)
                        let prevCat = prev.categories.first { $0.name == cat.name }
                        let previous = prevCat?.spentCents(in: prev) ?? 0
                        let delta = current - previous

                        VStack(spacing: 4) {
                            Text(cat.emoji)
                                .font(.title3)
                            Text(cat.name)
                                .font(.caption.bold())
                                .lineLimit(1)
                            Text(CurrencyFormatter.format(cents: current))
                                .font(.caption)
                            HStack(spacing: 2) {
                                Image(systemName: delta > 0 ? "arrow.up" : delta < 0 ? "arrow.down" : "minus")
                                    .font(.caption2)
                                Text(CurrencyFormatter.format(cents: abs(delta)))
                                    .font(.caption2)
                            }
                            .foregroundStyle(delta > 0 ? .red : delta < 0 ? .green : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityLabel("\(cat.name): \(CurrencyFormatter.format(cents: current)) this month, \(delta > 0 ? "up" : "down") \(CurrencyFormatter.format(cents: abs(delta))) from last month")
                    }
                }
            } else {
                Text("No previous month data available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Insight Cards

    @ViewBuilder
    private var insightCards: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Insights")
                .font(.headline)

            if insights.isEmpty {
                Text("Keep logging — insights appear as patterns emerge.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(insights) { insight in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: insight.severity.iconName)
                            .foregroundStyle(severityColor(insight.severity))
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(insight.title)
                                .font(.subheadline.bold())
                            Text(insight.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(insight.severity.rawValue): \(insight.title). \(insight.message)")
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Top Spending Days

    @ViewBuilder
    private func topSpendingDays(budget: Budget) -> some View {
        let expenses = periodTransactions.filter { !$0.isIncome }
        let grouped = Dictionary(grouping: expenses) { tx in
            Calendar.current.startOfDay(for: tx.date)
        }
        let topDays = grouped
            .map { (date: $0.key, total: $0.value.reduce(Int64(0)) { $0 + $1.amountCents }) }
            .sorted { $0.total > $1.total }
            .prefix(3)

        VStack(alignment: .leading, spacing: 8) {
            Text("Top Spending Days")
                .font(.headline)

            if topDays.isEmpty {
                Text("No spending data yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(topDays.enumerated()), id: \.offset) { index, day in
                    HStack {
                        Text("\(index + 1).")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        Text(day.date, style: .date)
                            .font(.subheadline)
                        Spacer()
                        Text(CurrencyFormatter.format(cents: day.total))
                            .font(.subheadline.bold())
                    }
                    .accessibilityLabel("Number \(index + 1): \(day.date.formatted(date: .abbreviated, time: .omitted)), \(CurrencyFormatter.format(cents: day.total))")
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func severityColor(_ severity: Insight.Severity) -> Color {
        switch severity {
        case .warning: .red
        case .info: .blue
        case .success: .green
        case .nudge: .orange
        }
    }
}
