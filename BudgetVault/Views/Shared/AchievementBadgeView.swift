import SwiftUI
import BudgetVaultShared

// MARK: - Milestones List (opened from Settings → Milestones)

/// VaultRevamp v2.1 Phase 8.3 §8.5.
///
/// The old AchievementGridView was a LazyVGrid of 60pt badges with a
/// premium-gate overlay on top. Phase 8.3 replaces it with a row-based
/// list that groups Earned and Locked into chamber-cards with per-row
/// progress bars. The premium gate stays — free users see the structure
/// but can't unlock — it just lives inside the chamber cohesion now.
struct AchievementGridView: View {
    @AppStorage(AppStorageKeys.isPremium) private var isPremium = false
    @Environment(StoreKitManager.self) private var storeKit
    private var premium: Bool { isPremium || storeKit.isPremium }
    @AppStorage(AppStorageKeys.currentStreak) private var currentStreak = 0
    @Environment(\.dismiss) private var dismiss

    private var unlocked: [AchievementService.Achievement] {
        AchievementService.unlockedAchievements()
    }

    private var unlockedIDs: Set<String> {
        Set(unlocked.map(\.id))
    }

    private var earnedCount: Int { premium ?unlocked.count : 0 }
    private var totalCount: Int { AchievementService.allAchievements.count }

    private var earnedAchievements: [AchievementService.Achievement] {
        AchievementService.allAchievements.filter { unlockedIDs.contains($0.id) }
    }

    private var lockedAchievements: [AchievementService.Achievement] {
        AchievementService.allAchievements.filter { !unlockedIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BudgetVaultTheme.navyDark.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: BudgetVaultTheme.spacingLG) {
                        summaryStrip
                            .padding(.top, BudgetVaultTheme.spacingMD)

                        if !earnedAchievements.isEmpty && premium {
                            milestonesSection(
                                title: "Earned",
                                count: earnedAchievements.count,
                                achievements: earnedAchievements,
                                isLocked: false
                            )
                        }

                        milestonesSection(
                            title: "Locked",
                            count: lockedAchievements.count,
                            achievements: premium ?lockedAchievements : AchievementService.allAchievements,
                            isLocked: true
                        )

                        if !premium {
                            premiumPromptCard
                        }
                    }
                    .padding(.horizontal, BudgetVaultTheme.spacingLG)
                    .padding(.bottom, BudgetVaultTheme.spacingXL)
                }
            }
            .navigationTitle("Milestones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(BudgetVaultTheme.navyDark, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(BudgetVaultTheme.accentSoft)
                }
            }
        }
    }

    // MARK: - Summary Strip

    @ViewBuilder
    private var summaryStrip: some View {
        HStack(spacing: 10) {
            summaryCell(value: "\(earnedCount)", label: "EARNED", color: BudgetVaultTheme.badgeGold)
            summaryCell(value: "\(totalCount)", label: "TOTAL", color: .white)
            summaryCell(value: "\(currentStreak)", label: "STREAK", color: BudgetVaultTheme.accentSoft)
        }
    }

    @ViewBuilder
    private func summaryCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(2.0)
                .foregroundStyle(BudgetVaultTheme.titanium400)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(BudgetVaultTheme.chamberDeep)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(BudgetVaultTheme.titanium700.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Sections

    @ViewBuilder
    private func milestonesSection(
        title: String,
        count: Int,
        achievements: [AchievementService.Achievement],
        isLocked: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                EngravedSectionHeader(title: title)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .tracking(1.5)
                    // Audit 2026-04-22 P0-9: titanium500 on navy = 3.25:1,
                    // fails WCAG 1.4.3 (4.5:1 required). titanium400 = 5.8:1.
                    .foregroundStyle(BudgetVaultTheme.titanium400)
                    .padding(.top, 20)
            }

            ChamberCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(achievements.enumerated()), id: \.element.id) { index, ach in
                        milestoneRow(ach, isLocked: isLocked)

                        if index < achievements.count - 1 {
                            HingeRule(weight: .thin)
                                .padding(.horizontal, 16)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func milestoneRow(_ achievement: AchievementService.Achievement, isLocked: Bool) -> some View {
        let tier = badgeTier(for: achievement.tier)
        let isAchUnlocked = unlockedIDs.contains(achievement.id) && premium

        HStack(spacing: 14) {
            AchievementBadge(
                tier: tier,
                glyph: .emoji(achievement.emoji),
                size: 42,
                isLocked: !isAchUnlocked
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(achievement.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isAchUnlocked ? .white : BudgetVaultTheme.titanium400)

                Text(achievement.description)
                    .font(.system(size: 12))
                    .foregroundStyle(BudgetVaultTheme.titanium400)
                    .lineLimit(2)
            }

            Spacer()

            if isAchUnlocked, let date = achievement.unlockedDate {
                VStack(alignment: .trailing, spacing: 3) {
                    Text("Earned")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(tierColor(for: achievement.tier))
                    Text(date, style: .date)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(BudgetVaultTheme.titanium400)
                }
            } else if isLocked {
                Text("Locked")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    // Audit 2026-04-22 P0-9: titanium500 on navy fails WCAG
                    // 1.4.3 body-text contrast. titanium400 = 5.8:1.
                    .foregroundStyle(BudgetVaultTheme.titanium400)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(achievement.title), \(isAchUnlocked ? "earned" : "locked")")
        .accessibilityHint("\(achievement.description). \(tierLabel(for: achievement.tier)) tier.")
    }

    // MARK: - Premium Prompt

    @ViewBuilder
    private var premiumPromptCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 20))
                .foregroundStyle(BudgetVaultTheme.caution)

            VStack(alignment: .leading, spacing: 2) {
                Text("Unlock milestone tracking")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Premium members earn badges as they build habits.")
                    .font(.system(size: 12))
                    .foregroundStyle(BudgetVaultTheme.titanium300)
            }

            Spacer()
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [BudgetVaultTheme.navyElevated, BudgetVaultTheme.navyDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(BudgetVaultTheme.accentSoft.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Helpers

    private func badgeTier(for tier: AchievementService.Achievement.Tier) -> AchievementBadge.Tier {
        switch tier {
        case .bronze: return .bronze
        case .silver: return .silver
        case .gold:   return .gold
        }
    }

    private func tierColor(for tier: AchievementService.Achievement.Tier) -> Color {
        switch tier {
        case .bronze: return BudgetVaultTheme.badgeBronze
        case .silver: return BudgetVaultTheme.badgeSilver
        case .gold:   return BudgetVaultTheme.badgeGold
        }
    }

    private func tierLabel(for tier: AchievementService.Achievement.Tier) -> String {
        switch tier {
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold:   return "Gold"
        }
    }
}

// MARK: - Legacy AchievementBadgeView shim
//
// The old grid rendered individual AchievementBadgeView cells. That
// view is kept as a thin compatibility wrapper in case any other call
// site still references it (so removal doesn't break sources outside
// this file). It now composes the new AchievementBadge primitive.

struct AchievementBadgeView: View {
    let achievement: AchievementService.Achievement
    var isUnlocked: Bool = true
    var size: CGFloat = 60

    private var tier: AchievementBadge.Tier {
        switch achievement.tier {
        case .bronze: return .bronze
        case .silver: return .silver
        case .gold:   return .gold
        }
    }

    var body: some View {
        VStack(spacing: BudgetVaultTheme.spacingXS) {
            AchievementBadge(
                tier: tier,
                glyph: .emoji(achievement.emoji),
                size: size,
                isLocked: !isUnlocked
            )

            Text(achievement.title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isUnlocked ? .white : BudgetVaultTheme.titanium400)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(width: size + 12)
        }
        .accessibilityLabel("\(achievement.title): \(achievement.description). \(isUnlocked ? "Unlocked" : "Locked")")
    }
}

#Preview("Badge - Unlocked") {
    AchievementBadgeView(
        achievement: AchievementService.allAchievements[0],
        isUnlocked: true,
        size: 80
    )
    .padding(40)
    .background(BudgetVaultTheme.navyDark)
}

#Preview("Milestones list") {
    AchievementGridView()
}
