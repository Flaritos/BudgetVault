import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreKitManager.self) private var storeKit

    @ScaledMetric(relativeTo: .body) private var featureIconSize: CGFloat = 36

    private let features: [(icon: String, title: String, detail: String)] = [
        ("brain.head.profile", "Smart Insights", "Predictions, anomaly detection & spending patterns"),
        ("square.grid.2x2", "Unlimited Categories", "Organize with unlimited categories"),
        ("repeat", "Unlimited Recurring", "Automate all your bills"),
        ("doc.text", "Full CSV Import/Export", "Full history export & import"),
        ("chart.xyaxis.line", "Historical Charts", "Month comparisons & smart insights"),
        ("flame", "Streak Freeze", "Protect your streak once a week"),
    ]

    private var daysRemaining: Int {
        let now = Date()
        let end = StoreKitManager.launchPricingEndDate
        let components = Calendar.current.dateComponents([.day], from: now, to: end)
        return max(components.day ?? 0, 0)
    }

    private var displayPrice: String? {
        storeKit.premiumProduct?.displayPrice
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

                        if storeKit.isLaunchPricing, let price = displayPrice {
                            VStack(spacing: 4) {
                                Text("Launch Special: \(price) — limited time")
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
                            .foregroundStyle(BudgetVaultTheme.positive)
                        Text("One-time purchase — no subscription")
                            .font(.caption.bold())
                            .foregroundStyle(BudgetVaultTheme.positive)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(BudgetVaultTheme.positive.opacity(0.12), in: Capsule())

                    // Feature list
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(features, id: \.title) { feature in
                            HStack(spacing: 12) {
                                Image(systemName: feature.icon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white)
                                    .frame(width: featureIconSize, height: featureIconSize)
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
                    if let price = displayPrice {
                        VStack(spacing: 4) {
                            Text(price)
                                .font(BudgetVaultTheme.priceDisplay)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                                .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                            Text("one-time purchase")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Pay once, use forever")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)
                    }

                    // Product load error (Bug 5)
                    if let loadError = storeKit.productLoadError, storeKit.premiumProduct == nil {
                        VStack(spacing: 12) {
                            Text(loadError)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Try Again") {
                                storeKit.retryLoadProducts()
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }
                        .padding(.horizontal, 32)
                    } else if storeKit.premiumProduct == nil {
                        // Products still loading (Bug 8)
                        ProgressView("Loading products...")
                            .padding(.vertical, 8)
                    } else {
                        // Purchase button
                        purchaseButton
                            .padding(.horizontal, 32)
                    }

                    // Restore
                    Button("Restore Purchases") {
                        Task { await storeKit.restorePurchases() }
                    }
                    .font(.subheadline)

                    // Footers
                    VStack(spacing: 4) {
                        Text("Family Sharing included — one purchase covers your whole family.")
                        Text("No subscription. No recurring charges. Ever.")
                        Text("All data stays on your device. Always.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                    HStack(spacing: 16) {
                        Link("Privacy Policy", destination: URL(string: "https://budgetvault.io/privacy")!)
                        Link("Terms of Service", destination: URL(string: "https://budgetvault.io/terms")!)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
            .alert("Purchase Pending", isPresented: .init(
                get: { storeKit.showPendingAlert },
                set: { if !$0 { storeKit.showPendingAlert = false } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your purchase is pending approval. You'll get access once it's approved.")
            }
            .onChange(of: storeKit.purchaseState) { _, newState in
                if newState == .success {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    Task {
                        try? await Task.sleep(for: .seconds(2))
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
                    Text("Unlock Premium\(displayPrice.map { " for \($0)" } ?? "")")
                        .font(.headline)
                case .loading:
                    ProgressView()
                        .tint(.white)
                case .success:
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28))
                        Text("Vault Unlocked!")
                            .font(.subheadline.bold())
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle(isEnabled: storeKit.purchaseState != .loading && storeKit.purchaseState != .success))
        .disabled(storeKit.purchaseState == .loading || storeKit.purchaseState == .success)
    }
}
