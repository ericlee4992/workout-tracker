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
            }
            .navigationTitle("Rest Durations")
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
    }

    private func save() {
        do {
            try RestTimerService(context: modelContext).setOverride(
                for: exercise,
                warmupSeconds: warmupUsesGlobal ? nil : warmupSeconds,
                workingSeconds: workingUsesGlobal ? nil : workingSeconds)
            dismiss()
        } catch {
            assertionFailure("Failed to save rest override: \(error)")
        }
    }
}
