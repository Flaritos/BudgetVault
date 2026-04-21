import SwiftUI

/// Tier-colored mechanical badge that borrows its geometry from
/// `VaultDial` but swaps titanium for bronze/silver/gold. Used on the
/// Achievement unlock moment and inside rows on the Milestones list.
///
/// Phase 8.3 §8.3 rationale: tying achievements to the VaultDial
/// language keeps the ritual coherent. Tier color replaces titanium
/// rather than sitting on top of it — the badge reads as a forged
/// medallion of the same family as the vault's dial, not a sticker
/// slapped onto chrome.
///
/// Composed, not inherited. `VaultDial` stays a titanium-only
/// primitive so its open/locked states and tick animation remain
/// focused. This struct builds its own ring / chamber / ticks /
/// glyph stack with tier colors, but reuses the size scaling pattern
/// so both primitives behave consistently under Dynamic Type.
struct AchievementBadge: View {
    enum Tier {
        case bronze
        case silver
        case gold

        fileprivate var ringColors: [Color] {
            switch self {
            case .bronze: return [BudgetVaultTheme.badgeBronze, BudgetVaultTheme.badgeBronzeDark]
            case .silver: return [BudgetVaultTheme.badgeSilver, BudgetVaultTheme.badgeSilverDark]
            case .gold:   return [BudgetVaultTheme.badgeGold, BudgetVaultTheme.badgeGoldDark]
            }
        }

        fileprivate var glyphColor: Color {
            switch self {
            case .bronze: return BudgetVaultTheme.badgeBronze
            case .silver: return BudgetVaultTheme.badgeSilver
            case .gold:   return BudgetVaultTheme.badgeGold
            }
        }

        fileprivate var darkShadow: Color {
            switch self {
            case .bronze: return BudgetVaultTheme.badgeBronzeDark
            case .silver: return BudgetVaultTheme.badgeSilverDark
            case .gold:   return BudgetVaultTheme.badgeGoldDark
            }
        }

        fileprivate var haloOpacity: Double { 0.35 }
    }

    enum Glyph {
        case symbol(String)     // SF Symbol name
        case emoji(String)      // Emoji character
    }

    let tier: Tier
    var glyph: Glyph = .symbol("star.fill")
    var size: CGFloat = 180
    var isLocked: Bool = false

    @ScaledMetric(relativeTo: .largeTitle) private var scaleFactor: CGFloat = 1.0

    private var dim: CGFloat { size * scaleFactor }

    var body: some View {
        ZStack {
            if !isLocked {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [tier.glyphColor.opacity(tier.haloOpacity), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: dim * 0.75
                        )
                    )
                    .frame(width: dim * 1.35, height: dim * 1.35)
                    .blur(radius: 6)
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: tier.ringColors,
                        center: UnitPoint(x: 0.35, y: 0.30),
                        startRadius: 0,
                        endRadius: dim * 0.55
                    )
                )
                .overlay(
                    Circle()
                        .strokeBorder(tier.darkShadow, lineWidth: dim * 0.012)
                )
                .frame(width: dim, height: dim)

            Circle()
                .fill(BudgetVaultTheme.chamberDeep)
                .overlay(
                    Circle()
                        .strokeBorder(tier.darkShadow.opacity(0.6), lineWidth: 1)
                )
                .frame(width: dim * 0.80, height: dim * 0.80)

            tickRing

            glyphView
        }
        .grayscale(isLocked ? 1.0 : 0.0)
        .opacity(isLocked ? 0.35 : 1.0)
        .accessibilityHidden(true)
    }

    /// Four cardinal tick marks in tier-dark. Keeps the dial language
    /// without rendering the full 40-tick face (which belongs to
    /// VaultDial's combination-wheel metaphor).
    @ViewBuilder
    private var tickRing: some View {
        ForEach(0..<4) { i in
            Rectangle()
                .fill(tier.darkShadow.opacity(0.6))
                .frame(width: dim * 0.012, height: dim * 0.045)
                .offset(y: -(dim * 0.37))
                .rotationEffect(.degrees(Double(i) * 90))
        }
    }

    @ViewBuilder
    private var glyphView: some View {
        switch glyph {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: dim * 0.30, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [tier.glyphColor, tier.darkShadow],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
        case .emoji(let character):
            Text(character)
                .font(.system(size: dim * 0.34))
                .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
        }
    }
}

#Preview("All tiers — hero size") {
    HStack(spacing: 24) {
        AchievementBadge(tier: .bronze, glyph: .emoji("\u{1F525}"), size: 120)
        AchievementBadge(tier: .silver, glyph: .emoji("\u{1F3AF}"), size: 120)
        AchievementBadge(tier: .gold, glyph: .emoji("\u{1F451}"), size: 120)
    }
    .padding(40)
    .background(BudgetVaultTheme.navyDark)
}

#Preview("Locked vs unlocked") {
    HStack(spacing: 16) {
        AchievementBadge(tier: .gold, glyph: .symbol("star.fill"), size: 56, isLocked: false)
        AchievementBadge(tier: .gold, glyph: .symbol("star.fill"), size: 56, isLocked: true)
    }
    .padding(40)
    .background(BudgetVaultTheme.navyDark)
}
