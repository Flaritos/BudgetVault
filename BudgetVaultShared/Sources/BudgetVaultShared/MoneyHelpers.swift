import Foundation

public enum MoneyHelpers {

    /// Convert Int64 cents to Decimal dollars: 1450 → 14.50
    public static func centsToDollars(_ cents: Int64) -> Decimal {
        Decimal(cents) / 100
    }

    /// Convert Decimal dollars to Int64 cents: 14.50 → 1450
    public static func dollarsToCents(_ dollars: Decimal) -> Int64 {
        Int64(truncating: (dollars * 100) as NSDecimalNumber)
    }

    /// Parse a currency string (e.g. "14.50") to Int64 cents (1450).
    /// Returns nil if the string is not a valid number.
    public static func parseCurrencyString(_ string: String) -> Int64? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        guard let decimal = Decimal(string: trimmed) else { return nil }
        return dollarsToCents(decimal)
    }
}
