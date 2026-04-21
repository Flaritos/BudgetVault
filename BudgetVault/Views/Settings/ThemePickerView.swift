import SwiftUI
import BudgetVaultShared

/// Accent color picker — VaultRevamp v2.1 Phase 8.3 §5.3.
///
/// Pixel-matched to `mockup-theme-picker.html`:
/// - 80pt preview orb with accent-colored drop shadow (0 8 24 @ 40%)
/// - "CURRENT" eyebrow label in titanium400 (10pt, 0.28em tracking)
/// - 22pt bold color name (updates with selection — "Electric Blue",
///   "Purple", "Emerald", etc.)
/// - 5-column color grid with 14pt gap
/// - Unselected: 2pt titanium @ 15% border + drop shadow
/// - Selected: titanium radial bezel with inner color inset 4pt
/// - Hint card at bottom: "Applied to buttons, charts, and highlights
///   throughout the app. Free for everyone — no premium gating."
struct ThemePickerView: View {
    @AppStorage(AppStorageKeys.accentColorHex) private var accentColorHex = "#2563EB"
    @Environment(\.dismiss) private var dismiss

    // 5 across per mockup line 90
    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var currentAccentName: String {
        BudgetVaultTheme.accentColorOptions
            .first(where: { $0.hex == accentColorHex })?
            .name ?? "Custom"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BudgetVaultTheme.navyDark.ignoresSafeArea()

                VStack(spacing: 0) {
                    previewHeader
                        .padding(.top, 32)
                        .padding(.bottom, 40)

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(BudgetVaultTheme.accentColorOptions, id: \.hex) { option in
                            swatch(option: option)
                        }
                    }
                    .padding(.horizontal, 24 + 8)

                    hintCard
                        .padding(.top, 36)
                        .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .navigationTitle("Accent Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(BudgetVaultTheme.navyDark, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(BudgetVaultTheme.accentSoft)
                }
            }
        }
    }

    // MARK: - Preview Header

    @ViewBuilder
    private var previewHeader: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(Color(hex: accentColorHex))
                .frame(width: 80, height: 80)
                .shadow(color: Color(hex: accentColorHex).opacity(0.4), radius: 24, y: 8)

            VStack(spacing: 4) {
                // Mockup lines 78–81: 10pt, 0.28em tracking, uppercase
                Text("CURRENT")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.8)
                    .foregroundStyle(BudgetVaultTheme.titanium400)

                // Mockup lines 82–85: 22pt bold, -0.02em tracking
                Text(currentAccentName)
                    .font(.system(size: 22, weight: .bold))
                    .tracking(-0.44)
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
        }
    }

    // MARK: - Swatch

    @ViewBuilder
    private func swatch(option: (name: String, hex: String)) -> some View {
        let isSelected = accentColorHex == option.hex

        Button {
            HapticManager.selection()
            accentColorHex = option.hex
        } label: {
            ZStack {
                if isSelected {
                    // Mockup lines 102–106: 3pt transparent padding
                    // with titanium radial bezel — the "dial frame"
                    // treatment. Implemented as a stroked circle with
                    // a transparent inner edge.
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    BudgetVaultTheme.titanium200,
                                    BudgetVaultTheme.titanium400,
                                    BudgetVaultTheme.titanium600,
                                    BudgetVaultTheme.titanium400,
                                    BudgetVaultTheme.titanium200
                                ],
                                center: .center
                            ),
                            lineWidth: 3
                        )

                    Circle()
                        .fill(Color(hex: option.hex))
                        .padding(4)
                        // Mockup line 114: inner shadow
                        // inset 0 1px 3px rgba(0,0,0,0.4) — simulated
                        // with a tight black inset overlay.
                        .overlay(
                            Circle()
                                .stroke(.black.opacity(0.4), lineWidth: 1)
                                .blur(radius: 1)
                                .padding(4)
                                .mask(
                                    Circle()
                                        .padding(4)
                                )
                        )

                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    // Mockup lines 94–101: unselected cell — 2pt
                    // titanium @ 15% border + black @ 30% shadow.
                    Circle()
                        .fill(Color(hex: option.hex))
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    BudgetVaultTheme.titanium300.opacity(0.15),
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.name)\(isSelected ? ", selected" : "")")
    }

    // MARK: - Hint Card

    @ViewBuilder
    private var hintCard: some View {
        // Mockup lines 125–141: titanium-tinted hint card with blue
        // info icon on the left.
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(BudgetVaultTheme.accentSoft)
                .padding(.top, 1)

            (Text("Applied to buttons, charts, and highlights throughout the app. ")
                + Text("Free for everyone").foregroundStyle(.white).fontWeight(.semibold)
                + Text(" \u{2014} no premium gating."))
                .font(.system(size: 13))
                .foregroundStyle(BudgetVaultTheme.titanium300)
                .lineSpacing(3)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(BudgetVaultTheme.titanium300.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(BudgetVaultTheme.titanium300.opacity(0.14), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
