import ActivityKit
import Foundation

struct BudgetActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let remainingCents: Int64
        let dailyAllowanceCents: Int64
        let spentFraction: Double // 0.0 to 1.0
        let dayOfPeriod: Int
        let totalDays: Int
        let currencyCode: String
    }

    let periodEndDate: Date
}
