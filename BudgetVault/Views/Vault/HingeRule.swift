import SwiftUI

/// Horizontal titanium rule, three weights. Used at the top of Home ("door
/// edge"), and as section dividers between chambers. Decorative — accessibility-hidden.
struct HingeRule: View {
    enum Weight {
        case thin    // 1pt, 55% opacity
        case medium  // section divider
        case heavy   // door-edge, once per screen maximum
    }

    let weight: Weight

    private var height: CGFloat {
        switch weight {
        case .thin: return 1
        case .medium: return 1
        case .heavy: return 2
        }
    }

    private var opacity: Double {
        switch weight {
        case .thin: return 0.55
        case .medium: return 0.75
        case .heavy: return 1.0
        }
    }

    var body: some View {
        BudgetVaultTheme.titaniumBrushed
            .frame(height: height)
            .opacity(opacity)
            .accessibilityHidden(true)
    }
}

#Preview("HingeRule — all weights") {
    VStack(spacing: 40) {
        VStack(alignment: .leading, spacing: 4) {
            Text("Heavy (door edge)").font(.caption).foregroundStyle(.secondary)
            HingeRule(weight: .heavy)
        }
        VStack(alignment: .leading, spacing: 4) {
            Text("Medium (section divider)").font(.caption).foregroundStyle(.secondary)
            HingeRule(weight: .medium)
        }
        VStack(alignment: .leading, spacing: 4) {
            Text("Thin (subtle)").font(.caption).foregroundStyle(.secondary)
            HingeRule(weight: .thin)
        }
    }
    .padding()
    .background(BudgetVaultTheme.navyDark)
}
