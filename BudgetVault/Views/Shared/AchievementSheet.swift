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
    @State private var contentVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tierColor: Color {
        switch achievement.tier {
        case .bronze: return BudgetVaultTheme.badgeBronze
        case .silver: return BudgetVaultTheme.badgeSilver
        case .gold:   return BudgetVaultTheme.badgeGold
        }
    }

    var body: some View {
        VStack(spacing: BudgetVaultTheme.spacingLG) {
            Spacer()

            // VaultDialMark spin — the signature reward motion.
            VaultDialMark(size: 140, color: tierColor, showGlow: true, tickRotation: dialRotation)
                .accessibilityLabel("Vault opening")

            VStack(spacing: 8) {
                Text(achievement.emoji)
                    .font(.system(size: 56))
                    .opacity(contentVisible ? 1 : 0)
                    .scaleEffect(contentVisible ? 1 : 0.6)

                Text(achievement.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .opacity(contentVisible ? 1 : 0)

                Text(achievement.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(contentVisible ? 1 : 0)
            }
            .padding(.horizontal)

            Spacer()

            Button("Close") { onDismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal)
                .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            if reduceMotion {
                dialRotation = 0
                contentVisible = true
            } else {
                withAnimation(.easeOut(duration: 1.4)) {
                    dialRotation = 720
                }
                withAnimation(.easeIn(duration: 0.3).delay(0.5)) {
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
