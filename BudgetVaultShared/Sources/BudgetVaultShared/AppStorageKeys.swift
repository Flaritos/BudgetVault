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
    public static let hasSeenTransactionPaywall = "hasSeenTransactionPaywall"
    public static let hasSeenStreakPaywall = "hasSeenStreakPaywall"

    // MARK: - Appearance
    public static let selectedCurrency = "selectedCurrency"
    public static let accentColorHex = "accentColorHex"

    // MARK: - Security
    public static let biometricLockEnabled = "biometricLockEnabled"

    // MARK: - Streak
    public static let currentStreak = "currentStreak"
    public static let lastLogDate = "lastLogDate"
    public static let streakFreezesRemaining = "streakFreezesRemaining"
    public static let lastFreezeReset = "lastFreezeReset"

    // MARK: - Dashboard
    public static let lastSummaryViewed = "lastSummaryViewed"

    // MARK: - Notifications
    public static let dailyReminderEnabled = "dailyReminderEnabled"
    public static let dailyReminderHour = "dailyReminderHour"
    public static let weeklyDigestEnabled = "weeklyDigestEnabled"
    public static let billDueReminders = "billDueReminders"

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
