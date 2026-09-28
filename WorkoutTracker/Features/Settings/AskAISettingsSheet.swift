import SwiftUI

/// X02 Ask AI settings (Floodlight ticket 09): where the OpenAI key goes (D56–D58) and the three
/// permissions. Key first — the prerequisite: a card whose status is the bold element, "On" with
/// the key's last four characters (user decision 3) or "Off"; the field is full width and **Save
/// key** (the one filled command) appears only once something is typed. Then one "Send to OpenAI"
/// header over the three permissions — what is sent · the feature that sends it — and the policy
/// link. Each permission stays independent and revocable, and is still asked for at the point of
/// use. Remove key is a quiet destructive row at the end and asks first. Toggles apply at once, so
/// the only chrome is Done. The disclosure paragraph is gone (decision 4).
struct AskAISettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var key = ""
    @State private var savedKey = AskAIKeyStore.read()
    @State private var failure: String?
    @State private var confirmRemove = false
    @State private var savedTick = 0
    @State private var headerHeight: CGFloat = 0
    @State private var bodyHeight: CGFloat = 0
    @FocusState private var keyFocused: Bool
    @AppStorage(TerraAccess.exerciseConsentKey) private var exerciseConsent = false
    @AppStorage(TerraAccess.photoConsentKey) private var photoConsent = false
    @AppStorage(TerraAccess.routineConsentKey) private var routineConsent = false

    private var hasKey: Bool { savedKey != nil }
    private var canSave: Bool { !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            header
                .exercisesMeasureHeight($headerHeight)
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    keyCard
                    permissions
                    if hasKey {
                        DestructiveRowButton("Remove key") { confirmRemove = true }
                            .accessibilityIdentifier("askAIRemoveKey")
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 10)
                .padding(.bottom, 28)
                .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.84), value: hasKey)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .exercisesMeasureContent($bodyHeight)
        }
        .exercisesSheetChrome(fitted: headerHeight + bodyHeight)
        .sensoryFeedback(.success, trigger: savedTick)
        .confirmationDialog("Remove the saved key?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove key", role: .destructive, action: remove)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Ask AI turns off until you add a key.")
        }
    }

    // MARK: Header

    private var header: some View {
        ZStack {
            Text("Ask AI")
                .font(look.font.navTitle)
                .foregroundStyle(look.textPrimary)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Spacer()
                // Identified: the key field's return key is also "Done".
                GlassCapsuleButton("Done") { dismiss() }
                    .accessibilityIdentifier("askAIDone")
            }
        }
        .padding(.horizontal, look.space.margin)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    // MARK: Key (the bold element)

    private var keyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                IconDisc(symbol: "sparkles", size: 52, context: hasKey ? .onSurface : .make)
                    .celebrate(savedTick)
                VStack(alignment: .leading, spacing: 3) {
                    Text(hasKey ? "On" : "Off")
                        .font(look.font.bigNumber)
                        .foregroundStyle(hasKey ? look.textPrimary : look.textSecondary)
                        .contentTransition(.opacity)
                    if let savedKey {
                        Text(AskAIKeyHint.masked(savedKey))
                            .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                            .foregroundStyle(look.textSecondary)
                            .accessibilityIdentifier("askAIKeyHint")
                    }
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(savedKey.map { "Ask AI, On, key \(AskAIKeyHint.masked($0))" } ?? "Ask AI, Off")
            .accessibilityIdentifier("askAIStatus")

            LookDivider()

            VStack(alignment: .leading, spacing: 10) {
                SecureField(hasKey ? "Replace the saved key" : "OpenAI API key", text: $key,
                            prompt: Text(hasKey ? "Replace the saved key" : "OpenAI API key").foregroundStyle(look.textSecondary))
                    // One font throughout (the prototype switched to monospaced once text arrived;
                    // a secure field shows only dots, so it bought nothing).
                    .font(look.font.body)
                    .foregroundStyle(look.textPrimary)
                    .tint(look.actionText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($keyFocused)
                    .submitLabel(.done)
                    .onSubmit(save)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 50)
                    .lookSurface(.field)
                    .accessibilityIdentifier("askAIKeyField")
                if canSave {
                    Button(action: save) {
                        Label("Save key", systemImage: "key.fill")
                    }
                    .buttonStyle(.lookPrimary)
                    .accessibilityIdentifier("askAISaveKey")
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
                if let failure {
                    SettingsNotice(symbol: "exclamationmark.triangle.fill", text: failure, emphasized: true)
                        .foregroundStyle(look.destructive)
                } else {
                    SettingsNotice(symbol: "lock.fill", text: "Kept in this phone’s keychain only.")
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.85), value: canSave)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
    }

    // MARK: Permissions

    /// One header says where the data goes; each row names what is sent and the feature that sends
    /// it. VoiceOver (and the UI tests) keep the full "Send … to OpenAI" wording.
    private var permissions: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Send to OpenAI")
            LookList(separatorInset: 54) {
                consentRow("Equipment photos", feature: "Scan Machine", symbol: "camera.viewfinder",
                           label: "Send equipment photos to OpenAI", isOn: $photoConsent)
                consentRow("Routine details", feature: "Ask AI for Templates", symbol: "calendar",
                           label: "Send routine details to OpenAI", isOn: $routineConsent)
                consentRow("Model details", feature: "Suggest exercises with AI", symbol: "tag",
                           label: "Send model details to OpenAI", isOn: $exerciseConsent)
                Link(destination: URL(string: "https://developers.openai.com/api/docs/guides/your-data")!) {
                    SettingsRow("OpenAI API data policies", symbol: "doc.text", trailingStaysInline: true) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(.footnote, weight: .bold))
                            .foregroundStyle(look.textTertiary)
                    }
                }
                .buttonStyle(.lookPressable)
            }
        }
    }

    private func consentRow(_ title: String, feature: String, symbol: String, label: String,
                            isOn: Binding<Bool>) -> some View {
        SettingsRow(title, subtitle: feature, symbol: symbol, trailingStaysInline: true) {
            Toggle(isOn: isOn) { Text(label) }
                .toggleStyle(.settings)
                .fixedSize()
        }
    }

    // MARK: Actions

    private func save() {
        guard canSave else { return }
        do {
            try AskAIKeyStore.write(key)
            let stored = AskAIKeyStore.read()
            if reduceMotion { savedKey = stored } else { withAnimation(.snappy) { savedKey = stored } }
            key = ""
            keyFocused = false
            failure = nil
            savedTick += 1
        } catch {
            failure = error.localizedDescription
        }
    }

    private func remove() {
        AskAIKeyStore.delete()
        if reduceMotion { savedKey = nil } else { withAnimation(.snappy) { savedKey = nil } }
        key = ""
        failure = nil
    }
}
