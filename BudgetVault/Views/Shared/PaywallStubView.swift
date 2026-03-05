import SwiftUI

/// Minimal stub to prevent compile errors before Step 7a builds the real PaywallView.
struct PaywallStubView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Premium Feature")
                .font(.title2)
            Text("This feature will be available with BudgetVault Premium.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("OK") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
