import Foundation
import UserNotifications

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

        // Schedule one notification per weekday, each with a different message
        for weekday in 1...7 {
            let message = dailyMessages[weekday - 1]

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
            center.add(request)
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
        center.add(request)
    }

    static func cancelStreakAtRisk() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["streakAtRisk"])
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
        center.add(request)
    }

    // MARK: - Weekly Summary

    static func scheduleWeeklySummary() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["weeklySummary"])

        let content = UNMutableNotificationContent()
        content.title = "Weekly Summary"
        content.body = "Your weekly spending summary is ready. Open BudgetVault to see how you did!"
        content.sound = .default

        // Sunday at 6pm
        var components = DateComponents()
        components.weekday = 1 // Sunday
        components.hour = 18
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(identifier: "weeklySummary", content: content, trigger: trigger)
        center.add(request)
    }

    static func cancelWeeklySummary() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["weeklySummary"])
    }

    // MARK: - Spending Alerts (Category-Level)

    /// Checks each category in the budget and schedules local notifications
    /// when spending reaches 80% or exceeds 100% of the budgeted amount.
    /// Should be called when the app enters the foreground (e.g., from Dashboard .task).
    static func checkAndScheduleCategoryAlerts(budget: Budget) {
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
            center.add(request)
        }
    }

    private static func formatCentsForNotification(_ cents: Int64) -> String {
        CurrencyFormatter.format(cents: cents)
    }
}
