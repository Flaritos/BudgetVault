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
            errorMessage = success ? nil : "Authentication failed. Try again."
        } catch {
            // Audit fix: failing closed includes NOT preserving a
            // prior `isAuthenticated = true`. If the user was unlocked
            // from a previous session and re-auth throws (canceled,
            // fallback declined, etc.), treat it as a fresh lock.
            isAuthenticated = false
            errorMessage = Self.message(for: error, biometricName: biometricName)
        }
    }

    // Audit 2026-04-22 P0-13: previously surfaced
    // `error.localizedDescription` for every LAError — user saw "Canceled
    // by the user" for a Cancel tap, and got nothing actionable for
    // lockout / not-enrolled. Map the codes that actually reach users
    // into purpose-built copy; keep the system fallback for the long tail.
    private static func message(for error: Error, biometricName: String) -> String? {
        guard let laError = error as? LAError else {
            return error.localizedDescription
        }
        switch laError.code {
        case .userCancel, .systemCancel, .appCancel:
            // Silent — user or system dismissed the prompt; showing an
            // error here just adds noise. The lock screen already
            // communicates state.
            return nil
        case .authenticationFailed:
            return "\(biometricName) didn't recognize you. Try again or use your passcode."
        case .biometryNotEnrolled:
            return "No \(biometricName) is set up on this device. Add one in iOS Settings or use your passcode."
        case .biometryLockout:
            return "\(biometricName) is locked. Unlock your iPhone with your passcode to re-enable it."
        case .biometryNotAvailable:
            return "\(biometricName) isn't available on this device. Use your passcode instead."
        case .passcodeNotSet:
            return "Set a passcode in iOS Settings to use App Lock."
        case .userFallback:
            // User explicitly chose passcode; the `.deviceOwnerAuthentication`
            // policy should have handled it — if we got here, the passcode
            // prompt was dismissed. Treat as a cancel.
            return nil
        @unknown default:
            return laError.localizedDescription
        }
    }
}
