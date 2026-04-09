import SwiftUI

/// A branded share card for celebrating budget milestones.
/// Renders as a visually appealing card suitable for sharing via ShareLink.
struct ShareCardView: View {
    let title: String
    let subtitle: String
    let metric: String
    let metricLabel: String

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))

                Text(metric)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(metricLabel)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            Spacer().frame(height: 8)

            // Brand footer
            HStack(spacing: 6) {
                VaultDialMark(size: 16, color: .white.opacity(0.6))
                Text("budgetvault.io")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(32)
        .frame(width: 320, height: 280)
        .background(BudgetVaultTheme.brandGradient)
        .clipShape(RoundedRectangle(cornerRadius: BudgetVaultTheme.radiusXL, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
    }

    /// Render the card to a UIImage for sharing.
    @MainActor
    func renderImage() -> UIImage {
        let renderer = ImageRenderer(content: self)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage ?? UIImage()
    }
}
