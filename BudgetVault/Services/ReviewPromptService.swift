import SwiftUI
import StoreKit

enum ReviewPromptService {
    static func requestIfAppropriate() {
        let defaults = UserDefaults.standard
        let currentYear = Calendar.current.component(.year, from: Date())
        let yearKey = "reviewPromptYear"
        let countKey = "reviewPromptCount"

        // Reset counter for new year
        let storedYear = defaults.integer(forKey: yearKey)
        if storedYear != currentYear {
            defaults.set(currentYear, forKey: yearKey)
            defaults.set(0, forKey: countKey)
        }

        // Max 3 per year
        let count = defaults.integer(forKey: countKey)
        guard count < 3 else { return }

        // Suppress 48h after paywall decline
        let lastDecline = defaults.double(forKey: AppStorageKeys.lastPaywallDecline)
        if lastDecline > 0 {
            let hoursSinceDecline = (Date().timeIntervalSince1970 - lastDecline) / 3600
            guard hoursSinceDecline > 48 else { return }
        }

        // Minimum 7 days between prompts
        let lastPromptKey = "lastReviewPromptDate"
        let lastPrompt = defaults.double(forKey: lastPromptKey)
        if lastPrompt > 0 {
            let daysSinceLastPrompt = (Date().timeIntervalSince1970 - lastPrompt) / 86400
            guard daysSinceLastPrompt > 7 else { return }
        }

        // Request review
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
            defaults.set(count + 1, forKey: countKey)
            defaults.set(Date().timeIntervalSince1970, forKey: lastPromptKey)
        }
    }

    // MARK: - Trigger-Based Prompts

    /// Call after detecting the user finished their first month under budget.
    static func checkFirstMonthUnderBudget() {
        let defaults = UserDefaults.standard
        let key = "reviewTriggered_firstMonthUnderBudget"
        guard !defaults.bool(forKey: key) else { return }

        if AchievementService.isUnlocked("under_budget_1") {
            defaults.set(true, forKey: key)
            requestIfAppropriate()
        }
    }

    /// Call when transaction count in current period reaches a milestone.
    static func checkTransactionMilestone(transactionCount: Int) {
        let defaults = UserDefaults.standard
        let key = "reviewTriggered_10thTransaction"
        guard !defaults.bool(forKey: key) else { return }

        if transactionCount >= 10 {
            defaults.set(true, forKey: key)
            requestIfAppropriate()
        }
    }
}
