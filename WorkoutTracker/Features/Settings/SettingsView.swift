import SwiftData
import SwiftUI

/// X01 Settings, pushed from the gear on the Workout tab (Floodlight ticket 09). Grouped and
/// graphic where the old screen was one headerless list: **Units** is the bold element — two
/// tiles showing the units you will see, with the one line saying logged sets keep theirs —
/// then Appearance, Workout (rest defaults, the template prompt), cards that open the heart-rate
/// zones sheet, Ask AI and Export, and the one-time D51 history note at the end.
/// Every control writes through the canonical `AppPreferences` row (duplicates resolved by
/// `CanonicalRow`), exactly as the old `AppSettingsSection` did.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var allPreferences: [AppPreferences]
    /// Public beta ticket 02: Show Tour starts the guided tour (absent in previews and the tour's own world).
    @Environment(OnboardingCoordinator.self) private var onboarding: OnboardingCoordinator?
    /// Settings → Appearance: per device, not synced (see `AppearanceSetting`).
    @AppStorage(AppearanceSetting.key) private var appearanceRaw = Appearance.system.rawValue
    @AppStorage(ExportRecord.dateKey) private var lastExportSeconds: Double?
    @AppStorage(ExportRecord.formatKey) private var lastExportFormat: String?

    @State private var showMaxHeartRateSheet = false
    @State private var showAskAISheet = false
    @State private var showExport = false
    @State private var showFeedback = false
    /// Re-read when the Ask AI sheet closes; the keychain is not observable.
    @State private var askAIOn = AskAIKeyStore.read() != nil
    @State private var counts: ExportCounts?
    @State private var countFailure: String?
    @State private var titleVisible = false

    private var preferences: AppPreferences? { AppPreferences.canonical(of: allPreferences) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: look.space.section) {
                LookNavTitle("Settings")
                units
                appearance
                workout
                VStack(spacing: look.space.group) {
                    heartRate
                    askAI
                }
                export
                historyUpdate
                help
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 2)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: Bool.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top > (typeSize.isAccessibilitySize ? 90 : 52)
        } action: { _, past in
            withAnimation(.easeInOut(duration: 0.18)) { titleVisible = past }
        }
        .lookScreenBackground()
        .exercisesInlineTitle("Settings", visible: titleVisible)
        .sensoryFeedback(.selection, trigger: unitSystem)
        .sensoryFeedback(.selection, trigger: appearanceRaw)
        // Counted afresh on every visit (and after an export, on the way back), which is every
        // moment the number is looked at; logging happens in a full-screen cover.
        .task(id: showExport) { if !showExport { refreshCounts() } }
        .sheet(isPresented: $showMaxHeartRateSheet) { MaxHeartRateSheet() }
        .sheet(isPresented: $showAskAISheet, onDismiss: { askAIOn = AskAIKeyStore.read() != nil }) {
            AskAISettingsSheet()
        }
        .navigationDestination(isPresented: $showExport) { ExportView() }
        .sheet(isPresented: $showFeedback) {
            FeedbackSheet(details: FeedbackSample.details, initial: FeedbackSample.draft, send: FeedbackSample.stubSend)
        }
    }

    // MARK: Units (the bold element)

    private var unitSystem: AppUnitSystem {
        AppUnitSystem.resolve(preference: preferences?.unitPreference)
    }

    private var units: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
        return VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Units")
            layout {
                unitTile(.metric)
                unitTile(.usCustomary)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("appUnitPreference")
            SettingsNotice(symbol: "scalemass", text: "Logged sets keep the unit they were entered in.")
                .padding(.top, 2)
        }
    }

    private func unitTile(_ system: AppUnitSystem) -> some View {
        let selected = unitSystem == system
        return Button {
            if reduceMotion { setUnitSystem(system) } else {
                withAnimation(.snappy(duration: 0.25)) { setUnitSystem(system) }
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(system.title)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(look.textSecondary)
                    Spacer(minLength: 6)
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(look.textPrimary)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(system.weightUnit.rawValue)
                        .font(look.font.heroNumber)
                        .foregroundStyle(look.textPrimary)
                    Text(system.distanceUnit.rawValue)
                        .font(look.font.smallNumber)
                        .foregroundStyle(look.textSecondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .settingsChoiceSurface(isSelected: selected)
            .contentShape(RoundedRectangle(cornerRadius: look.radius.tile, style: .continuous))
        }
        .buttonStyle(.lookPressable)
        .accessibilityLabel("\(system.title), \(system.weightUnit.rawValue) and \(system.distanceUnit.rawValue)")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("appUnitPreference.\(system.rawValue)")
    }

    private func setUnitSystem(_ system: AppUnitSystem) {
        do {
            let preferences = try AppPreferences.canonical(in: modelContext)
            preferences.unitPreference = system.weightUnit
            preferences.updatedAt = .now
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save unit preference: \(error)")
        }
    }

    // MARK: Appearance

    private var appearance: some View {
        let options = Appearance.allCases
        return VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Appearance")
            SegmentedPills(options.map(\.label), selection: Binding(
                get: { options.firstIndex(of: AppearanceSetting.resolve(appearanceRaw)) ?? 0 },
                set: { appearanceRaw = options[$0].rawValue }))
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Appearance")
                .accessibilityIdentifier("appearanceSetting")
        }
    }

    // MARK: Workout (rest defaults and the template prompt)

    /// Public beta ticket 02: the guided tour again, any time (not while a workout runs — it explains why).
    /// Ticket 07: Send Feedback (works signed out).
    @ViewBuilder private var help: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Help")
            LookList(separatorInset: 54) {
                if let onboarding {
                    LookRow("Show Tour", symbol: "map", action: {
                        onboarding.startTour(realContext: modelContext)
                    })
                    .accessibilityIdentifier("showTour")
                }
                LookRow("Send Feedback", symbol: "bubble.left.and.text.bubble.right", action: { showFeedback = true })
                    .accessibilityIdentifier("sendFeedback")
            }
        }
        .alert(onboarding?.tourFailure ?? "", isPresented: Binding(
            get: { onboarding?.tourFailure != nil }, set: { if !$0 { onboarding?.tourFailure = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    private var workout: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Workout")
            LookList(separatorInset: 54) {
                SettingsRow("Working rest", symbol: "hourglass") {
                    NumberStepperPill(value: durationBinding(\.globalWorkingRestSeconds, fallback: 120),
                                      range: 0...600, step: 15) { Format.duration(seconds: $0) }
                        .accessibilityLabel("Working rest")
                        .accessibilityIdentifier("globalWorkingRest")
                }
                SettingsRow("Warmup rest", symbol: "hourglass.bottomhalf.filled") {
                    NumberStepperPill(value: durationBinding(\.globalWarmupRestSeconds, fallback: 60),
                                      range: 0...600, step: 15) { Format.duration(seconds: $0) }
                        .accessibilityLabel("Warmup rest")
                        .accessibilityIdentifier("globalWarmupRest")
                }
                // "Suppress template update prompts", said the positive way round: ON asks.
                SettingsRow("Ask to update templates", symbol: "square.on.square", trailingStaysInline: true) {
                    Toggle(isOn: askToUpdateTemplatesBinding) { Text("Ask to update templates") }
                        .toggleStyle(.settings)
                        .fixedSize()
                        .accessibilityIdentifier("askToUpdateTemplates")
                }
            }
        }
    }

    private var askToUpdateTemplatesBinding: Binding<Bool> {
        Binding(
            get: { !(preferences?.driftPromptSuppressed ?? false) },
            set: { ask in
                do {
                    let preferences = try AppPreferences.canonical(in: modelContext)
                    preferences.driftPromptSuppressed = !ask
                    preferences.updatedAt = .now
                    try modelContext.save()
                } catch {
                    assertionFailure("Failed to save template prompt preference: \(error)")
                }
            })
    }

    private func durationBinding(
        _ keyPath: ReferenceWritableKeyPath<AppPreferences, Int>,
        fallback: Int
    ) -> Binding<Int> {
        Binding(
            get: { preferences?[keyPath: keyPath] ?? fallback },
            set: { value in
                do {
                    let preferences = try AppPreferences.canonical(in: modelContext)
                    preferences[keyPath: keyPath] = value
                    preferences.updatedAt = .now
                    try modelContext.save()
                } catch {
                    assertionFailure("Failed to save rest default: \(error)")
                }
            })
    }

    // MARK: Heart rate

    /// The maximum the zones are computed against right now (measured, else 220−age); the basis
    /// still decides the zones but is not named on screen (D52).
    private var maxHeartRate: Int? {
        MaxHeartRateResolver.resolve(
            measured: preferences?.measuredMaxHeartRate, birthDate: preferences?.birthDate, at: .now)?.bpm
    }

    /// The ONLY way into this sheet used to be the "zone estimated" button on the live heart-rate
    /// bar, which needs a zone, which needs the maximum this sheet sets (D45) — so it lives here too.
    private var heartRate: some View {
        let max = maxHeartRate
        return SettingsCardButton { showMaxHeartRateSheet = true } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "heart.fill")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(look.heartRate)
                        .frame(width: 26)
                    Text("Heart rate zones")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    if let max {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(max)").font(look.font.statNumber).foregroundStyle(look.textPrimary)
                            Text("bpm").font(.system(.footnote, weight: .semibold)).foregroundStyle(look.textSecondary)
                        }
                        .fixedSize()
                    } else {
                        Text("Not set").font(look.font.subhead).foregroundStyle(look.textSecondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(look.textTertiary)
                }
                if let max {
                    SettingsZoneLadder(maxBpm: max)
                        .padding(.leading, 38)
                } else {
                    SettingsNotice(symbol: "plus.circle", text: "Set up zones").padding(.leading, 34)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
        }
        .accessibilityElement(children: .ignore)
        // The card ignores its children, so it says the zones too (codex-review-09 #4).
        .accessibilityLabel(max.map { "Heart rate zones, \($0) bpm. \(SettingsZoneLadder.summary(maxBpm: $0))" }
            ?? "Heart rate zones, Not set")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("heartRateZonesSettings")
    }

    // MARK: Ask AI

    /// "Ask AI" (was "Ask AI about plates": the sheet covers scanning, routines and model
    /// suggestions). One status; the key and the three permissions live in the sheet.
    private var askAI: some View {
        SettingsCardButton { showAskAISheet = true } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(look.textSecondary)
                    .frame(width: 26)
                Text("Ask AI")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(look.textPrimary)
                Spacer(minLength: 8)
                Text(askAIOn ? "On" : "Off")
                    .font(look.font.subhead)
                    .foregroundStyle(look.textSecondary)
                    .contentTransition(.opacity)
                Image(systemName: "chevron.right")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(look.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(minHeight: 58)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(askAIOn ? "Ask AI, On" : "Ask AI, Off")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("askAISettings")
    }

    // MARK: Export

    private var lastExport: ExportRecord? {
        lastExportSeconds.map {
            ExportRecord(date: Date(timeIntervalSinceReferenceDate: $0), format: lastExportFormat.flatMap(ExportFormat.init(rawValue:)))
        }
    }

    private var export: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Export")
            SettingsCardButton { showExport = true } label: {
                SettingsRow(counts?.summary ?? " ",
                            subtitle: countFailure ?? lastExport.map { BackupStatus.lastExportLine($0, now: .now) },
                            symbol: "square.and.arrow.up", showsChevron: true)
            }
            // One element whose label starts with the count ("0 workouts · 0 sets"), so it
            // says the export is not empty before the tap.
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("exportSettings")
            if BackupStatus.showsOnlyCopyNotice(lastExport: lastExport?.date, now: .now) {
                // The one line this screen must keep saying (codex-review 06).
                SettingsNotice(symbol: "iphone", text: "This phone holds the only copy until you export.")
                    .padding(.top, 2)
            }
        }
    }

    private func refreshCounts() {
        do {
            counts = try ExportCounts.fetch(from: modelContext)
            countFailure = nil
        } catch {
            countFailure = "Could not count what there is to export: \(error.localizedDescription)"
        }
    }

    // MARK: History update (D51)

    /// The one-time dumbbell history move is a rewrite of snapshots (D23), so it is announced,
    /// on its own at the end (it is not part of Export). The CANONICAL row — the seeder writes
    /// there, and duplicates are possible under CloudKit (codex-review 04, high).
    @ViewBuilder private var historyUpdate: some View {
        if let preferences, let moved = preferences.dumbbellHistoryMovedSets, moved > 0,
           let when = preferences.dumbbellHistoryMovedAt {
            LookList(separatorInset: 54) {
                SettingsRow("History update",
                            subtitle: "\(moved) set\(moved == 1 ? "" : "s") moved to dumbbell exercises",
                            symbol: "arrow.triangle.2.circlepath") {
                    Text(when.formatted(.dateTime.month(.abbreviated).day()))
                        .font(look.font.subhead)
                        .foregroundStyle(look.textSecondary)
                        .accessibilityLabel(when.formatted(date: .abbreviated, time: .omitted))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("dumbbellMoveNote")
        }
    }
}
