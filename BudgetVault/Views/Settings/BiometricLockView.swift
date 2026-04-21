import SwiftUI

struct BiometricLockView: View {
    let authService: BiometricAuthService

    var body: some View {
        ZStack {
            // VaultRevamp v2.1: radial ambient glow from the top of the
            // chamber — same language as the Vault tab inner sanctum.
            RadialGradient(
                colors: [BudgetVaultTheme.navyElevated, BudgetVaultTheme.navyDark, BudgetVaultTheme.navyAbyss],
                center: UnitPoint(x: 0.5, y: 0.15),
                startRadius: 40,
                endRadius: 600
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Canonical VaultDial at hero size — shared primitive.
                VaultDial(size: .hero, state: .locked)
                    .frame(width: 140, height: 140)

                Text("BudgetVault")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                Text("Authenticate to open your vault")
                    .font(.body)
                    .foregroundStyle(BudgetVaultTheme.titanium300)

                Button {
                    Task { await authService.authenticate() }
                } label: {
                    Label("Unlock with \(authService.biometricName)", systemImage: authService.biometricIcon)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(BudgetVaultTheme.accentSoft, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 40)
                .accessibilityHint("Authenticate to open your vault")

                if let error = authService.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(BudgetVaultTheme.titanium300)
                }

                Spacer()
                Spacer()
            }
        }
        .task {
            await authService.authenticate()
            if authService.isAuthenticated {
                // Audit fix: notify the app that database-mutating
                // operations deferred at scenePhase .active (rollover,
                // recurring posting, streak update) can now run.
                NotificationCenter.default.post(name: .biometricUnlocked, object: nil)
            }
        }
        .onChange(of: authService.isAuthenticated) { _, newValue in
            if newValue {
                NotificationCenter.default.post(name: .biometricUnlocked, object: nil)
            }
        }
    }
}
