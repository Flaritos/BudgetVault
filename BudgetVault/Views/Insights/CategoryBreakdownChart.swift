import SwiftUI
import Charts
import BudgetVaultShared

struct CategoryBreakdownChart: View {
    let budget: Budget

    private var chartData: [(name: String, emoji: String, spent: Double, color: Color)] {
        (budget.categories ?? [])
            .filter { !$0.isHidden && $0.spentCents(in: budget) > 0 }
            .sorted { $0.spentCents(in: budget) > $1.spentCents(in: budget) }
            .map { cat in
                (name: cat.name,
                 emoji: cat.emoji,
                 spent: Double(cat.spentCents(in: budget)) / 100.0,
                 color: Color(hex: cat.color))
            }
    }

    private var totalSpent: Double {
        chartData.reduce(0) { $0 + $1.spent }
    }

    private var totalSpentCents: Int64 {
        (budget.categories ?? [])
            .filter { !$0.isHidden }
            .reduce(Int64(0)) { $0 + $1.spentCents(in: budget) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category Breakdown")
                .font(.headline)

            if chartData.isEmpty {
                Text("No spending data yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 180)
            } else {
                Chart(chartData, id: \.name) { item in
                    SectorMark(
                        angle: .value("Spent", item.spent),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .foregroundStyle(item.color)
                    .cornerRadius(4)
                }
                .chartBackground { proxy in
                    GeometryReader { geo in
                        VStack(spacing: 2) {
                            Text(CurrencyFormatter.format(cents: totalSpentCents))
                                .font(.system(.title3, design: .rounded).bold())
                            Text("spent")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    }
                }
                .frame(height: 180)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Category breakdown donut chart with \(chartData.count) categories")

                // Legend
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(chartData, id: \.name) { item in
                        let pct = totalSpent > 0 ? Int(item.spent / totalSpent * 100) : 0
                        HStack(spacing: 8) {
                            Circle()
                                .fill(item.color)
                                .frame(width: 10, height: 10)
                            Text("\(item.emoji) \(item.name)")
                                .font(.caption)
                            Spacer()
                            Text("\(pct)%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("\(item.name): \(pct) percent, \(CurrencyFormatter.format(cents: Int64(item.spent * 100)))")
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
