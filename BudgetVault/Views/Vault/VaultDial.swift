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
            // 1. Plate — bezel + chamber. Locked uses titanium chrome with
            //    deep navy chamber; open swaps to electric-blue tinted
            //    chamber with an outer aura glow.
            Image("\(assetPrefix)Plate")
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .frame(width: dim, height: dim)

            // 2. Ticks layer — rotates like a real combination dial, sliding
            //    past the fixed pointer above it. Locked set has major +
            //    minor ticks + 0/20/40/60/80 numerals; open set has just
            //    the 10 major ticks (the numerals have served their purpose
            //    once the vault is open).
            Image("\(assetPrefix)Ticks")
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .frame(width: dim, height: dim)
                .rotationEffect(.degrees(faceRotationDegrees))

            // 3. Top — pointer at 12 o'clock + center boss + lock glyph.
            //    Fixed. Locked is titanium; open swaps to electric blue
            //    with an OPEN padlock (shackle detached on one side).
            Image("\(assetPrefix)Top")
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .frame(width: dim, height: dim)

            // 4. Progress arc overlay (only when state = .progress).
            progressArc

            // 5. Open-state glow (when state = .open or showGlow forced).
            openGlow
        }
        .frame(width: dim, height: dim)
        .opacity(size.watermarkOpacity)
        .accessibilityHidden(true)
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
            }
        }
        .padding()
    }
    .background(BudgetVaultTheme.navyDark)
}
