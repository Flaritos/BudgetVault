import Foundation
import BudgetVaultShared

/// Picks ONE non-financial brag stat per Wrapped share. Per spec 5.10 user
/// decision, all three slots rotate (streak / tx count / no-spend days)
/// keyed by `wrappedSharesAllTime` so successive shares cycle naturally.
/// Empty slots fall through to the next non-empty one; if all empty, the
/// brand fallback ships ("Privacy-first budgeting").
enum BragStatRotator {

    static func pick(slot: Int, streakDays: Int, txCount: Int, zeroSpendDays: Int) -> String {
        let candidates: [String?] = [
            streakDays > 0 ? "\(streakDays)-day streak" : nil,
            txCount > 0 ? "\(txCount) logs" : nil,
            zeroSpendDays > 0 ? "\(zeroSpendDays) no-spend days" : nil
        ]

        // Try the requested slot, then walk forward modulo 3.
        for offset in 0..<3 {
            let i = (slot + offset) % 3
            if let s = candidates[i] { return s }
        }
        return "Privacy-first budgeting"
    }

    /// Convenience that pulls the rotation slot from on-device share count.
    static func currentBragStat(streakDays: Int, txCount: Int, zeroSpendDays: Int) -> String {
        let slot = UserDefaults.standard.integer(forKey: AppStorageKeys.wrappedSharesAllTime)
        return pick(slot: slot, streakDays: streakDays, txCount: txCount, zeroSpendDays: zeroSpendDays)
    }
}
