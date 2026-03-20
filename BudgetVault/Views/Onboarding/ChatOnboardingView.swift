import SwiftUI
import SwiftData
import UserNotifications

// MARK: - Chat Step

private enum ChatStep: Int, CaseIterable {
    case welcome = 0
    case currency
    case income
    case template
    case categories
    case notifications
    case complete
}

// MARK: - Chat Message

private struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isBot: Bool
    var responseType: ResponseType?

    enum ResponseType {
        case currency
        case numberPad
        case templatePicker
        case categoryEditor
        case yesNo
        case completion
    }
}

// MARK: - Chat Onboarding View

struct ChatOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage(AppStorageKeys.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @AppStorage(AppStorageKeys.selectedCurrency) private var selectedCurrency = "USD"
    @AppStorage(AppStorageKeys.resetDay) private var resetDay = 1
    @AppStorage(AppStorageKeys.dailyReminderEnabled) private var dailyReminderEnabled = false

    @State private var messages: [ChatMessage] = []
    @State private var currentStep: ChatStep = .welcome
    @State private var showTyping = false
    @State private var incomeText = ""
    @State private var selectedTemplate: BudgetTemplates.OnboardingTemplate = .single
    @State private var editableCategories: [(name: String, emoji: String, color: String, pct: Double)] = []
    @State private var budgetCreated = false

    // Vault dial animation
    @State private var dialRotation: Double = 0
    @State private var dialUnlocked = false

    private let categoryLimit = 6

    private var currencySymbol: String {
        CurrencyPickerView.currencies.first { $0.code == selectedCurrency }?.symbol ?? "$"
    }

    var body: some View {
        ZStack {
            // Navy dark background
            BudgetVaultTheme.navyDark
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar with vault dial + skip
                topBar

                // Chat messages
                chatContent

                // Input area based on current step
                inputArea
            }
        }
        .task {
            await startWelcomeSequence()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Spacer()

            VaultDialMark(size: 60, showGlow: dialUnlocked, tickRotation: dialRotation)
                .opacity(dialUnlocked ? 1 : 0.6)

            Spacer()

            Button {
                skipOnboarding()
            } label: {
                Text("Skip")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Chat Content

    private var chatContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        ChatBubbleView(text: message.text, isBot: message.isBot)
                            .id(message.id)
                    }

                    if showTyping {
                        TypingIndicatorView()
                            .id("typing")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation {
                    if let last = messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: showTyping) { _, isTyping in
                if isTyping {
                    withAnimation {
                        proxy.scrollTo("typing", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Input Area

    @ViewBuilder
    private var inputArea: some View {
        switch currentStep {
        case .welcome:
            EmptyView()

        case .currency:
            CurrencyChipPicker { code in
                selectedCurrency = code
                addUserMessage("I use \(code)")
                advanceAfterDelay(to: .income, botMessage: "Great choice! Now, what's your monthly take-home income? This helps us divide your money into envelopes.")
            }
            .padding(.bottom, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))

        case .income:
            VStack(spacing: 12) {
                ChatNumberPadView(text: $incomeText, currencySymbol: currencySymbol)

                if let cents = MoneyHelpers.parseCurrencyString(incomeText), cents > 0 {
                    Button {
                        let formatted = CurrencyFormatter.format(cents: cents)
                        addUserMessage(formatted)
                        advanceAfterDelay(to: .template, botMessage: "Perfect! Now pick a template to get started quickly. You can customize everything next.")
                    } label: {
                        Text("Confirm")
                            .font(.headline)
                            .foregroundStyle(BudgetVaultTheme.navyDark)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 24)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.bottom, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))

        case .template:
            ChatTemplatePicker { template in
                selectedTemplate = template
                editableCategories = Array(template.categories.prefix(categoryLimit))
                addUserMessage(template.rawValue)
                if template == .custom {
                    // Start with one empty category for custom
                    editableCategories = [("New Category", "\u{1F4E6}", "#8E8E93", 0.20)]
                    advanceAfterDelay(to: .categories, botMessage: "Starting from scratch! Add up to \(categoryLimit) categories below. Adjust the percentages to divide your income.")
                } else {
                    advanceAfterDelay(to: .categories, botMessage: "Here are your categories. Edit names, adjust percentages with +/-, or remove any you don't need. Max \(categoryLimit) categories.")
                }
            }
            .padding(.bottom, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))

        case .categories:
            VStack(spacing: 12) {
                ChatCategoryEditor(categories: $editableCategories, categoryLimit: categoryLimit)

                if !editableCategories.isEmpty {
                    let totalPct = editableCategories.reduce(0.0) { $0 + $1.pct }
                    Text("Total: \(Int(totalPct * 100))%")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))

                    Button {
                        let catNames = editableCategories.map { $0.emoji + " " + $0.name }.joined(separator: ", ")
                        addUserMessage("My categories: \(catNames)")
                        createBudget()
                        advanceAfterDelay(to: .notifications, botMessage: "Your budget is created! Would you like a daily reminder to log your expenses? Most users find 8pm works great.")
                    } label: {
                        Text("Looks good!")
                            .font(.headline)
                            .foregroundStyle(BudgetVaultTheme.navyDark)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 24)
                }
            }
            .padding(.bottom, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))

        case .notifications:
            ChatYesNoButtons(
                onYes: {
                    addUserMessage("Yes, remind me!")
                    requestNotifications()
                },
                onNo: {
                    addUserMessage("Not now")
                    advanceAfterDelay(to: .complete, botMessage: "No problem! You can always enable reminders in Settings.\n\nYour budget is set up! Explore your Home screen to see your daily allowance and envelope cards.")
                }
            )
            .padding(.bottom, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))

        case .complete:
            ChatCompletionButton {
                withAnimation(.smooth(duration: 0.5)) {
                    hasCompletedOnboarding = true
                }
            }
            .padding(.bottom, 24)
            .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: - Welcome Sequence

    private func startWelcomeSequence() async {
        // Animate vault dial
        if reduceMotion {
            dialRotation = 240
            dialUnlocked = true
        } else {
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.easeInOut(duration: 1.0)) {
                dialRotation = 270
            }
            try? await Task.sleep(for: .milliseconds(1000))
            withAnimation(.easeOut(duration: 0.25)) {
                dialRotation = 240
            }
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                dialUnlocked = true
            }
        }

        try? await Task.sleep(for: .milliseconds(400))

        // Bot welcome messages
        await showBotMessage("Welcome to BudgetVault!")
        try? await Task.sleep(for: .milliseconds(800))
        await showBotMessage("I'll help you set up your first budget in under a minute. Your data stays on your device -- always.")
        try? await Task.sleep(for: .milliseconds(800))
        await showBotMessage("First, what currency do you use?")

        await MainActor.run {
            withAnimation(.easeOut(duration: 0.3)) {
                currentStep = .currency
            }
        }
    }

    // MARK: - Helpers

    @MainActor
    private func showBotMessage(_ text: String) async {
        showTyping = true
        let delay = reduceMotion ? 300 : 600
        try? await Task.sleep(for: .milliseconds(delay))
        showTyping = false
        withAnimation(.easeOut(duration: 0.25)) {
            messages.append(ChatMessage(text: text, isBot: true))
        }
    }

    private func addUserMessage(_ text: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            messages.append(ChatMessage(text: text, isBot: false))
        }
    }

    private func advanceAfterDelay(to step: ChatStep, botMessage: String) {
        Task {
            await showBotMessage(botMessage)
            try? await Task.sleep(for: .milliseconds(300))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    currentStep = step
                }
            }
        }
    }

    // MARK: - Budget Creation

    private func createBudget() {
        guard !budgetCreated else { return }
        guard let incomeCents = MoneyHelpers.parseCurrencyString(incomeText), incomeCents > 0 else { return }

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

        SafeSave.save(modelContext)
        budgetCreated = true
    }

    // MARK: - Notifications

    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    NotificationService.scheduleDailyReminder(hour: 20)
                    dailyReminderEnabled = true
                    addUserMessage("Reminders enabled!")
                }
                advanceAfterDelay(to: .complete, botMessage: granted
                    ? "You'll get a gentle nudge at 8pm each day.\n\nYour budget is set up! Explore your Home screen to see your daily allowance and envelope cards."
                    : "No worries! You can enable reminders later in Settings.\n\nYour budget is set up! Explore your Home screen to see your daily allowance and envelope cards."
                )
            }
        }
    }

    // MARK: - Skip

    private func skipOnboarding() {
        withAnimation(.smooth(duration: 0.5)) {
            hasCompletedOnboarding = true
        }
    }
}
