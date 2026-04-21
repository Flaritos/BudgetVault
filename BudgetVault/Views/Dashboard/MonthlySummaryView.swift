import SwiftUI
import StoreKit
import BudgetVaultShared

struct MonthlySummaryView: View {
    let budget: Budget
    @Environment(\.dismiss) private var dismiss
    @State private var shareImage: Image?
    @State private var showCelebration = false

    private var categories: [Category] {
        (budget.categories ?? []).filter { !$0.isHidden }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var underBudgetCount: Int {
        categories.filter { $0.spentCents(in: budget) <= $0.budgetedAmountCents }.count
    }

    private var totalSpent: Int64 {
        budget.totalSpentCents()
    }

    private var delta: Int64 {
        budget.totalIncomeCents - totalSpent
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 16) {
                        Text(DateHelpers.monthYearString(month: budget.month, year: budget.year))
                            .font(.title.bold())
                            .foregroundStyle(.white)

                        HStack(spacing: 32) {
                            VStack {
                                Text("Income")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                                Text(CurrencyFormatter.format(cents: budget.totalIncomeCents))
                                    .font(.system(.title3, design: .rounded).bold())
                                    .foregroundStyle(.white)
                            }
                            VStack {
                                Text("Spent")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                                Text(CurrencyFormatter.format(cents: totalSpent))
                                    .font(.system(.title3, design: .rounded).bold())
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .background(BudgetVaultTheme.heroBrandGradient)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(DateHelpers.monthYearString(month: budget.month, year: budget.year)) summary. Income: \(CurrencyFormatter.format(cents: budget.totalIncomeCents)), Spent: \(CurrencyFormatter.format(cents: totalSpent))")

                    // Delta
                    HStack {
                        Image(systemName: delta >= 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        Text(delta >= 0 ? "Under budget by \(CurrencyFormatter.format(cents: delta))" : "Over budget by \(CurrencyFormatter.format(cents: abs(delta)))")
                    }
                    .font(.headline)
                    .foregroundStyle(delta >= 0 ? BudgetVaultTheme.positive : BudgetVaultTheme.negative)

                    // Category breakdown
                    VStack(spacing: 8) {
                        ForEach(categories, id: \.id) { cat in
                            let spent = cat.spentCents(in: budget)
                            let budgeted = cat.budgetedAmountCents
                            let under = spent <= budgeted

                            HStack {
                                Text(cat.emoji)
                                Text(cat.name)
                                    .font(.subheadline)
                                Spacer()
                                Image(systemName: under ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(under ? BudgetVaultTheme.positive : BudgetVaultTheme.negative)
                                Text(CurrencyFormatter.format(cents: spent))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("/ \(CurrencyFormatter.format(cents: budgeted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(cat.name): \(CurrencyFormatter.format(cents: spent)) of \(CurrencyFormatter.format(cents: budgeted)), \(under ? "under budget" : "over budget")")
                        }
                    }
                    // Phase 9 §4: Phase 8 scoped the ultraThinMaterial
                    // sweep to Views/Insights/ only; this Dashboard file
                    // got missed. Swap for the chamber treatment used by
                    // every other grouped container in VaultRevamp.
                    .padding()
                    .background(
                        BudgetVaultTheme.chamberBackground,
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(BudgetVaultTheme.titanium700.opacity(0.4), lineWidth: 1)
                    )

                    // Phase 9 §9.3: "Budget Hero!" was gamified copy that
                    // predated the VaultRevamp calm-tone pass. The amount
                    // + positive green + confetti (elsewhere) already
                    // carry the achievement feel; the label becomes a
                    // quiet engraved eyebrow instead.
                    if delta > 0 {
                        VStack(spacing: 8) {
                            Text("SAVED THIS MONTH")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(2.4)
                                .textCase(.uppercase)
                                .foregroundStyle(BudgetVaultTheme.titanium300)
                            Text("+\(CurrencyFormatter.format(cents: delta))")
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .foregroundStyle(BudgetVaultTheme.positive)
                            if underBudgetCount > 0 {
                                Text("Under budget in \(underBudgetCount) of \(categories.count) categories")
                                    .font(.caption)
                                    .foregroundStyle(BudgetVaultTheme.titanium400)
                            }
                        }
                        .padding()
                    } else if underBudgetCount > 0 {
                        Text("Under budget in \(underBudgetCount) of \(categories.count) categories")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding()
                    }

                    // Share button. "Share Achievement" retired to
                    // "Share Summary" per §9.3 — less gamified, more
                    // descriptive of what the recipient will see.
                    ShareLink(item: shareCardImage, preview: SharePreview("Monthly Summary", image: shareCardImage)) {
                        Label("Share Summary", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationTitle("Monthly Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay {
                ConfettiView(isActive: showCelebration, style: .confetti, particleCount: 50)
            }
            .onAppear {
                // Prompt for review if user was under budget
                if budget.remainingCents > 0 {
                    showCelebration = true
                    HapticManager.notification(.success)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        ReviewPromptService.requestIfAppropriate()
                    }
                }
            }
        }
    }

    // MARK: - Share Card

    @MainActor
    private var shareCardImage: Image {
        let renderer = ImageRenderer(content: shareCardView)
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "square")
    }

    private var topCategories: [Category] {
        categories
            .sorted { $0.spentCents(in: budget) > $1.spentCents(in: budget) }
            .filter { $0.spentCents(in: budget) > 0 }
            .prefix(5)
            .map { $0 }
    }

    private var shareCardView: some View {
        VStack(spacing: 12) {
            VaultDial(size: .icon, state: .locked, tint: BudgetVaultTheme.electricBlue)
                .frame(width: 36, height: 36)

            Text(DateHelpers.monthYearString(month: budget.month, year: budget.year))
                .font(.title3.bold())

            HStack(spacing: 24) {
                VStack {
                    Text("Income")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.format(cents: budget.totalIncomeCents))
                        .font(.subheadline.bold())
                }
                VStack {
                    Text("Spent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CurrencyFormatter.format(cents: totalSpent))
                        .font(.subheadline.bold())
                }
            }

            Text("Under budget in \(underBudgetCount)/\(categories.count) categories")
                .font(.caption)
                .foregroundStyle(delta >= 0 ? BudgetVaultTheme.positive : BudgetVaultTheme.negative)

            if !topCategories.isEmpty {
                Divider()
                ForEach(topCategories, id: \.id) { cat in
                    HStack {
                        Text(cat.emoji)
                        Text(cat.name)
                            .font(.caption)
                        Spacer()
                        Text(CurrencyFormatter.format(cents: cat.spentCents(in: budget)))
                            .font(.caption.bold())
                    }
                }
            }

            Divider()

            Text("Tracked with BudgetVault")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 300)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .environment(\.colorScheme, .light)
        .accessibilityLabel("Achievement card: stayed under budget in \(underBudgetCount) of \(categories.count) categories for \(DateHelpers.monthYearString(month: budget.month, year: budget.year))")
    }
}
