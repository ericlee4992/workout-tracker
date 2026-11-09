import SwiftData
import SwiftUI

/// X01 Settings (Floodlight ticket 09), since Soft redesign S6 the page Profile → Preferences
/// (`ProfileTabView`): **Units** is the bold element — two tiles showing the units you will see, with the one line
/// saying logged sets keep theirs — then Appearance, Workout (rest defaults, the template prompt) and the one-time D51
/// history note at the end. Heart rate zones, Ask AI, Export & backup, the account and Help moved to Profile's root (D80).
/// Every control writes through the canonical `AppPreferences` row (duplicates resolved by
/// `CanonicalRow`), exactly as the old `AppSettingsSection` did.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var allPreferences: [AppPreferences]
    /// Settings → Appearance: per device, not synced (see `AppearanceSetting`).
    @AppStorage(AppearanceSetting.key) private var appearanceRaw = Appearance.system.rawValue

    @State private var titleVisible = false
    /// S6: the page's title is the Profile row that opens it.
    static let pageTitle = "Preferences"
    var title = SettingsView.pageTitle

    private var preferences: AppPreferences? { AppPreferences.canonical(of: allPreferences) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: look.space.section) {
                LookNavTitle(title)
                units
                appearance
                workout
                historyUpdate
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
        .exercisesInlineTitle(title, visible: titleVisible)
        .sensoryFeedback(.selection, trigger: unitSystem)
        .sensoryFeedback(.selection, trigger: appearanceRaw)
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
