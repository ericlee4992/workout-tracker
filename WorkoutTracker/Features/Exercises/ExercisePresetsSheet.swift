import SwiftData
import SwiftUI

/// Presets for one exercise: the grips, stances and single/double variations
/// the user actually switches between (D36–D38).
///
/// Attached to the exercise, seeded or not (D37). A preset on a seeded exercise
/// is user data hanging off a catalog row — the same shape D27 already blessed
/// for user-created exercises linked to seeded models — so catalog
/// reconciliation leaves it alone.
struct ExercisePresetsSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var exercise: Exercise

    @State private var newName = ""
    @State private var editing: ExercisePreset?
    @State private var editText = ""

    private var presets: [ExercisePreset] {
        (exercise.presets ?? []).sorted {
            ($0.order, $0.name) < ($1.order, $1.name)
        }
    }

    private var existingNames: [String] { presets.map(\.name) }

    private var unusedSuggestions: [String] {
        ExercisePresets.suggestions.filter {
            !ExercisePresets.isDuplicate($0, among: existingNames)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if presets.isEmpty {
                        Text("No presets yet. Without any, this exercise is logged as one thing.")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("noPresets")
                    }
                    ForEach(presets) { preset in
                        Text(preset.name)
                            .accessibilityIdentifier("preset.\(preset.name)")
                            .contextMenu {
                                Button("Rename…") {
                                    editText = preset.name
                                    editing = preset
                                }
                                Button("Delete", role: .destructive) { delete(preset) }
                            }
                    }
                    .onMove(perform: move)
                    .onDelete(perform: deleteAt)
                } header: {
                    Text("Presets")
                }

                Section {
                    HStack {
                        TextField("New preset (e.g. Wide grip)", text: $newName)
                            .accessibilityIdentifier("newPresetName")
                            .onSubmit(add)
                        Button("Add", action: add)
                            .disabled(!ExercisePresets.isValid(newName, existing: existingNames))
                            .accessibilityIdentifier("addPreset")
                    }
                    if ExercisePresets.isDuplicate(newName, among: existingNames) {
                        Text("\(ExercisePresets.cleanedName(newName)) is already a preset here.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Add")
                }

                if !unusedSuggestions.isEmpty {
                    Section {
                        ForEach(unusedSuggestions, id: \.self) { suggestion in
                            Button(suggestion) { add(named: suggestion) }
                                .accessibilityIdentifier("presetSuggestion.\(suggestion)")
                        }
                    } header: {
                        Text("Common")
                    }
                }
            }
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
            .alert(
                "Rename Preset",
                isPresented: Binding(
                    get: { editing != nil },
                    set: { if !$0 { editing = nil } }),
                presenting: editing
            ) { preset in
                TextField("Name", text: $editText)
                Button("Save") { rename(preset) }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - Editing

    private func add() { add(named: newName) }

    private func add(named name: String) {
        let cleaned = ExercisePresets.cleanedName(name)
        guard ExercisePresets.isValid(cleaned, existing: existingNames) else { return }
        let preset = ExercisePreset(
            name: cleaned,
            order: ExercisePresets.nextOrder(after: presets.map(\.order)),
            exercise: exercise)
        modelContext.insert(preset)
        save()
        newName = ""
    }

    private func rename(_ preset: ExercisePreset) {
        let cleaned = ExercisePresets.cleanedName(editText)
        let others = presets.filter { $0.id != preset.id }.map(\.name)
        guard ExercisePresets.isValid(cleaned, existing: others) else { return }
        preset.name = cleaned
        save()
    }

    private func delete(_ preset: ExercisePreset) {
        modelContext.delete(preset)
        renumber()
    }

    private func deleteAt(_ offsets: IndexSet) {
        for index in offsets { modelContext.delete(presets[index]) }
        renumber()
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = presets
        ordered.move(fromOffsets: source, toOffset: destination)
        for (preset, order) in zip(ordered, ExercisePresets.renumbered(ordered.count)) {
            preset.order = order
        }
        save()
    }

    private func renumber() {
        for (preset, order) in zip(presets, ExercisePresets.renumbered(presets.count)) {
            preset.order = order
        }
        save()
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save presets: \(error)")
        }
    }
}
