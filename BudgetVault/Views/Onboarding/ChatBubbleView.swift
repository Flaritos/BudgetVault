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

// Audit 2026-04-23 A11y P2: TypingIndicatorView deleted. Was unused
// in production but shipped in the binary with a `.repeatForever`
// animation + no Reduce Motion guard — accessibility landmine if
// ever re-enabled. If a "bot is typing" affordance is needed later,
// rebuild it with proper reduceMotion handling from scratch.
