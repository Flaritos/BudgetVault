import SwiftUI
import UIKit

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
    /// WCAG AA compliant with white text (4.5:1+ contrast ratio)
    static let warningGradient: [Color] = [Color(hex: "#B45309"), Color(hex: "#92400E")]
    static let dangerGradient: [Color] = [Color(hex: "#F87171"), Color(hex: "#DC2626")]
    static let premiumGradient: [Color] = [Color(hex: "#818CF8"), Color(hex: "#6366F1")]

    // MARK: - Semantic Colors (softer than raw system)
    static let positive = Color(hex: "#10B981")
    static let negative = Color(hex: "#EF4444")
    static let caution = Color(hex: "#F59E0B")
    // Round 5 M9: collapsed the info/brightBlue drift. One accent.
    static let info = brightBlue

    // MARK: - Accent Token
    static let accentSoft = Color(hex: "#60A5FA")

    // MARK: - Neon Accents
    static let neonBlue = accentSoft               // alias for #60A5FA
    static let neonGreen = Color(hex: "#34D399")
    static let neonPurple = Color(hex: "#A78BFA")
    static let neonOrange = Color(hex: "#FB923C")
    static let neonYellow = Color(hex: "#FBBF24")

    // MARK: - Spacing
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 12
    static let spacingLG: CGFloat = 16
    static let spacingXL: CGFloat = 24
    static let spacing2XL: CGFloat = 32
    static let spacingSection: CGFloat = 32
    static let spacingPage: CGFloat = 40

    // MARK: - Corner Radii
    static let radiusXS: CGFloat = 4
    static let radiusSM: CGFloat = 8
    static let radiusPad: CGFloat = 10
    static let radiusMD: CGFloat = 12
    static let radiusButton: CGFloat = 14
    static let radiusLG: CGFloat = 16
    static let radiusXL: CGFloat = 20

    // MARK: - Animation Durations
    static let animationQuick: Double = 0.15
    static let animationStandard: Double = 0.3
    static let animationSlow: Double = 0.6

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

    // MARK: - Typography (Dynamic Type)
    // All tokens use semantic TextStyles so they scale with Dynamic Type.
    // For custom sizes beyond what TextStyle offers, views should use
    // @ScaledMetric locally (e.g. @ScaledMetric(relativeTo: .largeTitle) var size: CGFloat = 54).
    static let heroAmount = Font.system(.largeTitle, design: .rounded).weight(.heavy)
    static let amountEntry = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let wrappedHero = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let priceDisplay = Font.system(.title, design: .rounded).weight(.bold)
    static let brandTitle = Font.system(.title, design: .rounded).weight(.bold)
    static let statistic = Font.system(.title2, design: .rounded).weight(.bold)
    static let cardAmount = Font.system(.title3, design: .rounded).weight(.bold)
    static let rowAmount = Font.system(.callout, design: .rounded).weight(.semibold)
    static let sectionIcon = Font.system(.largeTitle, design: .default)
    static let iconLarge = Font.system(.largeTitle, design: .default)

    // MARK: - Hero Spacing
    static let spacingHero: CGFloat = 40

    // MARK: - Achievement Badge Colors
    static let badgeBronze = Color(hex: "#CD7F32")
    static let badgeBronzeDark = Color(hex: "#8B5A2B")
    static let badgeSilver = Color(hex: "#C0C0C0")
    static let badgeSilverDark = Color(hex: "#808080")
    static let badgeGold = Color(hex: "#FFD700")
    static let badgeGoldDark = Color(hex: "#DAA520")

    // MARK: - Adaptive Colors

    /// Creates a dynamic color that adapts to light/dark mode.
    /// - Parameters:
    ///   - light: Hex color string for light mode
    ///   - dark: Hex color string for dark mode
    /// - Returns: A Color that automatically adapts to the current color scheme
    static func adaptiveColor(light: String, dark: String) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark))
                : UIColor(Color(hex: light))
        })
    }

    // MARK: - Surface Colors
    static let cardBackground = adaptiveColor(light: "#FFFFFF", dark: "#1C1C1E")

    // Round 5 M8: single source of truth for card surfaces. The app was
    // using white/cream/gray ad-hoc across Home/Envelopes/Siri tip/Streak
    // card. These four tokens cover every legitimate card variant.
    /// Default white data card (envelopes, transactions, insights).
    static let surfaceCardPrimary = cardBackground
    /// Subtle elevated card for secondary groupings (streak, tip, info).
    static let surfaceCardSecondary = cardBackground
    /// Dark card used on navy chrome (Vault tab features, paywall items).
    static let surfaceCardDark = adaptiveColor(light: "#F2F2F7", dark: "#0F1B33")
    /// Subtle highlight card for celebratory moments (wrapped).
    static let surfaceCardAccent = adaptiveColor(light: "#EFF6FF", dark: "#0F1B33")
    static let surfaceBackground = adaptiveColor(light: "#F2F2F7", dark: "#000000")

    // MARK: - User Accent Color

    static var userAccentColor: Color {
        let hex = UserDefaults.standard.string(forKey: AppStorageKeys.accentColorHex) ?? "#2563EB"
        return Color(hex: hex)
    }

    // MARK: - Accent Color Options

    static let accentColorOptions: [(name: String, hex: String)] = [
        ("Electric Blue", "#2563EB"),
        ("Emerald", "#10B981"),
        ("Purple", "#8B5CF6"),
        ("Rose", "#F43F5E"),
        ("Amber", "#F59E0B"),
        ("Teal", "#14B8A6"),
        ("Indigo", "#6366F1"),
        ("Orange", "#F97316"),
        ("Slate", "#64748B"),
        ("Crimson", "#DC2626"),
    ]
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
