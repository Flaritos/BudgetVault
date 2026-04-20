import SwiftUI

/// The hero vault primitive — a **1:1 port of the VaultRevamp HTML SVG dial**.
///
/// Coordinates are authored in the HTML's 260×260 viewBox (center 130,130, radius 130)
/// and scaled to the requested dimension via a single `scale = dim / 260` factor.
///
/// Layers (bottom to top):
///  1. Chamber fill (radial gradient `#0f1e38` → `#070E1F` → `#030610`) — r = 112/260
///  2. Chamber stroke (`#2E3645`, 1.5pt scaled)
///  3. Bezel **ring** (radial gradient, transparent inside 82% of 130, bright rim) — drawn
///     as a stroked circle on the outer edge of radius 130
///  4. Ticks — 10 major (every 36°, length 14, width 2 / top 2.5) + 50 minor (every 6°,
///     length 8, width 0.9, opacity 0.55); these rotate with the dial state
///  5. Numerals — 0/20/40/60/80 at radius 68 from center (HTML's exact pixel anchors)
///  6. Pointer — fixed blue triangle at 12 o'clock, 12pt × 14pt in 260-space
///  7. Center boss — radius 32 radial gradient + inner black disc radius 26
///  8. Lock glyph — custom `Path` (NOT SF Symbol): 22×18 body + quadratic-Bezier shackle
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

        /// Below this size, numerals are too small to read — hide them.
        var hidesNumerals: Bool {
            switch self {
            case .small, .watermark: return true
            default: return false
            }
        }

        /// Below this size, minor ticks become visual noise — hide them.
        var hidesMinorTicks: Bool {
            self == .small
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

    @ScaledMetric(relativeTo: .largeTitle) private var scaleFactor: CGFloat = 1.0

    // MARK: - Resolved geometry

    /// Outer dimension after Dynamic Type scaling.
    private var dim: CGFloat { size.dimension * scaleFactor }

    /// Maps HTML 260-space units → SwiftUI points.
    private var k: CGFloat { dim / 260 }

    private var rotationDegrees: Double {
        switch state {
        case .locked: return 0
        case .open: return 72
        case .progress(let p): return max(0, min(p, 1.0)) * 360
        }
    }

    private var isOpenState: Bool {
        if case .open = state { return true }
        return false
    }

    private var shouldDrawNumerals: Bool {
        showNumerals && !size.hidesNumerals
    }

    private var shouldDrawMinorTicks: Bool {
        !size.hidesMinorTicks
    }

    // HTML-exact colors used only here (not in theme tokens).
    private let chamberStop0 = Color(red: 0x0F/255, green: 0x1E/255, blue: 0x38/255) // #0f1e38
    private let chamberStop1 = Color(red: 0x07/255, green: 0x0E/255, blue: 0x1F/255) // #070E1F
    private let chamberStop2 = Color(red: 0x03/255, green: 0x06/255, blue: 0x10/255) // #030610
    private let pointerStroke = Color(red: 0x1E/255, green: 0x3A/255, blue: 0x8A/255) // #1e3a8a

    var body: some View {
        ZStack {
            chamber
            bezelRing
            rotatingDialContents
                .rotationEffect(.degrees(rotationDegrees))
                .animation(.easeOut(duration: 0.6), value: rotationDegrees)
            progressArc
            pointer
            centerBoss
            openGlow
        }
        .frame(width: dim, height: dim)
        .opacity(size.watermarkOpacity)
        .accessibilityHidden(true)
    }

    // MARK: - 1. Chamber (r=112) — radial gradient fill + 1.5pt stroke

    private var chamber: some View {
        // HTML: <radialGradient cx=50% cy=50% r=50%> 0% #0f1e38 → 70% #070E1F → 100% #030610
        // Applied to a circle of r=112 (diameter 224 in 260-space).
        let chamberDiameter = 224 * k
        return Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: chamberStop0, location: 0.0),
                        .init(color: chamberStop1, location: 0.7),
                        .init(color: chamberStop2, location: 1.0)
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: chamberDiameter / 2
                )
            )
            .overlay(
                Circle()
                    .strokeBorder(BudgetVaultTheme.titanium700, lineWidth: max(0.5, 1.5 * k))
            )
            .frame(width: chamberDiameter, height: chamberDiameter)
    }

    // MARK: - 2. Bezel ring (annulus, 82%→100% of r=130 → inner r=107, outer r=130)

    private var bezelRing: some View {
        // HTML radial gradient (within 260-space, center=130, r=130):
        //   82% (r=107): #434D5E opacity 0
        //   88% (r=114.4): #E4E8EE
        //   93% (r=120.9): #A8B2C2
        //   97% (r=126.1): #5E6A7C
        //  100% (r=130): #1D2330
        //
        // SwiftUI: full-disc Circle filled with an equivalent RadialGradient,
        // clipped to the annulus via a shape mask so the chamber shows through inside.
        let outerR = 130 * k
        return Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: BudgetVaultTheme.titanium600.opacity(0), location: 0.82),
                        .init(color: BudgetVaultTheme.titanium100,               location: 0.88),
                        .init(color: BudgetVaultTheme.titanium300,               location: 0.93),
                        .init(color: BudgetVaultTheme.titanium500,               location: 0.97),
                        .init(color: BudgetVaultTheme.titanium800,               location: 1.00)
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: outerR
                )
            )
            .frame(width: outerR * 2, height: outerR * 2)
    }

    // MARK: - 3+4. Rotating contents (ticks + numerals)

    private var rotatingDialContents: some View {
        ZStack {
            majorTicks
            if shouldDrawMinorTicks { minorTicks }
            if shouldDrawNumerals { numerals }
        }
        .frame(width: dim, height: dim)
    }

    // 10 major ticks, every 36°. Top (0°) is brighter + thicker; others are titanium300.
    private var majorTicks: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { i in
                let isTop = (i == 0)
                DialTick(
                    lengthInnerR: 92,
                    lengthOuterR: 106,
                    k: k
                )
                .stroke(
                    isTop ? BudgetVaultTheme.titanium100 : BudgetVaultTheme.titanium300,
                    style: StrokeStyle(
                        lineWidth: (isTop ? 2.5 : 2.0) * k,
                        lineCap: .butt
                    )
                )
                .rotationEffect(.degrees(Double(i) * 36))
            }
        }
    }

    // 50 minor ticks every 6° EXCEPT at major positions (multiples of 36°).
    private var minorTicks: some View {
        ZStack {
            ForEach(1..<60, id: \.self) { i in
                // Skip multiples of 6 that coincide with majors: i*6 % 36 == 0
                if (i * 6) % 36 != 0 {
                    DialTick(
                        lengthInnerR: 98,
                        lengthOuterR: 106,
                        k: k
                    )
                    .stroke(
                        BudgetVaultTheme.titanium300,
                        style: StrokeStyle(
                            lineWidth: 0.9 * k,
                            lineCap: .butt
                        )
                    )
                    .opacity(0.55)
                    .rotationEffect(.degrees(Double(i) * 6))
                }
            }
        }
    }

    // MARK: - 5. Numerals — HTML pixel anchors mapped into 260-space

    private var numerals: some View {
        // HTML anchors (x,y in 260-space, center=130,130):
        //   0  (130,  62) → offset from center ( 0, -68)
        //   20 (206, 109) → ( 76, -21)
        //   40 (177, 198) → ( 47,  68)
        //   60 ( 83, 198) → (-47,  68)
        //   80 ( 54, 109) → (-76, -21)
        let anchors: [(label: String, dx: CGFloat, dy: CGFloat)] = [
            ("0",   0, -68),
            ("20", 76, -21),
            ("40", 47,  68),
            ("60", -47, 68),
            ("80", -76, -21)
        ]
        return ZStack {
            ForEach(anchors, id: \.label) { a in
                Text(a.label)
                    .font(.system(size: 12 * k, weight: .semibold))
                    .foregroundStyle(BudgetVaultTheme.titanium100)
                    .offset(x: a.dx * k, y: a.dy * k)
            }
        }
    }

    // MARK: - 6. Pointer — fixed blue triangle at 12 o'clock (does NOT rotate)

    private var pointer: some View {
        // HTML: M130 12 L136 26 L124 26 Z → vertices in 260-space.
        // Top apex is 118 units above center (130-12=118); triangle is 12w × 14h.
        DialPointerTriangle()
            .fill(BudgetVaultTheme.accentSoft) // #60A5FA
            .overlay(
                DialPointerTriangle()
                    .stroke(pointerStroke, lineWidth: 0.5 * k)
            )
            .frame(width: 12 * k, height: 14 * k)
            // Apex top sits at y = 12 in 260-space → distance from dial center = 118.
            // So the triangle's geometric center sits at y = (12+26)/2 = 19 → distance 111.
            .offset(y: -111 * k)
    }

    // MARK: - 7. Center boss — r=32 outer, r=26 inner black

    private var centerBoss: some View {
        let outerD = 64 * k
        let innerD = 52 * k
        return ZStack {
            // Outer boss with radial gradient: 0% #E4E8EE, 60% #A8B2C2, 100% #2E3645
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(stops: [
                            .init(color: BudgetVaultTheme.titanium100, location: 0.0),
                            .init(color: BudgetVaultTheme.titanium300, location: 0.6),
                            .init(color: BudgetVaultTheme.titanium700, location: 1.0)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: outerD / 2
                    )
                )
                .frame(width: outerD, height: outerD)

            // Inner black recess + 1pt titanium-700 hairline
            Circle()
                .fill(chamberStop2) // #030610
                .frame(width: innerD, height: innerD)
                .overlay(
                    Circle()
                        .strokeBorder(BudgetVaultTheme.titanium700, lineWidth: max(0.5, 1 * k))
                        .frame(width: innerD, height: innerD)
                )

            // Lock glyph (or open when state == .open).
            // HTML bounding box: width 22 (body is widest at -11…+11), height 30
            // (shackle top y=-18 … body bottom y=+12). Glyph is translated upward
            // by 3pt in 260-space so body sits slightly below center like HTML.
            LockGlyph(isOpen: isOpenState)
                .stroke(
                    isOpenState ? BudgetVaultTheme.accentSoft : BudgetVaultTheme.titanium300,
                    style: StrokeStyle(lineWidth: 1.5 * k, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 22 * k, height: 30 * k)
                .offset(y: -3 * k) // HTML glyph center-of-mass is above (0,0)
        }
    }

    // MARK: - Progress arc (only for .progress state)

    @ViewBuilder
    private var progressArc: some View {
        if case .progress(let p) = state {
            Circle()
                .trim(from: 0, to: max(0.001, min(p, 1.0)))
                .stroke(
                    BudgetVaultTheme.neonGreen,
                    style: StrokeStyle(
                        lineWidth: 3.5 * k,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 180 * k, height: 180 * k)
                .animation(.easeOut(duration: 0.5), value: p)
        }
    }

    // MARK: - Open-state glow

    @ViewBuilder
    private var openGlow: some View {
        if isOpenState || showGlow {
            Circle()
                .stroke(BudgetVaultTheme.accentSoft.opacity(0.4), lineWidth: 5 * k)
                .blur(radius: 15 * k)
                .frame(width: 224 * k, height: 224 * k)
        }
    }
}

// MARK: - DialTick (radial line from inner to outer radius at the top)

private struct DialTick: Shape {
    /// Inner radius in 260-space.
    let lengthInnerR: CGFloat
    /// Outer radius in 260-space.
    let lengthOuterR: CGFloat
    /// Scale factor (dim / 260).
    let k: CGFloat

    func path(in rect: CGRect) -> Path {
        let centerX = rect.midX
        let centerY = rect.midY
        var p = Path()
        // Line straight up (toward 12 o'clock). Rotation applied externally.
        p.move(to: CGPoint(x: centerX, y: centerY - lengthOuterR * k))
        p.addLine(to: CGPoint(x: centerX, y: centerY - lengthInnerR * k))
        return p
    }
}

// MARK: - Pointer triangle (HTML: M130 12 L136 26 L124 26 Z)

private struct DialPointerTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))   // top apex (130,12)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY)) // bottom-right (136,26)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY)) // bottom-left (124,26)
        p.closeSubpath()
        return p
    }
}

// MARK: - Lock glyph (custom path — 22×18 rect body + arched shackle)

/// Draws the HTML SVG lock glyph.
///
/// Local (0,0) origin = center of the 22×18 body (HTML placed the body at x=-11, y=-6,
/// w=22, h=18; shackle arches up from (-7,-6) via (0,-18) to (7,-6)).
///
/// In our `rect` (width 26, height 36), we translate so that the body sits in the
/// lower portion and the shackle sits above it, matching the HTML's vertical distribution.
private struct LockGlyph: Shape {
    var isOpen: Bool = false

    func path(in rect: CGRect) -> Path {
        // The HTML glyph lives in a 22×30 bounding box:
        //   body: x=-11…+11, y=-6…+12 (22×18)
        //   shackle top: y=-18
        //
        // Map HTML (0,0) to rect center-left-vertically: x_screen = rect.midX + x_html * sx,
        //                                                  y_screen = rect.minY + (y_html + 18) * sy
        let sx = rect.width / 22
        let sy = rect.height / 30
        func toScreen(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.midX + x * sx,
                    y: rect.minY + (y + 18) * sy)
        }

        var p = Path()

        // --- Body: rounded rect, HTML (x=-11, y=-6, w=22, h=18, rx=2)
        let bodyRect = CGRect(
            x: rect.midX + (-11) * sx,
            y: rect.minY + (-6 + 18) * sy,
            width: 22 * sx,
            height: 18 * sy
        )
        p.addRoundedRect(
            in: bodyRect,
            cornerSize: CGSize(width: 2 * sx, height: 2 * sy),
            style: .continuous
        )

        // --- Shackle: HTML path "M -7 -6 L -7 -13 Q -7 -18 0 -18 Q 7 -18 7 -13 L 7 -6"
        if isOpen {
            // Tilted shackle for open state: shift the right leg up+right by a few units.
            p.move(to: toScreen(-7, -6))
            p.addLine(to: toScreen(-7, -13))
            p.addQuadCurve(to: toScreen(2, -18), control: toScreen(-7, -18))
            p.addQuadCurve(to: toScreen(9, -13), control: toScreen(9, -18))
            p.addLine(to: toScreen(9, -8))
        } else {
            p.move(to: toScreen(-7, -6))
            p.addLine(to: toScreen(-7, -13))
            p.addQuadCurve(to: toScreen(0, -18), control: toScreen(-7, -18))
            p.addQuadCurve(to: toScreen(7, -13), control: toScreen(7, -18))
            p.addLine(to: toScreen(7, -6))
        }

        return p
    }
}

#Preview("VaultDial — sizes & states") {
    ScrollView {
        VStack(spacing: 40) {
            Group {
                Text("hero · locked").font(.caption).foregroundStyle(.white.opacity(0.7))
                VaultDial(size: .hero, state: .locked)
                    .shadow(color: .black.opacity(0.6), radius: 40, x: 0, y: 20)

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
