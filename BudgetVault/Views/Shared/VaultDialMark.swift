import SwiftUI

struct VaultDialMark: View {
    let size: CGFloat
    var color: Color = .white
    var showGlow: Bool = false
    var tickRotation: Double = 0

    private var ringWidth: CGFloat { max(size * 0.02, 1.5) }
    private var tickWidth: CGFloat { max(size * 0.013, 1) }
    private var tickHeight: CGFloat { size * 0.065 }
    private var tickOffset: CGFloat { -(size * 0.45) }
    private var pointerWidth: CGFloat { size * 0.075 }
    private var pointerHeight: CGFloat { size * 0.06 }
    private var pointerOffset: CGFloat { -(size * 0.53) }
    private var envelopeWidth: CGFloat { size * 0.3 }
    private var envelopeHeight: CGFloat { size * 0.21 }
    private var envelopeStroke: CGFloat { max(size * 0.015, 1.2) }

    var body: some View {
        ZStack {
            if showGlow {
                Circle()
                    .fill(BudgetVaultTheme.electricBlue.opacity(0.12))
                    .frame(width: size * 1.4, height: size * 1.4)
                    .blur(radius: size * 0.12)
            }

            // Dial ring
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [color.opacity(0.35), color.opacity(0.12)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: ringWidth
                )
                .frame(width: size, height: size)

            // Tick marks (only these rotate)
            ForEach(0..<12, id: \.self) { i in
                RoundedRectangle(cornerRadius: tickWidth / 2)
                    .fill(color.opacity(0.5))
                    .frame(width: tickWidth, height: tickHeight)
                    .offset(y: tickOffset)
                    .rotationEffect(.degrees(Double(i) * 30))
            }
            .rotationEffect(.degrees(tickRotation))

            // Pointer (stays fixed at top)
            VaultTriangle()
                .fill(color)
                .frame(width: pointerWidth, height: pointerHeight)
                .offset(y: pointerOffset)

            // Round 5 audit N11: the center glyph was an envelope which
            // reads as Mail.app, breaking the vault metaphor. Replaced
            // with a stylized lock + dial that actually looks like a vault.
            ZStack {
                // Outer dial ring
                Circle()
                    .strokeBorder(color.opacity(0.7), lineWidth: envelopeStroke)
                    .frame(width: envelopeWidth * 1.1, height: envelopeWidth * 1.1)

                // Lock shackle (arc)
                Path { path in
                    let w = envelopeWidth * 0.6
                    let h = envelopeHeight * 0.5
                    path.addArc(
                        center: CGPoint(x: w / 2, y: h),
                        radius: w / 2,
                        startAngle: .degrees(180),
                        endAngle: .degrees(0),
                        clockwise: false
                    )
                }
                .stroke(color.opacity(0.85), style: StrokeStyle(lineWidth: envelopeStroke * 1.2, lineCap: .round))
                .frame(width: envelopeWidth * 0.6, height: envelopeHeight * 0.5)
                .offset(y: -(envelopeHeight * 0.15))

                // Lock body
                RoundedRectangle(cornerRadius: size * 0.015)
                    .fill(color.opacity(0.85))
                    .frame(width: envelopeWidth * 0.75, height: envelopeHeight * 0.5)
                    .offset(y: envelopeHeight * 0.15)
            }
        }
        .frame(width: size * (showGlow ? 1.4 : 1), height: size * (showGlow ? 1.4 : 1))
        .accessibilityHidden(true)
    }
}

// MARK: - Shapes

private struct VaultTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct VaultEnvelopeFlap: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}
