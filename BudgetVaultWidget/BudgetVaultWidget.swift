import WidgetKit
import SwiftUI

// MARK: - Shared Data Types (duplicated from main app for widget target)

struct WidgetBudgetData: Codable {
    let remainingBudgetCents: Int64
    let totalBudgetCents: Int64
    let percentRemaining: Double
    let currencyCode: String
    let isPremium: Bool
    let topCategories: [CategorySummary]

    struct CategorySummary: Codable {
        let emoji: String
        let name: String
        let spentCents: Int64
        let budgetedCents: Int64
    }
}

// MARK: - Timeline Provider

struct BudgetTimelineProvider: TimelineProvider {
    static let suiteName = "group.io.budgetvault.shared"
    static let dataKey = "widgetData"

    func placeholder(in context: Context) -> BudgetEntry {
        BudgetEntry(date: .now, data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (BudgetEntry) -> Void) {
        completion(BudgetEntry(date: .now, data: readData() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetEntry>) -> Void) {
        let entry = BudgetEntry(date: .now, data: readData() ?? .placeholder)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func readData() -> WidgetBudgetData? {
        guard let data = UserDefaults(suiteName: Self.suiteName)?.data(forKey: Self.dataKey),
              let decoded = try? JSONDecoder().decode(WidgetBudgetData.self, from: data) else {
            return nil
        }
        return decoded
    }
}

// MARK: - Entry

struct BudgetEntry: TimelineEntry {
    let date: Date
    let data: WidgetBudgetData
}

extension WidgetBudgetData {
    static var placeholder: WidgetBudgetData {
        WidgetBudgetData(
            remainingBudgetCents: 150_000,
            totalBudgetCents: 500_000,
            percentRemaining: 0.3,
            currencyCode: "USD",
            isPremium: false,
            topCategories: [
                .init(emoji: "🏠", name: "Rent", spentCents: 150_000, budgetedCents: 150_000),
                .init(emoji: "🛒", name: "Groceries", spentCents: 8000, budgetedCents: 10000),
                .init(emoji: "🚗", name: "Transport", spentCents: 3000, budgetedCents: 5000),
            ]
        )
    }
}

// MARK: - Small Widget View

struct SmallBudgetWidgetView: View {
    let entry: BudgetEntry

    private var ringColor: Color {
        if entry.data.percentRemaining > 0.5 { return .green }
        if entry.data.percentRemaining > 0.25 { return .yellow }
        return .red
    }

    var body: some View {
        ZStack {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: max(0, min(entry.data.percentRemaining, 1.0)))
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 60, height: 60)

                Text(formatCents(entry.data.remainingBudgetCents, code: entry.data.currencyCode))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text("remaining")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            // Logo watermark
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "vault.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
                Spacer()
            }
            .padding(4)
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .accessibilityLabel("\(formatCents(entry.data.remainingBudgetCents, code: entry.data.currencyCode)) remaining in budget")
    }
}

// MARK: - Medium Widget View

struct MediumBudgetWidgetView: View {
    let entry: BudgetEntry

    private var ringColor: Color {
        if entry.data.percentRemaining > 0.5 { return .green }
        if entry.data.percentRemaining > 0.25 { return .yellow }
        return .red
    }

    var body: some View {
        HStack(spacing: 16) {
            // Left: Ring + amount
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: max(0, min(entry.data.percentRemaining, 1.0)))
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 50, height: 50)

                Text(formatCents(entry.data.remainingBudgetCents, code: entry.data.currencyCode))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text("remaining")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            // Right: Categories or upgrade prompt
            if entry.data.isPremium {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.data.topCategories.prefix(3), id: \.name) { cat in
                        HStack(spacing: 4) {
                            Text(cat.emoji)
                                .font(.system(size: 12))
                            Text(cat.name)
                                .font(.system(size: 11))
                                .lineLimit(1)
                            Spacer()
                            miniProgressBar(spent: cat.spentCents, budgeted: cat.budgetedCents)
                        }
                    }
                }
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Upgrade for\ncategory breakdown")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.horizontal, 4)
        .overlay(alignment: .topTrailing) {
            Image(systemName: "vault.fill")
                .font(.system(size: 8))
                .foregroundStyle(.secondary.opacity(0.5))
                .padding(4)
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .accessibilityLabel("\(formatCents(entry.data.remainingBudgetCents, code: entry.data.currencyCode)) remaining in budget")
    }

    @ViewBuilder
    private func miniProgressBar(spent: Int64, budgeted: Int64) -> some View {
        let pct = budgeted > 0 ? min(Double(spent) / Double(budgeted), 1.0) : 0
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.2))
                RoundedRectangle(cornerRadius: 2)
                    .fill(pct > 0.9 ? Color.red : pct > 0.75 ? Color.yellow : Color.green)
                    .frame(width: geo.size.width * pct)
            }
        }
        .frame(width: 40, height: 4)
    }
}

// MARK: - Widgets

struct BudgetVaultSmallWidget: Widget {
    let kind = "BudgetVaultSmallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BudgetTimelineProvider()) { entry in
            SmallBudgetWidgetView(entry: entry)
        }
        .configurationDisplayName("Budget Remaining")
        .description("See your remaining budget at a glance.")
        .supportedFamilies([.systemSmall])
    }
}

struct BudgetVaultMediumWidget: Widget {
    let kind = "BudgetVaultMediumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BudgetTimelineProvider()) { entry in
            MediumBudgetWidgetView(entry: entry)
        }
        .configurationDisplayName("Budget Overview")
        .description("Budget remaining with top categories.")
        .supportedFamilies([.systemMedium])
    }
}

@main
struct BudgetVaultWidgetBundle: WidgetBundle {
    var body: some Widget {
        BudgetVaultSmallWidget()
        BudgetVaultMediumWidget()
    }
}

// MARK: - Helpers

private func formatCents(_ cents: Int64, code: String) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = code
    let decimal = Decimal(cents) / 100
    return formatter.string(from: decimal as NSDecimalNumber) ?? "$0.00"
}
