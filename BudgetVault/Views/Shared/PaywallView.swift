import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var storeKit = StoreKitManager()

    private let features: [(icon: String, title: String, detail: String)] = [
        ("brain.head.profile", "AI Insights", "Smart spending analysis"),
        ("square.grid.2x2", "Unlimited Categories", "vs 6 free"),
        ("repeat", "Unlimited Recurring", "vs 3 free"),
        ("doc.text", "Full CSV Import/Export", "Full history"),
        ("app.badge", "Custom App Icons", "3 alternatives"),
        ("chart.xyaxis.line", "Historical Charts", "Compare months"),
        ("flame", "Streak Freeze", "1 per week"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // App icon
                    Image(systemName: "vault.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.accentColor)
                        .padding(.top, 24)

                    Text("Unlock BudgetVault Premium")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    // Launch pricing banner
                    if storeKit.isLaunchPricing {
                        Text("Launch Special: \(storeKit.premiumProduct?.displayPrice ?? "$9.99") — limited time")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.orange, in: Capsule())
                    }

                    // Feature list
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(features, id: \.title) { feature in
                            HStack(spacing: 12) {
                                Image(systemName: feature.icon)
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 28)
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
                        Text(storeKit.premiumProduct?.displayPrice ?? "$19.99")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
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
                    Text("Purchase")
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
            .padding()
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.white)
        }
        .disabled(storeKit.purchaseState == .loading || storeKit.purchaseState == .success)
    }
}
