import SwiftUI

/// The hero vault primitive. Brushed-titanium bezel, chamber-black face,
/// 5 numerals at 72° intervals, ticks every 36°/6°, blue pointer at 12
/// o'clock, center boss with lock glyph. Three states: .locked (pointer at
/// 0°), .open (rotated 72° + glow), .progress(x) (inner green arc from
/// 12 o'clock to x×360°). Fully decorative — accessibility-hidden.
struct VaultDial: View {
    enum Size {
        case hero       // 240pt — onboarding welcome, vault opens
        case large      // 80pt  — Home dashboard
        case medium     // 56pt  — FAB, Vault tab header
        case small      // 40pt  — section eyebrows
        case watermark  // 200pt at 10% opacity — Vault tab background

        var dimension: CGFloat {
            switch self {
            case .hero: return 240
            case .large: return 80
            case .medium: return 56
            case .small: return 40
            case .watermark: return 200
            }
        }

        var numeralsHiddenAtOrBelow: Bool {
            switch self {
            case .small, .watermark: return true
            default: return false
            }
        }

        var watermarkOpacity: Double {
            self == .watermark ? 0.10 : 1.0
        }
    }

    enum DialState {
        case locked
        case open
        case progress(Double)   // 0.0–1.0
    }

    let size: Size
    let state: DialState
    var showNumerals: Bool = true
    var showGlow: Bool = false

    @ScaledMetric(relativeTo: .largeTitle) private var scale: CGFloat = 1.0

    private var effectiveDimension: CGFloat {
        size.dimension * scale
    }

    private var rotation: Double {
        switch state {
        case .locked: return 0
        case .open: return 72
        case .progress(let p): return max(0, min(p, 1.0)) * 360
        }
    }

    private var showOpenGlow: Bool {
        if case .open = state { return true }
        return showGlow
    }

    private var shouldDrawNumerals: Bool {
        showNumerals && !size.numeralsHiddenAtOrBelow
    }

    var body: some View {
        ZStack {
            // Titanium bezel
            Circle()
                .fill(BudgetVaultTheme.titaniumBezel)
                .overlay(
                    Circle()
                        .strokeBorder(BudgetVaultTheme.titanium800, lineWidth: max(1, effectiveDimension * 0.008))
                )

            // Chamber-black inner face
            Circle()
                .inset(by: effectiveDimension * 0.08)
                .fill(BudgetVaultTheme.chamberBlack)
                .overlay(
                    Circle()
                        .inset(by: effectiveDimension * 0.08)
                        .strokeBorder(BudgetVaultTheme.titanium700.opacity(0.6), lineWidth: 1)
                )

            // Ticks + numerals — rotate together under the fixed pointer
            ZStack {
                ticks(majorEvery: 36, minorEvery: 6)
                if shouldDrawNumerals {
                    numerals()
                }
            }
            .rotationEffect(.degrees(rotation))
            .animation(.easeOut(duration: 0.6), value: rotation)

            // Progress arc (only for .progress state), drawn from 12 o'clock clockwise
            if case .progress(let p) = state {
                Circle()
                    .trim(from: 0, to: max(0.001, min(p, 1.0)))
                    .stroke(
                        BudgetVaultTheme.neonGreen,
                        style: StrokeStyle(
                            lineWidth: effectiveDimension * 0.035,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(effectiveDimension * 0.18)
                    .animation(.easeOut(duration: 0.5), value: p)
            }

            // Fixed pointer at 12 o'clock (doesn't rotate; ticks rotate beneath it)
            pointer()

            // Center boss with lock glyph
            centerBoss()

            // Open-state glow
            if showOpenGlow {
                Circle()
                    .stroke(BudgetVaultTheme.accentSoft.opacity(0.4), lineWidth: effectiveDimension * 0.02)
                    .blur(radius: effectiveDimension * 0.06)
            }
        }
        .frame(width: effectiveDimension, height: effectiveDimension)
        .opacity(size.watermarkOpacity)
        .accessibilityHidden(true)
    }

    // MARK: - Ticks
    @ViewBuilder
    private func ticks(majorEvery majorDeg: Double, minorEvery minorDeg: Double) -> some View {
        ZStack {
            ForEach(0..<Int(360 / minorDeg), id: \.self) { i in
                let angle = Double(i) * minorDeg
                let isMajor = angle.truncatingRemainder(dividingBy: majorDeg) < 0.001
                Rectangle()
                    .fill(BudgetVaultTheme.titanium300.opacity(isMajor ? 0.9 : 0.5))
                    .frame(
                        width: effectiveDimension * (isMajor ? 0.014 : 0.008),
                        height: effectiveDimension * (isMajor ? 0.06 : 0.035)
                    )
                    .offset(y: -effectiveDimension * 0.36)
                    .rotationEffect(.degrees(angle))
            }
        }
    }

    // MARK: - Numerals (5 @ 72° intervals, radius × 0.66)
    private func numerals() -> some View {
        let values = [0, 20, 40, 60, 80]
        return ZStack {
            ForEach(values, id: \.self) { val in
                let angleDeg = Double(values.firstIndex(of: val)!) * 72.0
                let angleRad = Angle.degrees(angleDeg).radians
                let radius = effectiveDimension * 0.33
                Text("\(val)")
                    .font(BudgetVaultTheme.flipDigitFont(size: effectiveDimension * 0.08))
                    .foregroundStyle(BudgetVaultTheme.titanium100)
                    .offset(
                        x: CGFloat(sin(angleRad)) * radius,
                        y: -CGFloat(cos(angleRad)) * radius
                    )
            }
        }
    }

    // MARK: - Pointer
    private func pointer() -> some View {
        DialPointerTriangle()
            .fill(
                LinearGradient(
                    colors: [BudgetVaultTheme.electricBlue, BudgetVaultTheme.accentSoft],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: effectiveDimension * 0.06, height: effectiveDimension * 0.11)
            .offset(y: -effectiveDimension * 0.36)
    }

    // MARK: - Center boss
    private func centerBoss() -> some View {
        ZStack {
            Circle()
                .fill(BudgetVaultTheme.titaniumBezel)
                .frame(width: effectiveDimension * 0.22, height: effectiveDimension * 0.22)
                .overlay(
                    Circle()
                        .strokeBorder(BudgetVaultTheme.titanium800, lineWidth: 1)
                )
            Circle()
                .fill(BudgetVaultTheme.chamberBlack)
                .frame(width: effectiveDimension * 0.14, height: effectiveDimension * 0.14)
            Image(systemName: lockGlyphName)
                .font(.system(size: effectiveDimension * 0.09, weight: .bold))
                .foregroundStyle(lockGlyphColor)
        }
    }

    private var lockGlyphName: String {
        if case .open = state { return "lock.open.fill" }
        return "lock.fill"
    }

    private var lockGlyphColor: Color {
        if case .open = state { return BudgetVaultTheme.accentSoft }
        return BudgetVaultTheme.titanium100
    }
}

private struct DialPointerTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

#Preview("VaultDial — sizes & states") {
    ScrollView {
        VStack(spacing: 40) {
            Group {
                Text("hero · locked").font(.caption).foregroundStyle(.white.opacity(0.7))
                VaultDial(size: .hero, state: .locked)

                Text("hero · open + glow").font(.caption).foregroundStyle(.white.opacity(0.7))
                VaultDial(size: .hero, state: .open, showGlow: true)

                Text("large · progress(0.72)").font(.caption).foregroundStyle(.white.opacity(0.7))
                VaultDial(size: .large, state: .progress(0.72))

                Text("medium · locked").font(.caption).foregroundStyle(.white.opacity(0.7))
                VaultDial(size: .medium, state: .locked)

                Text("small · locked (no numerals)").font(.caption).foregroundStyle(.white.opacity(0.7))
                VaultDial(size: .small, state: .locked, showNumerals: false)

                Text("watermark · 10% opacity").font(.caption).foregroundStyle(.white.opacity(0.7))
                VaultDial(size: .watermark, state: .locked)
            }
        }
        .padding()
    }
    .background(BudgetVaultTheme.navyDark)
}
