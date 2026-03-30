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
                    Text(storeKit.premiumProduct?.displayPrice ?? "$9.99")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("one-time, forever")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }

                HStack(spacing: 6) {
                    Text("Increases in")
                        .font(.caption2)
                        .foregroundStyle(BudgetVaultTheme.caution)

                    HStack(spacing: 3) {
                        cdBox("\(cd.days)d")
                        cdBox("\(cd.hours)h")
                        cdBox("\(cd.minutes)m")
                    }
                }
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

/// Dismissible dashboard banner for launch pricing
struct LaunchPricingDashboardBanner: View {
    @Environment(StoreKitManager.self) private var storeKit
    let action: () -> Void

    var body: some View {
        if storeKit.isLaunchPricing {
            Button(action: action) {
                HStack(spacing: 10) {
                    Image(systemName: "timer")
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch pricing: \(storeKit.premiumProduct?.displayPrice ?? "$9.99") forever")
                            .font(.subheadline.weight(.bold))
                        Text("Price increases July 1 — lock it in")
                            .font(.caption)
                            .opacity(0.85)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .opacity(0.6)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#F59E0B"), Color(hex: "#D97706")],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD)
                )
                .shadow(color: Color(hex: "#F59E0B").opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
        }
    }
}
