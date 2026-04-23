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

    /// Audit 2026-04-23 Smoke-6: at `.display` size (60pt) a digit plate
    /// consumes ~55pt including padding. Amounts with 10+ chars (e.g.
    /// `$12,345.67`) overflow the entry screen and earlier plates get
    /// clipped off the leading edge. Scale the whole HStack down when
    /// the formatted string exceeds 9 chars so every digit stays on
    /// screen. Formula `9/count` keeps typical amounts (≤ $9,999.99,
    /// i.e. 9 chars) at 1.0 and degrades smoothly for income/net-worth
    /// entry up to 15-char magnitudes.
    private var fitScale: CGFloat {
        let count = formatted.count
        guard count > 9 else { return 1.0 }
        return 9.0 / CGFloat(count)
    }

    private var effectiveScale: CGFloat { scale * fitScale }

    var body: some View {
        HStack(spacing: style.spacing * effectiveScale) {
            ForEach(Array(formatted.enumerated()), id: \.offset) { _, char in
                character(char)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(contextLabel.map { "\($0), \(formatted)" } ?? formatted)
    }

    @ViewBuilder
    private func character(_ char: Character) -> some View {
        if char.isNumber {
            digitPlate(String(char))
        } else {
            sepSpan(String(char))
        }
    }

    private func digitPlate(_ digit: String) -> some View {
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

    private func sepSpan(_ sep: String) -> some View {
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
