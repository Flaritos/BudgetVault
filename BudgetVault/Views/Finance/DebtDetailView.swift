import SwiftUI
import SwiftData

struct DebtDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var debt: DebtAccount

    @State private var showLogPayment = false
    @State private var showEditDebt = false
    @State private var paymentAmountText = ""
    @State private var paymentNote = ""
    @FocusState private var isInputFocused: Bool

    private var sortedPayments: [DebtPayment] {
        (debt.payments ?? []).sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            headerSection
            payoffProjectionSection
            paymentHistorySection
        }
        .navigationTitle(debt.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showLogPayment = true
                    } label: {
                        Label("Log Payment", systemImage: "dollarsign.circle")
                    }
                    Button {
                        showEditDebt = true
                    } label: {
                        Label("Edit Debt", systemImage: "pencil")
                    }
                    if debt.currentBalanceCents <= 0 {
                        Button {
                            debt.isActive = false
                            if !SafeSave.save(modelContext) {
                                debt.isActive = true
                                modelContext.rollback()
                                return
                            }
                            dismiss()
                        } label: {
                            Label("Mark as Paid Off", systemImage: "checkmark.circle")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More options")
            }
        }
        .sheet(isPresented: $showLogPayment) {
            logPaymentSheet
        }
        .sheet(isPresented: $showEditDebt) {
            editDebtSheet
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        Section {
            VStack(spacing: BudgetVaultTheme.spacingLG) {
                // Emoji and name
                Text(debt.emoji)
                    .font(.system(size: 48))

                // Current balance
                VStack(spacing: BudgetVaultTheme.spacingXS) {
                    Text("Current Balance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.format(cents: debt.currentBalanceCents))
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(debt.currentBalanceCents > 0 ? BudgetVaultTheme.negative : BudgetVaultTheme.positive)
                }

                // Progress
                VStack(spacing: BudgetVaultTheme.spacingXS) {
                    ProgressView(value: debt.paidOffPercentage)
                        .tint(BudgetVaultTheme.positive)

                    HStack {
                        Text("\(Int(debt.paidOffPercentage * 100))% paid off")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Original: \(CurrencyFormatter.format(cents: debt.originalBalanceCents))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Details grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BudgetVaultTheme.spacingMD) {
                    detailCard(title: "Interest Rate", value: debt.interestRate > 0 ? String(format: "%.2f%%", debt.interestRate) : "0%")
                    detailCard(title: "Min. Payment", value: CurrencyFormatter.format(cents: debt.minimumPaymentCents))
                    detailCard(title: "Due Day", value: "Day \(debt.dueDay)")
                    detailCard(title: "Total Paid", value: CurrencyFormatter.format(cents: debt.totalPaidCents))
                }
            }
            .padding(.vertical, BudgetVaultTheme.spacingSM)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(debt.emoji) \(debt.name): current balance \(CurrencyFormatter.format(cents: debt.currentBalanceCents)), \(Int(debt.paidOffPercentage * 100)) percent paid off, original \(CurrencyFormatter.format(cents: debt.originalBalanceCents))")
        }
    }

    private func detailCard(title: String, value: String) -> some View {
        VStack(spacing: BudgetVaultTheme.spacingXS) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
        }
        .frame(maxWidth: .infinity)
        .padding(BudgetVaultTheme.spacingSM)
        .background(
            RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusSM)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Payoff Projection

    private var payoffProjectionSection: some View {
        Section("Payoff Projection") {
            if let months = debt.estimatedMonthsToPayoff {
                VStack(alignment: .leading, spacing: BudgetVaultTheme.spacingSM) {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(BudgetVaultTheme.electricBlue)
                        Text("At minimum payments:")
                            .font(.subheadline)
                    }

                    let years = months / 12
                    let remainingMonths = months % 12
                    HStack(alignment: .firstTextBaseline) {
                        if years > 0 {
                            Text("\(years)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                            Text(years == 1 ? "year" : "years")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if remainingMonths > 0 || years == 0 {
                            Text("\(remainingMonths)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                            Text(remainingMonths == 1 ? "month" : "months")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if debt.interestRate > 0 {
                        let totalInterestCents = estimatedTotalInterest()
                        if totalInterestCents > 0 {
                            Text("Estimated total interest: \(CurrencyFormatter.format(cents: totalInterestCents))")
                                .font(.caption)
                                .foregroundStyle(BudgetVaultTheme.caution)
                        }
                    }
                }
                .padding(.vertical, BudgetVaultTheme.spacingXS)
            } else if debt.currentBalanceCents <= 0 {
                Label("This debt is paid off!", systemImage: "party.popper")
                    .foregroundStyle(BudgetVaultTheme.positive)
            } else {
                Label("Minimum payment doesn't cover interest", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(BudgetVaultTheme.negative)
                    .font(.subheadline)
            }
        }
    }

    private func estimatedTotalInterest() -> Int64 {
        guard debt.currentBalanceCents > 0, debt.minimumPaymentCents > 0 else { return 0 }
        let monthlyRate = debt.interestRate / 100.0 / 12.0
        guard monthlyRate > 0 else { return 0 }

        var balance = Double(debt.currentBalanceCents) / 100.0
        let payment = Double(debt.minimumPaymentCents) / 100.0
        var totalInterest = 0.0
        var monthsRemaining = 600 // safety cap at 50 years

        while balance > 0 && monthsRemaining > 0 {
            let interest = balance * monthlyRate
            totalInterest += interest
            balance = balance + interest - payment
            if balance < 0 { balance = 0 }
            monthsRemaining -= 1
        }

        return MoneyHelpers.dollarsToCents(Decimal(totalInterest))
    }

    // MARK: - Payment History

    private var paymentHistorySection: some View {
        Section("Payment History") {
            if sortedPayments.isEmpty {
                Text("No payments logged yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, BudgetVaultTheme.spacingSM)
            } else {
                ForEach(sortedPayments) { payment in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(CurrencyFormatter.format(cents: payment.amountCents))
                                .font(BudgetVaultTheme.rowAmount)
                                .foregroundStyle(BudgetVaultTheme.positive)
                            if !payment.note.isEmpty {
                                Text(payment.note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(payment.date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Payment of \(CurrencyFormatter.format(cents: payment.amountCents))\(payment.note.isEmpty ? "" : ", \(payment.note)"), \(payment.date.formatted(date: .abbreviated, time: .omitted))")
                }
                .onDelete(perform: deletePayments)
            }

            Button {
                showLogPayment = true
            } label: {
                Label("Log Payment", systemImage: "plus.circle")
            }
        }
    }

    // MARK: - Log Payment Sheet

    private var logPaymentSheet: some View {
        NavigationStack {
            Form {
                Section("Payment Amount") {
                    HStack {
                        Text(CurrencyFormatter.currencySymbol())
                            .foregroundStyle(.secondary)
                        TextField("0", text: $paymentAmountText)
                            .keyboardType(.decimalPad)
                            .font(.title3.bold())
                            .focused($isInputFocused)
                    }
                }

                Section("Note (optional)") {
                    TextField("e.g. Extra payment", text: $paymentNote)
                }

                Section {
                    Text("Current balance: \(CurrencyFormatter.format(cents: debt.currentBalanceCents))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Log Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isInputFocused = false }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        paymentAmountText = ""
                        paymentNote = ""
                        showLogPayment = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        logPayment()
                    }
                    .disabled(MoneyHelpers.parseCurrencyString(paymentAmountText) == nil)
                }
            }
        }
    }

    // MARK: - Edit Debt Sheet

    private var editDebtSheet: some View {
        NavigationStack {
            EditDebtForm(debt: debt) {
                showEditDebt = false
            }
        }
    }

    // MARK: - Actions

    private func logPayment() {
        guard let cents = MoneyHelpers.parseCurrencyString(paymentAmountText), cents > 0 else { return }

        let oldBalance = debt.currentBalanceCents
        let oldIsActive = debt.isActive

        let payment = DebtPayment(amountCents: cents, note: paymentNote.trimmingCharacters(in: .whitespaces))
        payment.debtAccount = debt
        modelContext.insert(payment)

        debt.currentBalanceCents = max(0, debt.currentBalanceCents - cents)

        if debt.currentBalanceCents <= 0 {
            debt.isActive = false
        }

        guard SafeSave.save(modelContext) else {
            debt.currentBalanceCents = oldBalance
            debt.isActive = oldIsActive
            modelContext.rollback()
            return
        }
        HapticManager.notification(.success)

        paymentAmountText = ""
        paymentNote = ""
        showLogPayment = false
    }

    private func deletePayments(at offsets: IndexSet) {
        let oldBalance = debt.currentBalanceCents
        let oldIsActive = debt.isActive
        for index in offsets {
            let payment = sortedPayments[index]
            // Restore the balance
            debt.currentBalanceCents += payment.amountCents
            debt.isActive = true
            modelContext.delete(payment)
        }
        if !SafeSave.save(modelContext) {
            debt.currentBalanceCents = oldBalance
            debt.isActive = oldIsActive
            modelContext.rollback()
        }
    }
}

// MARK: - Edit Debt Form

private struct EditDebtForm: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var debt: DebtAccount
    let onDismiss: () -> Void

    @State private var name: String = ""
    @State private var emoji: String = ""
    @State private var interestRateText: String = ""
    @State private var minimumPaymentText: String = ""
    @State private var dueDay: Int = 1
    @State private var currentBalanceText: String = ""
    @FocusState private var isInputFocused: Bool

    private let emojiOptions = ["💳", "🏦", "🏠", "🚗", "🎓", "💰", "📱", "🏥", "💍", "🛍️"]

    var body: some View {
        Form {
            Section("Name") {
                TextField("Debt name", text: $name)
            }

            Section("Icon") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                    ForEach(emojiOptions, id: \.self) { e in
                        Button {
                            emoji = e
                            HapticManager.selection()
                        } label: {
                            Text(e)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .strokeBorder(emoji == e ? Color.accentColor : Color.clear, lineWidth: 3)
                                )
                        }
                        .accessibilityLabel(e)
                        .accessibilityAddTraits(emoji == e ? .isSelected : [])
                    }
                }
            }

            Section("Current Balance") {
                HStack {
                    Text(CurrencyFormatter.currencySymbol())
                        .foregroundStyle(.secondary)
                    TextField("0", text: $currentBalanceText)
                        .keyboardType(.decimalPad)
                        .font(.title3.bold())
                        .focused($isInputFocused)
                }
            }

            Section("Interest Rate (APR %)") {
                TextField("0", text: $interestRateText)
                    .keyboardType(.decimalPad)
            }

            Section("Minimum Payment") {
                HStack {
                    Text(CurrencyFormatter.currencySymbol())
                        .foregroundStyle(.secondary)
                    TextField("0", text: $minimumPaymentText)
                        .keyboardType(.decimalPad)
                }
            }

            Section("Due Day of Month") {
                Picker("Due Day", selection: $dueDay) {
                    ForEach(1...28, id: \.self) { day in
                        Text("\(day)").tag(day)
                    }
                }
            }
        }
        .navigationTitle("Edit Debt")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isInputFocused = false }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { onDismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveEdits()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            name = debt.name
            emoji = debt.emoji
            interestRateText = debt.interestRate > 0 ? String(format: "%.2f", debt.interestRate) : ""
            minimumPaymentText = debt.minimumPaymentCents > 0 ? String(format: "%.2f", Double(debt.minimumPaymentCents) / 100.0) : ""
            dueDay = debt.dueDay
            currentBalanceText = String(format: "%.2f", Double(debt.currentBalanceCents) / 100.0)
        }
    }

    private func saveEdits() {
        let oldName = debt.name
        let oldEmoji = debt.emoji
        let oldRate = debt.interestRate
        let oldMinPayment = debt.minimumPaymentCents
        let oldDueDay = debt.dueDay
        let oldBalance = debt.currentBalanceCents

        debt.name = name.trimmingCharacters(in: .whitespaces)
        debt.emoji = emoji
        debt.interestRate = Double(interestRateText) ?? 0
        debt.minimumPaymentCents = MoneyHelpers.parseCurrencyString(minimumPaymentText) ?? 0
        debt.dueDay = dueDay
        if let cents = MoneyHelpers.parseCurrencyString(currentBalanceText) {
            debt.currentBalanceCents = cents
        }
        guard SafeSave.save(modelContext) else {
            debt.name = oldName
            debt.emoji = oldEmoji
            debt.interestRate = oldRate
            debt.minimumPaymentCents = oldMinPayment
            debt.dueDay = oldDueDay
            debt.currentBalanceCents = oldBalance
            modelContext.rollback()
            return
        }
        HapticManager.notification(.success)
        onDismiss()
    }
}
