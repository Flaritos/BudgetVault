import Foundation

enum DateHelpers {

    /// Calculate the budget period for a given month/year/resetDay.
    /// Returns (start, nextStart) for half-open interval filtering.
    static func budgetPeriod(for month: Int, year: Int, resetDay: Int) -> (start: Date, nextStart: Date) {
        let calendar = Calendar.current
        let clampedDay = min(resetDay, 28) // Safety clamp

        let start = calendar.date(from: DateComponents(year: year, month: month, day: clampedDay)) ?? Date()
        let nextStart = calendar.date(byAdding: .month, value: 1, to: start) ?? Date()

        return (start, nextStart)
    }

    /// Determine which budget period (month, year) a given date falls in,
    /// based on the resetDay.
    static func budgetPeriod(containing date: Date, resetDay: Int) -> (month: Int, year: Int) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)

        guard let day = components.day, let month = components.month, let year = components.year else {
            let now = calendar.dateComponents([.month, .year], from: Date())
            return (now.month ?? 1, now.year ?? 2026)
        }

        let clampedResetDay = min(resetDay, 28)

        // If today is before the reset day, we're in the previous month's budget
        if day < clampedResetDay {
            if month == 1 {
                return (12, year - 1)
            }
            return (month - 1, year)
        }

        return (month, year)
    }

    /// Get the current budget period based on today's date and the user's resetDay.
    static func currentBudgetPeriod(resetDay: Int = 1) -> (month: Int, year: Int) {
        budgetPeriod(containing: Date(), resetDay: resetDay)
    }

    // MARK: - Cached Formatters

    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    private static let dateStringFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Format a month/year as a display string (e.g. "March 2026")
    static func monthYearString(month: Int, year: Int) -> String {
        let components = DateComponents(year: year, month: month, day: 1)
        guard let date = Calendar.current.date(from: components) else { return "" }
        return monthYearFormatter.string(from: date)
    }

    /// Canonical yyyy-MM-dd string for streak and date comparison logic.
    static func dateString(_ date: Date) -> String {
        dateStringFormatter.string(from: date)
    }

    /// Get the previous month/year pair (handles Dec->Jan wraparound)
    static func previousMonth(from month: Int, year: Int) -> (month: Int, year: Int) {
        if month == 1 {
            return (12, year - 1)
        }
        return (month - 1, year)
    }

    /// Get the next month/year pair (handles Dec->Jan wraparound)
    static func nextMonth(from month: Int, year: Int) -> (month: Int, year: Int) {
        if month == 12 {
            return (1, year + 1)
        }
        return (month + 1, year)
    }
}
