import Foundation
import UserNotifications

enum NotificationService {

    // MARK: - Daily Reminder

    static func scheduleDailyReminder(hour: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["dailyReminder"])

        let messages = [
            "Don't forget to log today's expenses!",
            "Quick check: anything to log?",
            "Keep your streak alive! 🔥",
        ]
        let message = messages.randomElement() ?? messages[0]

        let content = UNMutableNotificationContent()
        content.title = "BudgetVault"
        content.body = message
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(identifier: "dailyReminder", content: content, trigger: trigger)
        center.add(request)
    }

    static func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyReminder"])
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

    static func scheduleWeeklySummary(spentText: String, categoryCount: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["weeklySummary"])

        let content = UNMutableNotificationContent()
        content.title = "Weekly Summary"
        content.body = "This week you spent \(spentText) across \(categoryCount) categories."
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
}
