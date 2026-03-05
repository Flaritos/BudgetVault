import Foundation
import SwiftUI

struct CurrencyFormatter {

    /// Format Int64 cents as a locale-aware currency string.
    /// Uses the user's selected currency code from AppStorage.
    static func format(cents: Int64, currencyCode: String = "") -> String {
        let dollars = MoneyHelpers.centsToDollars(cents)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency

        let code = currencyCode.isEmpty ? (UserDefaults.standard.string(forKey: "selectedCurrency") ?? "USD") : currencyCode
        formatter.currencyCode = code

        return formatter.string(from: dollars as NSDecimalNumber) ?? "$0.00"
    }

    /// Format a Decimal amount as currency
    static func format(amount: Decimal, currencyCode: String = "") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency

        let code = currencyCode.isEmpty ? (UserDefaults.standard.string(forKey: "selectedCurrency") ?? "USD") : currencyCode
        formatter.currencyCode = code

        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }

    /// Get just the currency symbol for the selected currency
    static func currencySymbol(for currencyCode: String = "") -> String {
        let code = currencyCode.isEmpty ? (UserDefaults.standard.string(forKey: "selectedCurrency") ?? "USD") : currencyCode
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.currencySymbol ?? "$"
    }
}
