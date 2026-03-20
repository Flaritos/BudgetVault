import SwiftUI

// MARK: - Chat Bubble

struct ChatBubbleView: View {
    let text: String
    let isBot: Bool
    var animate: Bool = true

    @State private var appeared = false

    var body: some View {
        HStack {
            if !isBot { Spacer(minLength: 60) }

            Text(text)
                .font(.body)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    isBot
                        ? AnyShapeStyle(Color.white.opacity(0.10))
                        : AnyShapeStyle(BudgetVaultTheme.electricBlue)
                )
                .clipShape(ChatBubbleShape(isBot: isBot))
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)

            if isBot { Spacer(minLength: 60) }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            if animate {
                withAnimation(.easeOut(duration: 0.35)) {
                    appeared = true
                }
            } else {
                appeared = true
            }
        }
    }
}

// MARK: - Chat Bubble Shape

/// A rounded rectangle with one corner less rounded to create the chat tail effect.
struct ChatBubbleShape: Shape {
    let isBot: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 16
        let tailRadius: CGFloat = 4

        let tl = isBot ? tailRadius : radius
        let tr = isBot ? radius : radius
        let bl = isBot ? radius : radius
        let br = isBot ? radius : tailRadius

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
                     tangent2End: CGPoint(x: rect.maxX, y: rect.minY + tr),
                     radius: tr)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
                     tangent2End: CGPoint(x: rect.maxX - br, y: rect.maxY),
                     radius: br)
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
                     tangent2End: CGPoint(x: rect.minX, y: rect.maxY - bl),
                     radius: bl)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY),
                     tangent2End: CGPoint(x: rect.minX + tl, y: rect.minY),
                     radius: tl)
        path.closeSubpath()
        return path
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorView: View {
    @State private var dotScales: [CGFloat] = [0.5, 0.5, 0.5]

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .scaleEffect(dotScales[index])
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.10))
            .clipShape(ChatBubbleShape(isBot: true))

            Spacer()
        }
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        for i in 0..<3 {
            withAnimation(
                .easeInOut(duration: 0.5)
                .repeatForever(autoreverses: true)
                .delay(Double(i) * 0.15)
            ) {
                dotScales[i] = 1.0
            }
        }
    }
}
