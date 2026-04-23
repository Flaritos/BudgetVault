import SwiftUI
import SwiftData
import BudgetVaultShared

struct ContentView: View {
    @AppStorage(AppStorageKeys.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @AppStorage(AppStorageKeys.biometricLockEnabled) private var biometricLockEnabled = false
    @AppStorage(AppStorageKeys.hasLoggedFirstTransaction) private var hasLoggedFirstTransaction = false

    @Environment(\.scenePhase) private var scenePhase
    @State private var authService = BiometricAuthService()
    @State private var showLaunchScreen = true
    // Audit 2026-04-22 P2-9: the app-switcher snapshot is captured at
    // `.inactive`, BEFORE `.background`. Previously the biometric lock
    // only engaged on `.background`, so financial data was visible in
    // the snapshot. Setting auth=false at `.inactive` would force
    // re-auth after every transient interruption (incoming call, Siri,
    // control center). Split: show a blur overlay at `.inactive` so
    // the snapshot is obscured, then fully de-auth at `.background`.
    @State private var obscureForSnapshot = false

    var body: some View {
        ZStack {
            // Main content
            if !showLaunchScreen {
                if !hasCompletedOnboarding {
                    ChatOnboardingView()
                } else if biometricLockEnabled && !authService.isAuthenticated {
                    BiometricLockView(authService: authService)
                } else {
                    MainTabView()
                }
            }

            // Launch screen overlay
            if showLaunchScreen {
                LaunchScreenView(isShowing: $showLaunchScreen)
            }

            // Audit 2026-04-22 P2-9: snapshot-obscuring overlay.
            // Rendered above everything else when the app is inactive
            // AND biometric lock is enabled. Uses the navy brand color
            // so the snapshot looks like the launch screen rather
            // than a "data was here a moment ago" blur.
            if obscureForSnapshot && biometricLockEnabled {
                BudgetVaultTheme.navyDark
                    .ignoresSafeArea()
                    .overlay {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(BudgetVaultTheme.accentSoft)
                    }
                    .transition(.opacity)
            }
        }
        .background {
            (hasCompletedOnboarding && !showLaunchScreen ? Color(.systemGroupedBackground) : BudgetVaultTheme.navyDark)
                .ignoresSafeArea()
        }
        .animation(.smooth(duration: 0.5), value: hasCompletedOnboarding)
        .onChange(of: hasCompletedOnboarding) { oldValue, newValue in
            if !oldValue && newValue && !hasLoggedFirstTransaction {
                Task {
                    try? await Task.sleep(for: .milliseconds(1500))
                    NotificationCenter.default.post(name: .openTransactionEntry, object: nil)
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .inactive:
                // Snapshot capture happens here. Obscure before
                // iOS grabs the frame for app-switcher.
                obscureForSnapshot = true
            case .active:
                obscureForSnapshot = false
            case .background:
                if biometricLockEnabled {
                    authService.isAuthenticated = false
                }
            @unknown default:
                break
            }
        }
    }
}
