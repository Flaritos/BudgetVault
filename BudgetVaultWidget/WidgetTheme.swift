import SwiftUI

/// Audit 2026-04-22 P2-5: these 6 constants duplicate the main app's
/// `BudgetVaultTheme` tokens. A proper dedupe would move them into
/// `BudgetVaultShared`, but that package is currently Foundation-only
/// — adding SwiftUI is a larger dependency shift than this audit item
/// justifies. If you change any value below, change the matching
/// constant in `BudgetVault/Views/Shared/BudgetVaultTheme.swift`:
///   - positive   → BudgetVaultTheme.positive
///   - caution    → BudgetVaultTheme.caution
///   - negative   → BudgetVaultTheme.negative
///   - neonOrange → BudgetVaultTheme.neonOrange
///   - navyDark   → BudgetVaultTheme.navyDark
///   - accentSoft → BudgetVaultTheme.accentSoft
enum WidgetTheme {
    static let positive = Color(hex: "#10B981")   // green
    static let caution = Color(hex: "#F59E0B")    // yellow/amber
    static let negative = Color(hex: "#EF4444")   // red
    static let neonOrange = Color(hex: "#FB923C") // orange
    static let navyDark = Color(hex: "#0F1B33")
    static let accentSoft = Color(hex: "#60A5FA")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
