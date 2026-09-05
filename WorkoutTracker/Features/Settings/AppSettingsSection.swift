import SwiftData
import SwiftUI

/// The app-wide preference block (unit default, global rest durations, drift
/// prompt suppression) rendered as one `Section` — it lives on the Gyms
/// screen, but nothing in it is about a gym. Every control writes through the
/// canonical `AppPreferences` row (duplicates resolved by `CanonicalRow`).
struct AppSettingsSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allPreferences: [AppPreferences]
    @State private var showMaxHeartRateSheet = false

    var body: some View {
        Section {
            Picker("App unit preference", selection: appUnitBinding) {
                ForEach(WeightUnit.allCases) { unit in
                    Text(unit.rawValue).tag(unit)
                }
            }
            .pickerStyle(.menu)
            Stepper(
                "Working rest · \(Format.duration(seconds: globalWorkingRest))",
                value: globalWorkingRestBinding,
                in: 0...600,
                step: 15)
            Stepper(
                "Warmup rest · \(Format.duration(seconds: globalWarmupRest))",
                value: globalWarmupRestBinding,
                in: 0...600,
                step: 15)
            Toggle(
                "Suppress template update prompts",
                isOn: driftPromptSuppressedBinding)
            // The ONLY way into this sheet used to be the "zone estimated"
            // button on the workout screen's heart-rate bar, which appears only
            // once a zone already exists — and a zone needs the maximum this
            // sheet sets (D45). With neither a measured max nor a date of
            // birth, zones were unreachable forever. It also belongs here on
            // its own merits: a date of birth is not a thing to enter mid-set.
            Button {
                showMaxHeartRateSheet = true
            } label: {
                LabeledContent("Heart rate zones") {
                    Text(maxHeartRateSummary)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("heartRateZonesSettings")
            .tint(.primary)
            // Hung off the ROW, not off the Section: a `.sheet` attached to a
            // `Section` inside a `List` silently never presents (milestone 3,
            // ticket 02 — cost an export that did nothing).
            .sheet(isPresented: $showMaxHeartRateSheet) {
                MaxHeartRateSheet()
            }
            // Milestone 9, ticket 04: the one-time dumbbell history move is a
            // rewrite of snapshots (D23), so it is announced rather than silent.
            // The CANONICAL row — the seeder writes there, and duplicates are
            // possible under CloudKit (codex-review 04, high).
            if let preferences = AppPreferences.canonical(of: allPreferences),
               let moved = preferences.dumbbellHistoryMovedSets, moved > 0,
               let when = preferences.dumbbellHistoryMovedAt {
                LabeledContent("History update") {
                    Text("\(moved) set\(moved == 1 ? "" : "s") moved to dumbbell exercises · \(when.formatted(date: .abbreviated, time: .omitted))")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                .accessibilityIdentifier("dumbbellMoveNote")
            }
        } header: {
            Text("Settings")
        }
    }

    /// What the zones would currently be computed against, so the row says
    /// whether the feature is on before the user taps into it.
    private var maxHeartRateSummary: String {
        let preferences = AppPreferences.canonical(of: allPreferences)
        guard let resolved = MaxHeartRateResolver.resolve(
            measured: preferences?.measuredMaxHeartRate,
            birthDate: preferences?.birthDate,
            at: .now)
        else { return "Not set" }
        // The basis (measured or 220−age) is still resolved and still
        // decides the zones; the row no longer names it (D52).
        return "\(resolved.bpm) bpm"
    }

    /// Binding onto the canonical persisted preference row. The row exists
    /// after first-launch bootstrap; reads fall back to the locale default.
    private var appUnitBinding: Binding<WeightUnit> {
        Binding(
            get: {
                AppPreferences.canonical(of: allPreferences)?.unitPreference
                    ?? UnitPrecedence.firstLaunchDefault(
                        for: Locale.current.measurementSystem)
            },
            set: { newValue in
                do {
                    let preferences = try AppPreferences.canonical(in: modelContext)
                    preferences.unitPreference = newValue
                    preferences.updatedAt = .now
                    try modelContext.save()
                } catch {
                    assertionFailure("Failed to save unit preference: \(error)")
                }
            }
        )
    }

    private var globalWorkingRest: Int {
        AppPreferences.canonical(of: allPreferences)?.globalWorkingRestSeconds ?? 120
    }

    private var globalWarmupRest: Int {
        AppPreferences.canonical(of: allPreferences)?.globalWarmupRestSeconds ?? 60
    }

    private var globalWorkingRestBinding: Binding<Int> {
        durationBinding(\.globalWorkingRestSeconds, fallback: 120)
    }

    private var globalWarmupRestBinding: Binding<Int> {
        durationBinding(\.globalWarmupRestSeconds, fallback: 60)
    }

    private var driftPromptSuppressedBinding: Binding<Bool> {
        Binding(
            get: {
                AppPreferences.canonical(of: allPreferences)?.driftPromptSuppressed
                    ?? false
            },
            set: { value in
                do {
                    let preferences = try AppPreferences.canonical(in: modelContext)
                    preferences.driftPromptSuppressed = value
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
            get: { AppPreferences.canonical(of: allPreferences)?[keyPath: keyPath] ?? fallback },
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
}
