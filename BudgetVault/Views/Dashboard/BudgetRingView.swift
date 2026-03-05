import SwiftUI

struct BudgetRingView: View {
    let spent: Int64
    let budgeted: Int64

    private var progress: Double {
        guard budgeted > 0 else { return 0 }
        return min(Double(spent) / Double(budgeted), 1.0)
    }

    private var ringColor: Color {
        if progress < 0.5 { return .green }
        if progress < 0.75 { return .yellow }
        return .red
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
