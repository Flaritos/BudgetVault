import SwiftUI

/// Reusable emoji circle category picker chip used across transaction entry,
/// transaction edit, recurring expense form, and move money views.
struct CategoryChipView: View {
    let emoji: String
    let name: String
    var isSelected: Bool = false
    var chipSize: CGFloat = 44
    var chipWidth: CGFloat = 56

    var body: some View {
        VStack(spacing: BudgetVaultTheme.spacingXS) {
            Text(emoji)
                .font(.title2)
                .frame(width: chipSize, height: chipSize)
                .background(
                    Circle()
                        .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                )
            Text(name)
                .font(.caption2)
                .lineLimit(1)
                .foregroundStyle(.secondary)
        }
        .frame(width: chipWidth)
    }
}
