import SwiftUI
import BudgetVaultShared

/// Chamber-black flip-digit numeric display — the signature VaultRevamp
/// amount presentation. Each digit is a separately-rendered plate with a
/// hairline seam at 50% height, animating with a vertical flip on value
/// change. Currency symbols, thousands separators, and decimals render as
/// inline sep spans, NOT as flip plates.
struct FlipDigitDisplay: View {
    enum FlipStyle {
        case hero       // 54pt — daily allowance on Home
        case display    // 60pt — amount entry
        case large      // 38pt — chamber card amounts
        case medium     // 28pt — inline totals
        case small      // 20pt — stats row

        var baseSize: CGFloat {
            switch self {
            case .hero: return 54
            case .display: return 60
            case .large: return 38
            case .medium: return 28
            case .small: return 20
            }
        }

        var plateCornerRadius: CGFloat { baseSize * 0.055 }
        var plateHorizontalPadding: CGFloat { baseSize * 0.14 }
        var plateVerticalPadding: CGFloat { baseSize * 0.08 }
        var spacing: CGFloat { baseSize * 0.04 }
        var sepFontRatio: CGFloat { 0.82 }
    }

    let amount: Decimal
    let style: FlipStyle
    var currencyCode: String = "USD"
    var showCents: Bool = true
    /// Optional VoiceOver label that prefixes the amount — e.g.
    /// "Daily allowance" or "Amount entered". Without it, VoiceOver
    /// reads just the number, which loses context when the caller
    /// doesn't wrap the display in a labeled element.
    var contextLabel: String? = nil

    @ScaledMetric(relativeTo: .title) private var scale: CGFloat = 1.0
    // Audit 2026-04-22 P1-37: dynamically-scaled seam height. 1pt fixed
    // disappears at XL Accessibility sizes where the plate grows.
    @ScaledMetric(relativeTo: .title) private var seamHeight: CGFloat = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var formatted: String {
        // Use shared CurrencyFormatter for locale-aware display.
        let cents = Int64(truncating: (amount * 100) as NSDecimalNumber)
        return CurrencyFormatter.format(cents: cents, currencyCode: currencyCode)
    }

    /// Audit 2026-04-23 Smoke-6 / smoke-7: the original fixed-threshold
    /// `fitScale = 9/count` didn't know the actual parent width, so a
    /// 9-char amount like `$1,428.57` (daily allowance on Home hero card
    /// which is narrower than the Transaction Entry width) still
    /// overflowed and clipped the leading `$`/`1`. Replaced with
    /// `ViewThatFits` so SwiftUI picks the largest pre-rendered scale
    /// whose HStack actually fits the offered horizontal space. Plates
    /// and separators render at the chosen scale — no scaleEffect, so
    /// the ideal size propagates correctly to the parent layout.
    private static let fitCandidates: [CGFloat] = [1.0, 0.88, 0.76, 0.64, 0.52, 0.42]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            ForEach(Self.fitCandidates, id: \.self) { candidate in
                plateRow(fitScale: candidate)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(contextLabel.map { "\($0), \(formatted)" } ?? formatted)
    }

    private func plateRow(fitScale: CGFloat) -> some View {
        let effScale = scale * fitScale
        return HStack(spacing: style.spacing * effScale) {
            ForEach(Array(formatted.enumerated()), id: \.offset) { _, char in
                character(char, effectiveScale: effScale)
            }
        }
    }

    @ViewBuilder
    private func character(_ char: Character, effectiveScale: CGFloat) -> some View {
        if char.isNumber {
            digitPlate(String(char), effectiveScale: effectiveScale)
        } else {
            sepSpan(String(char), effectiveScale: effectiveScale)
        }
    }

    private func digitPlate(_ digit: String, effectiveScale: CGFloat) -> some View {
        Text(digit)
            .font(BudgetVaultTheme.flipDigitFont(size: style.baseSize * effectiveScale))
            .foregroundStyle(.white)
            .monospacedDigit()
            .padding(.horizontal, style.plateHorizontalPadding * effectiveScale)
            .padding(.vertical, style.plateVerticalPadding * effectiveScale)
            .background(
                RoundedRectangle(cornerRadius: style.plateCornerRadius)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color(hex: "#080C16"), location: 0.0),
                                .init(color: Color(hex: "#030610"), location: 0.5),
                                .init(color: Color(hex: "#080C16"), location: 0.5001),
                                .init(color: Color(hex: "#02040A"), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                // Hairline horizontal seam at 50%
                // Audit 2026-04-22 P1-37: scale the seam so it doesn't
                // vanish under XL Accessibility sizes where the plate
                // grows but a 1pt line stays 1pt (perceptually thinner).
                Rectangle()
                    .fill(.black)
                    .frame(height: seamHeight)
            )
            .overlay(alignment: .top) {
                // Below-seam highlight for mechanical flip feel
                Rectangle()
                    .fill(BudgetVaultTheme.titanium300.opacity(0.08))
                    .frame(height: seamHeight)
                    .padding(.top, seamHeight)
            }
            .overlay(
                RoundedRectangle(cornerRadius: style.plateCornerRadius)
                    .strokeBorder(BudgetVaultTheme.titanium300.opacity(0.18), lineWidth: 1)
            )
            .transition(
                reduceMotion
                    ? .opacity
                    : .asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    )
            )
            .animation(reduceMotion ? .none : .easeOut(duration: 0.3), value: digit)
    }

    private func sepSpan(_ sep: String, effectiveScale: CGFloat) -> some View {
        Text(sep)
            .font(BudgetVaultTheme.flipDigitFont(size: style.baseSize * style.sepFontRatio * effectiveScale))
            .foregroundStyle(BudgetVaultTheme.titanium300)
            .monospacedDigit()
    }
}

#Preview("FlipDigitDisplay — all styles") {
    VStack(alignment: .leading, spacing: 28) {
        Group {
            Text("hero · 54pt").font(.caption).foregroundStyle(.white.opacity(0.7))
            FlipDigitDisplay(amount: 142.38, style: .hero)

            Text("display · 60pt").font(.caption).foregroundStyle(.white.opacity(0.7))
            FlipDigitDisplay(amount: 47.50, style: .display)

            Text("large · 38pt").font(.caption).foregroundStyle(.white.opacity(0.7))
            FlipDigitDisplay(amount: 1247.99, style: .large)

            Text("medium · 28pt").font(.caption).foregroundStyle(.white.opacity(0.7))
            FlipDigitDisplay(amount: 84.12, style: .medium)

            Text("small · 20pt").font(.caption).foregroundStyle(.white.opacity(0.7))
            FlipDigitDisplay(amount: 13.00, style: .small)
        }
    }
    .padding()
    .background(BudgetVaultTheme.chamberBackground)
}
