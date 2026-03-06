import Foundation
import SwiftUI

struct CurrencyFormatter {

    private nonisolated(unsafe) static var cachedFormatter: NumberFormatter?
    private nonisolated(unsafe) static var cachedCurrencyCode: String?

    private static func formatter(for currencyCode: String) -> NumberFormatter {
        let code = currencyCode.isEmpty ? (UserDefaults.standard.string(forKey: "selectedCurrency") ?? "USD") : currencyCode
        if let cached = cachedFormatter, cachedCurrencyCode == code {
            return cached
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        cachedFormatter = formatter
        cachedCurrencyCode = code
        return formatter
    }

    /// Format Int64 cents as a locale-aware currency string.
    /// Uses the user's selected currency code from AppStorage.
    static func format(cents: Int64, currencyCode: String = "") -> String {
        let dollars = MoneyHelpers.centsToDollars(cents)
        let fmt = formatter(for: currencyCode)
        return fmt.string(from: dollars as NSDecimalNumber) ?? "$0.00"
    }

    /// Format a Decimal amount as currency
    static func format(amount: Decimal, currencyCode: String = "") -> String {
        let fmt = formatter(for: currencyCode)
        return fmt.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }

    /// Get just the currency symbol for the selected currency
    static func currencySymbol(for currencyCode: String = "") -> String {
        let fmt = formatter(for: currencyCode)
        return fmt.currencySymbol ?? "$"
    }
}
