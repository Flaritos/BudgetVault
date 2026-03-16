import SwiftUI
import SwiftData
import UserNotifications

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppStorageKeys.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @AppStorage(AppStorageKeys.selectedCurrency) private var selectedCurrency = "USD"
    @AppStorage(AppStorageKeys.resetDay) private var resetDay = 1
    @AppStorage(AppStorageKeys.dailyReminderEnabled) private var dailyReminderEnabled = false

    @State private var currentPage = 0
    @State private var monthlyIncome = ""
    @State private var tempCurrency = "USD"
    @State private var selectedTemplate: BudgetTemplate = .single
    @State private var selectedCategories: [(name: String, emoji: String, color: String, pct: Double)] = Array(BudgetTemplate.single.categories.prefix(4))
    @State private var budgetCreated = false
    @State private var showCelebrationCheck = false
    @State private var stepIconScales: [Int: CGFloat] = [:]
    @State private var dialRotation: Double = 0
    @State private var dialUnlocked = false
    @State private var showWelcomeText = false
    @State private var showCategoryCapWarning = false

    private let totalPages = 7
    private let freeCategoryLimit = 4

    private func stepIndicator(current: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<totalPages, id: \.self) { i in
                Circle()
                    .fill(i <= current ? BudgetVaultTheme.electricBlue : Color.gray.opacity(0.3))
                    .frame(width: i == current ? 10 : 7, height: i == current ? 10 : 7)
            }
        }
        .padding(.top, 16)
    }

    private var selectedCurrencySymbol: String {
        CurrencyPickerView.currencies.first { $0.code == tempCurrency }?.symbol ?? "$"
    }

    // MARK: - Budget Templates

    private enum BudgetTemplate: String, CaseIterable {
        case single = "Single"
        case couple = "Couple"
        case family = "Family"
        case custom = "Custom"

        var icon: String {
            switch self {
            case .single: return "person.fill"
            case .couple: return "person.2.fill"
            case .family: return "person.3.fill"
            case .custom: return "slider.horizontal.3"
            }
        }

        var categories: [(name: String, emoji: String, color: String, pct: Double)] {
            switch self {
            case .single:
                return [
                    ("Rent", "\u{1F3E0}", "#5856D6", 0.30),
                    ("Groceries", "\u{1F6D2}", "#34C759", 0.15),
                    ("Transport", "\u{1F697}", "#FF9500", 0.10),
                    ("Dining Out", "\u{1F37D}\u{FE0F}", "#FF2D55", 0.10),
                    ("Entertainment", "\u{1F3AC}", "#AF52DE", 0.05),
                    ("Savings", "\u{1F3E6}", "#007AFF", 0.10),
                ]
            case .couple:
                return [
                    ("Housing", "\u{1F3E0}", "#5856D6", 0.30),
                    ("Groceries", "\u{1F6D2}", "#34C759", 0.15),
                    ("Dining Out", "\u{1F37D}\u{FE0F}", "#FF2D55", 0.10),
                    ("Transport", "\u{1F697}", "#FF9500", 0.10),
                    ("Date Night", "\u{2764}\u{FE0F}", "#AF52DE", 0.05),
                    ("Savings", "\u{1F3E6}", "#007AFF", 0.10),
                ]
            case .family:
                return [
                    ("Housing", "\u{1F3E0}", "#5856D6", 0.30),
                    ("Groceries", "\u{1F6D2}", "#34C759", 0.15),
                    ("Kids", "\u{1F476}", "#FF2D55", 0.10),
                    ("Transport", "\u{1F697}", "#FF9500", 0.10),
                    ("Utilities", "\u{1F4A1}", "#FFCC00", 0.05),
                    ("Savings", "\u{1F3E6}", "#007AFF", 0.10),
                ]
            case .custom:
                return []
            }
        }
    }

    var body: some View {
        TabView(selection: $currentPage) {
            welcomePage.tag(0)
            envelopeExplainerPage.tag(1)
            currencyPage.tag(2)
            templatePage.tag(3)
            budgetSetupPage.tag(4)
            celebrationPage.tag(5)
            notificationPage.tag(6)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut, value: currentPage)
        .highPriorityGesture(DragGesture())
        .onAppear { tempCurrency = selectedCurrency }
    }

    // MARK: - Brand Overlay

    private var subtleTopGradient: some View {
        VStack {
            LinearGradient(
                colors: [BudgetVaultTheme.navyDark.opacity(0.05), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .allowsHitTesting(false)
            Spacer()
        }
        .ignoresSafeArea()
    }

    // MARK: - Page 0: Welcome + Privacy

    private var welcomePage: some View {
        ZStack {
            BudgetVaultTheme.navyDark
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Animated vault dial
                VaultDialMark(size: 160, showGlow: true, tickRotation: dialRotation)
                    .opacity(dialUnlocked ? 1 : 0.7)

                Spacer()
                    .frame(height: 48)

                // Dial mark + title
                HStack(spacing: 12) {
                    VaultDialMark(size: 36)

                    Text("BudgetVault")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .opacity(showWelcomeText ? 1 : 0)
                .offset(y: showWelcomeText ? 0 : 12)

                Text("Your budget. Your device. No one else.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
                    .opacity(showWelcomeText ? 1 : 0)
                    .offset(y: showWelcomeText ? 0 : 8)

                Spacer()

                Button {
                    // Spin the dial again then navigate
                    withAnimation(.easeInOut(duration: 0.6)) {
                        dialRotation += 360
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation { currentPage = 1 }
                    }
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundStyle(BudgetVaultTheme.electricBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
                .opacity(showWelcomeText ? 1 : 0)
            }
        }
        .task {
            // Small delay to ensure view is visible before animating
            try? await Task.sleep(for: .milliseconds(400))
            guard !dialUnlocked else { return }
            withAnimation(.easeInOut(duration: 1.2)) {
                dialRotation = 270
            }
            try? await Task.sleep(for: .milliseconds(1200))
            withAnimation(.easeOut(duration: 0.3)) {
                dialRotation = 240
            }
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                dialUnlocked = true
            }
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.easeOut(duration: 0.6)) {
                showWelcomeText = true
            }
        }
    }

    // MARK: - Page 1: Envelope Explainer

    private var envelopeExplainerPage: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            subtleTopGradient

            VStack(spacing: 24) {
                stepIndicator(current: 1)

                Spacer()

                Image(systemName: "tray.2.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(BudgetVaultTheme.electricBlue)
                    .symbolEffect(.pulse)

                Text("Envelope Budgeting")
                    .font(.title2.bold())

                VStack(alignment: .leading, spacing: 16) {
                    explainerStep(number: "1", text: "Divide your income into spending categories", index: 0)
                    explainerStep(number: "2", text: "Spend from each envelope throughout the month", index: 1)
                    explainerStep(number: "3", text: "When an envelope is empty, stop or move money", index: 2)
                }
                .padding(.horizontal, 32)
                .onAppear {
                    for i in 0..<3 {
                        stepIconScales[i] = 0.3
                    }
                    for i in 0..<3 {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(Double(i) * 0.15)) {
                            stepIconScales[i] = 1.0
                        }
                    }
                }

                Text("It's the method behind YNAB, used by millions \u{2014} now private and on your device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                HStack(spacing: 12) {
                    Button { withAnimation { currentPage = 0 } } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .frame(width: 52, height: 52)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    }
                    Button { withAnimation { currentPage = 2 } } label: { Text("Continue") }
                        .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }

    private func explainerStep(number: String, text: String, index: Int) -> some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(BudgetVaultTheme.electricBlue, in: Circle())
                .scaleEffect(stepIconScales[index] ?? 1.0)
            Text(text)
                .font(.subheadline)
        }
    }

    // MARK: - Page 2: Currency

    private var currencyPage: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            subtleTopGradient

            VStack(spacing: 16) {
                stepIndicator(current: 2)

                Text(selectedCurrencySymbol)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 80, height: 80)
                    .background(BudgetVaultTheme.electricBlue, in: Circle())
                    .padding(.top, 8)

                Text("Choose Your Currency")
                    .font(.title2.bold())

                Text("You can change this later in Settings")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                CurrencyPickerView(selectedCurrency: $tempCurrency)

                HStack(spacing: 12) {
                    Button { withAnimation { currentPage = 1 } } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .frame(width: 52, height: 52)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    }
                    Button {
                        selectedCurrency = tempCurrency
                        withAnimation { currentPage = 3 }
                    } label: {
                        Text("Continue")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Page 3: Template Selection + Category Customization

    private var templatePage: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            subtleTopGradient

            VStack(spacing: 16) {
                stepIndicator(current: 3)

                Text("Choose a Template")
                    .font(.title2.bold())

                Text("Pick a starting point, then customize your categories.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(BudgetTemplate.allCases, id: \.rawValue) { template in
                        let isSelected = selectedTemplate == template
                        Button {
                            selectedTemplate = template
                            selectedCategories = Array(template.categories.prefix(freeCategoryLimit))
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: template.icon)
                                    .font(.title2)
                                Text(template.rawValue)
                                    .font(.subheadline.bold())

                                if !template.categories.isEmpty {
                                    HStack(spacing: 2) {
                                        ForEach(template.categories.indices, id: \.self) { i in
                                            let cat = template.categories[i]
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(Color(hex: cat.color))
                                                .frame(width: max(4, CGFloat(cat.pct) * 80), height: 6)
                                        }
                                    }
                                    .padding(.top, 2)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isSelected ? BudgetVaultTheme.electricBlue.opacity(0.1) : Color(.secondarySystemBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(isSelected ? BudgetVaultTheme.electricBlue : Color.clear, lineWidth: 2)
                            )
                            .shadow(color: isSelected ? BudgetVaultTheme.electricBlue.opacity(0.3) : Color.clear, radius: 8, y: 2)
                        }
                        .foregroundStyle(isSelected ? BudgetVaultTheme.electricBlue : .primary)
                    }
                }
                .padding(.horizontal, 24)

                if !selectedCategories.isEmpty {
                    List {
                        ForEach(selectedCategories.indices, id: \.self) { index in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color(hex: selectedCategories[index].color))
                                    .frame(width: 8, height: 8)
                                Text(selectedCategories[index].emoji)
                                    .font(.title3)
                                TextField("Category name", text: Binding(
                                    get: { selectedCategories[index].name },
                                    set: { selectedCategories[index].name = $0 }
                                ))
                                .textFieldStyle(.plain)
                                Spacer()
                                Text("\(Int(selectedCategories[index].pct * 100))%")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color(.systemGray5), in: Capsule())
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    selectedCategories.remove(at: index)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }

                        if selectedCategories.count < freeCategoryLimit {
                            Button {
                                selectedCategories.append(("New Category", "\u{1F4E6}", "#8E8E93", 0.05))
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                    Text("Add Category")
                                        .foregroundStyle(Color.accentColor)
                                    Spacer()
                                    Text("\(selectedCategories.count)/\(freeCategoryLimit)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(.secondary)
                                Text("Upgrade to Premium for more categories")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                } else {
                    List {
                        Button {
                            selectedCategories.append(("New Category", "\u{1F4E6}", "#8E8E93", 0.05))
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                                Text("Add Category")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .listStyle(.plain)
                }

                HStack(spacing: 12) {
                    Button { withAnimation { currentPage = 2 } } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .frame(width: 52, height: 52)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    }
                    Button {
                        withAnimation { currentPage = 4 }
                    } label: {
                        Text("Continue")
                    }
                    .buttonStyle(PrimaryButtonStyle(isEnabled: !selectedCategories.isEmpty))
                    .disabled(selectedCategories.isEmpty)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Page 4: Income Entry + Preview

    private var budgetSetupPage: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            subtleTopGradient

            ScrollView {
                VStack(spacing: 24) {
                    stepIndicator(current: 4)

                    Text("Set Your Monthly Income")
                        .font(.title2.bold())

                    let totalPct = selectedCategories.reduce(0.0) { $0 + $1.pct }
                    let pctString = String(format: "%.0f", totalPct * 100)
                    Text("We'll allocate \(pctString)% across your \(selectedCategories.count) categories. You can customize everything later.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    HStack {
                        Text(currencySymbol)
                            .font(.title)
                            .foregroundStyle(.secondary)
                        TextField("0", text: $monthlyIncome)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.secondarySystemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(Color(.separator), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 40)

                    if let cents = MoneyHelpers.parseCurrencyString(monthlyIncome), cents > 0 {
                        let maxPct = selectedCategories.map(\.pct).max() ?? 1.0
                        let totalPctVal = selectedCategories.reduce(0.0) { $0 + $1.pct }
                        let allocated = selectedCategories.reduce(Int64(0)) { $0 + Int64(Double(cents) * $1.pct) }
                        VStack(spacing: 10) {
                            ForEach(selectedCategories.indices, id: \.self) { index in
                                let cat = selectedCategories[index]
                                let catCents = Int64(Double(cents) * cat.pct)
                                let barFraction = maxPct > 0 ? cat.pct / maxPct : 0
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("\(cat.emoji) \(cat.name) (\(Int(cat.pct * 100))%)")
                                        Spacer()
                                        Text(CurrencyFormatter.format(cents: catCents))
                                            .foregroundStyle(.secondary)
                                    }
                                    .font(.subheadline)

                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Color(.systemGray5))
                                                .frame(height: 6)
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Color(hex: cat.color))
                                                .frame(width: max(4, geo.size.width * barFraction), height: 6)
                                        }
                                    }
                                    .frame(height: 6)
                                }
                            }

                            if totalPctVal < 1.0 {
                                let unallocatedPct = Int((1.0 - totalPctVal) * 100)
                                HStack {
                                    Text("Unallocated (\(unallocatedPct)%)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(CurrencyFormatter.format(cents: cents - allocated))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.horizontal, 40)

                        Text("Total allocated: \(CurrencyFormatter.format(cents: allocated))")
                            .font(.subheadline.bold())
                            .foregroundStyle(BudgetVaultTheme.electricBlue)
                            .padding(.horizontal, 40)
                    }

                    HStack(spacing: 12) {
                        Button { withAnimation { currentPage = 3 } } label: {
                            Image(systemName: "chevron.left")
                                .font(.headline)
                                .frame(width: 52, height: 52)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                        }
                        Button {
                            completeOnboarding()
                        } label: {
                            Text("Create My Budget")
                        }
                        .buttonStyle(PrimaryButtonStyle(isEnabled: isValidIncome))
                        .disabled(!isValidIncome)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }

    // MARK: - Page 5: Celebration

    private var celebrationPage: some View {
        ZStack {
            BudgetVaultTheme.brandGradient
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VaultDialMark(size: 120, showGlow: true)
                    .scaleEffect(showCelebrationCheck ? 1.0 : 0.3)
                    .opacity(showCelebrationCheck ? 1.0 : 0.0)

                Text("You're All Set!")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                Text("Your first budget is ready to go.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.75))

                Spacer()

                Button {
                    withAnimation { currentPage = 6 }
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(BudgetVaultTheme.electricBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showCelebrationCheck = true
            }
        }
    }

    // MARK: - Page 6: Notifications

    private var notificationPage: some View {
        ZStack {
            BudgetVaultTheme.brandGradient
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)

                Text("Stay on Track")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("A daily reminder helps you log expenses before you forget. Most BudgetVault users log at 8pm.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    requestNotificationPermission()
                } label: {
                    Text("Enable Daily Reminder")
                        .font(.headline)
                        .foregroundStyle(BudgetVaultTheme.electricBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 40)

                Button {
                    finishOnboarding()
                } label: {
                    Text("Not Now")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()
            }
        }
    }

    // MARK: - Helpers

    private var isValidIncome: Bool {
        guard let cents = MoneyHelpers.parseCurrencyString(monthlyIncome) else { return false }
        return cents > 0
    }

    private var currencySymbol: String {
        CurrencyPickerView.currencies.first { $0.code == selectedCurrency }?.symbol ?? "$"
    }

    private func completeOnboarding() {
        guard !budgetCreated else { return }
        guard let incomeCents = MoneyHelpers.parseCurrencyString(monthlyIncome), incomeCents > 0 else { return }

        let (month, year) = DateHelpers.currentBudgetPeriod(resetDay: resetDay)
        let budget = Budget(month: month, year: year, totalIncomeCents: incomeCents, resetDay: resetDay)
        modelContext.insert(budget)

        // Free tier: cap at 4 categories (onboarding always runs before any purchase)
        let categoriesToCreate = Array(selectedCategories.prefix(4))
        for (index, cat) in categoriesToCreate.enumerated() {
            let catCents = Int64(Double(incomeCents) * cat.pct)
            let category = Category(name: cat.name, emoji: cat.emoji, budgetedAmountCents: catCents, color: cat.color, sortOrder: index)
            category.budget = budget
            modelContext.insert(category)
        }

        SafeSave.save(modelContext)
        budgetCreated = true
        withAnimation { currentPage = 5 }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    NotificationService.scheduleDailyReminder(hour: 20)
                    dailyReminderEnabled = true
                }
                finishOnboarding()
            }
        }
    }

    private func finishOnboarding() {
        hasCompletedOnboarding = true
    }
}

