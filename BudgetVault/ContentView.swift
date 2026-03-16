import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage(AppStorageKeys.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @AppStorage(AppStorageKeys.biometricLockEnabled) private var biometricLockEnabled = false
    @AppStorage(AppStorageKeys.hasLoggedFirstTransaction) private var hasLoggedFirstTransaction = false

    @Environment(\.scenePhase) private var scenePhase
    @State private var authService = BiometricAuthService()

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView()
            } else if biometricLockEnabled && !authService.isAuthenticated {
                BiometricLockView(authService: authService)
            } else {
                MainTabView()
            }
        }
        .background {
            // Fill the entire screen including safe areas
            // Uses navyDark during onboarding, system background otherwise
            (hasCompletedOnboarding ? Color(.systemGroupedBackground) : BudgetVaultTheme.navyDark)
                .ignoresSafeArea()
        }
        .onChange(of: hasCompletedOnboarding) { oldValue, newValue in
            if !oldValue && newValue && !hasLoggedFirstTransaction {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
