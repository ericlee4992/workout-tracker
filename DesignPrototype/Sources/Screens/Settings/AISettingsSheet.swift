import SwiftUI

// PROTOTYPE — X02 Ask AI settings. Key first (the prerequisite; the real sheet put it last):
// a key card whose status is the bold element — On with the masked key, or Off — kept in this
// phone's keychain. The field is full width; Save key (the one filled command) appears only
// once something is typed, so a disabled button never poses as a second field. Then one
// "Send to OpenAI" header over the three permissions (what is sent · the feature that sends
// it) and the policy link; Remove key is a quiet single-rule row at the very end (a rare,
// destructive command must not outweigh Save key) and now asks first (it deleted immediately).
// The five-line legal paragraph is gone. Toggles apply at once, so the only chrome is Done. The
// sheet opens at the height of its content.

struct AISettingsSheet: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var keyDraft = ""
    @State private var confirmRemove = false
    @State private var savedTick = 0
    @State private var headerHeight: CGFloat = 0
    @State private var bodyHeight: CGFloat = 0
    @FocusState private var keyFocused: Bool

    private var saved: Bool { store.settings.aiKeySaved }
    private var canSave: Bool { !keyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            header
                .settingsMeasureHeight($headerHeight)
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    keyCard
                    permissions
                    if saved {
                        removeRow
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 10)
                .padding(.bottom, 28)
                .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.84), value: saved)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .settingsMeasureContent($bodyHeight)
        }
        .settingsSheetPresentation(look, fitted: headerHeight + bodyHeight)
        .sensoryFeedback(.success, trigger: savedTick)
        .confirmationDialog("Remove the saved key?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove key", role: .destructive) {
                if reduceMotion { store.removeAIKey() } else { withAnimation(.snappy) { store.removeAIKey() } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Ask AI turns off until you add a key.")
        }
        .onAppear(perform: applyVariant)
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
                GlassCapsuleButton("Done") { router.dismissSheet() }
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
                IconDisc(symbol: "sparkles", size: 52, context: saved ? .onSurface : .make)
                    .celebrate(saved)
                VStack(alignment: .leading, spacing: 3) {
                    Text(saved ? "On" : "Off")
                        .font(look.font.bigNumber)
                        .foregroundStyle(saved ? look.textPrimary : look.textSecondary)
                        .contentTransition(.opacity)
                    if saved {
                        Text(store.settings.aiKeyHint)
                            .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                            .foregroundStyle(look.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(saved ? "Ask AI, On, key \(store.settings.aiKeyHint)" : "Ask AI, Off")

            LookDivider()

            VStack(alignment: .leading, spacing: 10) {
                SecureField(saved ? "Replace the saved key" : "OpenAI API key", text: $keyDraft,
                            prompt: Text(saved ? "Replace the saved key" : "OpenAI API key").foregroundStyle(look.textTertiary))
                    .font(keyDraft.isEmpty ? look.font.body : .system(.body, design: .monospaced))
                    .foregroundStyle(look.textPrimary)
                    .tint(look.actionText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($keyFocused)
                    .submitLabel(.done)
                    .onSubmit(saveKey)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 50)
                    .lookSurface(.field)
                if canSave {
                    // The sheet's one primary (C: cobalt with the hard offset).
                    Button(action: saveKey) {
                        Label("Save key", systemImage: "key.fill")
                    }
                    .buttonStyle(.lookPrimary)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
                SettingsNotice(symbol: "lock.fill", text: "Kept in this phone’s keychain only.")
            }
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.85), value: canSave)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
    }

    // MARK: Remove key

    /// A plain row with one rule (C's single pressable outline, no double rule, no filled disc):
    /// the verb and the glyph carry it, the confirmation keeps it safe. A draws it in danger.
    private var removeRow: some View {
        Button { confirmRemove = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "trash").font(.system(.body, weight: .semibold))
                Text("Remove key").font(look.settingsRowTitle)
                Spacer(minLength: 0)
            }
            .foregroundStyle(look.id == .floodlight ? look.destructive : look.textPrimary)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
            .lookSurface(.tile, radius: look.radius.row)
            .contentShape(RoundedRectangle(cornerRadius: look.radius.row, style: .continuous))
        }
        .buttonStyle(.lookPressable)
    }

    // MARK: Permissions

    /// One header says where the data goes; each row names what is sent and the feature that
    /// sends it (the three "Send … to OpenAI" labels repeated the same words).
    private var permissions: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Send to OpenAI")
            LookList(separatorInset: 54) {
                ForEach(AIConsent.allCases) { kind in consentRow(kind) }
                Link(destination: URL(string: "https://developers.openai.com/api/docs/guides/your-data")!) {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(look.settingsGlyphTint)
                            .frame(width: 26)
                        Text("OpenAI API data policies")
                            .font(look.settingsRowTitle)
                            .foregroundStyle(look.id.isPaperClub ? look.actionText : look.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.up.right")
                            .font(.system(.footnote, weight: .bold))
                            .foregroundStyle(look.textTertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(SettingsRowPressStyle())
            }
        }
    }

    private func consentRow(_ kind: AIConsent) -> some View {
        SettingsRow(kind.settingsShortLabel, subtitle: kind.settingsFeature, symbol: kind.settingsSymbol, showsChevron: false,
                    trailingStaysInline: true) {
            Toggle(isOn: Binding(get: { store.settings.consent(kind) }, set: { store.setConsent(kind, $0) })) { EmptyView() }
                .toggleStyle(.settings)
                .fixedSize()
                .accessibilityLabel(kind.label)
        }
    }

    // MARK: Actions

    private func saveKey() {
        guard canSave else { return }
        if reduceMotion { store.saveAIKey(keyDraft) } else { withAnimation(.snappy) { store.saveAIKey(keyDraft) } }
        keyDraft = ""
        keyFocused = false
        savedTick += 1
    }

    private func applyVariant() {
        guard let variant = SettingsVariant.consume(.x02, store: store, router: router) else { return }
        if SettingsVariant.has(variant, "noKey") { store.removeAIKey() }
        if SettingsVariant.has(variant, "typing") { keyDraft = "sk-proj-7Hq2c9Tz" }
        if SettingsVariant.has(variant, "remove") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { confirmRemove = true }
        }
    }
}
