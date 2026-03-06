import SwiftUI
import Charts

struct TrendChartView: View {
    let budget: Budget
    let transactions: [Transaction]

    private var dailyCumulative: [(day: Int, total: Double)] {
        let calendar = Calendar.current
        let expenses = transactions.filter { !$0.isIncome }

        // Group by day-of-period
        var dailyTotals: [Int: Int64] = [:]
        for tx in expenses {
            let day = max(1, (calendar.dateComponents([.day], from: budget.periodStart, to: tx.date).day ?? 0) + 1)
            dailyTotals[day, default: 0] += tx.amountCents
        }

        let daysInPeriod = calendar.dateComponents([.day], from: budget.periodStart, to: budget.nextPeriodStart).day ?? 30
        let todayDay = min(daysInPeriod, max(1, (calendar.dateComponents([.day], from: budget.periodStart, to: Date()).day ?? 0) + 1))

        var cumulative: Int64 = 0
        var result: [(day: Int, total: Double)] = []
        for d in 1...todayDay {
            cumulative += dailyTotals[d, default: 0]
            result.append((day: d, total: Double(cumulative) / 100.0))
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Spending Trend")
                .font(.headline)

            if dailyCumulative.isEmpty {
                Text("No spending data yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 180)
            } else {
                Chart {
                    ForEach(dailyCumulative, id: \.day) { item in
                        LineMark(
                            x: .value("Day", item.day),
                            y: .value("Spent", item.total)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.accentColor)

                        AreaMark(
                            x: .value("Day", item.day),
                            y: .value("Spent", item.total)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }

                    // Budget pace line (if budget has income)
                    if budget.totalIncomeCents > 0 {
                        RuleMark(y: .value("Budget", Double(budget.totalIncomeCents) / 100.0))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                            .foregroundStyle(.secondary.opacity(0.5))
                            .annotation(position: .trailing) {
                                Text("Budget")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .chartXAxisLabel("Day of month")
                .chartYAxisLabel(CurrencyFormatter.currencySymbol())
                .frame(height: 180)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Spending trend chart showing cumulative spending over \(dailyCumulative.count) days, total \(CurrencyFormatter.format(cents: Int64((dailyCumulative.last?.total ?? 0) * 100)))")
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
