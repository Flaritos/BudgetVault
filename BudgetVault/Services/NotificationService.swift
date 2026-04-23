import Foundation
import os
import UIKit
import UserNotifications
import BudgetVaultShared

private let notificationLog = Logger(subsystem: "io.budgetvault.app", category: "notifications")

// Audit 2026-04-22 P1-27: single helper so every `center.addLogged(request)`
// in this file logs its error instead of discarding it. Previously 13
// call sites silently swallowed scheduling failures — users wondering
// why their daily reminder stopped firing had zero signal to debug
// against. Marker-subsystem routing so Console.app / the unified log
// can filter on io.budgetvault.app/notifications.
private extension UNUserNotificationCenter {
    func addLogged(_ request: UNNotificationRequest) {
        add(request) { error in
            if let error {
                notificationLog.error("add(\(request.identifier, privacy: .public)) failed: \(error.localizedDescription, privacy: .private)")
            }
        }
    }
}

enum NotificationService {

    // MARK: - Notification Categories & Actions

    static let dailyReminderCategoryIdentifier = "DAILY_REMINDER"
    static let logExpenseActionIdentifier = "LOG_EXPENSE_ACTION"

    /// Register notification categories with actions. Call once on app launch.
    static func registerCategories() {
        let logExpenseAction = UNNotificationAction(
            identifier: logExpenseActionIdentifier,
            title: "Log Expense",
            options: [.foreground]
        )

        let dailyReminderCategory = UNNotificationCategory(
            identifier: dailyReminderCategoryIdentifier,
            actions: [logExpenseAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([dailyReminderCategory])
    }

    // MARK: - Daily Reminder

    private static let dailyMessages = [
        "Don't forget to log today's expenses!",
        "Quick check: anything to log?",
        "Keep your streak alive!",
        "A minute now saves budget surprises later.",
        "How did you spend today? Log it!",
        "Stay on track -- log your expenses.",
        "Your budget is waiting for today's update!",
    ]

    static func scheduleDailyReminder(hour: Int) {
        let center = UNUserNotificationCenter.current()

        // Remove all existing daily reminder notifications
        let identifiers = (1...7).map { "dailyReminder-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        let streak = UserDefaults.standard.integer(forKey: AppStorageKeys.currentStreak)

        // Schedule one notification per weekday, each with a different message
        for weekday in 1...7 {
            var message = dailyMessages[weekday - 1]
            // Prepend streak count for motivation
            if streak > 1 {
                message = "Day \(streak): \(message)"
            }

            let content = UNMutableNotificationContent()
            content.title = "BudgetVault"
            content.body = message
            content.sound = .default
            content.userInfo = ["type": "dailyReminder"]
            content.categoryIdentifier = dailyReminderCategoryIdentifier

            var components = DateComponents()
            components.hour = hour
            components.minute = 0
            components.weekday = weekday
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

            let request = UNNotificationRequest(identifier: "dailyReminder-\(weekday)", content: content, trigger: trigger)
            center.addLogged(request)
        }
    }

    static func cancelDailyReminder() {
        let identifiers = (1...7).map { "dailyReminder-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Streak at Risk

    static func scheduleStreakAtRisk(streakCount: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["streakAtRisk"])

        let content = UNMutableNotificationContent()
        content.title = "Streak at Risk!"
        content.body = "Your \(streakCount)-day streak is at risk! Log an expense before midnight."
        content.sound = .default

        var components = DateComponents()
        components.hour = 20
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: "streakAtRisk", content: content, trigger: trigger)
        center.addLogged(request)
    }

    static func cancelStreakAtRisk() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["streakAtRisk"])
    }

    // MARK: - Evening Close Vault (v3.2 daily loop)

    /// Schedule a 9pm "close today's vault" reminder. The action is the
    /// daily-loop habit anchor — open the app, mark the day done (or no-spend),
    /// and close the ring. Repeats daily until cancelled.
    ///
    /// v3.2 audit L1: skip this push if a streak-at-risk reminder is
    /// already scheduled today. Back-to-back 8pm + 9pm pings read as
    /// nagging rather than helpful.
    static func scheduleEveningCloseVault(hour: Int = 21) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["closeVault"])

        center.getPendingNotificationRequests { requests in
            let hasStreakAtRisk = requests.contains { $0.identifier == "streakAtRisk" }
            guard !hasStreakAtRisk else { return }

            let content = UNMutableNotificationContent()
            content.title = "Close today's vault"
            content.body = "Log anything you missed — or tap “No spending today.”"
            content.sound = .default
            content.userInfo = ["type": "closeVault"]
            content.categoryIdentifier = dailyReminderCategoryIdentifier

            var components = DateComponents()
            components.hour = hour
            components.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

            let request = UNNotificationRequest(identifier: "closeVault", content: content, trigger: trigger)
            center.addLogged(request)
        }
    }

    static func cancelEveningCloseVault() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["closeVault"])
    }

    // MARK: - Bill Due Reminder

    static func scheduleBillDueReminder(expenseName: String, dueDate: Date, id: String) {
        let center = UNUserNotificationCenter.current()
        let identifier = "billDue-\(id)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "Bill Due Tomorrow"
        content.body = "\(expenseName) is due tomorrow."
        content.sound = .default

        // 1 day before due date, at 9am
        guard let reminderDate = Calendar.current.date(byAdding: .day, value: -1, to: dueDate) else { return }
        var components = Calendar.current.dateComponents([.year, .month, .day], from: reminderDate)
        components.hour = 9
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.addLogged(request)
    }

    // MARK: - Weekly Summary (Personalized)

    /// Schedule a personalized weekly summary with computed spending data.
    /// Call this from the dashboard or app lifecycle with actual budget data.
    ///
    /// v3.2 Sprint 3: now takes `lastWeekSpent` to build a comparative body —
    /// comparison-to-last-week copy is the format Copilot users praise most,
    /// per the competitive audit.
    static func scheduleWeeklySummary(weeklySpent: Int64, transactionCount: Int, remaining: Int64, currencyCode: String, lastWeekSpent: Int64 = -1) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["weeklySummary"])

        let spentFormatted = CurrencyFormatter.format(cents: weeklySpent, currencyCode: currencyCode)
        let remainingFormatted = CurrencyFormatter.format(cents: remaining, currencyCode: currencyCode)

        let content = UNMutableNotificationContent()
        content.title = "Weekly Pulse"
        if weeklySpent > 0 {
            var body = "You spent \(spentFormatted) this week across \(transactionCount) transaction\(transactionCount == 1 ? "" : "s")."
            if lastWeekSpent > 0 {
                let delta = weeklySpent - lastWeekSpent
                let deltaFormatted = CurrencyFormatter.format(cents: abs(delta), currencyCode: currencyCode)
                if delta < 0 {
                    body += " \(deltaFormatted) less than last week — nice."
                } else if delta > 0 {
                    body += " \(deltaFormatted) more than last week."
                } else {
                    body += " Same as last week."
                }
            }
            body += " \(remainingFormatted) remaining."
            content.body = body
        } else {
            content.body = "No spending logged this week. \(remainingFormatted) remaining in your budget."
        }
        content.sound = .default

        // Sunday at 6pm
        var components = DateComponents()
        components.weekday = 1 // Sunday
        components.hour = 18
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(identifier: "weeklySummary", content: content, trigger: trigger)
        center.addLogged(request)
    }

    static func cancelWeeklySummary() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["weeklySummary"])
    }

    // MARK: - Lapsed User Re-engagement

    private static let reengagementIdentifiers = [
        "reengagement3Day", "reengagement7Day", "reengagement14Day", "reengagement30Day"
    ]

    /// Schedule re-engagement notifications for lapsed users.
    /// Call this whenever the user logs a transaction to reset the timers.
    static func scheduleReengagementNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: reengagementIdentifiers)

        // 3-day reminder
        let content3 = UNMutableNotificationContent()
        content3.title = "BudgetVault"
        content3.body = "You haven't logged expenses in 3 days. Quick catch-up?"
        content3.sound = .default
        content3.userInfo = ["type": "reengagement"]

        let trigger3 = UNTimeIntervalNotificationTrigger(timeInterval: 3 * 24 * 60 * 60, repeats: false)
        let request3 = UNNotificationRequest(identifier: "reengagement3Day", content: content3, trigger: trigger3)
        center.addLogged(request3)

        // 7-day reminder
        let content7 = UNMutableNotificationContent()
        content7.title = "BudgetVault"
        content7.body = "Your budget is waiting. Tap to see where you stand."
        content7.sound = .default
        content7.userInfo = ["type": "reengagement"]

        let trigger7 = UNTimeIntervalNotificationTrigger(timeInterval: 7 * 24 * 60 * 60, repeats: false)
        let request7 = UNNotificationRequest(identifier: "reengagement7Day", content: content7, trigger: trigger7)
        center.addLogged(request7)

        // 14-day reminder
        let content14 = UNMutableNotificationContent()
        content14.title = "Half the month is gone"
        content14.body = "Your budget is mostly untracked. There's still time to finish strong."
        content14.sound = .default
        content14.userInfo = ["type": "reengagement"]

        let trigger14 = UNTimeIntervalNotificationTrigger(timeInterval: 14 * 24 * 60 * 60, repeats: false)
        let request14 = UNNotificationRequest(identifier: "reengagement14Day", content: content14, trigger: trigger14)
        center.addLogged(request14)

        // 30-day reminder (final attempt)
        let content30 = UNMutableNotificationContent()
        content30.title = "Fresh start?"
        content30.body = "New month, clean slate. Come back and take control of your budget."
        content30.sound = .default
        content30.userInfo = ["type": "reengagement"]

        let trigger30 = UNTimeIntervalNotificationTrigger(timeInterval: 30 * 24 * 60 * 60, repeats: false)
        let request30 = UNNotificationRequest(identifier: "reengagement30Day", content: content30, trigger: trigger30)
        center.addLogged(request30)
    }

    /// Cancel all re-engagement notifications.
    static func cancelReengagementNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: reengagementIdentifiers)
    }

    // MARK: - Morning Briefing

    /// Schedule a morning briefing notification with pre-computed budget data.
    static func scheduleMorningBriefing(dailyAllowance: Int64, daysRemaining: Int, upcomingBills: Int, currencyCode: String, hour: Int = 8) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["morningBriefing"])

        let allowanceFormatted = CurrencyFormatter.format(cents: dailyAllowance, currencyCode: currencyCode)

        let content = UNMutableNotificationContent()
        content.title = "Good Morning!"

        var body = "You can spend \(allowanceFormatted)/day for the next \(daysRemaining) day\(daysRemaining == 1 ? "" : "s")."
        if upcomingBills > 0 {
            body += " \(upcomingBills) bill\(upcomingBills == 1 ? "" : "s") coming this week."
        }
        content.body = body
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(identifier: "morningBriefing", content: content, trigger: trigger)
        center.addLogged(request)
    }

    static func cancelMorningBriefing() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["morningBriefing"])
    }

    // MARK: - End-of-Period Notifications

    /// Schedule end-of-period notifications: 3 days before reset and on reset day.
    static func scheduleEndOfPeriodNotifications(periodEnd: Date, remainingCents: Int64, currencyCode: String) {
        let center = UNUserNotificationCenter.current()
        let identifiers = ["periodEnd3Days", "periodReset"]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        let remainingFormatted = CurrencyFormatter.format(cents: remainingCents, currencyCode: currencyCode)

        // 3 days before period end
        if let threeDaysBefore = Calendar.current.date(byAdding: .day, value: -3, to: periodEnd),
           threeDaysBefore > Date() {
            let content3 = UNMutableNotificationContent()
            content3.title = "3 Days Left"
            content3.body = "3 days left in your budget period. You have \(remainingFormatted) remaining. Can you make it?"
            content3.sound = .default

            var components3 = Calendar.current.dateComponents([.year, .month, .day], from: threeDaysBefore)
            components3.hour = 9
            let trigger3 = UNCalendarNotificationTrigger(dateMatching: components3, repeats: false)
            let request3 = UNNotificationRequest(identifier: "periodEnd3Days", content: content3, trigger: trigger3)
            center.addLogged(request3)
        }

        // On reset day
        if periodEnd > Date() {
            let contentReset = UNMutableNotificationContent()
            contentReset.title = "Fresh Start!"
            contentReset.body = "New month, fresh start! Your budget has reset."
            contentReset.sound = .default

            var componentsReset = Calendar.current.dateComponents([.year, .month, .day], from: periodEnd)
            componentsReset.hour = 9
            let triggerReset = UNCalendarNotificationTrigger(dateMatching: componentsReset, repeats: false)
            let requestReset = UNNotificationRequest(identifier: "periodReset", content: contentReset, trigger: triggerReset)
            center.addLogged(requestReset)
        }
    }

    static func cancelEndOfPeriodNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["periodEnd3Days", "periodReset"])
    }

    // MARK: - Spending Alerts (Category-Level)

    /// Checks each category in the budget and schedules local notifications
    /// when spending reaches 80% or exceeds 100% of the budgeted amount.
    /// Should be called when the app enters the foreground (e.g., from Dashboard .task).
    static func checkAndScheduleCategoryAlerts(budget: Budget) {
        // Alerts are scheduled regardless of app state. The UNUserNotificationCenterDelegate
        // willPresent method handles foreground delivery with [.banner, .sound].
        let center = UNUserNotificationCenter.current()
        let categories = (budget.categories ?? []).filter { !$0.isHidden && $0.budgetedAmountCents > 0 }

        for category in categories {
            let spent = category.spentCents(in: budget)
            let budgeted = category.budgetedAmountCents
            let pct = Double(spent) / Double(budgeted)
            let identifier = "categoryAlert-\(category.id.uuidString)"

            // Remove any existing alert for this category
            center.removePendingNotificationRequests(withIdentifiers: [identifier])

            guard pct >= 0.8 else { continue }

            // Throttle: only fire once per day per category
            let throttleKey = "lastCategoryAlert-\(category.id.uuidString)"
            if let lastAlert = UserDefaults.standard.object(forKey: throttleKey) as? Date,
               Calendar.current.isDateInToday(lastAlert) {
                continue
            }

            let content = UNMutableNotificationContent()
            content.sound = .default

            let spentFormatted = formatCentsForNotification(spent)
            let budgetedFormatted = formatCentsForNotification(budgeted)

            if pct >= 1.0 {
                content.title = "\(category.emoji) \(category.name) Over Budget"
                content.body = "\(spentFormatted) of \(budgetedFormatted) spent"
            } else {
                content.title = "\(category.emoji) \(category.name) at \(Int(pct * 100))%"
                content.body = "\(spentFormatted) of \(budgetedFormatted) spent"
            }

            UserDefaults.standard.set(Date(), forKey: throttleKey)

            // Fire in 2 seconds (immediate feedback when app foregrounds)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.addLogged(request)
        }
    }

    private static func formatCentsForNotification(_ cents: Int64) -> String {
        CurrencyFormatter.format(cents: cents)
    }
}
