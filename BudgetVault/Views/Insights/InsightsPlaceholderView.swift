import SwiftUI
import SwiftData
import Charts

struct InsightsPlaceholderView: View {
    @AppStorage("resetDay") private var resetDay = 1
    @AppStorage("isPremium") private var isPremium = false

    @Query(sort: [SortDescriptor(\Budget.year, order: .reverse), SortDescriptor(\Budget.month, order: .reverse)]) private var allBudgets: [Budget]
    // TODO: iOS 18 - Add @Query predicate for budget filtering to avoid loading all records
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    @State private var showPaywall = false
    @State private var selectedRange: DateRange = .thisMonth
    @State private var showShareSheet = false
    @State private var shareUIImage: UIImage?

    enum DateRange: String, CaseIterable {
        case thisMonth = "This Month"
        case lastMonth = "Last Month"
        case threeMonths = "3 Months"
        case yearToDate = "Year to Date"
    }

    private var currentBudget: Budget? {
        let (m, y) = DateHelpers.currentBudgetPeriod(resetDay: resetDay)
        return allBudgets.first { $0.month == m && $0.year == y }
    }

    private var previousBudget: Budget? {
        let (m, y) = DateHelpers.currentBudgetPeriod(resetDay: resetDay)
        let (pm, py) = DateHelpers.previousMonth(from: m, year: y)
        return allBudgets.first { $0.month == pm && $0.year == py }
    }

    private var dateRangeStart: Date {
        let calendar = Calendar.current
        let now = Date()
        switch selectedRange {
        case .thisMonth:
            return currentBudget?.periodStart ?? calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        case .lastMonth:
            return previousBudget?.periodStart ?? calendar.date(byAdding: .month, value: -1, to: now)!
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: now)!
        case .yearToDate:
            return calendar.date(from: DateComponents(year: calendar.component(.year, from: now), month: 1, day: 1))!
        }
    }

    private var dateRangeEnd: Date {
        switch selectedRange {
        case .thisMonth:
            return currentBudget?.nextPeriodStart ?? Date()
        case .lastMonth:
            return currentBudget?.periodStart ?? Date()
        case .threeMonths, .yearToDate:
            return Date()
        }
    }

    private var periodTransactions: [Transaction] {
        return Array(allTransactions.lazy.filter { $0.date >= dateRangeStart && $0.date < dateRangeEnd })
    }

    private var monthlyTotals: [(month: String, spent: Int64)] {
        allBudgets
            .sorted { ($0.year, $0.month) < ($1.year, $1.month) }
            .suffix(12)
            .map { budget in
                let label = DateHelpers.monthYearString(month: budget.month, year: budget.year)
                let spent = budget.totalSpentCents()
                return (month: label, spent: spent)
            }
    }

    private var insights: [Insight] {
        guard let budget = currentBudget else { return [] }
        return InsightsEngine.generateInsights(budget: budget, previousBudget: previousBudget, allBudgets: allBudgets)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Range", selection: $selectedRange) {
                        ForEach(DateRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if let budget = currentBudget {
                        // PREMIUM: ML Spending Forecast
                        premiumSection("ML Forecast") {
                            if let prediction = BudgetMLEngine.predictMonthEndSpending(budget: budget) {
                                SpendingPredictionCard(prediction: prediction)
                            }
                        }

                        // PREMIUM: Spending Pattern Classification
                        premiumSection("Spending Style") {
                            if let pattern = BudgetMLEngine.classifySpendingPattern(budget: budget) {
                                SpendingPatternCard(pattern: pattern)
                            }
                        }

                        // PREMIUM: Anomaly Detection
                        premiumSection("Anomaly Detection") {
                            let anomalies = BudgetMLEngine.detectAnomalies(budget: budget)
                            AnomalyListCard(anomalies: anomalies)
                        }

                        // PREMIUM: Category Forecasts
                        premiumSection("Category Forecasts") {
                            let forecasts = BudgetMLEngine.forecastCategories(budget: budget)
                            if !forecasts.isEmpty {
                                CategoryForecastCard(forecasts: forecasts)
                            }
                        }

                        // PREMIUM: Spending Heatmap
                        premiumSection("Spending Heatmap") {
                            SpendingHeatmapView(budget: budget, allTransactions: periodTransactions)
                        }

                        // FREE: Trend chart (only shown for single-month ranges)
                        if selectedRange == .thisMonth || selectedRange == .lastMonth {
                            let trendBudget = selectedRange == .lastMonth ? (previousBudget ?? budget) : budget
                            TrendChartView(budget: trendBudget, transactions: periodTransactions)
                        }

                        // FREE: Category breakdown
                        CategoryBreakdownChart(budget: budget)

                        // Monthly Totals bar chart
                        if monthlyTotals.count > 1 {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Monthly Spending")
                                    .font(.headline)

                                Chart(Array(monthlyTotals.enumerated()), id: \.offset) { _, item in
                                    BarMark(
                                        x: .value("Month", item.month),
                                        y: .value("Spent", Double(truncating: MoneyHelpers.centsToDollars(item.spent) as NSDecimalNumber))
                                    )
                                    .foregroundStyle(Color.accentColor.gradient)
                                    .cornerRadius(4)
                                }
                                .frame(height: 200)
                                .chartXAxis {
                                    AxisMarks(values: .automatic) { value in
                                        AxisValueLabel {
                                            if let str = value.as(String.self) {
                                                Text(str)
                                                    .font(.caption2)
                                                    .rotationEffect(.degrees(-45))
                                            }
                                        }
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks { value in
                                        AxisGridLine()
                                        AxisValueLabel {
                                            if let val = value.as(Double.self) {
                                                Text(CurrencyFormatter.format(amount: Decimal(val)))
                                                    .font(.caption2)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }

                        // PREMIUM: vs Last Month
                        premiumSection("vs. Last Month") {
                            comparisonCards(budget: budget)
                        }

                        // PREMIUM: Smart Insights
                        premiumSection("Smart Insights") {
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
                            message: "Start logging expenses to see insights.",
                            actionLabel: "Start Logging"
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Insights")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if currentBudget != nil {
                        Button {
                            renderAndShare()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let img = shareUIImage {
                    ActivityView(items: [img])
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .task {
                if let budget = currentBudget {
                    NotificationService.checkAndScheduleCategoryAlerts(budget: budget)
                }
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
                // Show placeholder skeleton instead of computing real content and blurring
                premiumPlaceholderSkeleton(title: title)

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

    // MARK: - Premium Placeholder Skeleton

    @ViewBuilder
    private func premiumPlaceholderSkeleton(title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            ForEach(0..<3, id: \.self) { _ in
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                        .frame(width: 24, height: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.quaternary)
                            .frame(width: 120, height: 12)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.quaternary)
                            .frame(width: 80, height: 10)
                    }
                    Spacer()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.quaternary)
                        .frame(width: 50, height: 12)
                }
                .padding(8)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Comparison Cards

    @ViewBuilder
    private func comparisonCards(budget: Budget) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("vs. Last Month")
                .font(.headline)

            if let prev = previousBudget {
                let categories = (budget.categories ?? []).filter { !$0.isHidden }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(categories, id: \.id) { cat in
                        let current = cat.spentCents(in: budget)
                        let prevCat = (prev.categories ?? []).first { $0.name == cat.name }
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
                            .foregroundStyle(delta > 0 ? BudgetVaultTheme.negative : delta < 0 ? BudgetVaultTheme.positive : .secondary)
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
        case .warning: BudgetVaultTheme.negative
        case .info: .blue
        case .success: BudgetVaultTheme.positive
        case .nudge: BudgetVaultTheme.caution
        }
    }

    @MainActor
    private func renderAndShare() {
        guard let budget = currentBudget else { return }
        let topCats = (budget.categories ?? [])
            .filter { !$0.isHidden }
            .sorted { $0.spentCents(in: budget) > $1.spentCents(in: budget) }
            .prefix(5)

        let card = VStack(spacing: 12) {
            Text("Insights - \(DateHelpers.monthYearString(month: budget.month, year: budget.year))")
                .font(.headline)

            HStack(spacing: 24) {
                VStack {
                    Text("Income")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.format(cents: budget.totalIncomeCents))
                        .font(.subheadline.bold())
                }
                VStack {
                    Text("Spent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.format(cents: budget.totalSpentCents()))
                        .font(.subheadline.bold())
                }
            }

            Divider()

            ForEach(Array(topCats), id: \.id) { cat in
                HStack {
                    Text(cat.emoji)
                    Text(cat.name)
                        .font(.caption)
                    Spacer()
                    Text(CurrencyFormatter.format(cents: cat.spentCents(in: budget)))
                        .font(.caption.bold())
                }
            }

            Text("Tracked with BudgetVault")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding(20)
        .frame(width: 320)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        if let image = renderer.uiImage {
            shareUIImage = image
            showShareSheet = true
        }
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
