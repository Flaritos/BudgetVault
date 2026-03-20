import Foundation

enum StreakService {

    private static let calendar = Calendar.current

    /// Call on every scenePhase .active to handle freeze logic and Monday reset.
    static func processOnForeground() {
        let today = calendar.startOfDay(for: Date())
        let todayStr = DateHelpers.dateString(today)
        let lastLogDate = UserDefaults.standard.string(forKey: AppStorageKeys.lastLogDate) ?? ""
        var streak = UserDefaults.standard.integer(forKey: AppStorageKeys.currentStreak)
        var freezes = UserDefaults.standard.integer(forKey: AppStorageKeys.streakFreezesRemaining)

        // Reset freeze to 1 every Monday — free for everyone
        let weekday = calendar.component(.weekday, from: today)
        let lastFreezeReset = UserDefaults.standard.string(forKey: AppStorageKeys.lastFreezeReset) ?? ""
        if weekday == 2 && lastFreezeReset != todayStr { // Monday
            freezes = 1
            UserDefaults.standard.set(freezes, forKey: AppStorageKeys.streakFreezesRemaining)
            UserDefaults.standard.set(todayStr, forKey: AppStorageKeys.lastFreezeReset)
        }

        // Check if yesterday was missed and we can use a freeze
        if streak > 0 && lastLogDate != todayStr {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return }
            let yesterdayStr = DateHelpers.dateString(yesterday)

            if lastLogDate != yesterdayStr {
                // Missed yesterday
                if freezes > 0 {
                    // Use freeze -- preserve streak
                    freezes -= 1
                    UserDefaults.standard.set(freezes, forKey: AppStorageKeys.streakFreezesRemaining)
                } else {
                    // No freeze -- streak is broken
                    streak = 0
                    UserDefaults.standard.set(streak, forKey: AppStorageKeys.currentStreak)
                }
            }
        }

        // Schedule streak-at-risk notification if no log today
        if streak > 0 && lastLogDate != todayStr {
            NotificationService.scheduleStreakAtRisk(streakCount: streak)
        } else {
            NotificationService.cancelStreakAtRisk()
        }

        // Write to widget suite
        let suite = UserDefaults(suiteName: WidgetDataService.suiteName)
        suite?.set(streak, forKey: AppStorageKeys.currentStreak)
    }

    /// Record that the user logged an entry today — updates streak.
    static func recordLogEntry() {
        let today = Calendar.current.startOfDay(for: Date())
        let todayString = DateHelpers.dateString(today)
        let lastLogDate = UserDefaults.standard.string(forKey: AppStorageKeys.lastLogDate) ?? ""
        var streak = UserDefaults.standard.integer(forKey: AppStorageKeys.currentStreak)

        if lastLogDate == todayString {
            // Already logged today
            return
        }

        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) else { return }
        let yesterdayString = DateHelpers.dateString(yesterday)

        if lastLogDate == yesterdayString {
            streak += 1
        } else {
            streak = 1
        }

        UserDefaults.standard.set(todayString, forKey: AppStorageKeys.lastLogDate)
        UserDefaults.standard.set(streak, forKey: AppStorageKeys.currentStreak)
    }

    /// Check if current streak just hit a milestone.
    static func checkMilestone() -> Int? {
        let streak = UserDefaults.standard.integer(forKey: AppStorageKeys.currentStreak)
        let milestones = [7, 14, 30, 60, 90]
        if milestones.contains(streak) {
            // Request review at key milestones
            if [14, 30, 60, 90].contains(streak) {
                ReviewPromptService.requestIfAppropriate()
            }
            return streak
        }
        return nil
    }
}
