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
                                    Circle()
                                        .fill(Color(hex: option.hex))
                                        .frame(width: 48, height: 48)
                                    // Phase 8.2 §5.7: every non-selected
                                    // swatch gets a subtle titanium rim so
                                    // it reads as a "set bezel" on the
                                    // navy chamber, not a floating dot.
                                    Circle()
                                        .strokeBorder(BudgetVaultTheme.titanium700.opacity(0.6), lineWidth: 1)
                                        .frame(width: 48, height: 48)

                                    if isSelected {
                                        // Selected swatch gets the full
                                        // titanium bezel — the accent is
                                        // "locked into the dial."
                                        Circle()
                                            .strokeBorder(BudgetVaultTheme.titanium200, lineWidth: 2)
                                            .frame(width: 52, height: 52)
                                        Image(systemName: "checkmark")
                                            .font(.body.bold())
                                            .foregroundStyle(.white)
                                    }
                                }

                                Text(option.name)
                                    .font(.caption2)
                                    .foregroundStyle(BudgetVaultTheme.titanium400)
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
