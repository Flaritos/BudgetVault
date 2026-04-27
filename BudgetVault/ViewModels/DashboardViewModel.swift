import Foundation

enum DashboardViewModel {

    // MARK: - Computed Budget Period Data

    /// Number of days remaining in the current budget period (minimum 1).
    /// Audit 2026-04-27: anchored `today` to `startOfDay(for:)` so the
    /// `.day` component returns whole-day distances *including the
    /// current day*. Prior `Date()` instant returned "future days only,"
    /// excluding today — daily allowance ran ~3% over for the whole
    /// period (e.g., $1000 / 29 instead of $1000 / 30 on day 1).
    /// Same pattern shipped to `WidgetDataService` in audit P1-4.
    static func daysRemainingInPeriod(periodStart: Date, nextPeriodStart: Date) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return max(calendar.dateComponents([.day], from: today, to: nextPeriodStart).day ?? 1, 1)
    }

    /// Fraction of the budget period that has elapsed, clamped to 0...1.
    /// Anchored to `startOfDay` for stable day-boundary semantics.
    static func dayProgressFraction(periodStart: Date, nextPeriodStart: Date) -> Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let totalDays = max(calendar.dateComponents([.day], from: periodStart, to: nextPeriodStart).day ?? 30, 1)
        let elapsed = max(calendar.dateComponents([.day], from: periodStart, to: today).day ?? 0, 0)
        return min(Double(elapsed) / Double(totalDays), 1.0)
    }

    /// Human-readable "Day X of Y" string for the budget period.
    /// Anchored to `startOfDay` for stable day-boundary semantics.
    static func budgetDayProgress(periodStart: Date, nextPeriodStart: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let totalDays = max(calendar.dateComponents([.day], from: periodStart, to: nextPeriodStart).day ?? 30, 1)
        let elapsed = max(calendar.dateComponents([.day], from: periodStart, to: today).day ?? 0, 0)
        let dayNumber = min(elapsed + 1, totalDays)
        return "Day \(dayNumber) of \(totalDays)"
    }

    /// Daily spending allowance in cents based on remaining budget and days left.
    static func dailyAllowanceCents(remainingCents: Int64, periodStart: Date, nextPeriodStart: Date) -> Int64 {
        guard remainingCents > 0 else { return 0 }
        let days = daysRemainingInPeriod(periodStart: periodStart, nextPeriodStart: nextPeriodStart)
        return remainingCents / Int64(max(days, 1))
    }

    // MARK: - Status

    static func statusText(for percentRemaining: Double) -> String {
        if percentRemaining > 0.5 { return "On Track" }
        if percentRemaining > 0.25 { return "Watch It" }
        return "Over Budget"
    }

}
