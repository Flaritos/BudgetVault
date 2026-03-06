import SwiftUI

struct BiometricLockView: View {
    let authService: BiometricAuthService

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)

            Text("BudgetVault")
                .font(.largeTitle.bold())

            Text("Unlock to continue")
                .font(.body)
                .foregroundStyle(.secondary)

            Button {
                Task { await authService.authenticate() }
            } label: {
                Label("Unlock with \(authService.biometricName)", systemImage: authService.biometricIcon)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 40)
            .accessibilityHint("Authenticate to access your budget")

            if let error = authService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()
            Spacer()
        }
        .task {
            await authService.authenticate()
        }
    }
}
