import Foundation

enum AchievementService {

    // MARK: - Types

    struct Achievement: Identifiable, Codable, Equatable {
        let id: String
        let title: String
        let description: String
        let emoji: String
        let tier: Tier
        var unlockedDate: Date?

        enum Tier: String, Codable, CaseIterable {
            case bronze, silver, gold
        }

        static func == (lhs: Achievement, rhs: Achievement) -> Bool {
            lhs.id == rhs.id
        }
    }

    // MARK: - All Achievements

    static let allAchievements: [Achievement] = [
        // Streak achievements
        Achievement(id: "streak_7", title: "Week Warrior", description: "7-day logging streak", emoji: "\u{1F525}", tier: .bronze),
        Achievement(id: "streak_30", title: "Monthly Master", description: "30-day logging streak", emoji: "\u{1F525}", tier: .silver),
        Achievement(id: "streak_100", title: "Century Club", description: "100-day logging streak", emoji: "\u{1F525}", tier: .gold),

        // Budget achievements
        Achievement(id: "under_budget_1", title: "Budget Beginner", description: "First month under budget", emoji: "\u{1F3AF}", tier: .bronze),
        Achievement(id: "under_budget_3", title: "Budget Pro", description: "3 months under budget", emoji: "\u{1F3AF}", tier: .silver),
        Achievement(id: "under_budget_12", title: "Budget Legend", description: "12 months under budget", emoji: "\u{1F3AF}", tier: .gold),

        // Saving achievements
        Achievement(id: "saved_100", title: "First Hundred", description: "Saved $100 in a month", emoji: "\u{1F4B0}", tier: .bronze),
        Achievement(id: "saved_500", title: "Halfway There", description: "Saved $500 in a month", emoji: "\u{1F4B0}", tier: .silver),
        Achievement(id: "saved_1000", title: "Thousand Club", description: "Saved $1,000 in a month", emoji: "\u{1F4B0}", tier: .gold),

        // Category achievements
        Achievement(id: "all_under", title: "Clean Sweep", description: "All categories under budget", emoji: "\u{2705}", tier: .silver),
        Achievement(id: "no_spend_day", title: "Zero Day", description: "A day with no spending", emoji: "\u{1F9D8}", tier: .bronze),
        Achievement(id: "first_transaction", title: "Getting Started", description: "Logged your first expense", emoji: "\u{1F4DD}", tier: .bronze),
    ]

    // MARK: - UserDefaults Keys

    private static let unlockedKey = "unlockedAchievements"
    private static let underBudgetMonthsKey = "underBudgetMonthCount"

    // MARK: - Public API

    /// Check all achievements against current state and return newly unlocked ones.
    static func checkAchievements(budget: Budget, transactions: [Transaction]) -> [Achievement] {
        let alreadyUnlocked = unlockedDateMap()
        var newlyUnlocked: [Achievement] = []

        let periodTransactions = transactions.filter { tx in
            !tx.isIncome && tx.date >= budget.periodStart && tx.date < budget.nextPeriodStart
        }

        // -- First Transaction --
        if !alreadyUnlocked.keys.contains("first_transaction") && !periodTransactions.isEmpty {
            unlock("first_transaction")
            newlyUnlocked.append(achievement(for: "first_transaction"))
        }

        // -- Streak Achievements --
        let streak = UserDefaults.standard.integer(forKey: "currentStreak")

        if streak >= 7 && !alreadyUnlocked.keys.contains("streak_7") {
            unlock("streak_7")
            newlyUnlocked.append(achievement(for: "streak_7"))
        }
        if streak >= 30 && !alreadyUnlocked.keys.contains("streak_30") {
            unlock("streak_30")
            newlyUnlocked.append(achievement(for: "streak_30"))
        }
        if streak >= 100 && !alreadyUnlocked.keys.contains("streak_100") {
            unlock("streak_100")
            newlyUnlocked.append(achievement(for: "streak_100"))
        }

        // -- Budget Achievements --
        // Only count completed months (not the current in-progress month)
        let remainingCents = budget.remainingCents
        let isCompletedMonth = Date() >= budget.nextPeriodStart
        if remainingCents >= 0 && isCompletedMonth {
            // Increment persistent under-budget month counter
            let underBudgetMonths = UserDefaults.standard.integer(forKey: underBudgetMonthsKey) + 1
            // Only count if not already counted for this period
            let periodKey = "underBudget_\(budget.month)_\(budget.year)"
            if !UserDefaults.standard.bool(forKey: periodKey) {
                UserDefaults.standard.set(true, forKey: periodKey)
                UserDefaults.standard.set(underBudgetMonths, forKey: underBudgetMonthsKey)
            }
            let count = UserDefaults.standard.integer(forKey: underBudgetMonthsKey)

            if count >= 1 && !alreadyUnlocked.keys.contains("under_budget_1") {
                unlock("under_budget_1")
                newlyUnlocked.append(achievement(for: "under_budget_1"))
            }
            if count >= 3 && !alreadyUnlocked.keys.contains("under_budget_3") {
                unlock("under_budget_3")
                newlyUnlocked.append(achievement(for: "under_budget_3"))
            }
            if count >= 12 && !alreadyUnlocked.keys.contains("under_budget_12") {
                unlock("under_budget_12")
                newlyUnlocked.append(achievement(for: "under_budget_12"))
            }
        }

        // -- Saving Achievements --
        if remainingCents >= 10000 && !alreadyUnlocked.keys.contains("saved_100") { // $100 = 10000 cents
            unlock("saved_100")
            newlyUnlocked.append(achievement(for: "saved_100"))
        }
        if remainingCents >= 50000 && !alreadyUnlocked.keys.contains("saved_500") {
            unlock("saved_500")
            newlyUnlocked.append(achievement(for: "saved_500"))
        }
        if remainingCents >= 100000 && !alreadyUnlocked.keys.contains("saved_1000") {
            unlock("saved_1000")
            newlyUnlocked.append(achievement(for: "saved_1000"))
        }

        // -- All Categories Under Budget --
        let categories = (budget.categories ?? []).filter { !$0.isHidden }
        if !categories.isEmpty && !alreadyUnlocked.keys.contains("all_under") {
            let allUnder = categories.allSatisfy { $0.spentCents(in: budget) <= $0.budgetedAmountCents }
            if allUnder {
                unlock("all_under")
                newlyUnlocked.append(achievement(for: "all_under"))
            }
        }

        // -- Zero Day --
        if !alreadyUnlocked.keys.contains("no_spend_day") {
            let calendar = Calendar.current
            let daysInMonth: Int = {
                let comps = DateComponents(year: budget.year, month: budget.month)
                guard let date = calendar.date(from: comps),
                      let range = calendar.range(of: .day, in: .month, for: date) else { return 30 }
                return range.count
            }()

            // Build set of days that have spending
            var spendingDays = Set<Int>()
            for tx in periodTransactions {
                spendingDays.insert(calendar.component(.day, from: tx.date))
            }

            // Check if any past day had zero spending
            let today = calendar.component(.day, from: Date())
            let checkUpTo = min(today, daysInMonth)
            for day in 1...checkUpTo {
                if !spendingDays.contains(day) {
                    unlock("no_spend_day")
                    newlyUnlocked.append(achievement(for: "no_spend_day"))
                    break
                }
            }
        }

        return newlyUnlocked
    }

    /// Get all unlocked achievements with their unlock dates.
    static func unlockedAchievements() -> [Achievement] {
        let dateMap = unlockedDateMap()
        return allAchievements.compactMap { ach in
            guard let date = dateMap[ach.id] else { return nil }
            var unlocked = ach
            unlocked.unlockedDate = date
            return unlocked
        }
    }

    /// Unlock a specific achievement by ID.
    static func unlock(_ achievementId: String) {
        var dateMap = unlockedDateMap()
        guard dateMap[achievementId] == nil else { return } // Already unlocked
        dateMap[achievementId] = Date()
        saveDateMap(dateMap)
    }

    /// Check if a specific achievement is unlocked.
    static func isUnlocked(_ achievementId: String) -> Bool {
        unlockedDateMap()[achievementId] != nil
    }

    // MARK: - Private Helpers

    private static func achievement(for id: String) -> Achievement {
        allAchievements.first { $0.id == id } ?? Achievement(id: id, title: id, description: "", emoji: "?", tier: .bronze)
    }

    private static func unlockedDateMap() -> [String: Date] {
        guard let data = UserDefaults.standard.data(forKey: unlockedKey),
              let map = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return [:]
        }
        return map
    }

    private static func saveDateMap(_ map: [String: Date]) {
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: unlockedKey)
        }
    }
}
