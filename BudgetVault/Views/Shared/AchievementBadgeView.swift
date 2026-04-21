import SwiftUI
import BudgetVaultShared

// MARK: - Single Achievement Badge

struct AchievementBadgeView: View {
    let achievement: AchievementService.Achievement
    var isUnlocked: Bool = true
    var size: CGFloat = 60

    @State private var showDetail = false

    private var tierColor: Color {
        switch achievement.tier {
        case .bronze: return BudgetVaultTheme.badgeBronze
        case .silver: return BudgetVaultTheme.badgeSilver
        case .gold: return BudgetVaultTheme.badgeGold
        }
    }

    private var tierGradient: LinearGradient {
        switch achievement.tier {
        case .bronze:
            return LinearGradient(
                colors: [BudgetVaultTheme.badgeBronze, BudgetVaultTheme.badgeBronzeDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .silver:
            return LinearGradient(
                colors: [BudgetVaultTheme.badgeSilver, BudgetVaultTheme.badgeSilverDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .gold:
            return LinearGradient(
                colors: [BudgetVaultTheme.badgeGold, BudgetVaultTheme.badgeGoldDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var body: some View {
        VStack(spacing: BudgetVaultTheme.spacingXS) {
            ZStack {
                // Chamber backing (recessed vault compartment) — titanium
                // hairline ring that becomes tier-colored when unlocked.
                Circle()
                    .fill(BudgetVaultTheme.chamberBackground)
                    .frame(width: size, height: size)

                Circle()
                    .strokeBorder(
                        isUnlocked ? tierGradient : LinearGradient(
                            colors: [BudgetVaultTheme.titanium700],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: size * 0.04
                    )
                    .frame(width: size, height: size)

                // Inner titanium hairline for chamber depth
                Circle()
                    .strokeBorder(BudgetVaultTheme.titanium300.opacity(0.12), lineWidth: 1)
                    .frame(width: size - 4, height: size - 4)

                if isUnlocked {
                    Text(achievement.emoji)
                        .font(.system(size: size * 0.42))
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: size * 0.24))
                        .foregroundStyle(BudgetVaultTheme.titanium300)
                }
            }
            .shadow(color: isUnlocked ? tierColor.opacity(0.35) : .black.opacity(0.3), radius: 6, y: 3)

            Text(achievement.title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isUnlocked ? .white : BudgetVaultTheme.titanium300)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(width: size + 12)
        }
        .onTapGesture {
            showDetail = true
        }
        .popover(isPresented: $showDetail) {
            achievementDetail
                .presentationCompactAdaptation(.popover)
        }
        .accessibilityLabel("\(achievement.title): \(achievement.description). \(isUnlocked ? "Unlocked" : "Locked")")
    }

    private var achievementDetail: some View {
        VStack(spacing: BudgetVaultTheme.spacingMD) {
            Text(achievement.emoji)
                .font(.system(size: 40))

            Text(achievement.title)
                .font(.headline)
                .foregroundStyle(.white)

            Text(achievement.description)
                .font(.subheadline)
                .foregroundStyle(BudgetVaultTheme.titanium300)

            HStack(spacing: BudgetVaultTheme.spacingXS) {
                Image(systemName: "star.fill")
                    .foregroundStyle(tierColor)
                Text(achievement.tier.rawValue.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(tierColor)
            }

            if isUnlocked, let date = achievement.unlockedDate {
                Text("Unlocked \(date, style: .date)")
                    .font(.caption2)
                    .foregroundStyle(BudgetVaultTheme.titanium300)
            } else if !isUnlocked {
                Text("Not yet unlocked")
                    .font(.caption2)
                    .foregroundStyle(BudgetVaultTheme.titanium300)
            }
        }
        .padding(BudgetVaultTheme.spacingLG)
        .background(BudgetVaultTheme.chamberBackground)
    }
}

// MARK: - Achievement Grid

struct AchievementGridView: View {
    @AppStorage(AppStorageKeys.isPremium) private var isPremium = false

    private let columns = [
        GridItem(.adaptive(minimum: 80, maximum: 100), spacing: BudgetVaultTheme.spacingMD)
    ]

    private var unlocked: [AchievementService.Achievement] {
        AchievementService.unlockedAchievements()
    }

    private var unlockedIDs: Set<String> {
        Set(unlocked.map(\.id))
    }

    var body: some View {
        ZStack {
            BudgetVaultTheme.navyDark.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: BudgetVaultTheme.spacingLG) {
                    HingeRule(weight: .heavy)

                    // Header — VaultRevamp engraved typography
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Achievements")
                                .font(.system(size: 32, weight: .bold))
                                .tracking(-0.8)
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(unlocked.count)/\(AchievementService.allAchievements.count)")
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .foregroundStyle(BudgetVaultTheme.titanium300)
                        }
                        Text("UNLOCKED MILESTONES")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(2.0)
                            .foregroundStyle(BudgetVaultTheme.titanium300)
                    }
                    .padding(.horizontal, BudgetVaultTheme.spacingLG)

                    // Progress bar — chamber recess with gold fill
                    GeometryReader { geo in
                        let progress = AchievementService.allAchievements.isEmpty
                            ? 0.0
                            : Double(unlocked.count) / Double(AchievementService.allAchievements.count)
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(BudgetVaultTheme.chamberBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .strokeBorder(BudgetVaultTheme.titanium700, lineWidth: 1)
                                )
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [BudgetVaultTheme.badgeGold, BudgetVaultTheme.badgeGoldDark],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, geo.size.width * progress), height: 6)
                        }
                    }
                    .frame(height: 6)
                    .padding(.horizontal, BudgetVaultTheme.spacingLG)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Achievement progress: \(unlocked.count) of \(AchievementService.allAchievements.count) unlocked")

                    // Grid wrapped in ChamberCard
                    ChamberCard(padding: BudgetVaultTheme.spacingLG) {
                        ZStack {
                            LazyVGrid(columns: columns, spacing: BudgetVaultTheme.spacingLG) {
                                ForEach(AchievementService.allAchievements) { ach in
                                    let isAchUnlocked = unlockedIDs.contains(ach.id)
                                    let displayAch: AchievementService.Achievement = {
                                        if let match = unlocked.first(where: { $0.id == ach.id }) {
                                            return match
                                        }
                                        return ach
                                    }()

                                    AchievementBadgeView(
                                        achievement: displayAch,
                                        isUnlocked: isPremium ? isAchUnlocked : false,
                                        size: 60
                                    )
                                }
                            }

                            if !isPremium {
                                RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD)
                                    .fill(.ultraThinMaterial)
                                    .overlay {
                                        VStack(spacing: BudgetVaultTheme.spacingMD) {
                                            Image(systemName: "lock.fill")
                                                .font(.title)
                                                .foregroundStyle(BudgetVaultTheme.titanium300)
                                            Text("Upgrade to Premium")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.white)
                                            Text("Unlock achievement tracking and badges")
                                                .font(.caption)
                                                .foregroundStyle(BudgetVaultTheme.titanium300)
                                                .multilineTextAlignment(.center)
                                        }
                                        .padding()
                                    }
                            }
                        }
                    }
                    .padding(.horizontal, BudgetVaultTheme.spacingLG)
                }
                .padding(.vertical, BudgetVaultTheme.spacingLG)
            }
        }
    }
}

#Preview("Badge - Unlocked") {
    AchievementBadgeView(
        achievement: AchievementService.allAchievements[0],
        isUnlocked: true,
        size: 80
    )
}

#Preview("Badge - Locked") {
    AchievementBadgeView(
        achievement: AchievementService.allAchievements[0],
        isUnlocked: false,
        size: 80
    )
}

#Preview("Grid") {
    ScrollView {
        AchievementGridView()
            .padding()
    }
}
