import SwiftUI

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
                        .foregroundStyle(.secondary)
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

                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.body.bold())
                                            .foregroundStyle(.white)
                                    }
                                }

                                Text(option.name)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
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
            .navigationTitle("Accent Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
