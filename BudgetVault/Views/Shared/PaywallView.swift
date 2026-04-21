import SwiftUI
import StoreKit

/// Paywall — VaultRevamp v2.1 Phase 8.3 §4.
///
/// Two states on a single dial-centered layout:
/// - Ready: locked `.hero` VaultDial above a price chamber, four
///   titanium bolt-head feature rows, and an "Unlock · $14.99" CTA.
/// - Success: open `.hero` VaultDial with positive-green glow, "The
///   vault is open." line, green purchase-complete chip, and a single
///   "Enter the vault" CTA.
///
/// The dial + chamber language is the shared ritual with Onboarding's
/// Vault-Opens screen — by the time a user reaches the paywall they've
/// seen this visual before, and the success state closes the metaphor.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreKitManager.self) private var storeKit
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dialFaceRotation: Double = 0
    @State private var chipVisible: Bool = false

    private var isSuccess: Bool {
        storeKit.purchaseState == .success
    }

    private var displayPrice: String? {
        storeKit.premiumProduct?.displayPrice
    }

    private var priceDecimal: Decimal {
        // Audit fix: `Decimal(14.99)` init-from-Double stores
        // 14.9899999… due to binary float rounding. Use string or
        // integer construction so the fallback is exact.
        storeKit.premiumProduct?.price ?? (Decimal(string: "14.99") ?? 0)
    }

    private var currencyCode: String {
        storeKit.premiumProduct?.priceFormatStyle.currencyCode ?? "USD"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Radial chamber backdrop. In success state the radial
                // shifts from titanium→navy to navy→positive-green so
                // the open dial sits in a "lit" chamber.
                RadialGradient(
                    colors: isSuccess
                        ? [BudgetVaultTheme.navyDark, BudgetVaultTheme.navyAbyss]
                        : [BudgetVaultTheme.navyMid, BudgetVaultTheme.navyAbyss],
                    center: .top,
                    startRadius: 0,
                    endRadius: 500
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: BudgetVaultTheme.spacingXL) {
                        heroDial
                            .padding(.top, BudgetVaultTheme.spacingHero)

                        titleBlock

                        if isSuccess {
                            purchaseCompleteChip
                                .opacity(chipVisible ? 1 : 0)
                                .scaleEffect(chipVisible ? 1 : 0.9)
                        } else {
                            priceChamber
                            featureList
                        }

                        ctaStack
                            .padding(.horizontal, BudgetVaultTheme.spacingXL)

                        if !isSuccess {
                            trustRow
                        }
                    }
                    .padding(.bottom, BudgetVaultTheme.spacingXL)
                    .frame(maxWidth: .infinity)
                }
            }
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
                            .foregroundStyle(.white.opacity(0.75), .white.opacity(0.12))
                            // Audit fix: bare toolbar image ≈ 22pt —
                            // fails WCAG 2.5.5 44×44 minimum. Expand
                            // hit area without enlarging the glyph.
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
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
                    HapticManager.notification(.success)
                    runSuccessAnimation()
                }
            }
            .onAppear {
                LocalMetricsService.increment(.paywallViews)
            }
        }
    }

    // MARK: - Hero Dial

    @ViewBuilder
    private var heroDial: some View {
        // Phase 8.3 §4.2: Ready state uses the locked .hero dial; Success
        // swaps to .open with positive-green halo and a 72° face rotation.
        // Reduce Motion skips the rotation and the scale swell.
        //
        // Audit fix: the dial is decorative — the title block carries
        // the meaning. Hide from VoiceOver so screen reader users don't
        // hear the dial's internal asset names before the actual copy.
        ZStack {
            if isSuccess {
                VaultDial(
                    size: .hero,
                    state: .open,
                    showGlow: true,
                    faceRotationDegrees: dialFaceRotation
                )
                .shadow(color: BudgetVaultTheme.positive.opacity(0.35), radius: 40)
                .shadow(color: .black.opacity(0.6), radius: 20, y: 20)
                .transition(.opacity)
            } else {
                VaultDial(size: .hero, state: .locked)
                    .shadow(color: BudgetVaultTheme.accentSoft.opacity(0.25), radius: 40)
                    .shadow(color: .black.opacity(0.6), radius: 20, y: 20)
                    .transition(.opacity)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Title Block

    @ViewBuilder
    private var titleBlock: some View {
        VStack(spacing: BudgetVaultTheme.spacingSM) {
            if isSuccess {
                Text("The vault is open.")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Every premium feature is yours. Nothing expires.")
                    .font(.subheadline)
                    .foregroundStyle(BudgetVaultTheme.titanium300)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, BudgetVaultTheme.spacingXL)
            } else {
                Text("Unlock the full vault.")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("One purchase. Everything in. Nothing ever renews.")
                    .font(.subheadline)
                    .foregroundStyle(BudgetVaultTheme.titanium300)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, BudgetVaultTheme.spacingXL)
            }
        }
    }

    // MARK: - Price Chamber (Ready)

    @ViewBuilder
    private var priceChamber: some View {
        ChamberCard(padding: 20) {
            VStack(spacing: 10) {
                Text("ONE-TIME PRICE")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.8)
                    .foregroundStyle(BudgetVaultTheme.titanium400)

                FlipDigitDisplay(
                    amount: priceDecimal,
                    style: .large,
                    currencyCode: currencyCode,
                    contextLabel: "Price"
                )

                Text("No subscription \u{00B7} No renewals")
                    .font(.system(size: 12))
                    .foregroundStyle(BudgetVaultTheme.titanium400)
                    .tracking(0.5)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: 320)
        .padding(.horizontal, BudgetVaultTheme.spacingXL)
    }

    // MARK: - Feature List (Ready)

    @ViewBuilder
    private var featureList: some View {
        // Phase 8.3 §4.4: titanium bolt-head checkmarks, not green. The
        // visual ties back to the onboarding Pledge screen — "earned
        // and sealed," not "task complete."
        let features: [(String, String)] = [
            ("Full history & export", "Unlimited CSV import and export"),
            ("Debt tracker", "Snowball and avalanche payoff projection"),
            ("Monthly Wrapped", "Your month in a shareable recap"),
            ("Budget templates", "Save and reuse setups across months")
        ]

        VStack(spacing: 0) {
            ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                featureRow(title: feature.0, subtitle: feature.1, isLast: index == features.count - 1)
            }
        }
        .frame(maxWidth: 320)
        .padding(.horizontal, BudgetVaultTheme.spacingXL)
    }

    @ViewBuilder
    private func featureRow(title: String, subtitle: String, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            boltHeadCheck
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(BudgetVaultTheme.titanium400)
            }

            Spacer()
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(BudgetVaultTheme.titanium700.opacity(0.4))
                    .frame(height: 1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Titanium bolt-head with checkmark — the "earned/sealed" glyph.
    @ViewBuilder
    private var boltHeadCheck: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            BudgetVaultTheme.titanium200,
                            BudgetVaultTheme.titanium400,
                            BudgetVaultTheme.titanium700
                        ],
                        center: UnitPoint(x: 0.35, y: 0.30),
                        startRadius: 0,
                        endRadius: 12
                    )
                )
                .overlay(
                    Circle()
                        .strokeBorder(BudgetVaultTheme.titanium800, lineWidth: 1)
                )
                .frame(width: 22, height: 22)

            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(BudgetVaultTheme.titanium800)
        }
    }

    // MARK: - Purchase Complete Chip (Success)

    @ViewBuilder
    private var purchaseCompleteChip: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(BudgetVaultTheme.positive)
            Text("Purchase complete")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BudgetVaultTheme.positive)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(BudgetVaultTheme.positive.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(BudgetVaultTheme.positive.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityLabel("Purchase complete")
    }

    // MARK: - CTA Stack

    @ViewBuilder
    private var ctaStack: some View {
        if isSuccess {
            Button {
                dismiss()
            } label: {
                Text("Enter the vault")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(17)
            }
            .background(
                LinearGradient(
                    colors: [BudgetVaultTheme.brightBlue, BudgetVaultTheme.electricBlue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: BudgetVaultTheme.electricBlue.opacity(0.45), radius: 14, y: 4)
            .accessibilityLabel("Enter the vault")
        } else if let loadError = storeKit.productLoadError, storeKit.premiumProduct == nil {
            VStack(spacing: BudgetVaultTheme.spacingMD) {
                Text(loadError)
                    .font(.subheadline)
                    .foregroundStyle(BudgetVaultTheme.titanium300)
                    .multilineTextAlignment(.center)
                Button("Try Again") {
                    storeKit.retryLoadProducts()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        } else if storeKit.premiumProduct == nil {
            ProgressView()
                .tint(BudgetVaultTheme.accentSoft)
                .padding(.vertical, 8)
        } else {
            VStack(spacing: 4) {
                purchasePrimaryButton

                Button {
                    Task { await storeKit.restorePurchases() }
                } label: {
                    Text("Restore Purchases")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(BudgetVaultTheme.titanium400)
                        .padding(12)
                }
            }
        }
    }

    @ViewBuilder
    private var purchasePrimaryButton: some View {
        Button {
            if let product = storeKit.premiumProduct {
                Task { await storeKit.purchase(product) }
            }
        } label: {
            Group {
                switch storeKit.purchaseState {
                case .loading:
                    ProgressView()
                        .tint(.white)
                case .success:
                    // Should not render — success state swaps to
                    // "Enter the vault" CTA above. Belt-and-suspenders.
                    Text("The vault is open.")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                default:
                    Text("Unlock \u{00B7} \(displayPrice ?? "$14.99")")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(17)
        }
        .background(
            LinearGradient(
                colors: [BudgetVaultTheme.brightBlue, BudgetVaultTheme.electricBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: BudgetVaultTheme.electricBlue.opacity(0.45), radius: 14, y: 4)
        .disabled(storeKit.purchaseState == .loading || storeKit.purchaseState == .success)
        .accessibilityLabel("Unlock the vault for \(displayPrice ?? "14 dollars and 99 cents")")
    }

    // MARK: - Trust Row (Ready)

    @ViewBuilder
    private var trustRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 11))
            Text("No subscription. Cancel nothing. Yours forever.")
                .font(.system(size: 11))
        }
        .foregroundStyle(BudgetVaultTheme.titanium400)
        .tracking(0.4)
        .padding(.top, 4)
        .accessibilityLabel("No subscription. Cancel nothing. Yours forever.")
    }

    // MARK: - Success Animation

    private func runSuccessAnimation() {
        guard !reduceMotion else {
            dialFaceRotation = 72
            chipVisible = true
            return
        }

        withAnimation(.easeOut(duration: 0.9)) {
            dialFaceRotation = 72
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.5)) {
            chipVisible = true
        }
    }
}
