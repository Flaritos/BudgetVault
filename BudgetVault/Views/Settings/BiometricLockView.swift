import SwiftUI
import UIKit

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

                // Audit 2026-04-23 Smoke-6: VaultDial(.hero) has an
                // intrinsic 240×240 frame set internally. The prior
                // outer `.frame(width: 140, height: 140)` only shrank
                // the layout slot — the 240pt PNG still rendered at
                // full size, overflowing ±50pt beyond the slot and
                // overlapping the "BudgetVault" title below. Let the
                // dial render at its natural hero size; the VStack
                // spacing then spaces every element correctly.
                VaultDial(size: .hero, state: .locked)

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
                    VStack(spacing: 8) {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(BudgetVaultTheme.titanium300)
                            // Audit 2026-04-23 Max Audit P1-40: error
                            // message appears without live-region
                            // semantics. VO users got no feedback after
                            // a failed auth.
                            .accessibilityAddTraits(.isStaticText)

                        // Audit 2026-04-23 Max Audit P1-31: when the
                        // error is "Set a passcode in iOS Settings", the
                        // user was hard-locked out with no link. Surface
                        // an Open Settings button on passcode-class
                        // errors so the recovery path is one tap away.
                        if error.lowercased().contains("passcode")
                            || error.lowercased().contains("settings") {
                            Button {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Text("Open iOS Settings")
                                    .font(.caption.bold())
                                    .foregroundStyle(BudgetVaultTheme.accentSoft)
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                }

                Spacer()
                Spacer()
            }
        }
        // Audit 2026-04-23 M6: previously auto-called `authenticate()`
        // from `.task`. On devices with no biometric enrollment AND no
        // passcode set (common in simulators upgrading from no-auth
        // state), the auto-call surfaced an iOS system prompt that can
        // only be dismissed by setting a passcode — effectively
        // locking the user out. Require an explicit button tap instead.
        // The manual "Unlock with Face ID" button is already present.
        .task {
            // Refresh biometryType detection in case the user enrolled
            // a new face/finger between app opens.
            authService.refreshBiometryType()
        }
        .onChange(of: authService.isAuthenticated) { _, newValue in
            // Audit fix: single source of the post. The prior version
            // posted from both .task and .onChange, running the
            // deferred rollover/recurring/streak work twice on each
            // unlock (wasted cycles and duplicate notifications).
            // `.onChange` fires on the false→true transition from
            // the .task's successful authenticate, so it covers both
            // initial-lock unlock and any future re-authentication.
            if newValue {
                NotificationCenter.default.post(name: .biometricUnlocked, object: nil)
            }
        }
    }
}
