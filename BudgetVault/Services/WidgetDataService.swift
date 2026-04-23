import Foundation
import SwiftData
import WidgetKit
import BudgetVaultShared

enum WidgetDataService {

    static let suiteName = "group.io.budgetvault.shared"
    static let dataKey = "widgetData"

    /// Audit 2026-04-22 P2-8 — privacy trade-off note:
    ///
    /// `topCategories[].name` can be rendered by the widget on the
    /// lock screen (WidgetKit snapshots persist across app termination
    /// and iOS does NOT expose a "device locked" state to widget
    /// render code). For a user who has named a category something
    /// sensitive — "Therapy", "Legal retainer", "Medication" — the
    /// category name becomes visible to anyone who can see the lock
    /// screen.
    ///
    /// Current posture: accept the exposure, document in privacy
    /// policy. Rationale: the widget's core value is at-a-glance
    /// budget status; stripping category names would degrade it to
    /// emoji-only. A future setting (`AppStorageKeys.widgetPrivacyMode`)
    /// could let users opt into emoji-only rendering at the cost of
    /// widget utility — tracked separately, not in this audit.
    struct WidgetData: Codable {
        let remainingBudgetCents: Int64
        let totalBudgetCents: Int64
        let percentRemaining: Double
        let currencyCode: String
        let isPremium: Bool
        let topCategories: [CategorySummary]
        let dailyAllowanceCents: Int64
        let currentStreak: Int
        let daysRemaining: Int

        struct CategorySummary: Codable {
            let emoji: String
            let name: String
            let spentCents: Int64
            let budgetedCents: Int64
        }
    }

    @MainActor
    static func update(from context: ModelContext, resetDay: Int) {
        let (month, year) = DateHelpers.currentBudgetPeriod(resetDay: resetDay)

        let m = month
        let y = year
        let descriptor = FetchDescriptor<Budget>(
            predicate: #Predicate<Budget> { $0.month == m && $0.year == y }
        )
        guard let budget = try? context.fetch(descriptor).first else { return }

        let categories = (budget.categories ?? [])
            .filter { !$0.isHidden }
            .sorted { $0.spentCents(in: budget) > $1.spentCents(in: budget) }
            .prefix(3)
            .map { cat in
                WidgetData.CategorySummary(
                    emoji: cat.emoji,
                    name: cat.name,
                    spentCents: cat.spentCents(in: budget),
                    budgetedCents: cat.budgetedAmountCents
                )
            }

        // Compute daily allowance
        let daysRemaining = max(Calendar.current.dateComponents([.day], from: Date(), to: budget.nextPeriodStart).day ?? 0, 1)
        let dailyAllowance = budget.remainingCents / Int64(daysRemaining)

        let data = WidgetData(
            remainingBudgetCents: budget.remainingCents,
            totalBudgetCents: budget.totalIncomeCents,
            percentRemaining: budget.percentRemaining,
            currencyCode: UserDefaults.standard.string(forKey: AppStorageKeys.selectedCurrency) ?? "USD",
            isPremium: UserDefaults.standard.bool(forKey: AppStorageKeys.isPremium),
            topCategories: categories,
            dailyAllowanceCents: dailyAllowance,
            currentStreak: UserDefaults.standard.integer(forKey: AppStorageKeys.currentStreak),
            daysRemaining: daysRemaining
        )

        guard let encoded = try? JSONEncoder().encode(data) else { return }
        UserDefaults(suiteName: suiteName)?.set(encoded, forKey: dataKey)

        WidgetCenter.shared.reloadAllTimelines()
    }

    static func read() -> WidgetData? {
        guard let data = UserDefaults(suiteName: suiteName)?.data(forKey: dataKey),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return nil
        }
        return decoded
    }
}
