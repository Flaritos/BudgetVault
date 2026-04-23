import Foundation

/// Centralized string constants for all @AppStorage and UserDefaults keys.
/// Using a single enum prevents typos and makes key usage searchable.
public enum AppStorageKeys {
    // MARK: - Budget & Onboarding
    public static let resetDay = "resetDay"
    public static let hasCompletedOnboarding = "hasCompletedOnboarding"
    public static let hasLoggedFirstTransaction = "hasLoggedFirstTransaction"
    public static let userName = "userName"

    // MARK: - Premium & Monetization
    public static let isPremium = "isPremium"
    public static let debugPremiumOverride = "debugPremiumOverride"
    public static let lastPaywallDecline = "lastPaywallDecline"
    public static let reviewPromptCount = "reviewPromptCount"
    public static let transactionCount = "transactionCount"
    /// Audit 2026-04-22 P1-34: per-install timestamp used to anchor the
    /// launch-pricing countdown. Prior implementation hardcoded a wall-
    /// clock end date — if App Review slipped, the banner expired
    /// before any user saw the app. Each user now gets their own
    /// 30-day launch window from first app open.
    public static let installDate = "installDate"
    // Audit note: `hasSeenTransactionPaywall` / `hasSeenStreakPaywall`
    // were defined but never read in production. Removed as dead code.

    // MARK: - Appearance
    public static let selectedCurrency = "selectedCurrency"
    // `accentColorHex` removed in v3.3.1 (theme picker retired).

    // MARK: - Security
    public static let biometricLockEnabled = "biometricLockEnabled"
    public static let vaultName = "vaultName"
    /// Audit 2026-04-22 P1-22: one-shot flag that flips true the first
    /// time the app successfully stamps `FileProtectionType.complete`
    /// onto Application Support. Subsequent launches skip the walk.
    public static let didStampFileProtection = "didStampFileProtection"

    // MARK: - Streak
    public static let currentStreak = "currentStreak"
    public static let lastLogDate = "lastLogDate"
    public static let streakFreezesRemaining = "streakFreezesRemaining"
    public static let lastFreezeReset = "lastFreezeReset"

    // MARK: - Dashboard
    public static let lastSummaryViewed = "lastSummaryViewed"
    /// Audit 2026-04-22 P2-1: hoisted from bare string literals in
    /// DashboardView + FinanceTabView. Tracks the last-viewed month
    /// key for the Monthly Wrapped badge.
    public static let lastWrappedViewed = "lastWrappedViewed"
    /// Audit 2026-04-22 P2-1: hoisted from bare string literal in
    /// DashboardView. Tracks the highest streak day the user has
    /// already celebrated so we don't re-fire the sheet.
    public static let lastCelebratedMilestone = "lastCelebratedMilestone"

    // MARK: - Notifications
    public static let dailyReminderEnabled = "dailyReminderEnabled"
    public static let dailyReminderHour = "dailyReminderHour"
    public static let weeklyDigestEnabled = "weeklyDigestEnabled"
    public static let billDueReminders = "billDueReminders"
    // Audit 2026-04-23 Smoke-9 Fix 1: wire up the v3.2 "close today's
    // vault" habit-anchor reminder (9pm daily). Was dead code until now.
    public static let closeVaultReminderEnabled = "closeVaultReminderEnabled"

    // MARK: - Cloud
    public static let iCloudSyncEnabled = "iCloudSyncEnabled"

    // MARK: - Engagement & Retention
    public static let lastActiveDate = "lastActiveDate"
    public static let morningBriefingEnabled = "morningBriefingEnabled"
    public static let morningBriefingHour = "morningBriefingHour"
    public static let catchUpDismissedDate = "catchUpDismissedDate"

    // MARK: - Local Metrics (on-device-only counters, never sent over network)
    public static let wrappedSharesAllTime = "wrappedSharesAllTime"
}
