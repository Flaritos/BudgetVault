import Foundation

public struct CurrencyFormatter {

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
    public static func format(cents: Int64, currencyCode: String = "") -> String {
        let dollars = MoneyHelpers.centsToDollars(cents)
        return formattedString(for: currencyCode, value: dollars as NSDecimalNumber)
    }

    /// Format a Decimal amount as currency
    public static func format(amount: Decimal, currencyCode: String = "") -> String {
        return formattedString(for: currencyCode, value: amount as NSDecimalNumber)
    }

    /// Get just the currency symbol for the selected currency
    public static func currencySymbol(for currencyCode: String = "") -> String {
        return resolvedSymbol(for: currencyCode)
    }

    /// Convert Int64 cents to a raw numeric string (e.g. 1450 -> "14.50", 500 -> "5").
    public static func formatRaw(cents: Int64) -> String {
        let dollars = cents / 100
        let remainder = cents % 100
        if remainder == 0 { return "\(dollars)" }
        return String(format: "%d.%02d", dollars, remainder)
    }

    /// Format a raw amount text string for display with the user's currency symbol.
    public static func displayAmount(text: String) -> String {
        let symbol = currencySymbol()
        if text.isEmpty { return "\(symbol)0" }
        return "\(symbol)\(text)"
    }
}
