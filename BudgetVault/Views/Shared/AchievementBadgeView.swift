import SwiftUI

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
                // Background circle
                Circle()
                    .fill(isUnlocked ? tierColor.opacity(0.15) : Color(.systemGray5))
                    .frame(width: size, height: size)

                // Border ring
                Circle()
                    .strokeBorder(
                        isUnlocked ? tierGradient : LinearGradient(colors: [.gray.opacity(0.3)], startPoint: .top, endPoint: .bottom),
                        lineWidth: size * 0.05
                    )
                    .frame(width: size, height: size)

                if isUnlocked {
                    // Emoji
                    Text(achievement.emoji)
                        .font(.system(size: size * 0.4))
                } else {
                    // Lock overlay
                    Image(systemName: "lock.fill")
                        .font(.system(size: size * 0.25))
                        .foregroundStyle(.secondary)
                }
            }
            .shadow(color: isUnlocked ? tierColor.opacity(0.3) : .clear, radius: 4, y: 2)

            // Title
            Text(achievement.title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(isUnlocked ? .primary : .secondary)
                .lineLimit(1)
                .frame(width: size + 10)
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

            Text(achievement.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: BudgetVaultTheme.spacingXS) {
                Image(systemName: "star.fill")
                    .foregroundStyle(tierColor)
                Text(achievement.tier.rawValue.capitalized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tierColor)
            }

            if isUnlocked, let date = achievement.unlockedDate {
                Text("Unlocked \(date, style: .date)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if !isUnlocked {
                Text("Not yet unlocked")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(BudgetVaultTheme.spacingLG)
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
        VStack(alignment: .leading, spacing: BudgetVaultTheme.spacingLG) {
            // Header
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(BudgetVaultTheme.badgeGold)
                Text("Achievements")
                    .font(.headline)
                Spacer()
                Text("\(unlocked.count)/\(AchievementService.allAchievements.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Progress bar
            GeometryReader { geo in
                let progress = AchievementService.allAchievements.isEmpty
                    ? 0.0
                    : Double(unlocked.count) / Double(AchievementService.allAchievements.count)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [BudgetVaultTheme.badgeGold, BudgetVaultTheme.badgeGoldDark],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Achievement progress: \(unlocked.count) of \(AchievementService.allAchievements.count) unlocked")

            // Grid
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

                // Premium overlay for free users
                if !isPremium {
                    RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            VStack(spacing: BudgetVaultTheme.spacingMD) {
                                Image(systemName: "lock.fill")
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                                Text("Upgrade to Premium")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text("Unlock achievement tracking and badges")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                        }
                }
            }
        }
        .padding(BudgetVaultTheme.spacingLG)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
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
