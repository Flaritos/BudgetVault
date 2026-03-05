import Foundation

@Observable
final class DashboardViewModel {

    // MARK: - Streak

    func updateStreak() {
        let today = Calendar.current.startOfDay(for: Date())
        let todayString = Self.dateString(today)
        let lastLogDate = UserDefaults.standard.string(forKey: "lastLogDate") ?? ""
        var streak = UserDefaults.standard.integer(forKey: "currentStreak")

        if lastLogDate == todayString {
            // Already logged today
            return
        }

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let yesterdayString = Self.dateString(yesterday)

        if lastLogDate == yesterdayString {
            streak += 1
        } else {
            streak = 1
        }

        UserDefaults.standard.set(todayString, forKey: "lastLogDate")
        UserDefaults.standard.set(streak, forKey: "currentStreak")
    }

    // MARK: - Status

    func statusText(for percentRemaining: Double) -> String {
        if percentRemaining > 0.5 { return "On Track" }
        if percentRemaining > 0.25 { return "Watch It" }
        return "Over Budget"
    }

    func statusColor(for percentRemaining: Double) -> String {
        if percentRemaining > 0.5 { return "green" }
        if percentRemaining > 0.25 { return "yellow" }
        return "red"
    }

    // MARK: - Helpers

    private static func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
