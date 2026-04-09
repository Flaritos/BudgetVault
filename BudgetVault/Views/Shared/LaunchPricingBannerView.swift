import SwiftUI

/// Round 5 audit N1: the old ticking countdown banner ("Launch pricing
/// ends in 83d 9h 44m") has been DELETED entirely. The brand no longer
/// uses live urgency timers — the paywall stands on its own value.
/// Callers that reference `LaunchPricingBannerView()` now get an empty
/// view so we don't have to chase every call site in this commit.
struct LaunchPricingBannerView: View {
    var body: some View {
        EmptyView()
    }
}

/// Compact card style for Vault tab non-premium view.
///
/// Round 5 audit N2: was an orange urgency card with "Price goes up
/// July 1" warning. Now a calm electric-blue card matching the home
/// banner. Strips all caution-color language.
struct LaunchPricingCardView: View {
    @Environment(StoreKitManager.self) private var storeKit

    var body: some View {
        if storeKit.isLaunchPricing {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: "#60A5FA"))
                    Text("ONE-TIME PRICE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: "#60A5FA"))
                        .tracking(0.5)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(storeKit.premiumProduct?.displayPrice ?? "$14.99")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("once. yours forever.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG)
                            .strokeBorder(Color(hex: "#60A5FA").opacity(0.3), lineWidth: 1)
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
