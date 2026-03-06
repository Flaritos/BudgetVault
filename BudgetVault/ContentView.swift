import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("biometricLockEnabled") private var biometricLockEnabled = false
    @AppStorage("hasLoggedFirstTransaction") private var hasLoggedFirstTransaction = false

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
