import SwiftUI

/// Compact card style for Vault tab non-premium view.
///
/// Round 5 audit N2: was an orange urgency card with "Price goes up
/// July 1" warning. Now a calm electric-blue card matching the home
/// banner. Strips all caution-color language.
///
/// Phase 9 §9.1: file renamed from `LaunchPricingBannerView.swift` to
/// match the single surviving struct. The old `LaunchPricingBannerView`
/// (EmptyView stub) and `LaunchPricingDashboardBanner` (dead code only
/// referenced in a DashboardView comment) have been deleted.
struct LaunchPricingCardView: View {
    @Environment(StoreKitManager.self) private var storeKit

    var body: some View {
        if storeKit.isLaunchPricing {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .font(.subheadline)
                        .foregroundStyle(BudgetVaultTheme.accentSoft)
                    Text("ONE-TIME PRICE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(BudgetVaultTheme.accentSoft)
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
                            .strokeBorder(BudgetVaultTheme.accentSoft.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}
