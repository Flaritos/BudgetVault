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
        /// Audit 2026-04-27 M-1: signals to the lock-screen accessory
        /// widgets that the user has App Lock on, so they should render
        /// a "Tap to open" affordance instead of dollar amounts. Home-
        /// screen widgets ignore this flag — they're behind device
        /// unlock already and that's where users explicitly opt in.
        ///
        /// Optional with default `false` for forward-compat with
        /// previously-encoded JSON blobs sitting in the App Group from
        /// older app versions; `decodeIfPresent` falls through cleanly.
        let redactAmounts: Bool?

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

        // Audit 2026-04-23 Max Audit P0-6: when biometric lock is ON,
        // redact category names so the widget on the lock screen
        // shows only emoji + spent, never "Therapy" / "Legal" / etc.
        // Category emoji is already user-picked and considered
        // non-sensitive (it's a preset glyph, not a free-form
        // identifier), so the widget stays useful without leaking
        // verbatim category labels.
        let redactCategoryNames = UserDefaults.standard.bool(forKey: AppStorageKeys.biometricLockEnabled)
        let categories = (budget.categories ?? [])
            .filter { !$0.isHidden }
            .sorted { $0.spentCents(in: budget) > $1.spentCents(in: budget) }
            .prefix(3)
            .map { cat in
                WidgetData.CategorySummary(
                    emoji: cat.emoji,
                    name: redactCategoryNames ? "" : cat.name,
                    spentCents: cat.spentCents(in: budget),
                    budgetedCents: cat.budgetedAmountCents
                )
            }

        // Compute daily allowance.
        // Audit 2026-04-23 Max Audit P1-4: `.day` component from
        // `Date()` (current instant) to `nextPeriodStart` flips
        // between 0 and 1 depending on time-of-day on the last day of
        // the period. Anchor to `startOfDay` so the widget shows the
        // same "X days left" all day long.
        let today = Calendar.current.startOfDay(for: Date())
        let daysRemaining = max(Calendar.current.dateComponents([.day], from: today, to: budget.nextPeriodStart).day ?? 0, 1)
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
            daysRemaining: daysRemaining,
            redactAmounts: redactCategoryNames
        )

        guard let encoded = try? JSONEncoder().encode(data) else { return }

        // Audit 2026-04-23 Perf P0: dedupe byte-identical payloads.
        // 5 rapid transactions previously triggered 5 widget timeline
        // reloads; this short-circuit drops the redundant ones. iOS
        // does some throttling on its side but the app-side CPU cost
        // of JSON encoding + reloadAllTimelines still burned cycles.
        let appGroup = UserDefaults(suiteName: suiteName)
        if let previous = appGroup?.data(forKey: dataKey), previous == encoded {
            return
        }

        appGroup?.set(encoded, forKey: dataKey)
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
