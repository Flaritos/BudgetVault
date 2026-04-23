import Foundation
import BudgetVaultShared

enum StreakService {

    private static let calendar = Calendar.current

    /// ISO-8601 week key in `YYYY-WNN` format. Used as the freeze
    /// refill epoch — at most one freeze per distinct key value.
    static func currentISOWeekKey(for date: Date = Date()) -> String {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2 // Monday — matches ISO 8601
        let week = cal.component(.weekOfYear, from: date)
        let year = cal.component(.yearForWeekOfYear, from: date)
        return String(format: "%04d-W%02d", year, week)
    }

    /// Call on every scenePhase .active to handle freeze logic and Monday reset.
    static func processOnForeground() {
        let today = calendar.startOfDay(for: Date())
        let todayStr = DateHelpers.dateString(today)
        let lastLogDate = UserDefaults.standard.string(forKey: AppStorageKeys.lastLogDate) ?? ""
        var streak = UserDefaults.standard.integer(forKey: AppStorageKeys.currentStreak)
        var freezes = UserDefaults.standard.integer(forKey: AppStorageKeys.streakFreezesRemaining)

        // v3.3 P0 fix: previous implementation could grant unbounded freezes
        // if the user never opened the app on Monday. New rule: at most one
        // freeze is available per ISO week, keyed by `YYYY-WNN`. Refilled
        // exactly once when the week key changes.
        let weekKey = Self.currentISOWeekKey()
        let lastFreezeReset = UserDefaults.standard.string(forKey: AppStorageKeys.lastFreezeReset) ?? ""
        if lastFreezeReset != weekKey {
            freezes = 1
            UserDefaults.standard.set(freezes, forKey: AppStorageKeys.streakFreezesRemaining)
            UserDefaults.standard.set(weekKey, forKey: AppStorageKeys.lastFreezeReset)
        } else {
            // Same ISO week — clamp to at most 1 even if a stale value lingered.
            if freezes > 1 {
                freezes = 1
                UserDefaults.standard.set(freezes, forKey: AppStorageKeys.streakFreezesRemaining)
            }
        }

        // Check if yesterday was missed and we can use a freeze
        if streak > 0 && lastLogDate != todayStr {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return }
            let yesterdayStr = DateHelpers.dateString(yesterday)

            if lastLogDate != yesterdayStr {
                // Missed yesterday (or multiple days)
                // NOTE: A single freeze covers the entire gap, regardless of how many days were missed.
                // This is intentional — the freeze is a "forgiveness" mechanic, not a per-day counter.
                if freezes > 0 {
                    // Use freeze -- preserve streak
                    freezes -= 1
                    UserDefaults.standard.set(freezes, forKey: AppStorageKeys.streakFreezesRemaining)
                    UserDefaults.standard.set(true, forKey: "streakFreezeJustUsed")
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
            // Audit 2026-04-23 Smoke-9 Fix 1: after streakAtRisk is
            // cancelled, re-arm the close-vault 9pm reminder. Without
            // this, closeVault's "skip if streakAtRisk is scheduled"
            // guard silently dropped the schedule on at-risk days and
            // the 9pm ping never recovered the next day.
            if UserDefaults.standard.bool(forKey: AppStorageKeys.closeVaultReminderEnabled) {
                NotificationService.scheduleEveningCloseVault()
            }
        }

        // Write to widget suite
        let suite = UserDefaults(suiteName: WidgetDataService.suiteName)
        suite?.set(streak, forKey: AppStorageKeys.currentStreak)
    }

    /// One-tap "no spending today" — increments the streak without requiring
    /// the user to log a $0 transaction. Treated identically to a real log
    /// for streak purposes. Returns the new streak value.
    @discardableResult
    static func markNoSpendDay() -> Int {
        let today = calendar.startOfDay(for: Date())
        let todayString = DateHelpers.dateString(today)
        let lastLogDate = UserDefaults.standard.string(forKey: AppStorageKeys.lastLogDate) ?? ""
        if lastLogDate == todayString {
            return UserDefaults.standard.integer(forKey: AppStorageKeys.currentStreak)
        }
        recordLogEntry()
        UserDefaults.standard.set(todayString, forKey: "lastNoSpendDay")
        NotificationService.cancelStreakAtRisk()
        // Mirror processOnForeground: re-arm closeVault now that
        // streakAtRisk is gone (the skip-guard would otherwise eat it).
        if UserDefaults.standard.bool(forKey: AppStorageKeys.closeVaultReminderEnabled) {
            NotificationService.scheduleEveningCloseVault()
        }
        return UserDefaults.standard.integer(forKey: AppStorageKeys.currentStreak)
    }

    /// Whether the user has already logged something (real or no-spend) today.
    static func hasClosedToday() -> Bool {
        let todayString = DateHelpers.dateString(calendar.startOfDay(for: Date()))
        let lastLogDate = UserDefaults.standard.string(forKey: AppStorageKeys.lastLogDate) ?? ""
        return lastLogDate == todayString
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

    /// Whether the user has a streak freeze available this week.
    static func hasAvailableFreeze() -> Bool {
        UserDefaults.standard.integer(forKey: AppStorageKeys.streakFreezesRemaining) > 0
    }

    /// Day status for this week's streak progress dots (Mon–Sun).
    enum DayStatus { case logged, frozen, empty }

    static func thisWeekDots() -> [DayStatus] {
        let today = calendar.startOfDay(for: Date())
        let lastLogDateStr = UserDefaults.standard.string(forKey: AppStorageKeys.lastLogDate) ?? ""

        // Find Monday of this week
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        guard let weekInterval = cal.dateInterval(of: .weekOfYear, for: today) else {
            return Array(repeating: .empty, count: 7)
        }
        let monday = cal.startOfDay(for: weekInterval.start)

        var dots: [DayStatus] = []
        for i in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: i, to: monday) else {
                dots.append(.empty)
                continue
            }

            if day > today {
                dots.append(.empty) // Future
            } else {
                let dayStr = DateHelpers.dateString(day)
                if dayStr == lastLogDateStr || dayStr == DateHelpers.dateString(today) && lastLogDateStr == dayStr {
                    dots.append(.logged)
                } else {
                    // Simple heuristic: if streak is intact and day is in the past, it was either logged or frozen
                    let streak = UserDefaults.standard.integer(forKey: AppStorageKeys.currentStreak)
                    let daysSinceMonday = cal.dateComponents([.day], from: monday, to: today).day ?? 0
                    if streak > daysSinceMonday {
                        dots.append(.logged) // Streak covers this day
                    } else if day == today {
                        dots.append(.empty) // Haven't logged today yet
                    } else {
                        dots.append(.empty)
                    }
                }
            }
        }
        return dots
    }
}
