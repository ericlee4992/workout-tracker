import SwiftData
import SwiftUI

/// The app-wide preference block (unit default, global rest durations, drift
/// prompt suppression) rendered as one `Section` — it lives on the Gyms
/// screen, but nothing in it is about a gym. Every control writes through the
/// canonical `AppPreferences` row (duplicates resolved by `CanonicalRow`).
struct AppSettingsSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allPreferences: [AppPreferences]

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
        } header: {
            Text("Settings")
        } footer: {
            Text("The unit is used when neither machine nor gym sets one. Rest durations are global defaults; each exercise can override them from its workout menu. Suppressed template prompts always keep the original template.")
        }
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
