import SwiftUI

/// In-app feedback sheet. Writes locally only. User explicitly chooses
/// whether to email the log to support — nothing is sent automatically.
struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var category: FeedbackService.Category = .featureRequest
    @State private var message: String = ""
    @State private var didSave = false
    @State private var showMailFallback = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Category", selection: $category) {
                        ForEach(FeedbackService.Category.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.symbol).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(BudgetVaultTheme.accentSoft)
                    .listRowBackground(BudgetVaultTheme.chamberDeep)
                } header: {
                    EngravedSectionHeader(title: "Type")
                }

                Section {
                    // Phase 8.2 §5.5: TextEditor resists `.background()`
                    // alone — the iOS 16+ override is
                    // `.scrollContentBackground(.hidden)` plus an
                    // explicit `.background(...)`. Without both, the
                    // editor keeps its default white fill under forced
                    // dark mode.
                    TextEditor(text: $message)
                        .frame(minHeight: 140)
                        .accessibilityLabel("Feedback message")
                        .scrollContentBackground(.hidden)
                        .background(BudgetVaultTheme.chamberDeep)
                        .foregroundStyle(.white)
                        .listRowBackground(BudgetVaultTheme.chamberDeep)
                } header: {
                    EngravedSectionHeader(title: "Your message")
                }

                Section {
                    // v3.2 audit M8: rewritten to sound confident instead of
                    // defensive. Privacy-first brand should assert the rule,
                    // not hedge with "we can't read unless…"
                    Text("Stored on this device. Only sent if you choose Email to BudgetVault below.")
                        .font(.caption)
                        .foregroundStyle(BudgetVaultTheme.titanium400)
                        .listRowBackground(BudgetVaultTheme.chamberDeep)
                }

                // v3.2 audit H10: Email button always visible so the
                // "Only sent if you tap Email…" helper text makes sense.
                // Disabled until the user has saved at least one entry.
                Section {
                    Button {
                        if let url = FeedbackService.mailtoURL() {
                            openURL(url) { accepted in
                                if !accepted { showMailFallback = true }
                            }
                        }
                    } label: {
                        Label("Email to BudgetVault", systemImage: "envelope.fill")
                    }
                    .disabled(!didSave && FeedbackService.count() == 0)
                    .tint(BudgetVaultTheme.accentSoft)
                    .listRowBackground(BudgetVaultTheme.chamberDeep)
                } footer: {
                    Text("Opens Mail with your feedback log attached as text. Nothing is sent until you hit Send.")
                        .foregroundStyle(BudgetVaultTheme.titanium400)
                }
            }
            .scrollContentBackground(.hidden)
            .background(BudgetVaultTheme.navyDark)
            .navigationTitle("Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(BudgetVaultTheme.navyDark, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(didSave ? "Done" : "Save") {
                        if didSave {
                            dismiss()
                        } else {
                            FeedbackService.append(category: category, message: message)
                            HapticManager.notification(.success)
                            withAnimation { didSave = true }
                        }
                    }
                    .disabled(!didSave && message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("No mail account configured", isPresented: $showMailFallback) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your feedback is still saved on-device. Add a Mail account in Settings if you'd like to email it.")
            }
        }
    }
}
