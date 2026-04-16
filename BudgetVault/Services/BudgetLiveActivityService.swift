import Foundation
import os
#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif

#if canImport(ActivityKit) && os(iOS)

private let liveActivityLog = Logger(subsystem: "io.budgetvault.app", category: "LiveActivity")

/// Wrapper around ActivityKit for the daily allowance Live Activity.
/// Started on the first transaction of the day, updated on each subsequent
/// log, and ended at midnight or when the period rolls over.
///
/// Introduced in v3.2 Sprint 2 (the daily loop).
@available(iOS 16.2, *)
enum BudgetLiveActivityService {

    /// Returns true if Live Activities are enabled by the user system-wide.
    static var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Find an existing activity for the current period, if any.
    private static var currentActivity: Activity<BudgetActivityAttributes>? {
        Activity<BudgetActivityAttributes>.activities.first
    }

    /// Pure predicate for unit testing the stale-period guard.
    /// Returns `true` when the period end has already passed and the
    /// activity should be ended before requesting a new one.
    static func isPeriodEndStale(_ periodEndDate: Date, now: Date = Date()) -> Bool {
        periodEndDate < now
    }

    /// End any running activity whose `periodEndDate` is in the past.
    /// Safe to call repeatedly. Awaitable so the caller can sequence
    /// `start` after the cleanup completes.
    static func endStaleActivities(now: Date = Date()) async {
        for activity in Activity<BudgetActivityAttributes>.activities
            where isPeriodEndStale(activity.attributes.periodEndDate, now: now) {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Start a new Live Activity for the current budget period. Safe to call
    /// repeatedly — does nothing if one is already running.
    static func start(
        remainingCents: Int64,
        dailyAllowanceCents: Int64,
        spentFraction: Double,
        dayOfPeriod: Int,
        totalDays: Int,
        currencyCode: String,
        periodEndDate: Date
    ) {
        guard areActivitiesEnabled else { return }
        // v3.3 P0 fix: if a previous activity outlived its period (force-quit,
        // device sleep across midnight), end it before short-circuiting.
        if let existing = Activity<BudgetActivityAttributes>.activities.first {
            if isPeriodEndStale(existing.attributes.periodEndDate) {
                Task { await existing.end(nil, dismissalPolicy: .immediate) }
            } else {
                return
            }
        }

        let attributes = BudgetActivityAttributes(periodEndDate: periodEndDate)
        let state = BudgetActivityAttributes.ContentState(
            remainingCents: remainingCents,
            dailyAllowanceCents: dailyAllowanceCents,
            spentFraction: spentFraction,
            dayOfPeriod: dayOfPeriod,
            totalDays: totalDays,
            currencyCode: currencyCode
        )

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            // v3.2 audit L2: OSLog so production issues are diagnosable
            // via Console.app without crashing on the user.
            liveActivityLog.error("start failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Push a fresh content state to the running activity. No-op if none.
    static func update(
        remainingCents: Int64,
        dailyAllowanceCents: Int64,
        spentFraction: Double,
        dayOfPeriod: Int,
        totalDays: Int,
        currencyCode: String
    ) {
        guard let activity = currentActivity else { return }
        let state = BudgetActivityAttributes.ContentState(
            remainingCents: remainingCents,
            dailyAllowanceCents: dailyAllowanceCents,
            spentFraction: spentFraction,
            dayOfPeriod: dayOfPeriod,
            totalDays: totalDays,
            currencyCode: currencyCode
        )
        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    /// End all running Live Activities — call when the period rolls over or
    /// the user disables them.
    static func endAll() {
        Task {
            for activity in Activity<BudgetActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
#endif
