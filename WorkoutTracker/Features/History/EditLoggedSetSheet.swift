import SwiftData
import SwiftUI

// Milestone 8, ticket 03 — correcting one logged record.
//
// Only the numbers are editable. There is deliberately no path here to the
// entry's snapshot fields (exercise name, machine, gym, load type): D23 froze
// those so the past cannot be restated by today's catalog, and an edit screen
// that quietly re-resolved them would be that drift with a friendlier face.

struct EditLoggedSetSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Named `record`, not `set`: inside a computed property body the parser
    /// reads a bare `set` as the start of a setter definition.
    let record: SetRecord
    @State private var repsText = ""
    @State private var weightText = ""
    @State private var unit: WeightUnit = .kg
    @State private var setType: SetType = .working
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Weight") {
                        TextField(loadType == .assisted ? "Assistance" : "Weight", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("editSetWeight")
                    }
                    Picker("Unit", selection: $unit) {
                        ForEach(WeightUnit.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    LabeledContent("Reps") {
                        TextField("Reps", text: $repsText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("editSetReps")
                    }
                    Picker("Set type", selection: $setType) {
                        ForEach(SetType.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                } header: {
                    Text(record.isDeleted ? "" : (record.entry?.snapshotExerciseName ?? "Set"))
                } footer: {
                    Text(footerText)
                }
            }
            .navigationTitle("Edit Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                        .accessibilityIdentifier("saveEditedSet")
                }
            }
            .onAppear(perform: load)
        }
    }

    private var loadType: LoadType {
        record.isDeleted ? .weighted : WorkoutSession.loadType(of: record)
    }

    private var footerText: String {
        "The exercise and equipment this set was logged against stay as they were — editing a set never restates what machine you used. The workout will be marked as edited."
    }

    private var parsedReps: Int? { Int(repsText.trimmingCharacters(in: .whitespaces)) }

    private var parsedWeight: Double? {
        let text = weightText.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : Double(text.replacingOccurrences(of: ",", with: "."))
    }

    /// Mirrors the store's own rule, so Save can never enable on input the
    /// store will then refuse (the same guard the active workout uses).
    private var isValid: Bool {
        WorkoutSession.isLoggable(
            reps: parsedReps, weightValue: parsedWeight, loadType: loadType)
    }

    private func load() {
        guard !loaded, !record.isDeleted else { return }
        repsText = record.reps.map(String.init) ?? ""
        weightText = record.weightValue.map { Format.weight($0) } ?? ""
        unit = record.weightUnit
        setType = record.type
        loaded = true
    }

    private func save() {
        let edit = HistoryEditing.SetEdit(
            reps: parsedReps, weightValue: parsedWeight,
            weightUnit: unit, setType: setType)
        guard HistoryEditing.apply(edit, to: record) else { return }
        do { try modelContext.save() }
        catch { assertionFailure("Failed to save edited set: \(error)") }
        dismiss()
    }
}
