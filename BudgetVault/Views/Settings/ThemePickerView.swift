import SwiftUI
import BudgetVaultShared

struct ThemePickerView: View {
    @AppStorage(AppStorageKeys.accentColorHex) private var accentColorHex = "#2563EB"
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.adaptive(minimum: 70), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Preview
                VStack(spacing: 12) {
                    Circle()
                        .fill(Color(hex: accentColorHex))
                        .frame(width: 64, height: 64)
                        .shadow(color: Color(hex: accentColorHex).opacity(0.4), radius: 8, y: 4)

                    Text("Current Accent")
                        .font(.subheadline)
                        .foregroundStyle(BudgetVaultTheme.titanium300)
                }
                .padding(.top, 8)

                // Color Grid — all 10 colors free for everyone
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(BudgetVaultTheme.accentColorOptions, id: \.hex) { option in
                        let isSelected = accentColorHex == option.hex

                        Button {
                            accentColorHex = option.hex
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    // Phase 8.3 §5.3: selected swatch gets
                                    // a 3pt titanium radial bezel so the
                                    // accent reads as "locked into the
                                    // dial" — same mechanical metaphor as
                                    // the VaultDial primitive itself.
                                    // Unselected swatches get a 2pt inner
                                    // stroke so they still read as set
                                    // stones, not floating dots.
                                    if isSelected {
                                        Circle()
                                            .stroke(
                                                RadialGradient(
                                                    colors: [
                                                        BudgetVaultTheme.titanium300,
                                                        BudgetVaultTheme.titanium500
                                                    ],
                                                    center: .center,
                                                    startRadius: 0,
                                                    endRadius: 28
                                                ),
                                                lineWidth: 3
                                            )
                                            .frame(width: 56, height: 56)
                                    }

                                    Circle()
                                        .fill(Color(hex: option.hex))
                                        .overlay(
                                            Circle()
                                                .strokeBorder(
                                                    isSelected ? Color.clear : BudgetVaultTheme.titanium700.opacity(0.4),
                                                    lineWidth: isSelected ? 0 : 2
                                                )
                                        )
                                        .frame(width: 48, height: 48)
                                        .shadow(color: .black.opacity(0.3), radius: 2, y: 2)

                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }

                                Text(option.name)
                                    .font(.caption2)
                                    .foregroundStyle(isSelected ? BudgetVaultTheme.titanium200 : BudgetVaultTheme.titanium400)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(option.name)\(isSelected ? ", selected" : "")")
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BudgetVaultTheme.navyDark)
            .navigationTitle("Accent Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(BudgetVaultTheme.navyDark, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .tint(BudgetVaultTheme.accentSoft)
                }
            }
        }
    }
}
