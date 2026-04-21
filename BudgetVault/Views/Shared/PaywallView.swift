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

                    // MARK: - Launch Pricing Countdown (removed Round 5 — now EmptyView)
                    LaunchPricingBannerView()

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
                                title: "Vault Patterns",
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
                            bonusRow(icon: "arrow.forward.circle", text: "Per-category rollover rules")
                            bonusRow(icon: "star.circle.fill", text: "Monthly Wrapped spending recap")
                            bonusRow(icon: "square.and.arrow.up", text: "Shareable insight cards")
                        }
                        .padding(.horizontal, BudgetVaultTheme.spacingXL)

                        // MARK: - Own-value statement
                        // v3.2 audit M4: removed the competitor shamefile
                        // (YNAB/Monarch/Copilot yearly pricing table).
                        // Confident brands state their own value; they don't
                        // name-and-shame competitors.
                        if let price = displayPrice {
                            VStack(spacing: BudgetVaultTheme.spacingXS) {
                                Text(price)
                                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                                    .foregroundStyle(.primary)
                                Text("Once. Yours forever.")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, BudgetVaultTheme.spacingLG)
                            .background(BudgetVaultTheme.chamberBackground, in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG))
                            .overlay(
                                RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG)
                                    .strokeBorder(BudgetVaultTheme.titanium700, lineWidth: 1)
                            )
                            .padding(.horizontal, BudgetVaultTheme.spacingLG)
                        }

                        // MARK: - Purchase Area
                        purchaseArea

                        // MARK: - Footer
                        // v3.2 audit M5: stated once, not 4×. Repetition reads insecure.
                        VStack(spacing: BudgetVaultTheme.spacingXS) {
                            Text("Family Sharing included. All data stays on your device.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, BudgetVaultTheme.spacingXL)

                        HStack(spacing: BudgetVaultTheme.spacingLG) {
                            Link("Privacy Policy", destination: URL(string: "https://budgetvault.io/privacy")!)
                            Link("Terms of Service", destination: URL(string: "https://budgetvault.io/terms")!)
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, BudgetVaultTheme.spacingXL)
                    }
                }
            }
            // v3.2 K8/H6: circular Close in top-right (not blue text next
            // to the blue CTA).
            // Round 8 RR4: toolbarBackground is now hidden so the navy
            // hero extends flush to the top of the sheet without a
            // white nav bar strip above it.
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        LocalMetricsService.increment(.paywallDismissals)
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.7), .white.opacity(0.15))
                    }
                    .accessibilityLabel("Close")
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
            .onAppear {
                LocalMetricsService.increment(.paywallViews)
            }
        }
    }

    // MARK: - Hero Section

    @ViewBuilder
    private var heroSection: some View {
        VStack(spacing: BudgetVaultTheme.spacingMD) {
            VaultDialMark(size: 72)
                .padding(.top, BudgetVaultTheme.spacingXL + BudgetVaultTheme.spacingLG)

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
        // Round 7: use a taller navy band that extends past the sheet
        // grabber area, eliminating the white gap above the hero.
        .background(
            LinearGradient(colors: [BudgetVaultTheme.navyDark.opacity(0.95), BudgetVaultTheme.navyDark, BudgetVaultTheme.navyMid], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .top)
        )
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

    // MARK: - Purchase Area

    @ViewBuilder
    private var purchaseArea: some View {
        // Product load error
        if let loadError = storeKit.productLoadError, storeKit.premiumProduct == nil {
            VStack(spacing: BudgetVaultTheme.spacingMD) {
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
                    // v3.2 audit M2: removed "Launch pricing — increases
                    // after July 1" countdown-style subtitle. Calm brands
                    // don't use ticking clocks as conversion pressure.
                    Text("Unlock the Vault\(displayPrice.map { " for \($0)" } ?? "")")
                        .font(.headline)
                case .loading:
                    ProgressView()
                        .tint(.white)
                case .success:
                    VStack(spacing: BudgetVaultTheme.spacingXS) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28))
                        Text("The vault is open.")
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
            VStack(spacing: BudgetVaultTheme.spacingXL) {
                Spacer()

                VaultDialMark(size: 80, showGlow: true)

                Text("Welcome to the Full Vault!")
                    .font(.title.bold())

                Text("You've unlocked every premium feature.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: BudgetVaultTheme.spacingMD) {
                    unlockRow(icon: "brain.head.profile", text: "Vault Patterns & predictions")
                    unlockRow(icon: "square.grid.2x2", text: "Unlimited categories")
                    unlockRow(icon: "repeat", text: "Unlimited recurring expenses")
                    unlockRow(icon: "chart.xyaxis.line", text: "Advanced reports & charts")
                    unlockRow(icon: "doc.text", text: "Full CSV import & export")
                    unlockRow(icon: "creditcard.fill", text: "Debt payoff tracker")
                    unlockRow(icon: "star.circle.fill", text: "Monthly Wrapped recap")
                }
                .padding(.horizontal, BudgetVaultTheme.spacingPage)

                Spacer()

                Button {
                    showWelcomePremium = false
                    dismiss()
                } label: {
                    Text("Start Exploring")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, BudgetVaultTheme.spacing2XL)
                .padding(.bottom, BudgetVaultTheme.spacingPage)
            }
        }
    }

    private func unlockRow(icon: String, text: String) -> some View {
        HStack(spacing: BudgetVaultTheme.spacingMD) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(BudgetVaultTheme.positive)
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
        .accessibilityElement(children: .combine)
    }
}
