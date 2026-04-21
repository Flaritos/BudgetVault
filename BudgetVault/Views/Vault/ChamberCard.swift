import SwiftUI

/// Deep-recessed panel for amount displays and stat groupings. Chamber
/// gradient background, titanium hairline border, inset + drop shadows
/// for the "vault door sunk into wall" feel. Accepts arbitrary content.
struct ChamberCard<Content: View>: View {
    let padding: CGFloat
    @ViewBuilder let content: () -> Content

    init(padding: CGFloat = 20, @ViewBuilder content: @escaping () -> Content) {
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(BudgetVaultTheme.chamberBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(BudgetVaultTheme.titanium300.opacity(0.14), lineWidth: 1)
            )
            // Inner top-edge highlight
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .inset(by: 1)
                    .stroke(.white.opacity(0.06), lineWidth: 1)
                    .mask(
                        LinearGradient(
                            colors: [.white, .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            )
            // Inner bottom-edge shadow
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .inset(by: 1)
                    .stroke(.black.opacity(0.50), lineWidth: 1)
                    .mask(
                        LinearGradient(
                            colors: [.clear, .black],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    )
            )
            .shadow(color: .black.opacity(0.40), radius: 12, y: 4)
    }
}

#Preview("ChamberCard — variants") {
    VStack(spacing: 24) {
        ChamberCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("DAILY ALLOWANCE")
                    .font(BudgetVaultTheme.engravedLabel())
                    .textCase(.uppercase)
                    .tracking(2.4)
                    .foregroundStyle(.white.opacity(0.55))
                Text("$142.38")
                    .font(.system(size: 38, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }

        ChamberCard(padding: 16) {
            HStack {
                Text("SEALED").font(.caption).foregroundStyle(.white.opacity(0.55))
                Spacer()
                Text("13").font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
    }
    .padding()
    .background(BudgetVaultTheme.navyDark)
}
