import Foundation
import SwiftData
import WidgetKit

enum WidgetDataService {

    static let suiteName = "group.io.budgetvault.shared"
    static let dataKey = "widgetData"

    struct WidgetData: Codable {
        let remainingBudgetCents: Int64
        let totalBudgetCents: Int64
        let percentRemaining: Double
        let currencyCode: String
        let isPremium: Bool
        let topCategories: [CategorySummary]

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

        let data = WidgetData(
            remainingBudgetCents: budget.remainingCents,
            totalBudgetCents: budget.totalIncomeCents,
            percentRemaining: budget.percentRemaining,
            currencyCode: UserDefaults.standard.string(forKey: "selectedCurrency") ?? "USD",
            isPremium: UserDefaults.standard.bool(forKey: "isPremium"),
            topCategories: categories
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
