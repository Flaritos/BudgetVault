import SwiftUI

/// Vault dial primitive — static layers are PNG assets rendered from the
/// HTML's inline SVG via Chrome headless (pixel-identical to the HTML
/// design). The numbered ring is a separate layer so it can rotate like
/// a real bank vault combination dial while the bezel, pointer, and lock
/// stay fixed.
///
/// Why PNG assets instead of hand-drawn SwiftUI? Hand-drawn SwiftUI can't
/// match Chrome's SVG rasterizer: subtle differences in gradient
/// interpolation, stroke anti-aliasing, and color-space conversion add up
/// to a visible drift from the HTML ground truth. Since the HTML design
/// *is* the ground truth, we use the exact same renderer (Chrome) to emit
/// @1x/@2x/@3x PNGs and display those.
///
/// Assets come in two sets — locked and open — each split into three
/// transparent layers stacked bottom→top so the numbered ring can rotate
/// while the pointer and lock stay fixed (real bank vault physics):
///
///   Locked set (from HTML Step 01, `/tmp/render-dial-ticks-rotate.js`):
///     1. `VaultDialHeroPlate` — titanium bezel + deep navy chamber.
///     2. `VaultDialHeroTicks` — major + minor ticks + 0/20/40/60/80.
///     3. `VaultDialHeroTop`   — blue pointer + boss + closed lock.
///
///   Open set (from HTML Step 11, `/tmp/render-dial-open.js`):
///     1. `VaultDialOpenPlate` — outer aura glow + bezel + blue-tinted
///        chamber with electric-blue stroke.
///     2. `VaultDialOpenTicks` — just the 10 major ticks (numerals have
///        served their purpose once the vault is open).
///     3. `VaultDialOpenTop`   — blue pointer + blue boss + OPEN padlock
///        (shackle detached on one side).
///
/// Three layers — not two — because the chamber is a solid fill, so ticks
/// can't live "under" it, and the pointer has to render above the
/// rotating ticks to sweep correctly.
// Audit 2026-04-22 P2-11: the audit recommended `.drawingGroup()` /
// `.compositingGroup()` on VaultDial, FlipDigitDisplay, and the
// envelope cards. After review the recommendation doesn't apply:
//   - VaultDial's production path uses PNG assets (already GPU raster)
//     and the tick layer rotates — drawingGroup would make rotation
//     animations choppy.
//   - FlipDigitDisplay has flip animations that drawingGroup disrupts.
//   - EnvelopeDepositBox is a simple LinearGradient + strokeBorder;
//     a rasterization pass would be more expensive than direct render.
// Intentional skip. Revisit only if Instruments flags these as hot.
struct VaultDial: View {
    enum Size {
        case hero       // 240pt — onboarding welcome, vault opens
        case large      // 80pt  — Home dashboard
        case medium     // 56pt  — FAB, Vault tab header
        case small      // 40pt  — section eyebrows
        case watermark  // 200pt at 10% opacity — Vault tab background
        case icon       // 24pt  — share-card watermarks, inline badges.
                        // Rendered via SwiftUI shapes (not PNG assets)
                        // so the glyph stays legible at 16–60pt when
                        // scaled via .frame(). The PNG-based sizes lose
                        // tick detail below ~40pt.

        var dimension: CGFloat {
            switch self {
            case .hero: return 240
            case .large: return 80
            case .medium: return 56
            case .small: return 40
            case .watermark: return 200
            case .icon: return 24
            }
        }

        var watermarkOpacity: Double {
            self == .watermark ? 0.10 : 1.0
        }

        fileprivate var isSynthetic: Bool {
            self == .icon
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

    /// Tint color for the `.icon` size only. PNG-based sizes (hero /
    /// large / medium / small / watermark) ignore this — they're
    /// titanium by design. Share-card and inline-badge callers pass
    /// a tint (white, electric blue, etc.) so the glyph reads on
    /// whatever backdrop the share card uses.
    var tint: Color = .white

    /// Rotation applied to the DIAL FACE (ticks + numerals) only. Bezel,
    /// chamber, pointer, and center boss stay fixed — matches how a real
    /// bank vault dial behaves when you spin the combination wheel.
    /// Default 0 = rest state (identical to a static PNG).
    var faceRotationDegrees: Double = 0

    @ScaledMetric(relativeTo: .largeTitle) private var scaleFactor: CGFloat = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Outer dimension after Dynamic Type scaling.
    private var dim: CGFloat { size.dimension * scaleFactor }

    private var isOpenState: Bool {
        if case .open = state { return true }
        return false
    }

    /// Asset prefix for the current state. Locked and progress share the
    /// titanium-chrome layer set; open swaps to the electric-blue "vault
    /// opens" layer set from HTML Step 11.
    private var assetPrefix: String {
        isOpenState ? "VaultDialOpen" : "VaultDialHero"
    }

    var body: some View {
        ZStack {
            if size.isSynthetic {
                syntheticIconBody
            } else {
                pngDialBody
            }

            progressArc

            openGlow
        }
        .frame(width: dim, height: dim)
        .opacity(size.watermarkOpacity)
        .accessibilityHidden(true)
    }

    /// PNG-asset dial — the canonical vault chrome used by every size
    /// except `.icon`. Three stacked raster layers animate independently.
    @ViewBuilder
    private var pngDialBody: some View {
        // 1. Plate — bezel + chamber.
        Image("\(assetPrefix)Plate")
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .frame(width: dim, height: dim)

        // 2. Ticks layer — rotates on combination changes.
        Image("\(assetPrefix)Ticks")
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .frame(width: dim, height: dim)
            .rotationEffect(.degrees(faceRotationDegrees))

        // 3. Top — pointer + boss + lock glyph.
        Image("\(assetPrefix)Top")
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .frame(width: dim, height: dim)
    }

    /// SwiftUI-synthesized brand glyph used for `.icon` size. Ring +
    /// simplified tick marks + pointer + lock symbol. Stays legible
    /// at 16pt (share-card footer) through 60pt (Stories watermark)
    /// when callers scale via `.frame()`. The `tint` parameter colors
    /// the whole glyph for flexibility against varied share-card
    /// backgrounds.
    @ViewBuilder
    private var syntheticIconBody: some View {
        let ringWidth = max(dim * 0.02, 1.2)
        let tickWidth = max(dim * 0.013, 0.8)
        let tickHeight = dim * 0.065
        let tickOffset = -(dim * 0.45)
        let pointerWidth = dim * 0.075
        let pointerHeight = dim * 0.06
        let pointerOffset = -(dim * 0.53)

        // Ring
        Circle()
            .strokeBorder(
                LinearGradient(
                    colors: [tint.opacity(0.35), tint.opacity(0.12)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: ringWidth
            )
            .frame(width: dim, height: dim)

        // Ticks (12 around; only the ticks rotate under faceRotationDegrees)
        ZStack {
            ForEach(0..<12, id: \.self) { i in
                RoundedRectangle(cornerRadius: tickWidth / 2)
                    .fill(tint.opacity(0.5))
                    .frame(width: tickWidth, height: tickHeight)
                    .offset(y: tickOffset)
                    .rotationEffect(.degrees(Double(i) * 30))
            }
        }
        .rotationEffect(.degrees(faceRotationDegrees))

        // Pointer (fixed at 12 o'clock)
        VaultIconPointer()
            .fill(tint)
            .frame(width: pointerWidth, height: pointerHeight)
            .offset(y: pointerOffset)

        // Lock glyph
        Image(systemName: isOpenState ? "lock.open.fill" : "lock.fill")
            .font(.system(size: dim * 0.35, weight: .semibold))
            .foregroundStyle(tint.opacity(0.9))
    }

    // MARK: - Progress arc (only for .progress state)

    @ViewBuilder
    private var progressArc: some View {
        if case .progress(let p) = state {
            // Arc lives in 260-space at radius ~90 (just inside the ticks).
            // Convert to point units via dim / 260.
            let k = dim / 260
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
                .animation(reduceMotion ? .none : .easeOut(duration: 0.5), value: p)
        }
    }

    // MARK: - Open-state glow

    @ViewBuilder
    private var openGlow: some View {
        if isOpenState || showGlow {
            let k = dim / 260
            Circle()
                .stroke(BudgetVaultTheme.accentSoft.opacity(0.4), lineWidth: 5 * k)
                .blur(radius: 15 * k)
                .frame(width: 224 * k, height: 224 * k)
        }
    }
}

// MARK: - Icon-only shapes

/// Pointer triangle used by the synthetic `.icon` dial. Standalone
/// shape (not shared with the PNG-based sizes, which bake the pointer
/// into their Top asset).
private struct VaultIconPointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
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

                Text("small · locked").font(.caption).foregroundStyle(.white.opacity(0.7))
                VaultDial(size: .small, state: .locked)

                Text("watermark · 10% opacity").font(.caption).foregroundStyle(.white.opacity(0.7))
                VaultDial(size: .watermark, state: .locked)

                Text("icon · 24pt white").font(.caption).foregroundStyle(.white.opacity(0.7))
                VaultDial(size: .icon, state: .locked, tint: .white)

                Text("icon · scaled to 60pt (share card)").font(.caption).foregroundStyle(.white.opacity(0.7))
                VaultDial(size: .icon, state: .locked, tint: .white)
                    .frame(width: 60, height: 60)

                Text("icon · 36pt electric blue").font(.caption).foregroundStyle(.white.opacity(0.7))
                VaultDial(size: .icon, state: .locked, tint: BudgetVaultTheme.electricBlue)
                    .frame(width: 36, height: 36)
            }
        }
        .padding()
    }
    .background(BudgetVaultTheme.navyDark)
}
