import SwiftUI

/// Brief modal sheet that announces a newly-unlocked achievement.
/// Replaces the v3.2 overlay banner that was removed because it
/// kept colliding with other top-of-screen UI (DashboardView.swift:58
/// "Round 8: newAchievementBanner state removed").
///
/// Presented from DashboardView via `.sheet(item:)` with the unlocked
/// `Achievement`. User dismisses with the Close button or by swiping.
struct AchievementSheet: View {
    let achievement: AchievementService.Achievement
    let onDismiss: () -> Void

    @State private var dialRotation: Double = 0
    @State private var dialOpen = false
    @State private var contentVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tierColor: Color {
        switch achievement.tier {
        case .bronze: return BudgetVaultTheme.badgeBronze
        case .silver: return BudgetVaultTheme.badgeSilver
        case .gold:   return BudgetVaultTheme.badgeGold
        }
    }

    private var tierLabel: String {
        switch achievement.tier {
        case .bronze: return "BRONZE"
        case .silver: return "SILVER"
        case .gold:   return "GOLD"
        }
    }

    var body: some View {
        ZStack {
            // VaultRevamp v2.1 chamber backdrop with ambient glow from the
            // top — matches the Vault tab inner-sanctum aesthetic.
            RadialGradient(
                colors: [BudgetVaultTheme.navyMid, BudgetVaultTheme.navyDark, Color.black],
                center: UnitPoint(x: 0.5, y: 0.1),
                startRadius: 40,
                endRadius: 600
            )
            .ignoresSafeArea()

            VStack(spacing: BudgetVaultTheme.spacingLG) {
                Spacer(minLength: BudgetVaultTheme.spacingMD)

                // Canonical VaultDial — rotates while locked then swaps to
                // .open with a tier-colored halo. The halo is our way to
                // preserve bronze/silver/gold differentiation without losing
                // the shared primitive.
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [tierColor.opacity(0.35), tierColor.opacity(0)],
                                center: .center,
                                startRadius: 50,
                                endRadius: 110
                            )
                        )
                        .frame(width: 220, height: 220)
                        .blur(radius: 8)

                    VaultDial(
                        size: .hero,
                        state: dialOpen ? .open : .locked,
                        showGlow: dialOpen,
                        faceRotationDegrees: dialRotation
                    )
                    .frame(width: 160, height: 160)
                }
                .accessibilityElement()
                .accessibilityLabel("Vault unlocked, \(tierLabel) tier")

                VStack(spacing: 10) {
                    Text(tierLabel)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(2.5)
                        .foregroundStyle(tierColor)

                    Text(achievement.title)
                        .font(.system(size: 24, weight: .bold))
                        .tracking(-0.5)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(achievement.emoji)
                        .font(.system(size: 56))

                    Text(achievement.description)
                        .font(.subheadline)
                        .foregroundStyle(BudgetVaultTheme.titanium300)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, BudgetVaultTheme.spacingLG)
                }
                .opacity(contentVisible ? 1 : 0)

                Spacer()

                Button("Close") { onDismiss() }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal)
                    .padding(.bottom)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(BudgetVaultTheme.navyDark)
        .onAppear {
            if reduceMotion {
                dialRotation = 0
                dialOpen = true
                contentVisible = true
            } else {
                // Dial spins while "locked," then opens on a beat.
                withAnimation(.easeOut(duration: 1.2)) {
                    dialRotation = 720
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.9)) {
                    dialOpen = true
                }
                withAnimation(.easeIn(duration: 0.3).delay(1.2)) {
                    contentVisible = true
                }
            }
        }
        .accessibilityAddTraits(.isModal)
    }
}

#if DEBUG
#Preview {
    AchievementSheet(
        achievement: AchievementService.Achievement(
            id: "streak_7",
            title: "Week Warrior",
            description: "7-day logging streak",
            emoji: "\u{1F525}",
            tier: .bronze,
            unlockedDate: Date()
        ),
        onDismiss: {}
    )
}
#endif
