import Foundation

struct Insight: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let message: String
    let severity: Severity

    enum Severity: String {
        case warning, info, success, nudge

        var iconName: String {
            switch self {
            case .warning: "exclamationmark.triangle.fill"
            case .info: "info.circle.fill"
            case .success: "checkmark.circle.fill"
            case .nudge: "bell.fill"
            }
        }
    }
}

enum InsightsEngine {

    static func generateInsights(budget: Budget, previousBudget: Budget?) -> [Insight] {
        var insights: [Insight] = []
        let calendar = Calendar.current
        let today = Date()

        let categories = budget.categories.filter { !$0.isHidden }

        // 1. Category >90% budget
        for cat in categories {
            let pct = cat.percentSpent(in: budget)
            if pct >= 0.9 && cat.budgetedAmountCents > 0 {
                insights.append(Insight(
                    icon: cat.emoji,
                    title: "\(cat.name) is almost maxed",
                    message: "You've spent \(Int(pct * 100))% of your \(cat.name) budget.",
                    severity: .warning
                ))
            }
        }

        // 2. Spending velocity warning
        let daysInPeriod = calendar.dateComponents([.day], from: budget.periodStart, to: budget.nextPeriodStart).day ?? 30
        let daysSoFar = max(1, calendar.dateComponents([.day], from: budget.periodStart, to: today).day ?? 1)
        let totalSpent = budget.totalSpentCents()
        if daysSoFar > 0 && daysInPeriod > 0 {
            let dailyRate = Double(totalSpent) / Double(daysSoFar)
            let projected = Int64(dailyRate * Double(daysInPeriod))
            if projected > budget.totalIncomeCents && totalSpent > 0 {
                insights.append(Insight(
                    icon: "📈",
                    title: "On pace to overspend",
                    message: "At your current rate, you'll spend \(CurrencyFormatter.format(cents: projected)) this month.",
                    severity: .warning
                ))
            }
        }

        // 3. Transaction > 2x category average
        for cat in categories {
            let txs = cat.transactions.filter { !$0.isIncome && $0.date >= budget.periodStart && $0.date < budget.nextPeriodStart }
            guard txs.count >= 2 else { continue }
            let avg = txs.reduce(Int64(0)) { $0 + $1.amountCents } / Int64(txs.count)
            if let largest = txs.max(by: { $0.amountCents < $1.amountCents }),
               largest.amountCents > avg * 2 {
                insights.append(Insight(
                    icon: cat.emoji,
                    title: "Unusual \(cat.name) expense",
                    message: "\"\(largest.note.isEmpty ? "Transaction" : largest.note)\" at \(CurrencyFormatter.format(cents: largest.amountCents)) is over 2x your average.",
                    severity: .info
                ))
            }
        }

        // 4. Spent less than previous month at same point
        if let prev = previousBudget {
            let prevSpentAtSamePoint = prev.categories
                .flatMap { $0.transactions }
                .filter {
                    !$0.isIncome &&
                    $0.date >= prev.periodStart &&
                    $0.date < min(prev.periodStart.addingTimeInterval(TimeInterval(daysSoFar * 86400)), prev.nextPeriodStart)
                }
                .reduce(Int64(0)) { $0 + $1.amountCents }

            if totalSpent < prevSpentAtSamePoint && prevSpentAtSamePoint > 0 {
                let saved = prevSpentAtSamePoint - totalSpent
                insights.append(Insight(
                    icon: "🎉",
                    title: "Spending less than last month",
                    message: "You've spent \(CurrencyFormatter.format(cents: saved)) less than this point last month.",
                    severity: .success
                ))
            }
        }

        // 5. Streak
        let streak = UserDefaults.standard.integer(forKey: "currentStreak")
        if streak >= 7 {
            insights.append(Insight(
                icon: "🔥",
                title: "\(streak)-day streak!",
                message: "You've logged expenses \(streak) days in a row. Keep it up!",
                severity: .success
            ))
        }

        // 6. Streak at risk
        let lastLogDate = UserDefaults.standard.string(forKey: "lastLogDate") ?? ""
        if streak > 0 && !lastLogDate.isEmpty {
            let todayStr = DateHelpers.dateString(calendar.startOfDay(for: today))
            let hour = calendar.component(.hour, from: today)
            if lastLogDate != todayStr && hour >= 18 {
                insights.append(Insight(
                    icon: "⚠️",
                    title: "Streak at risk!",
                    message: "You haven't logged anything today. Don't break your \(streak)-day streak!",
                    severity: .nudge
                ))
            }
        }

        return insights
    }
}
