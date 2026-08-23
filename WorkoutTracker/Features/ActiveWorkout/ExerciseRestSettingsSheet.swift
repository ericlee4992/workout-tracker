import SwiftData
import SwiftUI

/// Per-exercise override editor (D22). nil means follow the editable global
/// default; values are stored independently for warmup and working/failure.
struct ExerciseRestSettingsSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var exercise: Exercise
    @Query private var allOverrides: [ExerciseRestOverride]
    @State private var warmupUsesGlobal = true
    @State private var workingUsesGlobal = true
    @State private var warmupSeconds = 60
    @State private var workingSeconds = 120
    @State private var restMode: RestMode = .standard
    @State private var thresholdBpm = HeartRateRestRule.defaultThresholdBpm
    @State private var capSeconds = Int(HeartRateRestRule.defaultCap)

    var body: some View {
        NavigationStack {
            Form {
                durationSection(
                    title: "Warmup sets",
                    usesGlobal: $warmupUsesGlobal,
                    seconds: $warmupSeconds)
                durationSection(
                    title: "Working & failure sets",
                    usesGlobal: $workingUsesGlobal,
                    seconds: $workingSeconds)
                heartRateSection
            }
            .navigationTitle("Rest")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: load)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
        }
    }

    /// D43: rest by the clock, or rest until the heart rate comes down.
    @ViewBuilder
    private var heartRateSection: some View {
        Section {
            Picker("Rest by", selection: $restMode) {
                ForEach(RestMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("restModePicker")

            if restMode == .heartRate {
                Stepper(
                    "End rest below \(thresholdBpm) bpm",
                    value: $thresholdBpm, in: 40...200, step: 5)
                    .accessibilityIdentifier("restThreshold")
                Stepper(
                    "…or after \(Format.duration(seconds: capSeconds)) at the latest",
                    value: $capSeconds, in: 30...900, step: 30)
                    .accessibilityIdentifier("restCap")
            }
        } header: {
            Text("How this exercise rests")
        } footer: {
            if restMode == .heartRate {
                // The cap is the part users delete if nobody explains it.
                Text("The cap is a safety net: if a reading never comes down — a hard set, a dropped connection, an earbud out — the alarm still fires and says the time ran out rather than claiming you recovered. With no live heart rate at all, this falls back to the timer above.")
            } else {
                Text("Working and failure sets use the durations above. Drop sets never start a rest (D26).")
            }
        }
    }

    private func durationSection(
        title: String,
        usesGlobal: Binding<Bool>,
        seconds: Binding<Int>
    ) -> some View {
        Section(title) {
            Toggle("Use global default", isOn: usesGlobal)
            if !usesGlobal.wrappedValue {
                Stepper(
                    Format.duration(seconds: seconds.wrappedValue),
                    value: seconds,
                    in: 0...600,
                    step: 15)
            }
        }
    }

    private func load() {
        let row = allOverrides.filter { $0.exerciseID == exercise.id }.canonical
        if let value = row?.warmupRestSeconds {
            warmupUsesGlobal = false
            warmupSeconds = value
        }
        if let value = row?.workingRestSeconds {
            workingUsesGlobal = false
            workingSeconds = value
        }
        restMode = row?.restMode ?? .standard
        thresholdBpm = row?.heartRateThresholdBpm ?? HeartRateRestRule.defaultThresholdBpm
        capSeconds = row?.heartRateCapSeconds ?? Int(HeartRateRestRule.defaultCap)
    }

    private func save() {
        do {
            try RestTimerService(context: modelContext).setOverride(
                for: exercise,
                warmupSeconds: warmupUsesGlobal ? nil : warmupSeconds,
                workingSeconds: workingUsesGlobal ? nil : workingSeconds,
                restMode: restMode,
                heartRateThresholdBpm: restMode == .heartRate ? thresholdBpm : nil,
                heartRateCapSeconds: restMode == .heartRate ? capSeconds : nil)
            dismiss()
        } catch {
            assertionFailure("Failed to save rest override: \(error)")
        }
    }
}
