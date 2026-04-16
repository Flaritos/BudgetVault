import SwiftUI
import SwiftData
import UserNotifications
import BudgetVaultShared

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

    @State private var currentStep = 0 // 0=welcome, 1=currency, 2=income, 3=envelopes, 4=unlocked
    @State private var dialRotation: Double = 0
    @State private var tempCurrency = "USD"
    @State private var incomeText = ""
    @State private var selectedTemplate: BudgetTemplates.OnboardingTemplate = .single
    @State private var editableCategories: [(name: String, emoji: String, color: String, pct: Double)] = []
    @State private var showSaveError = false
    @State private var showCurrencyPicker = false
    @State private var budgetCreated = false
    @ScaledMetric(relativeTo: .largeTitle) private var incomeDisplaySize: CGFloat = 48

    private let categoryLimit = 6

    // Step progress: 0=0%, 1=25%, 2=50%, 3=75%, 4=100%
    private var stepProgress: Double {
        min(Double(currentStep) / 4.0, 1.0)
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
                // Skip button (top right, steps 2-3 only). v3.2: promoted
                // from subtle gray text to a visible pill chip.
                // v3.2 audit M7: HIDDEN on currency step (step 1) — skipping
                // currency leaves the app in an undefined state.
                if currentStep > 1 && currentStep < 4 {
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
                    case 0: welcomeStep
                    case 1: currencyStep
                    case 2: incomeStep
                    case 3: envelopeStep
                    case 4: unlockedStep
                    default: EmptyView()
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

    // MARK: - Step 0: Welcome

    private var welcomeStep: some View {
        VStack(spacing: BudgetVaultTheme.spacingXL) {
            Spacer()

            OnboardingVaultDial(
                size: 200,
                progress: 0,
                stepNumber: nil,
                stepLabel: nil,
                rotation: dialRotation,
                showLock: true,
                showUnlock: false
            )

            VStack(spacing: BudgetVaultTheme.spacingMD) {
                Text("BudgetVault")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text("Your budget. Your device. No one else.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)

                // v3.2 audit M1/L5: surface the strongest anti-positioning
                // claim at the exact moment users decide to stay.
                Text("No bank login. One-time price.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BudgetVaultTheme.accentSoft)
                    .padding(.top, BudgetVaultTheme.spacingXS)

                Text("4 quick steps — skip anytime")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.top, BudgetVaultTheme.spacingSM)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    advanceStep()
                } label: {
                    Text("Begin Setup")
                        .font(.headline)
                        .foregroundStyle(BudgetVaultTheme.navyDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white, in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusButton))
                }

                // v3.2 audit M2: explicit "skip for now" on welcome so the
                // fastest path to the app is a single tap.
                Button {
                    skipOnboarding()
                } label: {
                    Text("Skip for now")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.vertical, 8)
                }
                .accessibilityIdentifier("welcomeSkipButton")
            }
            .padding(.horizontal, BudgetVaultTheme.spacingXL)
            .padding(.bottom, BudgetVaultTheme.spacingXL)
        }
    }

    // MARK: - Step 1: Currency

    private var currencyStep: some View {
        VStack(spacing: BudgetVaultTheme.spacingXL) {
            OnboardingVaultDial(
                size: 150,
                progress: 0.25,
                stepNumber: 1,
                stepLabel: "CURRENCY",
                rotation: dialRotation,
                showLock: false,
                showUnlock: false
            )
            .padding(.top, BudgetVaultTheme.spacingLG)

            VStack(spacing: BudgetVaultTheme.spacingMD) {
                Text("What currency do you use?")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }

            // Currency chips
            currencyChips
                .padding(.horizontal, BudgetVaultTheme.spacingLG)

            Button {
                showCurrencyPicker = true
            } label: {
                HStack(spacing: 4) {
                    Text("More currencies")
                        .font(.subheadline)
                    Image(systemName: "arrow.right")
                        .font(.caption)
                }
                .foregroundStyle(BudgetVaultTheme.accentSoft)
            }

            Spacer()

            Button {
                selectedCurrency = tempCurrency
                advanceStep()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .foregroundStyle(BudgetVaultTheme.navyDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.white, in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusButton))
            }
            .padding(.horizontal, BudgetVaultTheme.spacingXL)
            .padding(.bottom, BudgetVaultTheme.spacingXL)
        }
    }

    private var currencyChips: some View {
        let currencies: [(code: String, flag: String)] = [
            ("USD", "\u{1F1FA}\u{1F1F8}"),
            ("EUR", "\u{1F1EA}\u{1F1FA}"),
            ("GBP", "\u{1F1EC}\u{1F1E7}"),
            ("CAD", "\u{1F1E8}\u{1F1E6}"),
            ("AUD", "\u{1F1E6}\u{1F1FA}"),
            ("JPY", "\u{1F1EF}\u{1F1F5}"),
        ]

        return FlowLayout(spacing: 10) {
            ForEach(currencies, id: \.code) { currency in
                Button {
                    tempCurrency = currency.code
                } label: {
                    HStack(spacing: 6) {
                        Text(currency.flag)
                            .font(.title3)
                        Text(currency.code)
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        tempCurrency == currency.code
                            ? AnyShapeStyle(BudgetVaultTheme.accentSoft.opacity(0.35))
                            : AnyShapeStyle(Color.white.opacity(0.12)),
                        in: Capsule()
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                tempCurrency == currency.code
                                    ? BudgetVaultTheme.accentSoft
                                    : Color.clear,
                                lineWidth: 1.5
                            )
                    )
                    .accessibilityAddTraits(tempCurrency == currency.code ? .isSelected : [])
                }
            }
        }
    }

    // MARK: - Step 2: Income

    private var incomeStep: some View {
        VStack(spacing: BudgetVaultTheme.spacingMD) {
            OnboardingVaultDial(
                size: 140,
                progress: 0.5,
                stepNumber: 2,
                stepLabel: "INCOME",
                rotation: dialRotation,
                showLock: false,
                showUnlock: false
            )
            .padding(.top, BudgetVaultTheme.spacingSM)

            VStack(spacing: BudgetVaultTheme.spacingSM) {
                Text("Monthly take-home pay")
                    .font(.title3.bold())
                    .foregroundStyle(.white)

                Text("After taxes \u{00B7} stays on your device")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }

            // Large amount display.
            // v3.2 audit M6: format with thousands separators so $5,000 matches
            // the dashboard instead of "$5000".
            Text(formattedIncomeDisplay)
                .font(.system(size: min(incomeDisplaySize, 64), weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, BudgetVaultTheme.spacingSM)
                .contentTransition(.numericText())

            // Number pad (reuse ChatNumberPadView keys inline for dark theme)
            onboardingNumberPad
                .padding(.horizontal, BudgetVaultTheme.spacingXL)

            Spacer(minLength: BudgetVaultTheme.spacingMD)

            let hasIncome = (MoneyHelpers.parseCurrencyString(incomeText) ?? 0) > 0

            Button {
                advanceStep()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .foregroundStyle(hasIncome ? BudgetVaultTheme.navyDark : .white.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        hasIncome
                            ? AnyShapeStyle(Color.white)
                            : AnyShapeStyle(Color.white.opacity(0.08)),
                        in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusButton)
                    )
            }
            .disabled(!hasIncome)
            .padding(.horizontal, BudgetVaultTheme.spacingXL)
            .padding(.bottom, BudgetVaultTheme.spacingLG)
        }
    }

    private var onboardingNumberPad: some View {
        let keys: [[String]] = [
            ["1", "2", "3"],
            ["4", "5", "6"],
            ["7", "8", "9"],
            [".", "0", "\u{232B}"],
        ]

        return VStack(spacing: BudgetVaultTheme.spacingSM) {
            ForEach(keys, id: \.self) { row in
                HStack(spacing: BudgetVaultTheme.spacingSM) {
                    ForEach(row, id: \.self) { key in
                        Button {
                            handleNumberKey(key)
                        } label: {
                            Text(key)
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD)
                                        .fill(Color.white.opacity(0.08))
                                )
                        }
                        .accessibilityLabel(key == "\u{232B}" ? "Delete" : key)
                    }
                }
            }
        }
    }

    /// Formatted display for the income entry — always uses thousands
    /// separators to match the dashboard formatting (v3.2 audit M6).
    private var formattedIncomeDisplay: String {
        if incomeText.isEmpty { return CurrencyFormatter.displayAmount(text: "") }
        guard let cents = MoneyHelpers.parseCurrencyString(incomeText), cents > 0 else {
            return CurrencyFormatter.displayAmount(text: incomeText)
        }
        return CurrencyFormatter.format(cents: cents, currencyCode: selectedCurrency)
    }

    private func handleNumberKey(_ key: String) {
        HapticManager.impact(.light)

        if key == "\u{232B}" {
            if !incomeText.isEmpty { incomeText.removeLast() }
            return
        }
        if key == "." {
            if incomeText.contains(".") { return }
            incomeText += incomeText.isEmpty ? "0." : "."
            return
        }
        // Max 2 decimal places
        if let dotIndex = incomeText.firstIndex(of: ".") {
            let decimals = incomeText[incomeText.index(after: dotIndex)...]
            if decimals.count >= 2 { return }
        }
        // Prevent leading zeros
        if incomeText == "0" && key != "." {
            incomeText = key
            return
        }
        if incomeText.count < 10 {
            incomeText += key
        }
    }

    // MARK: - Step 3: Envelopes

    private var envelopeStep: some View {
        VStack(spacing: BudgetVaultTheme.spacingMD) {
            OnboardingVaultDial(
                size: 120,
                progress: 0.75,
                stepNumber: 3,
                stepLabel: "ENVELOPES",
                rotation: dialRotation,
                showLock: false,
                showUnlock: false
            )
            .padding(.top, BudgetVaultTheme.spacingSM)

            Text("Choose a template")
                .font(.title3.bold())
                .foregroundStyle(.white)

            Text("Divide your income into spending categories. Each category gets a portion of your monthly budget.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, BudgetVaultTheme.spacingLG)

            // Horizontal template scroll
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

            Button {
                createBudget()
            } label: {
                Text("Looks Good")
                    .font(.headline)
                    .foregroundStyle(editableCategories.isEmpty ? .white.opacity(0.3) : BudgetVaultTheme.navyDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        editableCategories.isEmpty
                            ? AnyShapeStyle(Color.white.opacity(0.08))
                            : AnyShapeStyle(Color.white),
                        in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusButton)
                    )
            }
            .disabled(editableCategories.isEmpty)
            .padding(.horizontal, BudgetVaultTheme.spacingXL)
            .padding(.bottom, BudgetVaultTheme.spacingLG)
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

    // MARK: - Step 4: Vault Unlocked

    private var unlockedStep: some View {
        VStack(spacing: BudgetVaultTheme.spacingXL) {
            Spacer()

            OnboardingVaultDial(
                size: 220,
                progress: 1.0,
                stepNumber: nil,
                stepLabel: nil,
                rotation: dialRotation,
                showLock: false,
                showUnlock: true
            )

            VStack(spacing: BudgetVaultTheme.spacingMD) {
                // v3.2 audit M2: was blue→purple gradient; purple is the only
                // purple in the app so it looked off-brand. Single-hue cyan
                // gradient keeps the palette disciplined.
                Text("Ready to Go")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [BudgetVaultTheme.accentSoft, BudgetVaultTheme.accentSoft],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("Your budget is set. Your data is safe.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: BudgetVaultTheme.spacingMD) {
                // v3.2 audit H9: biometric lock prompt — opt-in, on-brand,
                // defaults to ON for users with Face ID / Touch ID enrolled.
                Toggle(isOn: $biometricLockEnabled) {
                    HStack(spacing: 8) {
                        Image(systemName: "faceid")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                        Text("Lock the vault with Face ID")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: BudgetVaultTheme.accentSoft))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusMD)
                        .fill(Color.white.opacity(0.06))
                )

                Button {
                    // Round 7 P4: persist the user's Face ID choice.
                    persistedBiometricLock = biometricLockEnabled
                    withAnimation(.smooth(duration: 0.5)) {
                        hasCompletedOnboarding = true
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        // v3.2 audit L6: "Open My Vault" collides with "Unlock
                        // the Vault" on the premium paywall — two "vaults".
                        // Rename to clarify this is just "enter the app".
                        Text("Start Budgeting")
                    }
                    .font(.headline)
                    .foregroundStyle(BudgetVaultTheme.navyDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.white, in: RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusButton))
                }
            }
            .padding(.horizontal, BudgetVaultTheme.spacingXL)
            .padding(.bottom, BudgetVaultTheme.spacingXL)
        }
    }

    // MARK: - Step Advancement

    private func advanceStep() {
        let animation: Animation = reduceMotion
            ? .easeOut(duration: 0.2)
            : .spring(duration: 0.6)

        withAnimation(animation) {
            dialRotation += reduceMotion ? 0 : 90
            currentStep += 1
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
            currentStep = 4
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

