import SwiftUI

/// Full-screen unlock moment shown the instant a user earns a milestone.
/// VaultRevamp v2.1 Phase 8.3 §8.2.
///
/// Layers (back → front):
/// 1. Screen backdrop: navy radial gradient with a tier-colored center
///    tint (bronze amber / silver cool / gold warm)
/// 2. Tier-colored confetti — 8-12 pieces at 35-70% opacity, skipped
///    under Reduce Motion
/// 3. Hero content (centered): "MILESTONE UNLOCKED" eyebrow in tier
///    color, 180pt AchievementBadge, tier chip, title, description
/// 4. Dismiss CTA pinned to bottom
///
/// The sheet is presented via `.sheet(item:)` from DashboardView when
/// AchievementService detects a newly-earned achievement.
struct AchievementSheet: View {
    let achievement: AchievementService.Achievement
    let onDismiss: () -> Void

    @State private var contentVisible = false
    @State private var badgeScale: CGFloat = 0.5
    @State private var confettiActive = false
    @State private var confettiTask: Task<Void, Never>?
    // Audit 2026-04-22 P1-26: cancellable handle for the deferred
    // VoiceOver announcement (600ms after appear).
    @State private var announcementTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tier: AchievementBadge.Tier {
        switch achievement.tier {
        case .bronze: return .bronze
        case .silver: return .silver
        case .gold:   return .gold
        }
    }

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
            // Mockup line 279: `radial-gradient(ellipse at 50% 40%,
            // rgba(255,215,0,0.08) 0%, #0F1B33 40%, #070E1F 100%)` for
            // gold. Tier tint stays at 8% opacity (subtle — the badge
            // halo carries the main color lift, not the background).
            RadialGradient(
                colors: [
                    tierColor.opacity(0.08),
                    BudgetVaultTheme.navyDark,
                    BudgetVaultTheme.navyAbyss
                ],
                center: UnitPoint(x: 0.5, y: 0.4),
                startRadius: 0,
                endRadius: 500
            )
            .ignoresSafeArea()

            VStack(spacing: BudgetVaultTheme.spacingLG) {
                Spacer(minLength: BudgetVaultTheme.spacingMD)

                // Mockup line 77: `text-shadow: 0 0 12px rgba(255,215,0,0.6)`
                // — tier-colored glow around the eyebrow so it reads as
                // literally radiating light, matching the dial's halo.
                Text("MILESTONE UNLOCKED")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(4.0)
                    .foregroundStyle(tierColor)
                    .shadow(color: tierColor.opacity(0.6), radius: 12)
                    .opacity(contentVisible ? 1 : 0)
                    .accessibilityHidden(true)

                AchievementBadge(
                    tier: tier,
                    glyph: .emoji(achievement.emoji),
                    size: 180
                )
                .scaleEffect(badgeScale)
                .accessibilityElement()
                .accessibilityLabel("\(achievement.title) achievement unlocked, \(tierLabel) tier")

                VStack(spacing: 10) {
                    tierChip

                    Text(achievement.title)
                        .font(.system(size: 28, weight: .semibold))
                        .tracking(-0.5)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(achievement.description)
                        .font(.system(size: 15))
                        .foregroundStyle(BudgetVaultTheme.titanium200)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, BudgetVaultTheme.spacingXL)
                }
                .opacity(contentVisible ? 1 : 0)

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Text("Dismiss")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                }
                .background(BudgetVaultTheme.titanium700.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(BudgetVaultTheme.titanium500, lineWidth: 1)
                )
                .padding(.horizontal, BudgetVaultTheme.spacingXL)
                .padding(.bottom, BudgetVaultTheme.spacingXL)
            }

            // Tier-colored confetti overlay
            ConfettiView(
                isActive: confettiActive,
                style: .confetti,
                particleCount: 28,
                duration: 3.0
            )
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(BudgetVaultTheme.navyDark)
        .onAppear {
            HapticManager.notification(.success)

            // Audit 2026-04-22 P0-10: VoiceOver users previously got only
            // the haptic buzz. Post an announcement so the achievement is
            // actually read aloud. Delay slightly so it doesn't collide
            // with the sheet-transition announcement.
            // Audit 2026-04-22 P1-26: cancellable Task variant so a
            // fast-dismiss doesn't post an announcement for a torn-down
            // sheet.
            announcementTask?.cancel()
            announcementTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled else { return }
                let copy = "Milestone unlocked. \(achievement.title). \(achievement.description)"
                if #available(iOS 17.0, *) {
                    AccessibilityNotification.Announcement(copy).post()
                } else {
                    UIAccessibility.post(notification: .announcement, argument: copy)
                }
            }

            if reduceMotion {
                badgeScale = 1.0
                contentVisible = true
                // Reduce Motion skips confetti entirely per §8.4.
                return
            }

            withAnimation(.spring(response: 0.6, dampingFraction: 0.65).delay(0.1)) {
                badgeScale = 1.0
            }
            withAnimation(.easeIn(duration: 0.4).delay(0.5)) {
                contentVisible = true
            }
            // Audit fix: cancellable Task replaces DispatchQueue delay
            // so a fast-dismissed sheet doesn't fire state changes on
            // a torn-down view.
            confettiTask?.cancel()
            confettiTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                confettiActive = true
            }
        }
        .onDisappear {
            confettiTask?.cancel()
            announcementTask?.cancel()
            confettiActive = false
        }
        .accessibilityAddTraits(.isModal)
    }

    @ViewBuilder
    private var tierChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "seal.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tierColor)
            Text(tierLabel)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(2.0)
                .foregroundStyle(tierColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(tierColor.opacity(0.12))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(tierColor.opacity(0.35), lineWidth: 1)
        )
    }
}

#if DEBUG
#Preview("Gold unlock") {
    AchievementSheet(
        achievement: AchievementService.Achievement(
            id: "streak_100",
            title: "Century Club",
            description: "100-day logging streak",
            emoji: "\u{1F525}",
            tier: .gold,
            unlockedDate: Date()
        ),
        onDismiss: {}
    )
}

#Preview("Bronze unlock") {
    AchievementSheet(
        achievement: AchievementService.Achievement(
            id: "first_transaction",
            title: "Getting Started",
            description: "Logged your first expense",
            emoji: "\u{1F4DD}",
            tier: .bronze,
            unlockedDate: Date()
        ),
        onDismiss: {}
    )
}
#endif
