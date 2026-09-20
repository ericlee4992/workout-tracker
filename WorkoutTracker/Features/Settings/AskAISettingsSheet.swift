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
    @AppStorage(TerraAccess.photoConsentKey) private var photoConsent = false
    @AppStorage(TerraAccess.routineConsentKey) private var routineConsent = false

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
                    Text("GPT-5.6 Terra identifies equipment and drafts weekly routines. Photos and routine details are sent to OpenAI only with your permission. API usage is billed to your key. OpenAI may retain data under its API policies.")
                }

                Section("Permissions") {
                    Toggle("Send equipment photos to OpenAI", isOn: $photoConsent)
                    Toggle("Send routine details to OpenAI", isOn: $routineConsent)
                    Link("OpenAI API data policies", destination: URL(string: "https://developers.openai.com/api/docs/guides/your-data")!)
                }
                Section {
                    SecureField(hasKey ? "Replace the saved key" : "OpenAI API key", text: $key)
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
                    Text(failure ?? "Kept in this phone’s keychain only. Private trial: use your own OpenAI API key.")
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
