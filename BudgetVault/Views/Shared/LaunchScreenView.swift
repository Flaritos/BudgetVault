import SwiftUI

struct LaunchScreenView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1
    @State private var scale: Double = 1
    @Binding var isShowing: Bool

    var body: some View {
        ZStack {
            BudgetVaultTheme.navyDark
                .ignoresSafeArea()

            VStack(spacing: BudgetVaultTheme.spacingXL) {
                // VaultRevamp v2.1: launch dial uses the canonical VaultDial
                // primitive (shared with Home/Vault). The face rotation is
                // animated via `faceRotationDegrees`; pointer + lock stay fixed.
                //
                // No outer .frame here. `.hero` is intrinsically 240pt, and
                // VaultDial already sets its own frame internally. A
                // shrinking outer frame only clamps the VStack's layout slot
                // without resizing the dial — which is how the wordmark
                // below used to collide with the dial's bottom bezel.
                VaultDial(
                    size: .hero,
                    state: .locked,
                    faceRotationDegrees: rotation
                )

                Text("BudgetVault")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .task {
            if reduceMotion {
                // Skip animation for accessibility
                try? await Task.sleep(for: .seconds(0.5))
                isShowing = false
                return
            }

            // Spin the dial
            withAnimation(.easeInOut(duration: 1.5)) {
                rotation = 360
            }

            try? await Task.sleep(for: .seconds(1.8))

            // Fade out
            withAnimation(.easeOut(duration: 0.3)) {
                opacity = 0
                scale = 1.1
            }

            try? await Task.sleep(for: .seconds(0.3))
            isShowing = false
        }
    }
}
