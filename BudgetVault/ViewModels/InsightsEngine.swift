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

    static func generateInsights(budget: Budget, previousBudget: Budget?, allBudgets: [Budget] = [], currentStreak: Int? = nil, lastLogDate: String? = nil) -> [Insight] {
        var insights: [Insight] = []
        let calendar = Calendar.current
        let today = Date()

        let categories = (budget.categories ?? []).filter { !$0.isHidden }
        let allTxs = categories.flatMap { cat in
            (cat.transactions ?? []).filter { !$0.isIncome && $0.date >= budget.periodStart && $0.date < budget.nextPeriodStart }
        }

        let daysInPeriod = calendar.dateComponents([.day], from: budget.periodStart, to: budget.nextPeriodStart).day ?? 30
        let daysSoFar = max(1, calendar.dateComponents([.day], from: budget.periodStart, to: today).day ?? 1)
        let totalSpent = budget.totalSpentCents()

        // Pre-compute spent map once for all categories (0.1 performance fix)
        var spentMap: [UUID: Int64] = [:]
        for cat in categories {
            spentMap[cat.id] = cat.spentCents(in: budget)
        }

        // 1. Category >90% budget
        for cat in categories {
            let spent = spentMap[cat.id] ?? 0
            let pct = cat.budgetedAmountCents > 0 ? Double(spent) / Double(cat.budgetedAmountCents) : 0
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
            let txs = (cat.transactions ?? []).filter { !$0.isIncome && $0.date >= budget.periodStart && $0.date < budget.nextPeriodStart }
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
            let prevSpentAtSamePoint = (prev.categories ?? [])
                .flatMap { $0.transactions ?? [] }
                .filter {
                    !$0.isIncome &&
                    $0.date >= prev.periodStart &&
                    $0.date < min(calendar.date(byAdding: .day, value: daysSoFar, to: prev.periodStart)!, prev.nextPeriodStart)
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
        let streak = currentStreak ?? UserDefaults.standard.integer(forKey: AppStorageKeys.currentStreak)
        if streak >= 7 {
            insights.append(Insight(
                icon: "🔥",
                title: "\(streak)-day streak!",
                message: "You've logged expenses \(streak) days in a row. Keep it up!",
                severity: .success
            ))
        }

        // 6. Streak at risk
        let resolvedLastLogDate = lastLogDate ?? UserDefaults.standard.string(forKey: AppStorageKeys.lastLogDate) ?? ""
        if streak > 0 && !resolvedLastLogDate.isEmpty {
            let todayStr = DateHelpers.dateString(calendar.startOfDay(for: today))
            let hour = calendar.component(.hour, from: today)
            if resolvedLastLogDate != todayStr && hour >= 18 {
                insights.append(Insight(
                    icon: "⚠️",
                    title: "Streak at risk!",
                    message: "You haven't logged anything today. Don't break your \(streak)-day streak!",
                    severity: .nudge
                ))
            }
        }

        // 7. Weekend Warrior — weekend spending > 2x weekday average
        if allTxs.count >= 5 {
            var weekdayTotal: Int64 = 0, weekdayDays: Set<Date> = []
            var weekendTotal: Int64 = 0, weekendDays: Set<Date> = []

            for tx in allTxs {
                let day = calendar.startOfDay(for: tx.date)
                let weekday = calendar.component(.weekday, from: tx.date)
                if weekday == 1 || weekday == 7 {
                    weekendTotal += tx.amountCents
                    weekendDays.insert(day)
                } else {
                    weekdayTotal += tx.amountCents
                    weekdayDays.insert(day)
                }
            }

            let weekdayAvg = weekdayDays.count > 0 ? Double(weekdayTotal) / Double(weekdayDays.count) : 0
            let weekendAvg = weekendDays.count > 0 ? Double(weekendTotal) / Double(weekendDays.count) : 0

            if weekendAvg > weekdayAvg * 2 && weekendDays.count >= 2 {
                insights.append(Insight(
                    icon: "🎡",
                    title: "Weekend warrior",
                    message: "You spend \(CurrencyFormatter.format(cents: Int64(weekendAvg)))/day on weekends vs \(CurrencyFormatter.format(cents: Int64(weekdayAvg)))/day on weekdays.",
                    severity: .info
                ))
            }
        }

        // 8. Category Creep — spending increased 3+ months in a row
        if allBudgets.count >= 3 {
            let sorted = allBudgets.sorted { ($0.year, $0.month) < ($1.year, $1.month) }
            let recent = Array(sorted.suffix(4)) // need 3 comparisons = 4 months
            if recent.count >= 3 {
                for cat in categories {
                    var increasing = true
                    var prevSpent: Int64 = -1
                    var monthsIncreasing = 0

                    for b in recent {
                        let matchingCat = (b.categories ?? []).first { $0.name == cat.name }
                        let spent = matchingCat?.spentCents(in: b) ?? 0
                        if prevSpent >= 0 && spent > prevSpent && spent > 0 {
                            monthsIncreasing += 1
                        } else if prevSpent >= 0 {
                            increasing = false
                        }
                        prevSpent = spent
                    }

                    if increasing && monthsIncreasing >= 2 {
                        insights.append(Insight(
                            icon: "📊",
                            title: "\(cat.name) keeps rising",
                            message: "\(cat.name) spending has increased for \(monthsIncreasing + 1) months in a row.",
                            severity: .warning
                        ))
                        break // only show for first category found
                    }
                }
            }
        }

        // 9. Best Day to Shop — lowest average spending day of week
        if allTxs.count >= 7 {
            let dayNames = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            var dayTotals: [Int: Int64] = [:]
            var dayUniqueDates: [Int: Set<Date>] = [:]

            for tx in allTxs {
                let weekday = calendar.component(.weekday, from: tx.date)
                dayTotals[weekday, default: 0] += tx.amountCents
                let txDay = calendar.startOfDay(for: tx.date)
                dayUniqueDates[weekday, default: []].insert(txDay)
            }

            // Find day with lowest average (total per weekday / unique dates with that weekday)
            var bestDay = 0
            var bestAvg = Int64.max
            for (day, total) in dayTotals {
                let uniqueDateCount = dayUniqueDates[day]?.count ?? 1
                let avg = total / Int64(max(1, uniqueDateCount))
                if avg < bestAvg {
                    bestAvg = avg
                    bestDay = day
                }
            }

            if bestDay > 0 && bestDay <= 7 {
                insights.append(Insight(
                    icon: "📅",
                    title: "Your lightest day: \(dayNames[bestDay])",
                    message: "You spend an average of \(CurrencyFormatter.format(cents: bestAvg)) on \(dayNames[bestDay])s.",
                    severity: .info
                ))
            }
        }

        // 10. Payday Splurge — heavy spending in first 3 days of period
        if daysSoFar > 3 {
            let first3End = calendar.date(byAdding: .day, value: 3, to: budget.periodStart)!
            let first3Spent = allTxs.filter { $0.date >= budget.periodStart && $0.date < first3End }
                .reduce(Int64(0)) { $0 + $1.amountCents }
            let restSpent = totalSpent - first3Spent
            let restDays = max(1, daysSoFar - 3)

            let first3DailyAvg = Double(first3Spent) / 3.0
            let restDailyAvg = Double(restSpent) / Double(restDays)

            if first3DailyAvg > restDailyAvg * 2.5 && first3Spent > 0 && restSpent > 0 {
                let pct = Int(Double(first3Spent) * 100.0 / Double(totalSpent))
                insights.append(Insight(
                    icon: "💸",
                    title: "Payday splurge detected",
                    message: "You spent \(pct)% of your total in the first 3 days of the month.",
                    severity: .nudge
                ))
            }
        }

        // 11. Savings Rate
        if budget.totalIncomeCents > 0 && totalSpent > 0 {
            let savingsRate = Double(budget.totalIncomeCents - totalSpent) / Double(budget.totalIncomeCents)
            if savingsRate >= 0.2 {
                let pct = Int(savingsRate * 100)
                insights.append(Insight(
                    icon: "🏦",
                    title: "Saving \(pct)% of income",
                    message: "You're on track to save \(CurrencyFormatter.format(cents: budget.totalIncomeCents - totalSpent)) this month.",
                    severity: .success
                ))
            } else if savingsRate < 0 {
                insights.append(Insight(
                    icon: "🚨",
                    title: "Over budget",
                    message: "You've spent \(CurrencyFormatter.format(cents: totalSpent - budget.totalIncomeCents)) more than your income this month.",
                    severity: .warning
                ))
            }
        }

        // 12. Budget Fit Score — how close actual matches budgeted ratios
        let catsWithBudget = categories.filter { $0.budgetedAmountCents > 0 }
        if catsWithBudget.count >= 2 && totalSpent > 0 && budget.totalIncomeCents > 0 {
            var totalDeviation = 0.0
            for cat in catsWithBudget {
                let budgetedRatio = Double(cat.budgetedAmountCents) / Double(budget.totalIncomeCents)
                let actualRatio = Double(spentMap[cat.id] ?? 0) / Double(totalSpent)
                totalDeviation += abs(budgetedRatio - actualRatio)
            }
            // Score: 100 = perfect match, 0 = completely off
            let fitScore = max(0, Int((1.0 - totalDeviation / 2.0) * 100))
            if fitScore >= 80 {
                insights.append(Insight(
                    icon: "🎯",
                    title: "Budget fit: \(fitScore)%",
                    message: "Your spending closely matches your planned budget. Great discipline!",
                    severity: .success
                ))
            } else if fitScore < 50 && daysSoFar > 7 {
                insights.append(Insight(
                    icon: "🎯",
                    title: "Budget fit: \(fitScore)%",
                    message: "Your actual spending differs a lot from your planned budget. Consider adjusting your categories.",
                    severity: .nudge
                ))
            }
        }

        // 13. Fastest Draining Category
        if daysSoFar >= 3 {
            var fastestCat: Category?
            var fastestRate = 0.0

            for cat in catsWithBudget {
                let catSpent = spentMap[cat.id] ?? 0
                guard catSpent > 0 else { continue }
                let dailyRate = Double(catSpent) / Double(daysSoFar)
                let projectedDays = Double(cat.budgetedAmountCents) / dailyRate
                let burnRate = Double(daysSoFar) / projectedDays // >1 means draining faster than period

                if burnRate > fastestRate && burnRate > 1.2 {
                    fastestRate = burnRate
                    fastestCat = cat
                }
            }

            if let cat = fastestCat {
                let catSpent = spentMap[cat.id] ?? 0
                let dailyDrain = catSpent > 0 ? Double(catSpent) / Double(daysSoFar) : 0
                let daysUntilEmpty = dailyDrain > 0 ? Int(Double(cat.budgetedAmountCents - catSpent) / dailyDrain) : daysInPeriod
                if daysUntilEmpty > 0 && daysUntilEmpty < (daysInPeriod - daysSoFar) {
                    insights.append(Insight(
                        icon: "⏳",
                        title: "\(cat.name) draining fast",
                        message: "At this rate, \(cat.name) will be empty in \(daysUntilEmpty) days with \(daysInPeriod - daysSoFar) days left.",
                        severity: .warning
                    ))
                }
            }
        }

        // 14. Zero-Spend Days
        if daysSoFar >= 5 {
            var zeroSpendDays = 0
            let spendingByDay = Dictionary(grouping: allTxs) { calendar.startOfDay(for: $0.date) }

            for dayOffset in 0..<daysSoFar {
                guard let day = calendar.date(byAdding: .day, value: dayOffset, to: budget.periodStart) else { continue }
                let dayStart = calendar.startOfDay(for: day)
                if spendingByDay[dayStart] == nil {
                    zeroSpendDays += 1
                }
            }

            if zeroSpendDays >= 3 {
                insights.append(Insight(
                    icon: "🧘",
                    title: "\(zeroSpendDays) no-spend days",
                    message: "You've had \(zeroSpendDays) days without spending this month. Nice restraint!",
                    severity: .success
                ))
            }
        }

        // 15. Seasonal Trend — same month last year comparison
        if allBudgets.count >= 12 {
            let lastYearBudget = allBudgets.first { $0.month == budget.month && $0.year == budget.year - 1 }
            if let lastYear = lastYearBudget {
                let lastYearSpent = lastYear.totalSpentCents()
                if lastYearSpent > 0 {
                    let diff = totalSpent - lastYearSpent
                    let pctChange = abs(Double(diff) / Double(lastYearSpent) * 100)
                    if diff < 0 && pctChange >= 10 {
                        insights.append(Insight(
                            icon: "📉",
                            title: "Down from last year",
                            message: "You've spent \(Int(pctChange))% less than \(DateHelpers.monthYearString(month: lastYear.month, year: lastYear.year)).",
                            severity: .success
                        ))
                    } else if diff > 0 && pctChange >= 15 {
                        insights.append(Insight(
                            icon: "📈",
                            title: "Up from last year",
                            message: "Spending is up \(Int(pctChange))% compared to \(DateHelpers.monthYearString(month: lastYear.month, year: lastYear.year)).",
                            severity: .info
                        ))
                    }
                }
            }
        }

        // 16. Recurring vs Discretionary split — detect by linked RecurringExpense records
        var recurringSpent: Int64 = 0
        var discretionarySpent: Int64 = 0
        for cat in categories {
            let spent = spentMap[cat.id] ?? 0
            let isRecurring = !(cat.recurringExpenses ?? []).isEmpty
            if isRecurring {
                recurringSpent += spent
            } else {
                discretionarySpent += spent
            }
        }
        if recurringSpent > 0 && discretionarySpent > 0 && totalSpent > 0 {
            let fixedPct = Int(Double(recurringSpent) * 100.0 / Double(totalSpent))
            if fixedPct >= 70 {
                insights.append(Insight(
                    icon: "🔒",
                    title: "\(fixedPct)% goes to fixed costs",
                    message: "Most of your spending is fixed. Your flexible budget is \(CurrencyFormatter.format(cents: discretionarySpent)).",
                    severity: .info
                ))
            }
        }

        return insights
    }
}
