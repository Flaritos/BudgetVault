import Foundation

/// Centralized string constants for all @AppStorage and UserDefaults keys.
/// Using a single enum prevents typos and makes key usage searchable.
enum AppStorageKeys {
    // MARK: - Budget & Onboarding
    static let resetDay = "resetDay"
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let hasLoggedFirstTransaction = "hasLoggedFirstTransaction"
    static let userName = "userName"

    // MARK: - Premium & Monetization
    static let isPremium = "isPremium"
    static let debugPremiumOverride = "debugPremiumOverride"
    static let lastPaywallDecline = "lastPaywallDecline"
    static let reviewPromptCount = "reviewPromptCount"

    // MARK: - Appearance
    static let selectedCurrency = "selectedCurrency"
    static let accentColorHex = "accentColorHex"

    // MARK: - Security
    static let biometricLockEnabled = "biometricLockEnabled"

    // MARK: - Streak
    static let currentStreak = "currentStreak"
    static let lastLogDate = "lastLogDate"
    static let streakFreezesRemaining = "streakFreezesRemaining"
    static let lastFreezeReset = "lastFreezeReset"

    // MARK: - Dashboard
    static let lastSummaryViewed = "lastSummaryViewed"

    // MARK: - Notifications
    static let dailyReminderEnabled = "dailyReminderEnabled"
    static let dailyReminderHour = "dailyReminderHour"
    static let weeklyDigestEnabled = "weeklyDigestEnabled"
    static let billDueReminders = "billDueReminders"

    // MARK: - Cloud
    static let iCloudSyncEnabled = "iCloudSyncEnabled"

    // MARK: - Engagement & Retention
    static let lastActiveDate = "lastActiveDate"
    static let morningBriefingEnabled = "morningBriefingEnabled"
    static let morningBriefingHour = "morningBriefingHour"
    static let catchUpDismissedDate = "catchUpDismissedDate"
}
