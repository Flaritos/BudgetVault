import Foundation
import SwiftUI

struct CurrencyFormatter {

    private static let lock = NSLock()
    private static var _cachedFormatter: NumberFormatter?
    private static var _cachedCurrencyCode: String?

    private static func formattedString(for currencyCode: String, value: NSDecimalNumber) -> String {
        let code = currencyCode.isEmpty ? (UserDefaults.standard.string(forKey: AppStorageKeys.selectedCurrency) ?? "USD") : currencyCode
        lock.lock()
        defer { lock.unlock() }
        if let cached = _cachedFormatter, _cachedCurrencyCode == code {
            return cached.string(from: value) ?? "0"
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        _cachedFormatter = formatter
        _cachedCurrencyCode = code
        return formatter.string(from: value) ?? "0"
    }

    private static func resolvedSymbol(for currencyCode: String) -> String {
        let code = currencyCode.isEmpty ? (UserDefaults.standard.string(forKey: AppStorageKeys.selectedCurrency) ?? "USD") : currencyCode
        lock.lock()
        defer { lock.unlock() }
        if let cached = _cachedFormatter, _cachedCurrencyCode == code {
            return cached.currencySymbol ?? "$"
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        _cachedFormatter = formatter
        _cachedCurrencyCode = code
        return formatter.currencySymbol ?? "$"
    }

    /// Format Int64 cents as a locale-aware currency string.
    /// Uses the user's selected currency code from AppStorage.
    static func format(cents: Int64, currencyCode: String = "") -> String {
        let dollars = MoneyHelpers.centsToDollars(cents)
        return formattedString(for: currencyCode, value: dollars as NSDecimalNumber)
    }

    /// Format a Decimal amount as currency
    static func format(amount: Decimal, currencyCode: String = "") -> String {
        return formattedString(for: currencyCode, value: amount as NSDecimalNumber)
    }

    /// Get just the currency symbol for the selected currency
    static func currencySymbol(for currencyCode: String = "") -> String {
        return resolvedSymbol(for: currencyCode)
    }
}
