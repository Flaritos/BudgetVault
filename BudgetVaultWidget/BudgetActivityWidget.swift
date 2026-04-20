import ActivityKit
import SwiftUI
import WidgetKit
import AppIntents

// MARK: - Activity Widget Shell

@available(iOS 16.2, *)
struct BudgetActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BudgetActivityAttributes.self) { context in
            BudgetActivityLockScreenView(state: context.state, attributes: context.attributes)
                .containerBackground(.fill.tertiary, for: .widget)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    BudgetActivityRing(percent: 1.0 - context.state.spentFraction)
                        .frame(width: 38, height: 38)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatActivityCents(context.state.dailyAllowanceCents,
                                                 code: context.state.currencyCode))
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                        Text("today")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("\(formatActivityCents(context.state.remainingCents, code: context.state.currencyCode)) left this period")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if #available(iOS 17.0, *) {
                            Button(intent: LogExpenseFromActivityIntent()) {
                                Label("Log", systemImage: "plus.circle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .tint(.accentColor)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                BudgetActivityRing(percent: 1.0 - context.state.spentFraction)
                    .frame(width: 18, height: 18)
            } compactTrailing: {
                Text(compactActivityAmount(context.state.remainingCents))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            } minimal: {
                BudgetActivityRing(percent: 1.0 - context.state.spentFraction)
                    .frame(width: 18, height: 18)
            }
        }
    }
}

// MARK: - Lock Screen View

@available(iOS 16.2, *)
struct BudgetActivityLockScreenView: View {
    let state: BudgetActivityAttributes.ContentState
    let attributes: BudgetActivityAttributes

    private var periodPercent: Double {
        guard state.totalDays > 0 else { return 0 }
        return min(Double(state.dayOfPeriod) / Double(state.totalDays), 1.0)
    }

    var body: some View {
        HStack(spacing: 14) {
            BudgetActivityRing(percent: 1.0 - state.spentFraction)
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(formatActivityCents(state.remainingCents, code: state.currencyCode))
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("left this period")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                ProgressView(value: periodPercent)
                    .tint(.accentColor)
                    .frame(maxWidth: 140)
                Text("Day \(state.dayOfPeriod) of \(state.totalDays)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
    }
}

// MARK: - Reusable Vault Ring (mirrors widget styling)

@available(iOS 16.2, *)
struct BudgetActivityRing: View {
    let percent: Double

    private var color: Color {
        if percent > 0.5 { return .green }
        if percent > 0.25 { return .orange }
        return .red
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 4)
            Circle()
                .trim(from: 0, to: max(0, min(percent, 1.0)))
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "vault.fill")
                .font(.system(size: 12))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Local helpers (no SPM dep yet — those land in Task 14)

@available(iOS 16.2, *)
private func formatActivityCents(_ cents: Int64, code: String) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = code
    let decimal = Decimal(cents) / 100
    return formatter.string(from: decimal as NSDecimalNumber) ?? "$0.00"
}

@available(iOS 16.2, *)
private func compactActivityAmount(_ cents: Int64) -> String {
    let value = Double(cents) / 100.0
    if value >= 10_000 { return String(format: "%.0fk", value / 1000.0) }
    if value >= 1_000  { return String(format: "%.1fk", value / 1000.0) }
    return String(format: "%.0f", value)
}

// MARK: - Preview

#if DEBUG
@available(iOS 17.0, *)
#Preview("Lock Screen", as: .content, using: BudgetActivityAttributes(periodEndDate: .now.addingTimeInterval(86400 * 18))) {
    BudgetActivityWidget()
} contentStates: {
    BudgetActivityAttributes.ContentState(
        remainingCents: 18_000,
        dailyAllowanceCents: 1_200,
        spentFraction: 0.4,
        dayOfPeriod: 12,
        totalDays: 30,
        currencyCode: "USD"
    )
}
#endif
