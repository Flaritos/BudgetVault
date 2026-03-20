import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage(AppStorageKeys.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @AppStorage(AppStorageKeys.biometricLockEnabled) private var biometricLockEnabled = false
    @AppStorage(AppStorageKeys.hasLoggedFirstTransaction) private var hasLoggedFirstTransaction = false

    @Environment(\.scenePhase) private var scenePhase
    @State private var authService = BiometricAuthService()
    @State private var showLaunchScreen = true

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
        }
        .background {
            (hasCompletedOnboarding && !showLaunchScreen ? Color(.systemGroupedBackground) : BudgetVaultTheme.navyDark)
                .ignoresSafeArea()
        }
        .animation(.smooth(duration: 0.5), value: hasCompletedOnboarding)
        .onChange(of: hasCompletedOnboarding) { oldValue, newValue in
            if !oldValue && newValue && !hasLoggedFirstTransaction {
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    NotificationCenter.default.post(name: .openTransactionEntry, object: nil)
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background && biometricLockEnabled {
                authService.isAuthenticated = false
            }
        }
    }
}
