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
                Section("Type") {
                    Picker("Category", selection: $category) {
                        ForEach(FeedbackService.Category.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.symbol).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Your message") {
                    TextEditor(text: $message)
                        .frame(minHeight: 140)
                        .accessibilityLabel("Feedback message")
                }

                Section {
                    Text("Saved on this device only. We can't read it unless you tap “Email to BudgetVault” below — your call.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if didSave {
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
                    } footer: {
                        Text("Opens Mail with your full feedback log attached as text. Nothing is sent until you hit Send.")
                    }
                }
            }
            .navigationTitle("Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
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
