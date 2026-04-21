import SwiftUI
import SwiftData
import UserNotifications
import BudgetVaultShared

// MARK: - Onboarding State Machine (VaultRevamp Phase 3a)

/// Ordered steps in the VaultRevamp onboarding flow. Steps 0-3 are
/// pre-fork (Welcome, Pledge, Name Vault, Depth Fork) — see spec §7.1-7.4.
/// Steps 4-7 are the existing currency/income/envelopes/unlocked screens;
/// their bodies are unchanged in Phase 3a and will be restyled in 3b/3c.
///
/// At the Depth Fork (step 3) the user branches:
///   - Quick: auto-defaults applied, jump directly to step 7 (.unlocked)
///   - Thorough: continue linearly through 4 → 5 → 6 → 7
enum OnboardingStep: Int, CaseIterable {
    case welcome = 0       // NEW visuals (§7.1)
    case pledge = 1        // NEW screen (§7.2)
    case nameVault = 2     // NEW screen (§7.3)
    case depthFork = 3     // NEW screen (§7.4)
    case currency = 4      // EXISTING — restyle deferred to Phase 3b
    case income = 5        // EXISTING — restyle deferred to Phase 3b
    case envelopes = 6     // EXISTING — restyle deferred to Phase 3c
    case unlocked = 7      // EXISTING — becomes "Vault Opens" in Phase 3c

    /// BoltRow progress for header:
    /// - Steps 0-3 show 4-bolt row (pre-fork count)
    /// - Steps 4-7 show 7-bolt row (thorough path)
    var boltCount: Int {
        rawValue < 4 ? 4 : 7
    }

    var boltEngaged: Int {
        switch self {
        case .welcome: return 0
        case .pledge: return 1
        case .nameVault: return 2
        case .depthFork: return 3
        case .currency: return 4
        case .income: return 5
        case .envelopes: return 6
        case .unlocked: return 7
        }
    }
}

/// Which branch the user chose at the Depth Fork (step 3).
enum OnboardingPath { case quick, thorough }

// MARK: - Onboarding Vault Dial

/// A vault dial with a progress arc that fills as the user advances through onboarding steps.
private struct OnboardingVaultDial: View {
    let size: CGFloat
    let progress: Double // 0.0 to 1.0
    let stepNumber: Int?
    let stepLabel: String?
    let rotation: Double
    let showLock: Bool
    let showUnlock: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            VaultDialMark(size: size, showGlow: progress >= 1.0, tickRotation: rotation)
                .opacity(0.2 + progress * 0.1)

            // Track circle
            Circle()
                .stroke(.white.opacity(0.06), lineWidth: max(size * 0.04, 3))
                .frame(width: size * 0.82, height: size * 0.82)

            // Progress arc
            if progress > 0 {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        BudgetVaultTheme.accentSoft,
                        style: StrokeStyle(lineWidth: max(size * 0.04, 3), lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: size * 0.82, height: size * 0.82)
                    .shadow(color: BudgetVaultTheme.accentSoft.opacity(0.5), radius: 8)

                // Extra glow ring when fully unlocked
                if progress >= 1.0 {
                    Circle()
                        .trim(from: 0, to: 1.0)
                        .stroke(
                            BudgetVaultTheme.accentSoft,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: size * 0.82, height: size * 0.82)
                        .blur(radius: 8)
                }
            }

            // Center content
            VStack(spacing: 2) {
                if showLock {
                    Image(systemName: "lock.fill")
                        .font(.system(size: size * 0.12))
                        .foregroundStyle(.white.opacity(0.3))
                } else if showUnlock {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: size * 0.12))
                        .foregroundStyle(.white.opacity(0.5))
                } else if let stepNumber, let stepLabel {
                    Text("STEP \(stepNumber) OF 4")
                        .font(.system(size: max(size * 0.06, 8), weight: .bold))
                        .foregroundStyle(.white.opacity(0.25))
                        .tracking(1.5)
                    Text(stepLabel)
                        .font(.system(size: max(size * 0.09, 11), weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size * 1.4, height: size * 1.4)
        .animation(
            reduceMotion ? .none : .spring(duration: 0.8, bounce: 0.15),
            value: progress
        )
        .accessibilityHidden(true)
    }
}

// MARK: - Vault Unlocking Ceremony (ChatOnboardingView)

struct ChatOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage(AppStorageKeys.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @AppStorage(AppStorageKeys.selectedCurrency) private var selectedCurrency = "USD"
    @AppStorage(AppStorageKeys.resetDay) private var resetDay = 1
    @AppStorage(AppStorageKeys.dailyReminderEnabled) private var dailyReminderEnabled = false
    // Round 7 P4: biometric lock defaults ON for new users in a
    // privacy-first app. Users can opt out via the toggle before
    // tapping Start Budgeting. Existing users are unaffected because
    // they never pass through this step after install.
    // UI tests default it OFF so they don't hit the passcode prompt.
    @State private var biometricLockEnabled: Bool = !ProcessInfo.processInfo.arguments.contains("-uitest")
    @AppStorage(AppStorageKeys.biometricLockEnabled) private var persistedBiometricLock = false

    // TODO(vault-name-keychain): migrate to KeychainService for §7.3 compliance.
    // Spec §7.3 says "Stored only in iOS Keychain on this device" — @AppStorage
    // uses UserDefaults. Infrastructure exists (KeychainService.swift); a later
    // phase will migrate.
    @AppStorage(AppStorageKeys.vaultName) private var vaultName = ""

    @State private var currentStep: OnboardingStep = .welcome
    // Default to .quick — the Quick start card is visually labeled
    // "Recommended" per HTML design; the default selection must match.
    @State private var chosePath: OnboardingPath = .quick
    @State private var dialRotation: Double = 0
    @State private var tempCurrency = "USD"
    @State private var incomeText = ""
    @State private var selectedTemplate: BudgetTemplates.OnboardingTemplate = .single
    @State private var editableCategories: [(name: String, emoji: String, color: String, pct: Double)] = []
    @State private var showSaveError = false
    @State private var showCurrencyPicker = false
    @State private var budgetCreated = false
    // Welcome dial spin-to-advance state — rotates 720° on "Get started" tap.
    @State private var welcomeDialRotation: Double = 0
    @State private var welcomeAdvancing = false
    // Income step "Why we ask" disclosure sheet.
    @State private var showWhyWeAsk = false
    @FocusState private var vaultNameFocused: Bool

    private let categoryLimit = 6

    // Step progress: normalize rawValue against final step (.unlocked == 7).
    private var stepProgress: Double {
        min(Double(currentStep.rawValue) / 7.0, 1.0)
    }

    var body: some View {
        ZStack {
            // Navy gradient background
            LinearGradient(
                colors: [
                    BudgetVaultTheme.navyDark.opacity(0.95),
                    BudgetVaultTheme.navyDark,
                    BudgetVaultTheme.navyMid,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip pill — shown on currency (4) through envelopes (6).
                // Hidden on Welcome (its own dedicated "I'll set up later"
                // button), on Pledge/Name/Fork (which render their own inline
                // "Skip" text alongside the bolt row per HTML spec), and on
                // Unlocked (the terminal step).
                if currentStep.rawValue >= 4 && currentStep.rawValue <= 6 {
                    HStack {
                        Spacer()
                        Button { skipOnboarding() } label: {
                            Text("Skip for now")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(.white.opacity(0.12), in: Capsule())
                        }
                    }
                    .padding(.horizontal, BudgetVaultTheme.spacingXL)
                    .padding(.top, BudgetVaultTheme.spacingSM)
                }

                // Step content
                Group {
                    switch currentStep {
                    case .welcome: welcomeStep
                    case .pledge: pledgeStep
                    case .nameVault: nameVaultStep
                    case .depthFork: depthForkStep
                    case .currency: currencyStep
                    case .income: incomeStep
                    case .envelopes: envelopeStep
                    case .unlocked: unlockedStep
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity.combined(with: .move(edge: .leading))
                ))
            }
        }
        .alert("Save Failed", isPresented: $showSaveError) {
            Button("OK") {}
        } message: {
            Text("Could not save your budget. Please try again.")
        }
        .sheet(isPresented: $showCurrencyPicker) {
            NavigationStack {
                FullCurrencyPickerSheet { code in
                    tempCurrency = code
                    showCurrencyPicker = false
                }
            }
        }
    }

    // MARK: - Step 0: Welcome (VaultRevamp §7.1) — HTML 1:1

    /// HTML ground truth: VaultRevamp.html lines 1004-1144.
    /// - Background: radial-gradient (ellipse at 50% 30%) from #14234a → #0F1B33 → #070E1F
    /// - Giant 260x260 dial PNG (VaultDialHeroLocked), drop-shadow(0 20px 40px rgba(0,0,0,0.6))
    /// - 4 retracted bolts (no engaged)
    /// - .label "Welcome" (11pt, weight 600, tracking 0.22em, titanium300)
    /// - <h1> 34pt / weight 700 / letter-spacing -0.03em / line-height 1.1 / #E8EDF5
    /// - .label-sm (9pt / weight 600 / tracking 0.24em / titanium400) subtitle
    /// - Bottom-area: cta-primary "Get started" + cta-ghost "I'll set up later"
    private var welcomeStep: some View {
        ZStack {
            // Screen background — radial gradient per HTML .screen rule.
            RadialGradient(
                colors: [Color(hex: "#14234A"), Color(hex: "#0F1B33"), Color(hex: "#070E1F")],
                center: UnitPoint(x: 0.5, y: 0.3),
                startRadius: 0,
                endRadius: 600
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Giant hero dial — layered PNG assets (bezel + chamber,
                // ticks + numerals, pointer + boss + lock) so only the
                // FACE rotates on the "Get started" ceremony, matching how
                // a real bank vault dial behaves — pointer stays fixed at
                // 12 o'clock while the numbered wheel spins under it.
                // Respects Reduce Motion (skips the spin for accessibility).
                VaultDial(
                    size: .hero,
                    state: .locked,
                    faceRotationDegrees: welcomeDialRotation
                )
                    .shadow(color: .black.opacity(0.6), radius: 40, x: 0, y: 20)
                    .padding(.bottom, 32)

                // Retracted bolt row (4) — all titanium, no engaged.
                BoltRow(count: 4, engaged: 0, size: .medium)
                    .padding(.bottom, 32)

                // .label "WELCOME" — 11pt / weight 600 / tracking 2.42px / titanium300
                Text("Welcome")
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(2.42)   // 0.22em × 11pt
                    .foregroundStyle(BudgetVaultTheme.titanium300)
                    .padding(.bottom, 14)

                // Headline: 34pt / weight 700 / tracking -0.03em / line-height 1.1
                // Three equal-weight lines, center-aligned.
                (Text("Your budget.\n") + Text("Your device.\n") + Text("No one else."))
                    .font(.system(size: 34, weight: .bold))
                    .tracking(-1.02)    // -0.03em × 34pt
                    .lineSpacing(3.4)   // (1.1 - 1) × 34pt
                    .foregroundStyle(Color(hex: "#E8EDF5"))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 14)

                // .label-sm subtitle — 9pt / weight 600 / tracking 0.24em / text-3
                Text("$14.99 · One time · Yours forever")
                    .font(.system(size: 9, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(2.16)   // 0.24em × 9pt
                    .foregroundStyle(Color(hex: "#E8EDF5").opacity(0.42))

                Spacer()

                // Bottom area — cta-primary + cta-ghost.
                VStack(spacing: 8) {
                    // cta-primary: linear-gradient(180deg, #60A5FA 0%, #2563EB 55%, #1e40af 100%),
                    // 17px padding, 12px radius, 15pt weight 600 text, 1px #1e3a8a border.
                    Button { spinDialThenAdvance() } label: {
                        Text("Get started")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(hex: "#E8EDF5"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#60A5FA"),
                                        Color(hex: "#2563EB"),
                                        Color(hex: "#1E40AF"),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color(hex: "#1E3A8A"), lineWidth: 1)
                            )
                            .shadow(color: Color(hex: "#2563EB").opacity(0.4), radius: 3, x: 0, y: 2)
                    }

                    // cta-ghost: transparent, 13pt weight 500, color text-3.
                    Button { skipOnboarding() } label: {
                        Text("I'll set up later")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(hex: "#E8EDF5").opacity(0.42))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .accessibilityIdentifier("welcomeSkipButton")
                }
                // No inner horizontal padding — the outer .horizontal 32 is
                // the only padding layer (matches HTML screen-content exactly).
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 32) // HTML screen-content: padding: 0 32px
        }
    }

    // MARK: - Step 1: Privacy Pledge (VaultRevamp §7.2) — HTML 1:1

    /// HTML ground truth: VaultRevamp.html lines 1146-1233.
    /// - Top-bar: BoltRow (4, engaged 1) on left + "Skip" text on right
    ///   (13pt weight 500, color text-3)
    /// - .label "The Pledge" (11pt/600/tracking 0.22em/titanium300)
    /// - <h2>: 26pt/700/-0.025em tracking/line-height 1.15, left-aligned.
    ///   Split: "Four things we" white + "will never do." titanium300 weight 300
    /// - 4 .chamber rows (14px vertical / 16px horizontal padding) with
    ///   22x22 barred-circle SVG glyph in titanium300 and copy:
    ///     * "Ask for your bank login" / "No Plaid · No aggregator"
    ///     * "Send data to a server" / "Everything stays on this iPhone"
    ///     * "Charge you monthly" / "$14.99 once · Yours forever"
    ///     * "Use cloud AI on your spending" / "Patterns run on-device only"
    /// - Apple privacy credential card: titanium-circled shield with checkmark,
    ///   .label "APPLE PRIVACY LABEL" at titanium200, 12pt "Data Not Collected"
    /// - cta-primary "I understand"
    private var pledgeStep: some View {
        ZStack {
            // Screen background — radial per HTML .screen rule.
            RadialGradient(
                colors: [Color(hex: "#14234A"), Color(hex: "#0F1B33"), Color(hex: "#070E1F")],
                center: UnitPoint(x: 0.5, y: 0.3),
                startRadius: 0,
                endRadius: 600
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Top row: bolt row + plain Skip text (HTML: top: 64px with 16px padding)
                    HStack {
                        BoltRow(count: 4, engaged: 1, size: .medium)
                        Spacer()
                        Button { skipOnboarding() } label: {
                            Text("Skip")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color(hex: "#E8EDF5").opacity(0.42))
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 46) // approximates the ~110px top offset to first content

                    // .label "The Pledge"
                    Text("The Pledge")
                        .font(.system(size: 11, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(2.42)
                        .foregroundStyle(BudgetVaultTheme.titanium300)
                        .padding(.bottom, 10)

                    // <h2>: 26pt / 700 / -0.025em / line-height 1.15, left-aligned
                    // Weight-split: bold white + light titanium300.
                    (Text("Four things we\n")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(Color(hex: "#E8EDF5"))
                    + Text("will never do.")
                        .font(.system(size: 26, weight: .light))
                        .foregroundColor(BudgetVaultTheme.titanium300))
                        .tracking(-0.65)     // -0.025em × 26pt
                        .lineSpacing(3.9)    // (1.15 - 1) × 26pt
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 20)

                    // 4 pledge rows — gap: 10px
                    VStack(spacing: 10) {
                        pledgeRow(title: "Ask for your bank login",
                                  subtitle: "No Plaid · No aggregator")
                        pledgeRow(title: "Send data to a server",
                                  subtitle: "Everything stays on this iPhone")
                        pledgeRow(title: "Charge you monthly",
                                  subtitle: "$14.99 once · Yours forever")
                        pledgeRow(title: "Use cloud AI on your spending",
                                  subtitle: "Patterns run on-device only")
                    }
                    .padding(.bottom, 16)

                    // Apple privacy credential stamp — titanium border, navy gradient fill,
                    // titanium-circled shield with checkmark on left.
                    HStack(spacing: 12) {
                        PledgeAppleShield()
                            .frame(width: 30, height: 30)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Apple Privacy Label")
                                .font(.system(size: 10, weight: .semibold))
                                .textCase(.uppercase)
                                .tracking(2.2)    // 0.22em × 10pt
                                .foregroundStyle(BudgetVaultTheme.titanium200)
                            Text("Data Not Collected")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(hex: "#E8EDF5").opacity(0.68))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(
                                colors: [Color(hex: "#101A33"), Color(hex: "#070E1F")],
                                startPoint: UnitPoint(x: 0.15, y: 0),
                                endPoint: UnitPoint(x: 0.85, y: 1)
                            ))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(BudgetVaultTheme.titanium700, lineWidth: 1)
                    )

                    Spacer(minLength: 110) // floating CTA clearance
                }
                .padding(.horizontal, 24)
            }
        }
        .safeAreaInset(edge: .bottom) {
            pledgePrimaryCTA
        }
    }

    private var pledgePrimaryCTA: some View {
        Button { advanceToNextStep() } label: {
            Text("I understand")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(hex: "#E8EDF5"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#60A5FA"), Color(hex: "#2563EB"), Color(hex: "#1E40AF")],
                        startPoint: .top, endPoint: .bottom
                    ),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(hex: "#1E3A8A"), lineWidth: 1)
                )
                .shadow(color: Color(hex: "#2563EB").opacity(0.4), radius: 3, y: 2)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .background(Color(hex: "#0F1B33").opacity(0.95))
    }

    /// Single pledge row — .chamber-style panel with titanium barred-circle glyph.
    private func pledgeRow(title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            // 22x22 barred-circle SVG equivalent — titanium300 circle + diagonal stroke
            ZStack {
                Circle()
                    .strokeBorder(BudgetVaultTheme.titanium300, lineWidth: 1.8)
                    .frame(width: 17, height: 17)
                Capsule()
                    .fill(BudgetVaultTheme.titanium300)
                    .frame(width: 13.5, height: 1.8)
                    .rotationEffect(.degrees(-45))
            }
            .frame(width: 22, height: 22)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: "#E8EDF5"))
                Text(subtitle)
                    .font(.system(size: 9, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(2.16)   // 0.24em × 9pt
                    .foregroundStyle(Color(hex: "#E8EDF5").opacity(0.42))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(
                    colors: [Color(hex: "#0F1A30"), Color(hex: "#070E1F")],
                    startPoint: UnitPoint(x: 0.15, y: 0),
                    endPoint: UnitPoint(x: 0.85, y: 1)
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(BudgetVaultTheme.titanium300.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
    }

    // MARK: - Step 2: Name Your Vault (VaultRevamp §7.3) — HTML 1:1

    /// HTML ground truth: VaultRevamp.html lines 1235-1297.
    /// - Top-bar: BoltRow (4, engaged 2) + plain "Skip" text (13pt/500/text-3)
    /// - .label "Personal" (11pt/600/2.42 tracking/titanium300)
    /// - <h2> "Name your vault." — 28pt/700/-0.025em/line-height 1.15, left-aligned
    /// - Subtitle: "Appears at the top of your dashboard. You can change this anytime."
    ///   (14pt regular / line-height 1.5 / text-2)
    /// - Titanium EngravingPlate with brushed texture + character counter
    /// - .label-sm "Or choose a preset"
    /// - 3 preset pills: rgba(96,165,250,0.08) bg + rgba(96,165,250,0.3) border,
    ///   text in blue-soft (#60A5FA), 8x14 padding, 6px radius, 13pt/500.
    /// - Info note (electric-blue tinted): "Stored only in iOS Keychain on this
    ///   device. We can't read it." with info-circle icon.
    /// - cta-primary "Engrave it"
    private var nameVaultStep: some View {
        ZStack {
            RadialGradient(
                colors: [Color(hex: "#14234A"), Color(hex: "#0F1B33"), Color(hex: "#070E1F")],
                center: UnitPoint(x: 0.5, y: 0.3),
                startRadius: 0,
                endRadius: 600
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Top row: bolt row (4, engaged 2) + Skip
                    HStack {
                        BoltRow(count: 4, engaged: 2, size: .medium)
                        Spacer()
                        Button { skipOnboarding() } label: {
                            Text("Skip")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color(hex: "#E8EDF5").opacity(0.42))
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 46)

                    // .label "Personal"
                    Text("Personal")
                        .font(.system(size: 11, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(2.42)
                        .foregroundStyle(BudgetVaultTheme.titanium300)
                        .padding(.bottom, 12)

                    // <h2>: 28pt / 700 / -0.025em / line-height 1.15
                    Text("Name your vault.")
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-0.7)    // -0.025em × 28pt
                        .lineSpacing(4.2)  // (1.15 - 1) × 28pt
                        .foregroundStyle(Color(hex: "#E8EDF5"))
                        .padding(.bottom, 8)

                    // Subtitle — 14pt regular, line-height 1.5, text-2. VERBATIM.
                    Text("Appears at the top of your dashboard. You can change this anytime.")
                        .font(.system(size: 14))
                        .lineSpacing(7.0)  // (1.5 - 1) × 14pt
                        .foregroundStyle(Color(hex: "#E8EDF5").opacity(0.68))
                        .padding(.bottom, 28)

                    // Titanium engraving plate + invisible TextField for input.
                    // Placeholder "Emma's Vault" shows at 35% opacity so user
                    // sees it's a suggestion. Counter stacked below reflects
                    // real vaultName length (0 when empty, not placeholder length).
                    VStack(spacing: 8) {
                        ZStack {
                            EngravingPlate(text: vaultName.isEmpty ? "Emma's Vault" : vaultName,
                                           characterLimit: 24,
                                           showCounter: false)  // we render our own below
                                .opacity(vaultName.isEmpty ? 0.35 : 1.0)
                            TextField("", text: $vaultName)
                                .textFieldStyle(.plain)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.clear)
                                .tint(BudgetVaultTheme.titanium800)
                                .focused($vaultNameFocused)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                                .onChange(of: vaultName) { _, newValue in
                                    if newValue.count > 24 { vaultName = String(newValue.prefix(24)) }
                                }
                        }
                        Text("\(vaultName.count) / 24")
                            .font(BudgetVaultTheme.flipDigitFont(size: 12))
                            .foregroundStyle(BudgetVaultTheme.titanium600.opacity(0.75))
                    }
                    .padding(.bottom, 28)

                    // .label-sm "Or choose a preset" — 9pt/600/0.24em/titanium400
                    Text("Or choose a preset")
                        .font(.system(size: 9, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(2.16)    // 0.24em × 9pt
                        .foregroundStyle(BudgetVaultTheme.titanium400)
                        .padding(.bottom, 12)

                    // Preset pills — 6px gap, blue-tinted. Active state = selected preset.
                    HStack(spacing: 6) {
                        ForEach(["The Household", "Savings", "Ledger"], id: \.self) { preset in
                            namePresetPill(preset)
                        }
                    }
                    .padding(.bottom, 28)

                    // Keychain info note — rgba(96,165,250,0.06) bg + 0.2 border.
                    HStack(spacing: 12) {
                        // info-circle SVG equivalent, 16x16, stroke #60A5FA
                        ZStack {
                            Circle()
                                .strokeBorder(Color(hex: "#60A5FA"), lineWidth: 1.2)
                                .frame(width: 16, height: 16)
                            VStack(spacing: 1) {
                                Rectangle()
                                    .fill(Color(hex: "#60A5FA"))
                                    .frame(width: 1.2, height: 5)
                                Rectangle()
                                    .fill(Color(hex: "#60A5FA"))
                                    .frame(width: 1.2, height: 1)
                            }
                        }
                        .frame(width: 16, height: 16)
                        .accessibilityHidden(true)

                        Text("Stored only in iOS Keychain on this device. We can't read it.")
                            .font(.system(size: 12))
                            .lineSpacing(6.0)   // (1.5 - 1) × 12pt
                            .foregroundStyle(Color(hex: "#E8EDF5").opacity(0.68))
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(hex: "#60A5FA").opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color(hex: "#60A5FA").opacity(0.2), lineWidth: 1)
                    )

                    Spacer(minLength: 110)
                }
                .padding(.horizontal, 24)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button { advanceToNextStep() } label: {
                Text("Engrave it")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "#E8EDF5"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#60A5FA"), Color(hex: "#2563EB"), Color(hex: "#1E40AF")],
                            startPoint: .top, endPoint: .bottom
                        ),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color(hex: "#1E3A8A"), lineWidth: 1)
                    )
                    .shadow(color: Color(hex: "#2563EB").opacity(0.4), radius: 3, y: 2)
            }
            .disabled(vaultName.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(vaultName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.45 : 1.0)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .background(Color(hex: "#0F1B33").opacity(0.95))
        }
    }

    /// Preset pill — active (selected or typed match) gets brighter blue
    /// background/border; inactive is the subtle blue-tinted default.
    @ViewBuilder
    private func namePresetPill(_ preset: String) -> some View {
        let isActive = vaultName == preset
        Button {
            vaultName = preset
        } label: {
            Text(preset)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "#60A5FA"))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: "#60A5FA")
                            .opacity(isActive ? 0.18 : 0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            Color(hex: "#60A5FA").opacity(isActive ? 0.6 : 0.3),
                            lineWidth: isActive ? 1.5 : 1
                        )
                )
        }
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    // MARK: - Step 3: Depth Fork (VaultRevamp §7.4) — HTML 1:1

    /// HTML ground truth: VaultRevamp.html lines 1307-1358.
    /// - Top: BoltRow (4, engaged 3) — no Skip text here (HTML has none)
    /// - .label "Your Pace"
    /// - <h2> "Two ways to finish." (28pt/700/-0.025em/line-height 1.15)
    /// - Quick start card: linear-gradient(160deg, #162952 → #0F1B33),
    ///   2px electric-blue border, 12px radius, blue glow shadow.
    ///   "RECOMMENDED" corner notch top-left: electric-blue bg, white 9pt heavy,
    ///   0.2em tracking, 3px radius. "30 SEC" label-sm top-right.
    ///   Title "Quick start" 20pt/700/-0.01em white + subtitle 13pt/1.55 text-2.
    /// - Thorough setup card: linear-gradient(160deg, #101A33 → #070E1F),
    ///   1px titanium700 border, same layout. Title color text-2, subtitle text-3.
    /// - CTA: "Quick start" when quick; "Walk me through everything" when thorough.
    private var depthForkStep: some View {
        ZStack {
            RadialGradient(
                colors: [Color(hex: "#14234A"), Color(hex: "#0F1B33"), Color(hex: "#070E1F")],
                center: UnitPoint(x: 0.5, y: 0.3),
                startRadius: 0,
                endRadius: 600
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Top row: bolt row only — HTML shows NO Skip text on this step.
                    HStack {
                        BoltRow(count: 4, engaged: 3, size: .medium)
                        Spacer()
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 46)

                    // .label "Your Pace"
                    Text("Your Pace")
                        .font(.system(size: 11, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(2.42)
                        .foregroundStyle(BudgetVaultTheme.titanium300)
                        .padding(.bottom, 12)

                    // <h2>: 28pt / 700 / -0.025em / line-height 1.15
                    Text("Two ways to finish.")
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-0.7)
                        .lineSpacing(4.2)
                        .foregroundStyle(Color(hex: "#E8EDF5"))
                        .padding(.bottom, 28)

                    // Quick start card (recommended) — blue gradient, 2px electric border.
                    quickStartCard
                        .padding(.bottom, 10)

                    // Thorough setup card — titanium border, darker gradient.
                    thoroughSetupCard

                    Spacer(minLength: 110)
                }
                .padding(.horizontal, 24)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button { takeDepthForkDecision() } label: {
                Text(chosePath == .quick ? "Quick start" : "Walk me through everything")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "#E8EDF5"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#60A5FA"), Color(hex: "#2563EB"), Color(hex: "#1E40AF")],
                            startPoint: .top, endPoint: .bottom
                        ),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color(hex: "#1E3A8A"), lineWidth: 1)
                    )
                    .shadow(color: Color(hex: "#2563EB").opacity(0.4), radius: 3, y: 2)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .background(Color(hex: "#0F1B33").opacity(0.95))
        }
    }

    /// Quick start card — blue gradient fill with 2px electric border
    /// when selected (default), thinner + dimmer when user picks Thorough.
    /// "RECOMMENDED" notch protrudes top-left; "30 SEC" label top-right.
    private var quickStartCard: some View {
        let isSelected = chosePath == .quick
        return Button { chosePath = .quick } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Quick start")
                        .font(.system(size: 20, weight: .bold))
                        .tracking(-0.2)   // -0.01em × 20pt
                        .foregroundStyle(Color(hex: "#E8EDF5"))
                    Spacer()
                    Text("30 Sec")
                        .font(.system(size: 9, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(2.16)
                        .foregroundStyle(BudgetVaultTheme.titanium400)
                }
                Text("Go straight to your dashboard with a starter envelope. Add income and allocations when ready.")
                    .font(.system(size: 13))
                    .lineSpacing(7.15)  // (1.55 - 1) × 13pt
                    .foregroundStyle(Color(hex: "#E8EDF5").opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors: [Color(hex: "#162952"), Color(hex: "#0F1B33")],
                        startPoint: UnitPoint(x: 0.15, y: 0),
                        endPoint: UnitPoint(x: 0.85, y: 1)
                    ))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? Color(hex: "#2563EB") : BudgetVaultTheme.titanium700,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(color: isSelected ? Color(hex: "#2563EB").opacity(0.2) : .clear, radius: 14, y: 4)
            .shadow(color: isSelected ? Color(hex: "#2563EB").opacity(0.08) : .clear, radius: 24, x: 0, y: 0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
            .overlay(alignment: .topLeading) {
                // "RECOMMENDED" tab — HTML positions it top: -8px, left: 16px.
                Text("Recommended")
                    .font(.system(size: 9, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(1.8)    // 0.2em × 9pt
                    .foregroundStyle(Color(hex: "#E8EDF5"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hex: "#2563EB"))
                    )
                    .offset(x: 16, y: -8)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(chosePath == .quick ? .isSelected : [])
    }

    /// Thorough setup card — darker navy gradient. Static titanium
    /// hairline when unselected; 2pt electric-blue border + full-opacity
    /// title when selected (user-feedback parity with Quick card).
    private var thoroughSetupCard: some View {
        let isSelected = chosePath == .thorough
        return Button { chosePath = .thorough } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Thorough setup")
                        .font(.system(size: 20, weight: .bold))
                        .tracking(-0.2)
                        .foregroundStyle(Color(hex: "#E8EDF5").opacity(isSelected ? 1.0 : 0.68))
                    Spacer()
                    Text("2 Min")
                        .font(.system(size: 9, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(2.16)
                        .foregroundStyle(BudgetVaultTheme.titanium400)
                }
                Text("Face ID, income, envelopes, and allocation. Seven more steps. Any step still skippable.")
                    .font(.system(size: 13))
                    .lineSpacing(7.15)
                    .foregroundStyle(Color(hex: "#E8EDF5").opacity(isSelected ? 0.68 : 0.42))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors: [Color(hex: "#101A33"), Color(hex: "#070E1F")],
                        startPoint: UnitPoint(x: 0.15, y: 0),
                        endPoint: UnitPoint(x: 0.85, y: 1)
                    ))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? Color(hex: "#2563EB") : BudgetVaultTheme.titanium700,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(color: isSelected ? Color(hex: "#2563EB").opacity(0.2) : .clear, radius: 14, y: 4)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(chosePath == .thorough ? .isSelected : [])
    }

    private func takeDepthForkDecision() {
        if chosePath == .quick {
            // Auto-defaults so the user lands on a working Home without
            // revisiting currency/income/envelopes in onboarding.
            tempCurrency = "USD"
            selectedCurrency = "USD"
            incomeText = "5000"
            selectedTemplate = .single
            editableCategories = Array(BudgetTemplates.OnboardingTemplate.single.categories.prefix(categoryLimit))

            // Commit the budget now (same path as Looks Good), then jump
            // to the unlocked step. createBudget() handles the transition
            // to .unlocked via its internal animation.
            createBudget()
        } else {
            // Thorough path: advance normally to .currency.
            advanceToNextStep()
        }
    }

    // MARK: - Step 1: Currency

    // VaultRevamp Phase 3b — Currency step uses chamber-depth chips + engraved
    // label, not a dial-with-progress. Style aligned to §7 screen migrations
    // so Currency reads as part of the thorough-setup sequence (bolt 4 of 7).
    private var currencyStep: some View {
        let padding: CGFloat = 24
        return VStack(spacing: 0) {
            Spacer().frame(height: 64)

            BoltRow(count: 7, engaged: 4, size: .medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, padding)

            Spacer().frame(height: 36)

            Text("Step 1 of 7 · Currency")
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .tracking(2.42)
                .foregroundStyle(BudgetVaultTheme.titanium300)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, padding)

            Spacer().frame(height: 8)

            Text("Choose your currency.")
                .font(.system(size: 24, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(Color(hex: "#E8EDF5"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, padding)

            Spacer().frame(height: 24)

            vaultCurrencyChips
                .padding(.horizontal, padding)

            Spacer().frame(height: 16)

            Button { showCurrencyPicker = true } label: {
                HStack(spacing: 4) {
                    Text("More currencies")
                        .font(.system(size: 12, weight: .medium))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(BudgetVaultTheme.accentSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, padding)

            Spacer()

            Button {
                selectedCurrency = tempCurrency
                advanceStep()
            } label: {
                Text("Continue")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "#E8EDF5"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(ctaPrimaryBackground, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color(hex: "#1e3a8a"), lineWidth: 1)
                    )
            }
            .padding(.horizontal, padding)
            .padding(.bottom, 20)
        }
    }

    /// Vault-themed currency picker — chamber-depth chips in a 3-column grid.
    /// Selected chip is outlined in accent blue; unselected chips sit on the
    /// chamber gradient to read as recessed inlays.
    private var vaultCurrencyChips: some View {
        let currencies: [(code: String, flag: String)] = [
            ("USD", "\u{1F1FA}\u{1F1F8}"),
            ("EUR", "\u{1F1EA}\u{1F1FA}"),
            ("GBP", "\u{1F1EC}\u{1F1E7}"),
            ("CAD", "\u{1F1E8}\u{1F1E6}"),
            ("AUD", "\u{1F1E6}\u{1F1FA}"),
            ("JPY", "\u{1F1EF}\u{1F1F5}"),
        ]
        let columns = [GridItem(.flexible(), spacing: 8),
                       GridItem(.flexible(), spacing: 8),
                       GridItem(.flexible(), spacing: 8)]
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(currencies, id: \.code) { currency in
                Button {
                    tempCurrency = currency.code
                } label: {
                    HStack(spacing: 6) {
                        Text(currency.flag).font(.system(size: 18))
                        Text(currency.code)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Color(hex: "#E8EDF5"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: tempCurrency == currency.code
                                ? [BudgetVaultTheme.navyMid, BudgetVaultTheme.navyDark]
                                : [BudgetVaultTheme.chamberDeep, BudgetVaultTheme.chamberBlack],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                tempCurrency == currency.code
                                    ? BudgetVaultTheme.accentSoft
                                    : BudgetVaultTheme.titanium700,
                                lineWidth: tempCurrency == currency.code ? 2 : 1
                            )
                    )
                    .accessibilityAddTraits(tempCurrency == currency.code ? .isSelected : [])
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Shared cta-primary gradient (matches HTML: #60A5FA → #2563EB → #1e40af).
    private var ctaPrimaryBackground: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color(hex: "#60A5FA"), location: 0.0),
                .init(color: BudgetVaultTheme.electricBlue, location: 0.55),
                .init(color: Color(hex: "#1e40af"), location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Step 2: Income

    // VaultRevamp §7.5 — Income entry ceremony. HTML Step 07 verbatim:
    //   · BoltRow 7/6 (near end of thorough path)
    //   · Engraved "Step 3 of 7 · Income"
    //   · 24pt bold two-line headline "What lands in your account each month?"
    //   · "Why we ask →" text button (opens privacy disclosure sheet)
    //   · FlipDigitDisplay (.display, chamber-black mechanical plates)
    //   · Engraved "After-tax take-home"
    //   · TitaniumKeypad — the one place the metal keys earn their weight
    //   · cta-primary "Continue" (inline-positioned, NOT absolute)
    private var incomeStep: some View {
        let padding: CGFloat = 24
        let cents = MoneyHelpers.parseCurrencyString(incomeText) ?? 0
        let displayAmount = Decimal(cents) / Decimal(100)
        let hasIncome = cents > 0
        return VStack(spacing: 0) {
            Spacer().frame(height: 64)

            BoltRow(count: 7, engaged: 6, size: .medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, padding)

            Spacer().frame(height: 36)

            Text("Step 3 of 7 · Income")
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .tracking(2.42)
                .foregroundStyle(BudgetVaultTheme.titanium300)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, padding)

            Spacer().frame(height: 8)

            (Text("What lands in your\n") + Text("account each month?"))
                .font(.system(size: 24, weight: .bold))
                .tracking(-0.6)
                .lineSpacing(4.8)
                .foregroundStyle(Color(hex: "#E8EDF5"))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, padding)

            Spacer().frame(height: 4)

            Button { showWhyWeAsk = true } label: {
                Text("Why we ask \u{2192}")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(BudgetVaultTheme.accentSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, padding)

            Spacer().frame(height: 24)

            FlipDigitDisplay(
                amount: displayAmount,
                style: .display,
                currencyCode: selectedCurrency
            )
            .frame(maxWidth: .infinity)
            .contentTransition(.numericText())

            Spacer().frame(height: 10)

            Text("After-tax take-home")
                .font(.system(size: 9, weight: .semibold))
                .textCase(.uppercase)
                .tracking(2.16)
                .foregroundStyle(Color(hex: "#E8EDF5").opacity(0.42))
                .frame(maxWidth: .infinity)

            Spacer().frame(height: 22)

            TitaniumKeypad(text: $incomeText)
                .padding(.horizontal, padding)

            Spacer().frame(height: 14)

            Button { advanceStep() } label: {
                Text("Continue")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(
                        hasIncome
                            ? Color(hex: "#E8EDF5")
                            : Color(hex: "#E8EDF5").opacity(0.4)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(
                        hasIncome
                            ? AnyShapeStyle(ctaPrimaryBackground)
                            : AnyShapeStyle(Color.white.opacity(0.08)),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                hasIncome
                                    ? Color(hex: "#1e3a8a")
                                    : Color.white.opacity(0.05),
                                lineWidth: 1
                            )
                    )
            }
            .disabled(!hasIncome)
            .padding(.horizontal, padding)
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $showWhyWeAsk) {
            whyWeAskSheet
        }
    }

    /// Privacy disclosure for the Income step. Never says "required" — the
    /// user can skip with any amount. Matches the spec's privacy-pledge tone.
    private var whyWeAskSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Why we ask")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color(hex: "#E8EDF5"))
                .padding(.top, 8)

            Text("""
            We use your monthly take-home to calculate your daily allowance \
            and envelope targets. That's it.
            """)
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(Color(hex: "#E8EDF5").opacity(0.75))
            .fixedSize(horizontal: false, vertical: true)

            Text("""
            The number stays on this iPhone. It never leaves your device, \
            never hits a server, never funds an ad network.
            """)
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(Color(hex: "#E8EDF5").opacity(0.75))
            .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Button { showWhyWeAsk = false } label: {
                Text("Got it")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "#E8EDF5"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(ctaPrimaryBackground, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color(hex: "#1e3a8a"), lineWidth: 1)
                    )
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BudgetVaultTheme.navyDark.ignoresSafeArea())
        .presentationDetents([.medium])
    }

    // MARK: - Step 3: Envelopes

    // VaultRevamp Phase 3c — Envelopes step retheme. The functional core
    // (template scroll + editable category list + Unallocated footer) is
    // preserved; only the chrome (dial→bolt-row, engraved label, headline,
    // CTA gradient) swaps to match the Vault aesthetic. Spec §5 does not
    // re-spec this screen explicitly — it's treated as a data-entry step
    // in the thorough path.
    private var envelopeStep: some View {
        let padding: CGFloat = 24
        return VStack(spacing: 0) {
            Spacer().frame(height: 64)

            BoltRow(count: 7, engaged: 7, size: .medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, padding)

            Spacer().frame(height: 24)

            Text("Step 5 of 7 · Envelopes")
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .tracking(2.42)
                .foregroundStyle(BudgetVaultTheme.titanium300)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, padding)

            Spacer().frame(height: 8)

            Text("Split the vault into envelopes.")
                .font(.system(size: 24, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(Color(hex: "#E8EDF5"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, padding)

            Spacer().frame(height: 16)

            templateScroll
                .padding(.bottom, BudgetVaultTheme.spacingXS)

            // Editable category list
            ScrollView {
                VStack(spacing: BudgetVaultTheme.spacingSM) {
                    ForEach(Array(editableCategories.enumerated()), id: \.offset) { index, _ in
                        if index < editableCategories.count {
                            envelopeCategoryRow(index: index)
                        }
                    }

                    if editableCategories.count < categoryLimit {
                        Button {
                            withAnimation(.easeOut(duration: 0.25)) {
                                editableCategories.append(("New Category", "\u{1F4E6}", "#8E8E93", 0.05))
                            }
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Category")
                                Spacer()
                                Text("\(editableCategories.count)/\(categoryLimit)")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(BudgetVaultTheme.spacingMD)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD))
                        }
                    }

                }
                .padding(.horizontal, BudgetVaultTheme.spacingLG)
            }

            // Round 7 R3: Unallocated row moved OUT of ScrollView and
            // sits between the list and the CTA as a sticky footer so
            // it's never clipped behind "Looks Good".
            let totalPct = editableCategories.reduce(0.0) { $0 + $1.pct }
            let unallocated = max(0, 1.0 - totalPct)
            Text("Unallocated: \(Int(unallocated * 100))%")
                .font(.caption)
                .foregroundStyle(unallocated > 0 ? BudgetVaultTheme.accentSoft : .white.opacity(0.35))
                .padding(.bottom, BudgetVaultTheme.spacingSM)

            let canContinue = !editableCategories.isEmpty
            Button {
                createBudget()
            } label: {
                Text("Continue")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(
                        canContinue
                            ? Color(hex: "#E8EDF5")
                            : Color(hex: "#E8EDF5").opacity(0.4)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(
                        canContinue
                            ? AnyShapeStyle(ctaPrimaryBackground)
                            : AnyShapeStyle(Color.white.opacity(0.08)),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                canContinue
                                    ? Color(hex: "#1e3a8a")
                                    : Color.white.opacity(0.05),
                                lineWidth: 1
                            )
                    )
            }
            .disabled(!canContinue)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .onAppear {
            if editableCategories.isEmpty {
                selectTemplate(.single)
            }
        }
    }

    private var templateScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BudgetVaultTheme.spacingMD) {
                ForEach(BudgetTemplates.OnboardingTemplate.allCases, id: \.rawValue) { template in
                    Button {
                        selectTemplate(template)
                    } label: {
                        VStack(spacing: BudgetVaultTheme.spacingSM) {
                            Image(systemName: template.icon)
                                .font(.title2)
                                .foregroundStyle(.white)
                            Text(template.rawValue)
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                        .frame(width: 80)
                        .padding(.vertical, BudgetVaultTheme.spacingMD)
                        .background(
                            selectedTemplate == template
                                ? AnyShapeStyle(BudgetVaultTheme.accentSoft.opacity(0.25))
                                : AnyShapeStyle(Color.white.opacity(0.08)),
                            in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusLG)
                                .strokeBorder(
                                    selectedTemplate == template
                                        ? BudgetVaultTheme.accentSoft.opacity(0.6)
                                        : Color.white.opacity(0.12),
                                    lineWidth: 1
                                )
                        )
                    }
                    .accessibilityAddTraits(selectedTemplate == template ? .isSelected : [])
                }
            }
            .padding(.horizontal, BudgetVaultTheme.spacingLG)
        }
    }

    @ViewBuilder
    private func envelopeCategoryRow(index: Int) -> some View {
        let incomeCents = MoneyHelpers.parseCurrencyString(incomeText) ?? 0
        let amountCents = Int64(Double(incomeCents) * editableCategories[index].pct)

        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: editableCategories[index].color))
                .frame(width: 10, height: 10)

            Text(editableCategories[index].emoji)
                .font(.title3)

            TextField("Name", text: Binding(
                get: { editableCategories[index].name },
                set: { editableCategories[index].name = $0 }
            ))
            .font(.subheadline)
            .foregroundStyle(.white)
            .textFieldStyle(.plain)

            Spacer()

            // Percentage stepper
            HStack(spacing: 4) {
                Button {
                    if editableCategories[index].pct > 0.05 {
                        editableCategories[index].pct -= 0.05
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Circle())
                }

                Text("\(Int(editableCategories[index].pct * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 36)

                Button {
                    if editableCategories[index].pct < 0.95 {
                        editableCategories[index].pct += 0.05
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Circle())
                }
            }

            // Dollar amount
            if incomeCents > 0 {
                Text(CurrencyFormatter.format(cents: amountCents))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: 60, alignment: .trailing)
            }

            // Delete
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    if index < editableCategories.count {
                        editableCategories.remove(at: index)
                    }
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(BudgetVaultTheme.spacingMD)
        .background(
            RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD)
                .fill(Color.white.opacity(0.08))
        )
    }

    private func selectTemplate(_ template: BudgetTemplates.OnboardingTemplate) {
        selectedTemplate = template
        if template == .custom {
            editableCategories = [("New Category", "\u{1F4E6}", "#8E8E93", 0.20)]
        } else {
            editableCategories = Array(template.categories.prefix(categoryLimit))
        }
    }

    // MARK: - Step 4: Vault Opens (ritual moment)

    // VaultRevamp §7.6 — THE ritual screen. HTML Step 11 verbatim.
    //   · BoltRow(count: 4, engaged: 4) — all sealed in electric blue
    //   · VaultDial(.hero, state: .open, showGlow: true) with ticks
    //     rotated 72° (one major-tick click past rest) and a blue aura
    //   · Weight-split headline "The vault IS OPEN." — bold white + 300
    //     blue-soft
    //   · Subline "<Vault name> · $X/day"  (medium weight, text-2)
    //   · Engraved "Day 1 of your streak"
    //   · cta-primary "Enter the vault" — the ONE place in the app that
    //     uses this costume phrase (spec §7.6)
    //
    // The Face ID opt-in toggle from v3.2 is removed from this ritual —
    // the default stays ON (v3.2 audit H9), and users can toggle from
    // Settings later. Ritual screens don't carry chrome.
    private var unlockedStep: some View {
        let incomeCents = MoneyHelpers.parseCurrencyString(incomeText) ?? 0
        let perDayCents = incomeCents > 0 ? Int64(Double(incomeCents) / 30.0) : 0
        let vaultLabel = vaultName.isEmpty ? "Your vault" : "\(vaultName)'s Vault"
        let dayLabel = perDayCents > 0
            ? "\(vaultLabel) \u{00B7} \(CurrencyFormatter.format(cents: perDayCents, currencyCode: selectedCurrency))/day"
            : vaultLabel
        return VStack(spacing: 0) {
            Spacer().frame(height: 64)

            BoltRow(count: 4, engaged: 4, size: .medium)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 32)

            Spacer()

            VaultDial(
                size: .hero,
                state: .open,
                showGlow: true,
                faceRotationDegrees: 72
            )
            .shadow(color: BudgetVaultTheme.accentSoft.opacity(0.30), radius: 40, x: 0, y: 0)
            .shadow(color: .black.opacity(0.6), radius: 40, x: 0, y: 20)
            .padding(.bottom, 36)

            // Weight-split headline: "The vault " bold white + "is open."
            // light blue. The spec insists on this split — it's where the
            // weight contrast earns its keep across the whole onboarding.
            (
                Text("The vault ")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Color(hex: "#E8EDF5"))
                +
                Text("is open.")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(BudgetVaultTheme.accentSoft)
            )
            .tracking(-0.96)
            .multilineTextAlignment(.center)
            .padding(.bottom, 10)

            Text(dayLabel)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(hex: "#E8EDF5").opacity(0.7))
                .padding(.bottom, 6)

            Text("Day 1 of your streak")
                .font(.system(size: 9, weight: .semibold))
                .textCase(.uppercase)
                .tracking(2.16)
                .foregroundStyle(Color(hex: "#E8EDF5").opacity(0.42))

            Spacer()

            Button {
                // Preserve v3.2 audit H9 default — Face ID on by default
                // unless the user is running UI tests. Users can disable
                // it from Settings after onboarding.
                persistedBiometricLock = biometricLockEnabled
                withAnimation(.smooth(duration: 0.5)) {
                    hasCompletedOnboarding = true
                }
            } label: {
                Text("Enter the vault")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "#E8EDF5"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(ctaPrimaryBackground, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color(hex: "#1e3a8a"), lineWidth: 1)
                    )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Step Advancement

    /// Linear advance to the next step in the rawValue order. Used by
    /// Welcome → Pledge → Name → Fork, and by Thorough-path continuations.
    private func advanceToNextStep() {
        guard let next = OnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = next
        }
    }

    /// Welcome → Pledge ceremony: spin the dial 720° (two full rotations),
    /// then advance. Respects Reduce Motion by skipping the spin.
    /// Guard against double-taps with `welcomeAdvancing`.
    private func spinDialThenAdvance() {
        guard !welcomeAdvancing else { return }
        welcomeAdvancing = true

        if reduceMotion {
            advanceToNextStep()
            welcomeAdvancing = false
            return
        }

        withAnimation(.easeInOut(duration: 1.2)) {
            welcomeDialRotation += 720
        }
        HapticManager.impact(.light)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            advanceToNextStep()
            // Reset flag so if user comes back (via back nav) and taps again,
            // the animation fires fresh.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                welcomeAdvancing = false
            }
        }
    }

    /// Legacy advance used by currency/income steps — preserves the dial
    /// rotation flourish. Will be replaced in Phase 3b when those screens
    /// are restyled.
    private func advanceStep() {
        let animation: Animation = reduceMotion
            ? .easeOut(duration: 0.2)
            : .spring(duration: 0.6)

        withAnimation(animation) {
            dialRotation += reduceMotion ? 0 : 90
            if let next = OnboardingStep(rawValue: currentStep.rawValue + 1) {
                currentStep = next
            }
        }
    }

    // MARK: - Budget Creation

    private func createBudget() {
        guard !budgetCreated else { return }
        guard let incomeCents = MoneyHelpers.parseCurrencyString(incomeText), incomeCents > 0 else {
            // Allow zero-income budgets if user skipped income step or entered 0
            createBudgetWithIncome(0)
            return
        }
        createBudgetWithIncome(incomeCents)
    }

    private func createBudgetWithIncome(_ incomeCents: Int64) {
        let (month, year) = DateHelpers.currentBudgetPeriod(resetDay: resetDay)
        let budget = Budget(month: month, year: year, totalIncomeCents: incomeCents, resetDay: resetDay)
        modelContext.insert(budget)

        let categoriesToCreate = Array(editableCategories.prefix(categoryLimit))
        for (index, cat) in categoriesToCreate.enumerated() {
            let catCents = Int64(Double(incomeCents) * cat.pct)
            let category = Category(
                name: cat.name,
                emoji: cat.emoji,
                budgetedAmountCents: catCents,
                color: cat.color,
                sortOrder: index
            )
            category.budget = budget
            modelContext.insert(category)
        }

        guard SafeSave.save(modelContext) else {
            modelContext.rollback()
            showSaveError = true
            return
        }

        budgetCreated = true

        let animation: Animation = reduceMotion
            ? .easeOut(duration: 0.2)
            : .spring(duration: 0.6)

        withAnimation(animation) {
            dialRotation += reduceMotion ? 0 : 90
            currentStep = .unlocked
        }
    }

    // MARK: - Skip Onboarding

    private func skipOnboarding() {
        let (month, year) = DateHelpers.currentBudgetPeriod(resetDay: resetDay)
        let budget = Budget(month: month, year: year, totalIncomeCents: 0, resetDay: resetDay)
        modelContext.insert(budget)

        let generalCategory = Category(
            name: "General",
            emoji: "\u{1F4E6}",
            budgetedAmountCents: 0,
            color: "#8E8E93",
            sortOrder: 0
        )
        generalCategory.budget = budget
        modelContext.insert(generalCategory)

        guard SafeSave.save(modelContext) else { return }

        withAnimation(.smooth(duration: 0.5)) {
            hasCompletedOnboarding = true
        }
    }

    // MARK: - Daily Reminders

    private func requestDailyReminders() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    NotificationService.scheduleDailyReminder(hour: 20)
                    dailyReminderEnabled = true
                }
            }
        }
    }
}

// MARK: - Pledge Apple Shield

/// HTML: a titanium-bordered double-circle with a checkmark centered
/// (VaultRevamp.html lines 1216-1220). Rendered as plain SwiftUI shapes
/// because the path is trivial and a PNG would rasterize poorly.
private struct PledgeAppleShield: View {
    var body: some View {
        ZStack {
            // Outer 14-radius ring (1.5px stroke) in titanium300
            Circle()
                .strokeBorder(BudgetVaultTheme.titanium300, lineWidth: 1.5)

            // Inner 10-radius ring (0.8px stroke)
            Circle()
                .strokeBorder(BudgetVaultTheme.titanium300, lineWidth: 0.8)
                .padding(4)

            // Checkmark — matches path "M10 16l4 4 8-8" from a 32x32 viewBox
            GeometryReader { geo in
                let s = geo.size.width / 32
                Path { p in
                    p.move(to: CGPoint(x: 10 * s, y: 16 * s))
                    p.addLine(to: CGPoint(x: 14 * s, y: 20 * s))
                    p.addLine(to: CGPoint(x: 22 * s, y: 12 * s))
                }
                .stroke(BudgetVaultTheme.titanium300,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Flow Layout (for currency chips)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentY += lineHeight + spacing
                currentX = 0
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: maxWidth, height: currentY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentY += lineHeight + spacing
                currentX = bounds.minX
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Full Currency Picker Sheet (reused from old code)

private struct FullCurrencyPickerSheet: View {
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var tempSelection = "USD"

    var body: some View {
        CurrencyPickerView(selectedCurrency: $tempSelection)
            .navigationTitle("Select Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSelect(tempSelection)
                        dismiss()
                    }
                }
            }
    }
}

