import Foundation
import Accelerate

/// On-device machine learning engine for spending analysis.
/// Uses statistical ML methods (regression, z-score anomaly detection,
/// exponential smoothing) trained on the user's own data.
/// No data ever leaves the device.
enum BudgetMLEngine {

    // MARK: - Spending Prediction (Linear Regression)

    /// Predicts total month-end spending using weighted linear regression
    /// on daily cumulative spending. More accurate than simple daily rate
    /// extrapolation because it accounts for spending acceleration/deceleration.
    static func predictMonthEndSpending(budget: Budget, expenses: [Transaction]? = nil) -> SpendingPrediction? {
        let calendar = Calendar.current
        let today = Date()
        let allTxs = expenses ?? gatherExpenses(budget: budget)
        guard !allTxs.isEmpty else { return nil }

        let daysInPeriod = calendar.dateComponents([.day], from: budget.periodStart, to: budget.nextPeriodStart).day ?? 30
        let daysSoFar = max(1, calendar.dateComponents([.day], from: budget.periodStart, to: today).day ?? 1)
        // Audit 2026-04-22 P0-6 Fix 5: raised from 3 → 5. With 1-2 data
        // points the weighted regression extrapolates nonsense (MobAI
        // caught predicted $4.67 when user had already spent $12.50).
        guard daysSoFar >= 5 else { return nil }

        // Build daily cumulative spending series
        var dailySpending = [Double](repeating: 0, count: daysSoFar)
        for tx in allTxs {
            let dayIndex = calendar.dateComponents([.day], from: budget.periodStart, to: tx.date).day ?? 0
            let clamped = min(max(dayIndex, 0), daysSoFar - 1)
            dailySpending[clamped] += Double(tx.amountCents)
        }

        // Convert to cumulative
        var cumulative = [Double](repeating: 0, count: daysSoFar)
        cumulative[0] = dailySpending[0]
        for i in 1..<daysSoFar {
            cumulative[i] = cumulative[i - 1] + dailySpending[i]
        }

        // Weighted linear regression: recent days weighted more heavily
        let x = (0..<daysSoFar).map { Double($0 + 1) }
        let y = cumulative
        let weights = x.map { pow($0 / Double(daysSoFar), 0.5) } // sqrt weighting favors recent

        let result = weightedLinearRegression(x: x, y: y, weights: weights)

        // Predict at day = daysInPeriod
        let rawPredicted = Int64(max(0, result.slope * Double(daysInPeriod) + result.intercept))
        let currentTotal = Int64(cumulative.last ?? 0)

        // Audit 2026-04-22 P0-6 Fix 5: the predicted month-end total is
        // cumulative spending — it can never be less than what's already
        // been spent. Regression on sparse early-period data can produce
        // a negative-slope extrapolation that violates this invariant.
        // Floor at max(currentTotal, simpleProjected).
        let simpleProjectedPreview = Int64(Double(currentTotal) / Double(daysSoFar) * Double(daysInPeriod))
        let predicted = max(rawPredicted, currentTotal, simpleProjectedPreview)

        // Confidence based on MAPE of daily (non-cumulative) spending and data coverage
        let mape: Double = {
            let nonZeroDays = dailySpending.filter { $0 > 0 }
            guard !nonZeroDays.isEmpty else { return 1.0 }
            let meanDaily = nonZeroDays.reduce(0, +) / Double(nonZeroDays.count)
            guard meanDaily > 0 else { return 1.0 }
            let totalError = nonZeroDays.reduce(0.0) { $0 + abs($1 - meanDaily) / meanDaily }
            return totalError / Double(nonZeroDays.count)
        }()
        let confidence = max(0, min(1.0, 1.0 - mape)) * (Double(daysSoFar) / Double(daysInPeriod))

        // Simple prediction: daily rate extrapolation (for comparison)
        let simpleProjected = Int64(Double(currentTotal) / Double(daysSoFar) * Double(daysInPeriod))

        // Determine trend by comparing daily regression slope to average daily rate.
        // Audit 2026-04-23 AI P0: require ≥10 days of data AND a
        // minimum R² to label .accelerating / .decelerating. Previously
        // fired on 5-day random walks with no fit quality gate —
        // "Accelerating" confidently on noise.
        let dailyReg = weightedLinearRegression(
            x: (0..<daysSoFar).map { Double($0) },
            y: dailySpending,
            weights: [Double](repeating: 1.0, count: daysSoFar)
        )
        let avgDailyRate = Double(currentTotal) / Double(daysSoFar)
        let rSquared = Self.rSquared(
            x: (0..<daysSoFar).map { Double($0) },
            y: dailySpending,
            slope: dailyReg.slope,
            intercept: dailyReg.intercept
        )
        let trendThreshold = avgDailyRate * 0.05
        let trend: SpendingPrediction.Trend
        if daysSoFar < 10 || rSquared < 0.3 {
            trend = .steady
        } else if avgDailyRate > 0 && dailyReg.slope > trendThreshold {
            trend = .accelerating
        } else if avgDailyRate > 0 && dailyReg.slope < -trendThreshold {
            trend = .decelerating
        } else {
            trend = .steady
        }

        return SpendingPrediction(
            predictedTotalCents: predicted,
            simpleProjectedCents: simpleProjected,
            currentTotalCents: currentTotal,
            budgetCents: budget.totalIncomeCents,
            confidence: confidence,
            trend: trend,
            daysRemaining: daysInPeriod - daysSoFar
        )
    }

    // MARK: - Anomaly Detection (Z-Score)

    /// Detects anomalous transactions using modified z-score (median absolute deviation).
    /// More robust than mean/stddev for skewed spending distributions.
    static func detectAnomalies(budget: Budget) -> [AnomalyResult] {
        let categories = (budget.categories ?? []).filter { !$0.isHidden }
        var anomalies: [AnomalyResult] = []

        for cat in categories {
            let txs = (cat.transactions ?? []).filter {
                !$0.isIncome && $0.date >= budget.periodStart && $0.date < budget.nextPeriodStart
            }
            guard txs.count >= 4 else { continue } // need enough data

            let amounts = txs.map { Double($0.amountCents) }
            let sorted = amounts.sorted()
            // Audit 2026-04-23 AI P0: true median for even N. Prior
            // `sorted[sorted.count / 2]` returned the upper median on
            // even counts, biasing the MAD downstream and deflating
            // the z-score — missing real outliers.
            let median = Self.trueMedian(of: sorted)

            // MAD: Median Absolute Deviation
            let deviations = amounts.map { abs($0 - median) }
            let mad = Self.trueMedian(of: deviations.sorted())

            // Audit 2026-04-23 AI P0: MAD=0 used to silently skip
            // anomaly detection for this category. Real user case:
            // 4 identical $10 recurring coffees + 1 $200 outlier =
            // median $10, deviations [0,0,0,0,190], MAD=0 (because
            // 3 of 5 deviations are zero), outlier never flagged.
            // Fallback: use standard deviation × 2.5 when MAD=0.
            let mad_nonzero: Double
            if mad > 0 {
                mad_nonzero = mad
            } else {
                let mean = amounts.reduce(0, +) / Double(amounts.count)
                let variance = amounts.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(amounts.count)
                let stddev = variance.squareRoot()
                guard stddev > 0 else { continue }
                mad_nonzero = stddev / 1.4826 // ~equivalent to MAD for normal distribution
            }

            // Modified z-score: 0.6745 is the 0.75th quartile of the standard normal
            let threshold = 3.0
            for tx in txs {
                let modifiedZ = 0.6745 * (Double(tx.amountCents) - median) / mad_nonzero
                if modifiedZ > threshold {
                    anomalies.append(AnomalyResult(
                        transaction: tx,
                        categoryName: cat.name,
                        categoryEmoji: cat.emoji,
                        zScore: modifiedZ,
                        median: Int64(median),
                        amount: tx.amountCents
                    ))
                }
            }
        }

        return anomalies.sorted { $0.zScore > $1.zScore }
    }

    // MARK: - Spending Pattern Classification

    /// Classifies the user's spending behavior based on temporal patterns.
    /// Uses feature extraction + rule-based classification trained on
    /// common behavioral finance patterns.
    static func classifySpendingPattern(budget: Budget, expenses: [Transaction]? = nil) -> SpendingPattern? {
        let calendar = Calendar.current
        let today = Date()
        let allTxs = expenses ?? gatherExpenses(budget: budget)
        let daysSoFar = max(1, calendar.dateComponents([.day], from: budget.periodStart, to: today).day ?? 1)
        guard allTxs.count >= 5 && daysSoFar >= 7 else { return nil }

        // Feature extraction
        let dailyAmounts = buildDailyAmounts(txs: allTxs, periodStart: budget.periodStart, days: daysSoFar)

        // Feature 1: Front-loading ratio (first third vs rest)
        let thirdPoint = max(1, daysSoFar / 3)
        let frontSpend = dailyAmounts.prefix(thirdPoint).reduce(0, +)
        let totalSpend = dailyAmounts.reduce(0, +)
        let frontRatio = totalSpend > 0 ? frontSpend / totalSpend : 0

        // Feature 2: Weekend ratio
        var weekendSpend = 0.0
        for (i, amount) in dailyAmounts.enumerated() {
            if let date = calendar.date(byAdding: .day, value: i, to: budget.periodStart) {
                let weekday = calendar.component(.weekday, from: date)
                if weekday == 1 || weekday == 7 { weekendSpend += amount }
            }
        }
        let weekendRatio = totalSpend > 0 ? weekendSpend / totalSpend : 0

        // Feature 3: Spending consistency (coefficient of variation)
        let nonZeroDays = dailyAmounts.filter { $0 > 0 }
        let cv = coefficientOfVariation(nonZeroDays)

        // Feature 4: Zero-spend day ratio
        let zeroRatio = Double(dailyAmounts.filter { $0 == 0 }.count) / Double(daysSoFar)

        // Feature 5: Trend (are they spending more or less over time?)
        let reg = weightedLinearRegression(
            x: (0..<daysSoFar).map { Double($0) },
            y: dailyAmounts,
            weights: [Double](repeating: 1.0, count: daysSoFar)
        )
        let trendDirection = reg.slope

        // Score all patterns and return the one with highest confidence
        var candidates: [SpendingPattern] = []

        let frontLoaderConfidence = daysSoFar >= 10 ? min(1.0, frontRatio) * (frontRatio > 0.5 ? 1.0 : frontRatio) : 0
        candidates.append(SpendingPattern(
            type: .frontLoader,
            title: "Front-Loader",
            description: "You tend to spend heavily at the start of the month, then taper off.",
            tip: "Try setting a daily spending target to spread expenses more evenly.",
            confidence: frontLoaderConfidence
        ))

        let weekendConfidence = weekendRatio > 0.35 ? weekendRatio : 0
        candidates.append(SpendingPattern(
            type: .weekendSpender,
            title: "Weekend Spender",
            description: "Most of your spending happens on weekends.",
            tip: "Plan weekend activities in advance to stay within budget.",
            confidence: weekendConfidence
        ))

        let steadyConfidence = (cv < 0.8 && zeroRatio < 0.3) ? (1.0 - cv) * (1.0 - zeroRatio) : 0
        candidates.append(SpendingPattern(
            type: .steadyEddie,
            title: "Steady Eddie",
            description: "You spend consistently day to day. Very disciplined!",
            // Audit 2026-04-23 Brand: declarative, no exclamation.
            tip: "Consistent daily spending makes forecasts reliable.",
            confidence: steadyConfidence
        ))

        let batchConfidence = zeroRatio > 0.35 ? zeroRatio : 0
        candidates.append(SpendingPattern(
            type: .batchBuyer,
            title: "Batch Buyer",
            description: "You make few but larger purchases, with many no-spend days.",
            tip: "Great restraint! Just watch that individual purchases stay in budget.",
            confidence: batchConfidence
        ))

        let escalatorConfidence = (trendDirection > 0 && cv > 0.5) ? min(1.0, cv * 0.7) : 0
        candidates.append(SpendingPattern(
            type: .escalator,
            title: "Escalator",
            description: "Your daily spending is trending upward through the month.",
            tip: "Be mindful of spending creep. Check your remaining budget more often.",
            confidence: escalatorConfidence
        ))

        candidates.append(SpendingPattern(
            type: .balanced,
            title: "Balanced",
            description: "Your spending doesn't fit a strong pattern. That's flexible!",
            tip: "No strong tendencies detected. Keep tracking to reveal patterns over time.",
            confidence: 0.3
        ))

        return candidates.max(by: { $0.confidence < $1.confidence })
    }

    // MARK: - Category Forecast

    /// Predicts which categories will go over budget using exponential smoothing
    /// on per-category daily spending rates.
    static func forecastCategories(budget: Budget) -> [CategoryForecast] {
        let calendar = Calendar.current
        let today = Date()
        let daysInPeriod = calendar.dateComponents([.day], from: budget.periodStart, to: budget.nextPeriodStart).day ?? 30
        let daysSoFar = max(1, calendar.dateComponents([.day], from: budget.periodStart, to: today).day ?? 1)
        guard daysSoFar >= 5 else { return [] }

        let categories = (budget.categories ?? []).filter { !$0.isHidden && $0.budgetedAmountCents > 0 }
        var forecasts: [CategoryForecast] = []

        for cat in categories {
            let txs = (cat.transactions ?? []).filter {
                !$0.isIncome && $0.date >= budget.periodStart && $0.date < budget.nextPeriodStart
            }
            guard txs.count >= 3 else { continue } // require 3+ transactions per category

            let remaining = cat.budgetedAmountCents - cat.spentCents(in: budget)
            let daysRemaining = daysInPeriod - daysSoFar

            // For sparse categories (< 3 txs per period already filtered above),
            // use average-per-transaction * expected-transactions-remaining
            // instead of daily smoothing which zero-fills and underestimates.
            let projectedRemaining: Int64
            let recentRate: Double

            let txDays = Set(txs.map { calendar.startOfDay(for: $0.date) }).count
            if txDays < 3 {
                // Sparse: use per-transaction average * expected remaining transactions
                let avgPerTx = Double(cat.spentCents(in: budget)) / Double(txs.count)
                let txPerDay = Double(txs.count) / Double(daysSoFar)
                let expectedRemainingTxs = txPerDay * Double(daysRemaining)
                projectedRemaining = Int64(avgPerTx * expectedRemainingTxs)
                recentRate = avgPerTx * txPerDay
            } else {
                let dailyAmounts = buildDailyAmounts(txs: txs, periodStart: budget.periodStart, days: daysSoFar)
                let smoothed = exponentialSmoothing(dailyAmounts, alpha: 0.3)
                recentRate = smoothed.last ?? 0
                guard recentRate > 0 else { continue }
                projectedRemaining = Int64(recentRate * Double(daysRemaining))
            }

            let status: CategoryForecast.Status
            if remaining <= 0 {
                status = .overBudget
            } else if projectedRemaining > remaining {
                let daysUntilOver = remaining > 0 ? Int(Double(remaining) / recentRate) : 0
                status = .willExceed(inDays: daysUntilOver)
            } else {
                status = .onTrack
            }

            forecasts.append(CategoryForecast(
                categoryName: cat.name,
                categoryEmoji: cat.emoji,
                budgetedCents: cat.budgetedAmountCents,
                spentCents: cat.spentCents(in: budget),
                projectedTotalCents: cat.spentCents(in: budget) + projectedRemaining,
                dailyRate: Int64(recentRate),
                status: status
            ))
        }

        return forecasts.filter { $0.status != .onTrack }
    }

    // MARK: - Math Utilities

    private struct RegressionResult {
        let slope: Double
        let intercept: Double
        let rSquared: Double
    }

    private static func weightedLinearRegression(x: [Double], y: [Double], weights: [Double]) -> RegressionResult {
        let n = x.count
        guard n >= 2 && n == y.count && n == weights.count else {
            return RegressionResult(slope: 0, intercept: 0, rSquared: 0)
        }

        var sumW = 0.0, sumWX = 0.0, sumWY = 0.0, sumWXX = 0.0, sumWXY = 0.0

        for i in 0..<n {
            let w = weights[i]
            sumW += w
            sumWX += w * x[i]
            sumWY += w * y[i]
            sumWXX += w * x[i] * x[i]
            sumWXY += w * x[i] * y[i]
        }

        let denom = sumW * sumWXX - sumWX * sumWX
        guard abs(denom) > 1e-10 else {
            return RegressionResult(slope: 0, intercept: sumWY / max(sumW, 1), rSquared: 0)
        }

        let slope = (sumW * sumWXY - sumWX * sumWY) / denom
        let intercept = (sumWY - slope * sumWX) / sumW

        // R-squared
        let yMean = sumWY / sumW
        var ssRes = 0.0, ssTot = 0.0
        for i in 0..<n {
            let predicted = slope * x[i] + intercept
            ssRes += weights[i] * (y[i] - predicted) * (y[i] - predicted)
            ssTot += weights[i] * (y[i] - yMean) * (y[i] - yMean)
        }
        let rSquared = ssTot > 0 ? max(0, 1.0 - ssRes / ssTot) : 0

        return RegressionResult(slope: slope, intercept: intercept, rSquared: rSquared)
    }

    private static func exponentialSmoothing(_ data: [Double], alpha: Double) -> [Double] {
        guard !data.isEmpty else { return [] }
        var smoothed = [Double](repeating: 0, count: data.count)
        smoothed[0] = data[0]
        for i in 1..<data.count {
            smoothed[i] = alpha * data[i] + (1 - alpha) * smoothed[i - 1]
        }
        return smoothed
    }

    private static func coefficientOfVariation(_ data: [Double]) -> Double {
        guard data.count >= 2 else { return 0 }
        var mean = 0.0
        vDSP_meanvD(data, 1, &mean, vDSP_Length(data.count))
        guard mean > 0 else { return 0 }

        let diffs = data.map { ($0 - mean) * ($0 - mean) }
        let variance = diffs.reduce(0, +) / Double(data.count)
        return sqrt(variance) / mean
    }

    // MARK: - Data Helpers

    /// Gather all expense transactions for a budget period. Call once and pass to ML functions.
    static func gatherExpenses(budget: Budget) -> [Transaction] {
        (budget.categories ?? []).flatMap { cat in
            (cat.transactions ?? []).filter {
                !$0.isIncome && $0.date >= budget.periodStart && $0.date < budget.nextPeriodStart
            }
        }
    }

    private static func buildDailyAmounts(txs: [Transaction], periodStart: Date, days: Int) -> [Double] {
        let calendar = Calendar.current
        var daily = [Double](repeating: 0, count: days)
        for tx in txs {
            let dayIndex = calendar.dateComponents([.day], from: periodStart, to: tx.date).day ?? 0
            let clamped = min(max(dayIndex, 0), days - 1)
            daily[clamped] += Double(tx.amountCents)
        }
        return daily
    }

    // MARK: - Statistics helpers

    /// Audit 2026-04-23 AI P0: true median (averages the two middle
    /// values on even-N arrays). Prior `sorted[count/2]` returned the
    /// upper median, biasing the MAD downstream.
    static func trueMedian(of sorted: [Double]) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let count = sorted.count
        if count % 2 == 1 {
            return sorted[count / 2]
        } else {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2
        }
    }

    /// Audit 2026-04-23 AI P0: coefficient of determination for the
    /// weighted-linear-regression fit. Used to gate trend labeling so
    /// "Accelerating" doesn't fire on noise-heavy data.
    static func rSquared(x: [Double], y: [Double], slope: Double, intercept: Double) -> Double {
        guard x.count == y.count, !y.isEmpty else { return 0 }
        let meanY = y.reduce(0, +) / Double(y.count)
        var ssRes = 0.0
        var ssTot = 0.0
        for i in 0..<y.count {
            let predicted = slope * x[i] + intercept
            let residual = y[i] - predicted
            ssRes += residual * residual
            let totalDiff = y[i] - meanY
            ssTot += totalDiff * totalDiff
        }
        guard ssTot > 0 else { return 0 }
        return max(0, 1 - (ssRes / ssTot))
    }
}

// MARK: - Result Types

struct SpendingPrediction {
    let predictedTotalCents: Int64
    let simpleProjectedCents: Int64
    let currentTotalCents: Int64
    let budgetCents: Int64
    let confidence: Double
    let trend: Trend
    let daysRemaining: Int

    enum Trend {
        case accelerating, steady, decelerating
    }

    var willExceedBudget: Bool { predictedTotalCents > budgetCents }
    var predictedSavings: Int64 { max(0, budgetCents - predictedTotalCents) }
}

struct AnomalyResult {
    let transaction: Transaction
    let categoryName: String
    let categoryEmoji: String
    let zScore: Double
    let median: Int64
    let amount: Int64
}

struct SpendingPattern {
    let type: PatternType
    let title: String
    let description: String
    let tip: String
    let confidence: Double

    enum PatternType {
        case frontLoader, weekendSpender, steadyEddie
        case batchBuyer, escalator, balanced
    }
}

struct CategoryForecast {
    let categoryName: String
    let categoryEmoji: String
    let budgetedCents: Int64
    let spentCents: Int64
    let projectedTotalCents: Int64
    let dailyRate: Int64
    let status: Status

    enum Status: Equatable {
        case onTrack
        case willExceed(inDays: Int)
        case overBudget
    }
}
