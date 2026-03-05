import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("biometricLockEnabled") private var biometricLockEnabled = false

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
    }
}
