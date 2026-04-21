import SwiftUI
import BudgetVaultShared

/// A 1080×1920 share card used to export the monthly Wrapped to Instagram
/// Stories, TikTok, and other social platforms. Brand colors are LOCKED —
/// the card ignores the user's accentColor to keep the viral surface on-brand.
///
/// Five variants render different narrative beats from the user's month:
/// - `.savedHero`: hero savings ring + brag stat
/// - `.topCategory`: big emoji + top category name + amount
/// - `.personality`: spending personality with gradient name treatment
/// - `.byTheNumbers`: four hard numbers (transactions, avg daily, zero days, streak)
/// - `.finalCTA`: headline savings + three badge stats (privacy-first closer)
struct MonthlyWrappedShareCard: View {
    enum Variant: String, CaseIterable {
        case savedHero, topCategory, personality, byTheNumbers, finalCTA
    }

    let variant: Variant
    let monthName: String
    let monthYear: String
    let savedCents: Int64
    let savedPercent: Double
    let spentPercent: Double
    let totalIncomeCents: Int64
    let totalSpentCents: Int64
    let topCategoryName: String
    let topCategoryEmoji: String
    let topCategoryCents: Int64
    let topCategoryPercent: Double
    let transactionCount: Int
    let avgDailyCents: Int64
    let zeroSpendDays: Int
    let streakDays: Int
    let personalityName: String
    let personalityEmoji: String
    let bragStat: String

    // Brand-locked colors. These mirror BudgetVaultTheme tokens but are
    // declared inline so the share card never drifts when the theme evolves
    // and never picks up user accent overrides.
    private let navyDark = Color(hex: "#0F1B33")
    private let navyMid = Color(hex: "#1A2A4A")
    private let neonGreen = Color(hex: "#00FF9D")
    private let neonPurple = Color(hex: "#8E2DE2")

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [navyDark, navyMid, navyDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 0) {
                watermark
                    .padding(.top, 80)
                    .padding(.leading, 80)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
                content
                Spacer(minLength: 0)
                footer
                    .padding(.bottom, 100)
                    .padding(.horizontal, 80)
            }
        }
        .frame(width: 1080, height: 1920)
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Watermark / Footer

    private var watermark: some View {
        HStack(spacing: 16) {
            VaultDial(size: .icon, state: .locked, tint: .white)
                .frame(width: 60, height: 60)
            Text("BUDGETVAULT")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .tracking(4)
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    private var footer: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text("budgetvault.io")
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text("$14.99 once. No bank login. Ever.")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            VStack(spacing: 8) {
                Image(uiImage: QRCodeGenerator.image(for: "https://budgetvault.io", size: 160))
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 160, height: 160)
                    .padding(12)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
                Text("Scan to install")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Variant dispatch

    @ViewBuilder
    private var content: some View {
        switch variant {
        case .savedHero: savedHeroContent
        case .topCategory: topCategoryContent
        case .personality: personalityContent
        case .byTheNumbers: byTheNumbersContent
        case .finalCTA: finalCTAContent
        }
    }

    // MARK: - Variant: Saved Hero

    private var savedHeroContent: some View {
        VStack(spacing: 56) {
            Text("YOUR \(monthName) STORY")
                .font(.system(size: 28, weight: .bold))
                .tracking(8)
                .foregroundStyle(.white.opacity(0.7))

            ZStack {
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 36)
                    .frame(width: 560, height: 560)
                Circle()
                    .trim(from: 0, to: max(min(savedPercent / 100.0, 1.0), 0.001))
                    .stroke(neonGreen, style: StrokeStyle(lineWidth: 36, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 560, height: 560)
                    .shadow(color: neonGreen.opacity(0.5), radius: 24)
                VStack(spacing: 12) {
                    Text("SAVED")
                        .font(.system(size: 26, weight: .semibold))
                        .tracking(6)
                        .foregroundStyle(.white.opacity(0.7))
                    Text(CurrencyFormatter.format(cents: savedCents))
                        .font(.system(size: 110, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .padding(.horizontal, 40)
                    Text(String(format: "%.0f%% of income", savedPercent))
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundStyle(neonGreen)
                }
            }

            Text(bragStat)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 40)
                .padding(.vertical, 14)
                .background(.white.opacity(0.10), in: Capsule())
        }
        .padding(.horizontal, 80)
    }

    // MARK: - Variant: Top Category

    private var topCategoryContent: some View {
        VStack(spacing: 48) {
            Text("WHERE IT WENT")
                .font(.system(size: 28, weight: .bold))
                .tracking(8)
                .foregroundStyle(.white.opacity(0.7))
            Text(topCategoryEmoji).font(.system(size: 240))
            Text(topCategoryName)
                .font(.system(size: 96, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .lineLimit(2)
                .padding(.horizontal, 80)
            Text(CurrencyFormatter.format(cents: topCategoryCents))
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(neonPurple)
            Text(String(format: "%.0f%% of total spend", topCategoryPercent))
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 80)
    }

    // MARK: - Variant: Personality

    private var personalityContent: some View {
        VStack(spacing: 48) {
            Text("YOUR SPENDING TYPE")
                .font(.system(size: 28, weight: .bold))
                .tracking(8)
                .foregroundStyle(.white.opacity(0.7))
            Text(personalityEmoji)
                .font(.system(size: 280))
                .shadow(color: neonPurple.opacity(0.5), radius: 32)
            Text(personalityName)
                .font(.system(size: 88, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [neonGreen, neonPurple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .lineLimit(2)
                .padding(.horizontal, 40)
            Text(bragStat)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 40)
                .padding(.vertical, 14)
                .background(.white.opacity(0.10), in: Capsule())
        }
        .padding(.horizontal, 80)
    }

    // MARK: - Variant: By The Numbers

    private var byTheNumbersContent: some View {
        VStack(spacing: 56) {
            Text("BY THE NUMBERS")
                .font(.system(size: 28, weight: .bold))
                .tracking(8)
                .foregroundStyle(.white.opacity(0.7))
            VStack(spacing: 40) {
                numberRow(value: "\(transactionCount)", label: "transactions logged")
                numberRow(value: CurrencyFormatter.format(cents: avgDailyCents), label: "average daily spend")
                numberRow(value: "\(zeroSpendDays)", label: "zero-spend days")
                numberRow(value: "\(streakDays)", label: "day streak")
            }
            .padding(.horizontal, 60)
        }
        .padding(.horizontal, 80)
    }

    private func numberRow(value: String, label: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(value)
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 380, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.leading, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Variant: Final CTA

    private var finalCTAContent: some View {
        VStack(spacing: 56) {
            Text(monthYear.uppercased())
                .font(.system(size: 28, weight: .bold))
                .tracking(8)
                .foregroundStyle(.white.opacity(0.7))
            Text(CurrencyFormatter.format(cents: savedCents))
                .font(.system(size: 140, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .padding(.horizontal, 40)
            Text("saved this month")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            VStack(spacing: 16) {
                badgeStat(value: personalityName, label: "personality", color: neonPurple)
                badgeStat(value: bragStat, label: "this month", color: neonGreen)
                badgeStat(value: "Privacy-first", label: "no bank login", color: .white)
            }
            .padding(.horizontal, 80)
        }
        .padding(.horizontal, 80)
    }

    private func badgeStat(value: String, label: String, color: Color) -> some View {
        HStack {
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Spacer()
            Text(label)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 22)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Previews

#Preview("Saved Hero") {
    MonthlyWrappedShareCard(
        variant: .savedHero,
        monthName: "MARCH",
        monthYear: "March 2026",
        savedCents: 75_000,
        savedPercent: 32,
        spentPercent: 68,
        totalIncomeCents: 500_000,
        totalSpentCents: 425_000,
        topCategoryName: "Groceries",
        topCategoryEmoji: "\u{1F37D}\u{FE0F}",
        topCategoryCents: 120_000,
        topCategoryPercent: 28,
        transactionCount: 182,
        avgDailyCents: 13_700,
        zeroSpendDays: 12,
        streakDays: 47,
        personalityName: "Smart Saver",
        personalityEmoji: "\u{1F48E}",
        bragStat: "47-day streak"
    )
    .scaleEffect(0.25)
}

#Preview("Final CTA") {
    MonthlyWrappedShareCard(
        variant: .finalCTA,
        monthName: "MARCH",
        monthYear: "March 2026",
        savedCents: 75_000,
        savedPercent: 32,
        spentPercent: 68,
        totalIncomeCents: 500_000,
        totalSpentCents: 425_000,
        topCategoryName: "Groceries",
        topCategoryEmoji: "\u{1F37D}\u{FE0F}",
        topCategoryCents: 120_000,
        topCategoryPercent: 28,
        transactionCount: 182,
        avgDailyCents: 13_700,
        zeroSpendDays: 12,
        streakDays: 47,
        personalityName: "Smart Saver",
        personalityEmoji: "\u{1F48E}",
        bragStat: "47-day streak"
    )
    .scaleEffect(0.25)
}
