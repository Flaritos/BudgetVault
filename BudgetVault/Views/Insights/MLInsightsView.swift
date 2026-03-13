import SwiftUI

// MARK: - Spending Prediction Card

struct SpendingPredictionCard: View {
    let prediction: SpendingPrediction

    private var trendIcon: String {
        switch prediction.trend {
        case .accelerating: return "arrow.up.right"
        case .steady: return "arrow.right"
        case .decelerating: return "arrow.down.right"
        }
    }

    private var trendLabel: String {
        switch prediction.trend {
        case .accelerating: return "Accelerating"
        case .steady: return "Steady"
        case .decelerating: return "Slowing down"
        }
    }

    private var trendColor: Color {
        switch prediction.trend {
        case .accelerating: return BudgetVaultTheme.negative
        case .steady: return BudgetVaultTheme.caution
        case .decelerating: return BudgetVaultTheme.positive
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BudgetVaultTheme.spacingMD) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(BudgetVaultTheme.electricBlue)
                Text("ML Spending Forecast")
                    .font(.headline)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: trendIcon)
                    Text(trendLabel)
                }
                .font(.caption.bold())
                .foregroundStyle(trendColor)
            }

            // Predicted amount
            VStack(alignment: .leading, spacing: 4) {
                Text("Predicted month-end total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(CurrencyFormatter.format(cents: prediction.predictedTotalCents))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(prediction.willExceedBudget ? BudgetVaultTheme.negative : BudgetVaultTheme.positive)
            }

            // Progress bar: current -> predicted -> budget
            GeometryReader { geo in
                let width = geo.size.width
                let budgetMax = max(prediction.budgetCents, prediction.predictedTotalCents)
                let currentWidth = width * Double(prediction.currentTotalCents) / Double(budgetMax)
                let predictedWidth = width * Double(prediction.predictedTotalCents) / Double(budgetMax)
                let budgetLine = width * Double(prediction.budgetCents) / Double(budgetMax)

                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))

                    // Predicted (lighter)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(prediction.willExceedBudget ? BudgetVaultTheme.negative.opacity(0.3) : BudgetVaultTheme.positive.opacity(0.3))
                        .frame(width: min(predictedWidth, width))

                    // Current (solid)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(prediction.willExceedBudget ? BudgetVaultTheme.negative : BudgetVaultTheme.positive)
                        .frame(width: min(currentWidth, width))

                    // Budget line marker
                    if budgetLine < width {
                        Rectangle()
                            .fill(Color.primary)
                            .frame(width: 2, height: 16)
                            .offset(x: budgetLine)
                    }
                }
                .frame(height: 10)
            }
            .frame(height: 10)

            // Details row
            HStack {
                VStack(alignment: .leading) {
                    Text("Current")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.format(cents: prediction.currentTotalCents))
                        .font(.caption.bold())
                }
                Spacer()
                VStack {
                    Text("Budget")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.format(cents: prediction.budgetCents))
                        .font(.caption.bold())
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(prediction.willExceedBudget ? "Over by" : "Savings")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.format(cents: prediction.willExceedBudget
                        ? prediction.predictedTotalCents - prediction.budgetCents
                        : prediction.predictedSavings))
                        .font(.caption.bold())
                        .foregroundStyle(prediction.willExceedBudget ? BudgetVaultTheme.negative : BudgetVaultTheme.positive)
                }
            }

            // Confidence & days remaining
            HStack {
                Label("\(Int(prediction.confidence * 100))% confidence", systemImage: "chart.bar.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(prediction.daysRemaining) days remaining")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("ML forecast: predicted spending \(CurrencyFormatter.format(cents: prediction.predictedTotalCents)), \(prediction.willExceedBudget ? "over budget" : "under budget"), \(trendLabel) trend")
    }
}

// MARK: - Spending Pattern Card

struct SpendingPatternCard: View {
    let pattern: SpendingPattern

    private var patternIcon: String {
        switch pattern.type {
        case .frontLoader: return "arrow.down.right.circle.fill"
        case .weekendSpender: return "party.popper.fill"
        case .steadyEddie: return "metronome.fill"
        case .batchBuyer: return "cart.fill"
        case .escalator: return "arrow.up.right.circle.fill"
        case .balanced: return "equal.circle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BudgetVaultTheme.spacingMD) {
            HStack {
                Image(systemName: "person.text.rectangle")
                    .foregroundStyle(BudgetVaultTheme.electricBlue)
                Text("Your Spending Style")
                    .font(.headline)
            }

            HStack(spacing: 12) {
                Image(systemName: patternIcon)
                    .font(.system(size: 32))
                    .foregroundStyle(BudgetVaultTheme.electricBlue)
                    .frame(width: 48, height: 48)
                    .background(BudgetVaultTheme.electricBlue.opacity(0.1), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(pattern.title)
                        .font(.title3.bold())
                    Text(pattern.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Tip
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(BudgetVaultTheme.caution)
                    .font(.caption)
                Text(pattern.tip)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(BudgetVaultTheme.spacingSM)
            .background(BudgetVaultTheme.caution.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Spending pattern: \(pattern.title). \(pattern.description). Tip: \(pattern.tip)")
    }
}

// MARK: - Anomaly List Card

struct AnomalyListCard: View {
    let anomalies: [AnomalyResult]

    var body: some View {
        VStack(alignment: .leading, spacing: BudgetVaultTheme.spacingMD) {
            HStack {
                Image(systemName: "exclamationmark.magnifyingglass")
                    .foregroundStyle(BudgetVaultTheme.negative)
                Text("Anomaly Detection")
                    .font(.headline)
                Spacer()
                Text("\(anomalies.count) found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(anomalies.prefix(3).enumerated()), id: \.offset) { _, anomaly in
                HStack(spacing: 12) {
                    Text(anomaly.categoryEmoji)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(anomaly.transaction.note.isEmpty ? anomaly.categoryName : anomaly.transaction.note)
                            .font(.subheadline.bold())
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Text("Median: \(CurrencyFormatter.format(cents: anomaly.median))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("Score: \(String(format: "%.1f", anomaly.zScore))")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(BudgetVaultTheme.negative.opacity(0.1), in: Capsule())
                                .foregroundStyle(BudgetVaultTheme.negative)
                        }
                    }

                    Spacer()

                    Text(CurrencyFormatter.format(cents: anomaly.amount))
                        .font(.subheadline.bold())
                        .foregroundStyle(BudgetVaultTheme.negative)
                }
                .accessibilityLabel("\(anomaly.categoryEmoji) \(anomaly.transaction.note.isEmpty ? anomaly.categoryName : anomaly.transaction.note): \(CurrencyFormatter.format(cents: anomaly.amount)), anomaly score \(String(format: "%.1f", anomaly.zScore))")
            }

            if anomalies.isEmpty {
                Text("No unusual transactions detected this month.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Category Forecast Card

struct CategoryForecastCard: View {
    let forecasts: [CategoryForecast]

    var body: some View {
        VStack(alignment: .leading, spacing: BudgetVaultTheme.spacingMD) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(BudgetVaultTheme.caution)
                Text("Category Forecasts")
                    .font(.headline)
            }

            if forecasts.isEmpty {
                Text("All categories are on track.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(forecasts.prefix(4).enumerated()), id: \.offset) { _, forecast in
                    HStack(spacing: 12) {
                        Text(forecast.categoryEmoji)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(forecast.categoryName)
                                .font(.subheadline.bold())
                            statusLabel(forecast.status)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(CurrencyFormatter.format(cents: forecast.projectedTotalCents))
                                .font(.caption.bold())
                                .foregroundStyle(BudgetVaultTheme.negative)
                            Text("of \(CurrencyFormatter.format(cents: forecast.budgetedCents))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityLabel("\(forecast.categoryEmoji) \(forecast.categoryName): projected \(CurrencyFormatter.format(cents: forecast.projectedTotalCents)) of \(CurrencyFormatter.format(cents: forecast.budgetedCents)) budget")
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func statusLabel(_ status: CategoryForecast.Status) -> some View {
        switch status {
        case .onTrack:
            Label("On track", systemImage: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(BudgetVaultTheme.positive)
        case .willExceed(let days):
            Label("Exceeds in \(days)d", systemImage: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(BudgetVaultTheme.caution)
        case .overBudget:
            Label("Over budget", systemImage: "xmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(BudgetVaultTheme.negative)
        }
    }
}
