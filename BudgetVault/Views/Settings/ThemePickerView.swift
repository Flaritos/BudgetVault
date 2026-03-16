import SwiftUI

struct ThemePickerView: View {
    @AppStorage(AppStorageKeys.accentColorHex) private var accentColorHex = "#2563EB"
    @AppStorage(AppStorageKeys.isPremium) private var isPremium = false
    @Environment(\.dismiss) private var dismiss

    @State private var showPaywall = false

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

                // Color Grid
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(BudgetVaultTheme.accentColorOptions, id: \.hex) { option in
                        let isSelected = accentColorHex == option.hex
                        let isDefault = option.hex == "#2563EB"
                        let isLocked = !isPremium && !isDefault

                        Button {
                            if isLocked {
                                showPaywall = true
                            } else {
                                accentColorHex = option.hex
                            }
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

                                    if isLocked {
                                        Circle()
                                            .fill(.black.opacity(0.35))
                                            .frame(width: 48, height: 48)

                                        Image(systemName: "lock.fill")
                                            .font(.caption)
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
                        .accessibilityLabel("\(option.name)\(isSelected ? ", selected" : "")\(isLocked ? ", premium required" : "")")
                    }
                }
                .padding(.horizontal)

                if !isPremium {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                        Text("Unlock all colors with Premium")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }

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
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
}
