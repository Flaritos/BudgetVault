import LocalAuthentication

@MainActor
@Observable
final class BiometricAuthService {

    var isAuthenticated = false
    var biometricType: LABiometryType = .none
    var errorMessage: String?

    init() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricType = context.biometryType
        }
    }

    var biometricName: String {
        switch biometricType {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .opticID: "Optic ID"
        default: "Passcode"
        }
    }

    var biometricIcon: String {
        switch biometricType {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .opticID: "opticid"
        default: "lock.fill"
        }
    }

    func authenticate() async {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"

        // Audit fix: clear any stale error from a prior failed attempt
        // so the new prompt doesn't show "Authentication failed" before
        // the user responds to the live prompt.
        errorMessage = nil

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // Audit fix: was `isAuthenticated = true` (fail open). For a
            // privacy-first app claiming "App Lock," silently bypassing
            // auth when no passcode exists is off-message and could
            // surprise users on a shared device. Now we fail closed and
            // surface a message so the user knows why the lock didn't
            // engage. The Settings toggle stays on so they can set a
            // passcode in iOS Settings and return to a working lock.
            isAuthenticated = false
            errorMessage = "Set a passcode in iOS Settings to use App Lock."
            return
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock BudgetVault"
            )
            isAuthenticated = success
            errorMessage = success ? nil : "Authentication failed"
        } catch {
            // Audit fix: failing closed includes NOT preserving a
            // prior `isAuthenticated = true`. If the user was unlocked
            // from a previous session and re-auth throws (canceled,
            // fallback declined, etc.), treat it as a fresh lock.
            isAuthenticated = false
            errorMessage = error.localizedDescription
        }
    }
}
