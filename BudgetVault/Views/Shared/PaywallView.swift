import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreKitManager.self) private var storeKit
    @State private var showWelcomePremium = false

    @ScaledMetric(relativeTo: .body) private var heroIconSize: CGFloat = 44

    private var displayPrice: String? {
        storeKit.premiumProduct?.displayPrice
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // MARK: - Navy Gradient Hero
                    heroSection

                    // MARK: - Content on white/system background
                    VStack(spacing: BudgetVaultTheme.spacingXL) {
                        // One-time purchase badge
                        HStack(spacing: 6) {
                            Image(systemName: "tag.fill")
                                .foregroundStyle(BudgetVaultTheme.positive)
                            Text("One-time purchase \u{2014} no subscription")
                                .font(.caption.bold())
                                .foregroundStyle(BudgetVaultTheme.positive)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(BudgetVaultTheme.positive.opacity(0.12), in: Capsule())
                        .padding(.top, BudgetVaultTheme.spacingXL)

                        // MARK: - Hero Feature Cards
                        VStack(spacing: BudgetVaultTheme.spacingMD) {
                            heroFeatureCard(
                                icon: "brain.head.profile",
                                title: "Vault Intelligence",
                                description: "On-device AI predicts spending, spots anomalies, and finds patterns. Your data never leaves your phone."
                            )

                            heroFeatureCard(
                                icon: "square.grid.2x2",
                                title: "Unlimited Envelopes & Bills",
                                description: "Build the budget you actually need. No limits on categories or recurring expenses."
                            )

                            heroFeatureCard(
                                icon: "chart.xyaxis.line",
                                title: "Advanced Reports",
                                description: "Full CSV import/export, spending heatmaps, and category forecasts."
                            )
                        }
                        .padding(.horizontal, BudgetVaultTheme.spacingLG)

                        // MARK: - Bonus Features
                        VStack(alignment: .leading, spacing: BudgetVaultTheme.spacingMD) {
                            Text("Also included")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                            bonusRow(icon: "arrow.triangle.branch", text: "Debt payoff tracker (Snowball & Avalanche)")
                            bonusRow(icon: "star.circle.fill", text: "Monthly Wrapped spending recap")
                            bonusRow(icon: "square.and.arrow.up", text: "Shareable insight cards")
                        }
                        .padding(.horizontal, BudgetVaultTheme.spacingXL)

                        // MARK: - Competitor Comparison
                        VStack(spacing: 8) {
                            Text("Other apps charge yearly:")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            VStack(spacing: 4) {
                                competitorRow(name: "YNAB", price: "$109/year")
                                competitorRow(name: "Monarch", price: "$99/year")
                                competitorRow(name: "Copilot", price: "$70/year")
                            }

                            if let price = displayPrice {
                                HStack {
                                    Text("BudgetVault")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(BudgetVaultTheme.electricBlue)
                                    Spacer()
                                    Text("\(price) once. Forever.")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(BudgetVaultTheme.positive)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal, BudgetVaultTheme.spacingXL)
                        .padding(.vertical, BudgetVaultTheme.spacingMD)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD))
                        .padding(.horizontal, BudgetVaultTheme.spacingLG)

                        // MARK: - Purchase Area
                        purchaseArea

                        // MARK: - Footer
                        VStack(spacing: 4) {
                            Text("Family Sharing included \u{2014} one purchase covers your whole family.")
                            Text("No subscription. No recurring charges. Ever.")
                            Text("All data stays on your device. Always.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, BudgetVaultTheme.spacingXL)

                        HStack(spacing: 16) {
                            Link("Privacy Policy", destination: URL(string: "https://budgetvault.io/privacy")!)
                            Link("Terms of Service", destination: URL(string: "https://budgetvault.io/terms")!)
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, BudgetVaultTheme.spacingXL)
                    }
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
                    showWelcomePremium = true
                }
            }
            .sheet(isPresented: $showWelcomePremium) {
                postPurchaseWelcomeView
            }
        }
    }

    // MARK: - Hero Section

    @ViewBuilder
    private var heroSection: some View {
        VStack(spacing: BudgetVaultTheme.spacingMD) {
            VaultDialMark(size: 72)
                .padding(.top, BudgetVaultTheme.spacingXL)

            Text("Unlock the Full Vault")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("One-time purchase. Yours forever.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.bottom, BudgetVaultTheme.spacingXL)
        .frame(maxWidth: .infinity)
        .background(BudgetVaultTheme.brandGradient)
    }

    // MARK: - Hero Feature Card

    @ViewBuilder
    private func heroFeatureCard(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: BudgetVaultTheme.spacingMD) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: heroIconSize, height: heroIconSize)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(BudgetVaultTheme.spacingLG)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BudgetVaultTheme.cardBackground, in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Bonus Row

    @ViewBuilder
    private func bonusRow(icon: String, text: String) -> some View {
        HStack(spacing: BudgetVaultTheme.spacingSM) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(BudgetVaultTheme.positive)
                .font(.caption)
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)
            Text(text)
                .font(.caption)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Competitor Row

    private func competitorRow(name: String, price: String) -> some View {
        HStack {
            Text(name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(price)
                .font(.subheadline)
                .strikethrough()
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Purchase Area

    @ViewBuilder
    private var purchaseArea: some View {
        // Product load error
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
            .padding(.horizontal, BudgetVaultTheme.spacingXL)
        } else if storeKit.premiumProduct == nil {
            // Products still loading
            ProgressView("Loading products...")
                .padding(.vertical, 8)
        } else {
            // Purchase button
            purchaseButton
                .padding(.horizontal, BudgetVaultTheme.spacingXL)
        }

        // Restore
        Button("Restore Purchases") {
            Task { await storeKit.restorePurchases() }
        }
        .font(.subheadline)
    }

    // MARK: - Purchase Button

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
                    Text("Unlock the Vault\(displayPrice.map { " for \($0)" } ?? "")")
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

    // MARK: - Post-Purchase Welcome

    @ViewBuilder
    private var postPurchaseWelcomeView: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VaultDialMark(size: 80, showGlow: true)

                Text("Welcome to the Full Vault!")
                    .font(.title.bold())

                Text("You've unlocked every premium feature.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    unlockRow(icon: "brain.head.profile", text: "Vault Intelligence & predictions")
                    unlockRow(icon: "square.grid.2x2", text: "Unlimited categories")
                    unlockRow(icon: "repeat", text: "Unlimited recurring expenses")
                    unlockRow(icon: "chart.xyaxis.line", text: "Advanced reports & charts")
                    unlockRow(icon: "doc.text", text: "Full CSV import & export")
                    unlockRow(icon: "creditcard.fill", text: "Debt payoff tracker")
                    unlockRow(icon: "star.circle.fill", text: "Monthly Wrapped recap")
                }
                .padding(.horizontal, 40)

                Spacer()

                Button {
                    showWelcomePremium = false
                    dismiss()
                } label: {
                    Text("Start Exploring")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
    }

    private func unlockRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(BudgetVaultTheme.positive)
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}
