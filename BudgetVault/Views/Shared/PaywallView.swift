import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreKitManager.self) private var storeKit

    private let features: [(icon: String, title: String, detail: String)] = [
        ("brain.head.profile", "AI Insights", "Smart spending analysis"),
        ("square.grid.2x2", "Unlimited Categories", "vs 4 free"),
        ("repeat", "Unlimited Recurring", "vs 3 free"),
        ("doc.text", "Full CSV Import/Export", "Full history"),
        ("app.badge", "Custom App Icons", "3 alternatives"),
        ("chart.xyaxis.line", "Historical Charts", "Compare months"),
        ("flame", "Streak Freeze", "1 per week"),
    ]

    private var daysRemaining: Int {
        let now = Date()
        let end = StoreKitManager.launchPricingEndDate
        let components = Calendar.current.dateComponents([.day], from: now, to: end)
        return max(components.day ?? 0, 0)
    }

    private var displayPrice: String {
        storeKit.premiumProduct?.displayPrice ?? (storeKit.isLaunchPricing ? "$9.99" : "$19.99")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Hero header
                    VStack(spacing: 12) {
                        VaultDialMark(size: 72)
                            .padding(.top, 32)

                        Text("Unlock BudgetVault Premium")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        if storeKit.isLaunchPricing {
                            VStack(spacing: 4) {
                                Text("Launch Special: \(displayPrice) — limited time")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                                Text("\(daysRemaining) days left at this price")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.white.opacity(0.2), in: Capsule())
                        }
                    }
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity)
                    .background(BudgetVaultTheme.brandGradient)

                    // Save vs subscriptions callout
                    HStack(spacing: 6) {
                        Image(systemName: "tag.fill")
                            .foregroundStyle(.green)
                        Text("Save $80+/year vs subscriptions")
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.12), in: Capsule())

                    // Feature list
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(features, id: \.title) { feature in
                            HStack(spacing: 12) {
                                Image(systemName: feature.icon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Color.accentColor, in: Circle())
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(feature.title)
                                        .font(.subheadline.bold())
                                    Text(feature.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 32)

                    // Price
                    VStack(spacing: 4) {
                        HStack(spacing: 8) {
                            if storeKit.isLaunchPricing {
                                Text("$19.99")
                                    .font(.system(size: 20, weight: .medium, design: .rounded))
                                    .strikethrough()
                                    .foregroundStyle(.secondary)
                            }
                            Text(displayPrice)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                        }
                        Text("one-time purchase")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Compare to leading budget apps at $99/year")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    // Purchase button
                    purchaseButton
                        .padding(.horizontal, 32)

                    // Restore
                    Button("Restore Purchases") {
                        Task { await storeKit.restorePurchases() }
                    }
                    .font(.subheadline)

                    // Footers
                    VStack(spacing: 4) {
                        Text("Family Sharing included — one purchase covers your whole family.")
                        Text("No subscription. No recurring charges. Ever.")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Purchase Error", isPresented: .init(
                get: { storeKit.purchaseState == .error },
                set: { if !$0 { storeKit.purchaseState = .idle } }
            )) {
                Button("Retry") {
                    if let product = storeKit.premiumProduct {
                        Task { await storeKit.purchase(product) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(storeKit.errorMessage ?? "Something went wrong.")
            }
            .onChange(of: storeKit.purchaseState) { _, newState in
                if newState == .success {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var purchaseButton: some View {
        Button {
            if let product = storeKit.premiumProduct {
                Task { await storeKit.purchase(product) }
            }
        } label: {
            Group {
                switch storeKit.purchaseState {
                case .idle, .error:
                    Text("Unlock Premium for \(displayPrice)")
                        .font(.headline)
                case .loading:
                    ProgressView()
                        .tint(.white)
                case .success:
                    Image(systemName: "checkmark")
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle(isEnabled: storeKit.purchaseState != .loading && storeKit.purchaseState != .success))
        .disabled(storeKit.purchaseState == .loading || storeKit.purchaseState == .success)
    }
}
