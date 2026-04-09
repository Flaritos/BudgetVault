import SwiftUI

struct BudgetRingView: View {
    let spent: Int64
    let budgeted: Int64

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedProgress: Double = 0

    private var progress: Double {
        guard budgeted > 0 else { return 0 }
        return min(Double(spent) / Double(budgeted), 1.0)
    }

    private var ringColor: Color {
        if progress < 0.5 { return BudgetVaultTheme.positive }
        if progress < 0.75 { return BudgetVaultTheme.caution }
        return BudgetVaultTheme.negative
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: 4)
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .onAppear {
            if reduceMotion {
                animatedProgress = progress
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    animatedProgress = progress
                }
            }
        }
        .onChange(of: progress) { _, newValue in
            if reduceMotion {
                animatedProgress = newValue
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    animatedProgress = newValue
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Budget progress")
        .accessibilityValue("\(Int(progress * 100)) percent spent")
    }
}
