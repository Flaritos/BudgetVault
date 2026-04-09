import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: BudgetVaultTheme.spacingMD) {
            Image(systemName: icon)
                .font(BudgetVaultTheme.iconLarge)
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse)
            Text(title)
                .font(.title3.bold())
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let actionLabel, let action {
                Button(actionLabel, action: action)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
        }
        .padding(BudgetVaultTheme.spacingPage)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
