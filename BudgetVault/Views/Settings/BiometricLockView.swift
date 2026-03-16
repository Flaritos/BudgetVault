import SwiftUI

struct BiometricLockView: View {
    let authService: BiometricAuthService

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VaultDialMark(size: 100, showGlow: true)

            Text("BudgetVault")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text("Authenticate to open your vault")
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))

            Button {
                Task { await authService.authenticate() }
            } label: {
                Label("Unlock with \(authService.biometricName)", systemImage: authService.biometricIcon)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.white, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(BudgetVaultTheme.electricBlue)
            }
            .padding(.horizontal, 40)
            .accessibilityHint("Authenticate to open your vault")

            if let error = authService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BudgetVaultTheme.brandGradient)
        .ignoresSafeArea()
        .task {
            await authService.authenticate()
        }
    }
}
