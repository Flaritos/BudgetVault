import SwiftUI

enum BudgetVaultTheme {
    // MARK: - Brand Colors
    static let navyDark = Color(hex: "#0F1B33")
    static let navyMid = Color(hex: "#1A2744")
    static let electricBlue = Color(hex: "#2563EB")
    static let brightBlue = Color(hex: "#3B82F6")

    static let brandGradient = LinearGradient(
        colors: [navyDark, electricBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let heroBrandGradient = LinearGradient(
        colors: [navyDark, brightBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Gradients
    static let healthyGradient: [Color] = [navyDark, electricBlue]
    static let warningGradient: [Color] = [Color(hex: "#FBBF24"), Color(hex: "#D97706")]
    static let dangerGradient: [Color] = [Color(hex: "#F87171"), Color(hex: "#DC2626")]
    static let premiumGradient: [Color] = [Color(hex: "#818CF8"), Color(hex: "#6366F1")]

    // MARK: - Semantic Colors (softer than raw system)
    static let positive = Color(hex: "#10B981")
    static let negative = Color(hex: "#EF4444")
    static let caution = Color(hex: "#F59E0B")
    static let info = Color(hex: "#3B82F6")

    // MARK: - Spacing
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 12
    static let spacingLG: CGFloat = 16
    static let spacingXL: CGFloat = 24
    static let spacing2XL: CGFloat = 32

    // MARK: - Corner Radii
    static let radiusSM: CGFloat = 8
    static let radiusMD: CGFloat = 12
    static let radiusLG: CGFloat = 16
    static let radiusXL: CGFloat = 20

    // MARK: - Shadows
    static func cardShadow() -> some View {
        Color.clear.shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }

    // MARK: - Gradient for budget health
    static func budgetGradient(for percentRemaining: Double) -> LinearGradient {
        let colors: [Color]
        if percentRemaining > 0.5 {
            colors = healthyGradient
        } else if percentRemaining > 0.2 {
            colors = warningGradient
        } else {
            colors = dangerGradient
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: - Typography
    static let heroAmount = Font.system(size: 54, weight: .heavy, design: .rounded)
    static let cardAmount = Font.system(size: 20, weight: .bold, design: .rounded)
    static let rowAmount = Font.system(size: 16, weight: .semibold, design: .rounded)
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
