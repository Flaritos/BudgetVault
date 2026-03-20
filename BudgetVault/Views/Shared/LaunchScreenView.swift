import SwiftUI

struct LaunchScreenView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1
    @State private var scale: Double = 1
    @Binding var isFinished: Bool

    var body: some View {
        ZStack {
            BudgetVaultTheme.navyDark
                .ignoresSafeArea()

            VStack(spacing: BudgetVaultTheme.spacingLG) {
                VaultDialMark(size: 120, showGlow: true, tickRotation: rotation)

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
                isFinished = true
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
            isFinished = true
        }
    }
}
