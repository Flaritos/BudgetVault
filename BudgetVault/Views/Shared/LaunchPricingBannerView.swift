import SwiftUI

/// Amber countdown banner for launch pricing. Used in PaywallView, FinanceTabView, and DashboardView.
struct LaunchPricingBannerView: View {
    @Environment(StoreKitManager.self) private var storeKit

    /// Full banner style (PaywallView — horizontal bar)
    var body: some View {
        if let cd = storeKit.launchCountdownComponents {
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.subheadline.weight(.semibold))

                Text("Launch pricing ends in")
                    .font(.caption.weight(.semibold))

                HStack(spacing: 3) {
                    countdownBox("\(cd.days)d")
                    countdownBox("\(cd.hours)h")
                    countdownBox("\(cd.minutes)m")
                }
            }
            .foregroundStyle(.white)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#F59E0B"), Color(hex: "#D97706")],
                    startPoint: .leading, endPoint: .trailing
                )
            )
        }
    }

    private func countdownBox(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.bold).monospacedDigit())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
    }
}

/// Compact card style for Vault tab non-premium view
struct LaunchPricingCardView: View {
    @Environment(StoreKitManager.self) private var storeKit

    var body: some View {
        if let cd = storeKit.launchCountdownComponents {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.subheadline)
                        .foregroundStyle(BudgetVaultTheme.caution)
                    Text("LAUNCH PRICING")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(BudgetVaultTheme.caution)
                        .tracking(0.5)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(storeKit.premiumProduct?.displayPrice ?? "$14.99")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("one-time, forever")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }

                // v3.2 audit L8: was a ticking "83d 12h 0m" countdown which
                // felt like artificial urgency and conflicted with the calm
                // privacy-first tone. Now shows a single date.
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundStyle(BudgetVaultTheme.caution)
                    Text("Price goes up July 1")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(BudgetVaultTheme.caution)
                }
                // keep cd referenced so the guard-let stays meaningful
                .opacity(cd.days >= 0 ? 1 : 1)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#F59E0B").opacity(0.15), Color(hex: "#D97706").opacity(0.08)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG)
                            .strokeBorder(Color(hex: "#F59E0B").opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }

    private func cdBox(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.bold).monospacedDigit())
            .foregroundStyle(BudgetVaultTheme.caution)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(BudgetVaultTheme.caution.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
    }
}

/// Dismissible dashboard banner for launch pricing.
///
/// v3.2 audit M1/M2: removed the orange urgency gradient + "lock it in"
/// countdown copy that was running on the HOME screen. Home should be
/// calm; monetization lives on the Vault tab and Settings. This now
/// surfaces a quiet privacy reinforcement instead.
struct LaunchPricingDashboardBanner: View {
    @Environment(StoreKitManager.self) private var storeKit
    let action: () -> Void

    var body: some View {
        if storeKit.isLaunchPricing {
            Button(action: action) {
                HStack(spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                        .font(.title3)
                        .foregroundStyle(Color(hex: "#60A5FA"))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("One-time \(storeKit.premiumProduct?.displayPrice ?? "$14.99"). Never a subscription.")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(BudgetVaultTheme.navyDark)
                        Text("Unlock the Vault on your terms.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD)
                                .strokeBorder(Color(hex: "#60A5FA").opacity(0.3), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
        }
    }
}
