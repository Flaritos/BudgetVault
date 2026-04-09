import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Shared Data Types (duplicated from main app for widget target)

struct WidgetBudgetData: Codable {
    let remainingBudgetCents: Int64
    let totalBudgetCents: Int64
    let percentRemaining: Double
    let currencyCode: String
    let isPremium: Bool
    let topCategories: [CategorySummary]
    let dailyAllowanceCents: Int64
    let currentStreak: Int
    let daysRemaining: Int

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
                .init(emoji: "\u{1F3E0}", name: "Rent", spentCents: 150_000, budgetedCents: 150_000),
                .init(emoji: "\u{1F6D2}", name: "Groceries", spentCents: 8000, budgetedCents: 10000),
                .init(emoji: "\u{1F697}", name: "Transport", spentCents: 3000, budgetedCents: 5000),
            ],
            dailyAllowanceCents: 10_200,
            currentStreak: 12,
            daysRemaining: 18
        )
    }
}

// MARK: - Widget Intent for Interactive Button

struct OpenAddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Expense"
    static var description = IntentDescription("Open BudgetVault to add an expense")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
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
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: max(0, min(entry.data.percentRemaining, 1.0)))
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 48, height: 48)

                Text("DAILY BUDGET")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                    .padding(.top, 2)

                Text(formatCents(entry.data.dailyAllowanceCents, code: entry.data.currencyCode))
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text("\(formatCents(entry.data.remainingBudgetCents, code: entry.data.currencyCode)) left \u{00B7} \(entry.data.daysRemaining)d")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if entry.data.currentStreak > 0 {
                    HStack(spacing: 2) {
                        Text("\u{1F525}")
                            .font(.system(size: 9))
                        Text("\(entry.data.currentStreak)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.orange)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                }
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
        .accessibilityLabel("\(formatCents(entry.data.dailyAllowanceCents, code: entry.data.currencyCode)) daily budget. \(formatCents(entry.data.remainingBudgetCents, code: entry.data.currencyCode)) remaining. \(entry.data.currentStreak) day streak.")
    }
}

// MARK: - Medium Widget View (with Interactive Button)

struct MediumBudgetWidgetView: View {
    let entry: BudgetEntry

    private var ringColor: Color {
        if entry.data.percentRemaining > 0.5 { return .green }
        if entry.data.percentRemaining > 0.25 { return .yellow }
        return .red
    }

    var body: some View {
        HStack(spacing: 14) {
            // Left: Ring
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: max(0, min(entry.data.percentRemaining, 1.0)))
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 46, height: 46)
            }

            // Right: Daily allowance + streak + categories
            VStack(alignment: .leading, spacing: 3) {
                // Daily allowance hero
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatCents(entry.data.dailyAllowanceCents, code: entry.data.currencyCode))
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                    Text("/ day")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                // Remaining context
                Text("\(formatCents(entry.data.remainingBudgetCents, code: entry.data.currencyCode)) remaining \u{00B7} \(entry.data.daysRemaining) days left")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                // Streak badge
                if entry.data.currentStreak > 0 {
                    HStack(spacing: 3) {
                        Text("\u{1F525}")
                            .font(.system(size: 9))
                        Text("\(entry.data.currentStreak)-day streak")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.orange)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                }

                Spacer(minLength: 2)

                // Interactive Add Expense button
                Button(intent: OpenAddExpenseIntent()) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12))
                        Text("Add Expense")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                }
                .buttonStyle(.plain)
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
        .accessibilityLabel("\(formatCents(entry.data.dailyAllowanceCents, code: entry.data.currencyCode)) per day. \(formatCents(entry.data.remainingBudgetCents, code: entry.data.currencyCode)) remaining. \(entry.data.currentStreak) day streak.")
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

// MARK: - Lock Screen Widget Views

#if os(iOS)

struct AccessoryCircularBudgetView: View {
    let entry: BudgetEntry

    var body: some View {
        Gauge(value: max(0, min(entry.data.percentRemaining, 1.0))) {
            Image(systemName: "vault.fill")
                .font(.system(size: 10))
        } currentValueLabel: {
            Text(compactAmount(entry.data.remainingBudgetCents))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
        }
        .gaugeStyle(.accessoryCircular)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct AccessoryInlineBudgetView: View {
    let entry: BudgetEntry

    var body: some View {
        Text("\(formatCents(entry.data.remainingBudgetCents, code: entry.data.currencyCode)) remaining")
            .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct AccessoryRectangularBudgetView: View {
    let entry: BudgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "vault.fill")
                    .font(.system(size: 9))
                Text("BudgetVault")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(.secondary)

            Text(formatCents(entry.data.remainingBudgetCents, code: entry.data.currencyCode))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)

            if let topCat = entry.data.topCategories.first {
                HStack(spacing: 2) {
                    Text(topCat.emoji)
                        .font(.system(size: 9))
                    Text(topCat.name)
                        .font(.system(size: 9))
                    Text(formatCents(topCat.spentCents, code: entry.data.currencyCode))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

#endif

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
        .description("Budget remaining with top categories and quick add.")
        .supportedFamilies([.systemMedium])
    }
}

#if os(iOS)

struct LockScreenBudgetView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: BudgetEntry

    var body: some View {
        switch widgetFamily {
        case .accessoryCircular:
            AccessoryCircularBudgetView(entry: entry)
        case .accessoryInline:
            AccessoryInlineBudgetView(entry: entry)
        case .accessoryRectangular:
            AccessoryRectangularBudgetView(entry: entry)
        default:
            AccessoryCircularBudgetView(entry: entry)
        }
    }
}

struct BudgetVaultLockScreenWidget: Widget {
    let kind = "BudgetVaultLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BudgetTimelineProvider()) { entry in
            LockScreenBudgetView(entry: entry)
        }
        .configurationDisplayName("Budget at a Glance")
        .description("See your remaining budget on the Lock Screen.")
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular])
    }
}
#endif

@main
struct BudgetVaultWidgetBundle: WidgetBundle {
    var body: some Widget {
        BudgetVaultSmallWidget()
        BudgetVaultMediumWidget()
        #if os(iOS)
        BudgetVaultLockScreenWidget()
        if #available(iOS 18.0, *) {
            LogExpenseControl()
        }
        #endif
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

private func compactAmount(_ cents: Int64) -> String {
    let value = Double(cents) / 100.0
    if value >= 10_000 {
        return String(format: "%.0fk", value / 1000.0)
    } else if value >= 1_000 {
        return String(format: "%.1fk", value / 1000.0)
    } else {
        return String(format: "%.0f", value)
    }
}

