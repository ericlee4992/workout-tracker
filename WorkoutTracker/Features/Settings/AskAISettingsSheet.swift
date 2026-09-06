import SwiftUI

/// Scanner accuracy, ticket 05 — where the developer's API key goes (D53).
///
/// The key is never shown back: the sheet says whether one is saved and
/// offers to replace or remove it. What is sent, and when, is said here in
/// plain words because it is the one place the user consents to it.
struct AskAISettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var hasKey = AskAIKeyStore.read() != nil
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Ask AI") {
                        Text(hasKey ? "On" : "Off")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("askAIStatus")
                } footer: {
                    Text("When a scan cannot place a plate, the results screen offers Ask AI. Tapping it sends the plate inside the box, with a small margin around it — never the whole photo — to Claude with this key, and the app ranks what it reads. On a new model, “Suggest exercises with AI” sends the manufacturer and model you typed, the plate's text and the app's exercise list. Nothing is sent otherwise, and nothing is stored.")
                }

                Section {
                    SecureField(hasKey ? "Replace the saved key" : "Anthropic API key", text: $key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("askAIKeyField")
                    Button("Save key") { save() }
                        .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("askAISaveKey")
                    if hasKey {
                        Button("Remove key", role: .destructive) {
                            AskAIKeyStore.delete()
                            hasKey = false
                            key = ""
                        }
                        .accessibilityIdentifier("askAIRemoveKey")
                    }
                } header: {
                    Text("Key")
                } footer: {
                    Text(failure ?? "Kept in this phone's keychain only. Each ask costs about a cent.")
                }
            }
            .navigationTitle("Ask AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func save() {
        do {
            try AskAIKeyStore.write(key)
            hasKey = AskAIKeyStore.read() != nil
            key = ""
            failure = nil
        } catch {
            failure = error.localizedDescription
        }
    }
}
