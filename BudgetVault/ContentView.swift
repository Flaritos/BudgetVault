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
            Group {
                if !hasCompletedOnboarding {
                    ChatOnboardingView()
                } else if biometricLockEnabled && !authService.isAuthenticated {
                    BiometricLockView(authService: authService)
                } else {
                    MainTabView()
                }
            }
            .opacity(showLaunchScreen ? 0 : 1)

            if showLaunchScreen {
                LaunchScreenView(isFinished: $showLaunchScreen)
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.5), value: hasCompletedOnboarding)
        .animation(.easeOut(duration: 0.3), value: showLaunchScreen)
        .background {
            // Fill the entire screen including safe areas
            // Uses navyDark during onboarding/launch, system background otherwise
            (hasCompletedOnboarding && !showLaunchScreen ? Color(.systemGroupedBackground) : BudgetVaultTheme.navyDark)
                .ignoresSafeArea()
        }
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
