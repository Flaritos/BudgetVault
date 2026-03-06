import SwiftUI
import StoreKit

struct MonthlySummaryView: View {
    let budget: Budget
    @Environment(\.dismiss) private var dismiss
    @State private var shareImage: Image?

    private var categories: [Category] {
        budget.categories.filter { !$0.isHidden }.sorted { $0.sortOrder < $1.sortOrder }
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
                    Text(DateHelpers.monthYearString(month: budget.month, year: budget.year))
                        .font(.title.bold())

                    // Income vs Spent
                    HStack(spacing: 32) {
                        VStack {
                            Text("Income")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(CurrencyFormatter.format(cents: budget.totalIncomeCents))
                                .font(.title3.bold())
                        }
                        VStack {
                            Text("Spent")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(CurrencyFormatter.format(cents: totalSpent))
                                .font(.title3.bold())
                        }
                    }

                    // Delta
                    HStack {
                        Image(systemName: delta >= 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        Text(delta >= 0 ? "Under budget by \(CurrencyFormatter.format(cents: delta))" : "Over budget by \(CurrencyFormatter.format(cents: abs(delta)))")
                    }
                    .font(.headline)
                    .foregroundStyle(delta >= 0 ? .green : .red)

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
                                    .foregroundStyle(under ? .green : .red)
                                Text(CurrencyFormatter.format(cents: spent))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("/ \(CurrencyFormatter.format(cents: budgeted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                    // Celebration
                    if underBudgetCount > 0 {
                        Text("You stayed under budget in \(underBudgetCount)/\(categories.count) categories!")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding()
                    }

                    // Share button
                    ShareLink(item: shareCardImage, preview: SharePreview("Monthly Summary", image: shareCardImage)) {
                        Label("Share Achievement", systemImage: "square.and.arrow.up")
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
            .onAppear {
                // Prompt for review if user was under budget
                if budget.remainingCents > 0 {
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

    private var shareCardView: some View {
        VStack(spacing: 12) {
            Image(systemName: "vault.fill")
                .font(.system(size: 32))
                .foregroundStyle(.blue)

            Text("I stayed under budget in \(underBudgetCount)/\(categories.count) categories!")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(DateHelpers.monthYearString(month: budget.month, year: budget.year))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("BudgetVault")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("https://budgetvault.com")
                .font(.caption2)
                .foregroundStyle(.blue)
        }
        .padding(24)
        .frame(width: 300)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityLabel("Achievement card: stayed under budget in \(underBudgetCount) of \(categories.count) categories for \(DateHelpers.monthYearString(month: budget.month, year: budget.year))")
    }
}
