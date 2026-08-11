import SwiftData
import SwiftUI

/// What a caller wants a `NewExerciseSheet` opened with — a prefilled name
/// (the search text that matched nothing) and, optionally, the equipment model
/// the new exercise should be linked to. `Identifiable` so pickers can present
/// the sheet with `.sheet(item:)` and re-present it with a different name.
struct NewExerciseRequest: Identifiable {
    let id = UUID()
    /// Prefilled into the name field — the user typed it once already.
    var name: String = ""
    /// The station the exercise is being invented on (ticket 19): linking it
    /// makes the movement selectable on that machine next time. nil = plain
    /// creation (model-less machine, or the plain exercise picker).
    var linkTo: EquipmentModel?
}

/// User-created exercise creation (ticket 06), shared by the Exercises tab and
/// the mid-workout pickers (ticket 19): name, load type (all four), equipment
/// tags. Lands in the user ID space (`isSeeded == false`).
///
/// `onCreate` lets a mid-workout caller act on the row the moment it exists —
/// selecting it for the entry being added — so "this movement isn't listed"
/// leads straight to logging a set instead of a trip to the Exercises tab.
struct NewExerciseSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var initialName: String = ""
    /// Model to link the created exercise to (appended to its `exerciseIDs`).
    var linkTo: EquipmentModel?
    var onCreate: ((Exercise) -> Void)?
    @State private var name = ""
    @State private var loadType: LoadType = .weighted
    @State private var tags: Set<EquipmentTag> = []
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .accessibilityIdentifier("newExerciseName")
                } footer: {
                    if let linkTo {
                        Text("Will be linked to \(linkTo.displayName), so this station offers it next time.")
                    }
                }
                Section {
                    Picker("Load type", selection: $loadType) {
                        ForEach(LoadType.allCases, id: \.self) { type in
                            Text(type.badge).tag(type)
                        }
                    }
                    .accessibilityIdentifier("newExerciseLoadType")
                } footer: {
                    Text("Assisted machines count lower weight as harder — pick carefully, records depend on it.")
                }
                Section {
                    ForEach(EquipmentTag.allCases) { tag in
                        Button {
                            toggle(tag)
                        } label: {
                            HStack {
                                Text(tag.label)
                                Spacer()
                                if tags.contains(tag) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Equipment")
                }
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addExercise() }
                        .disabled(trimmedName.isEmpty)
                        .accessibilityIdentifier("saveNewExercise")
                }
            }
            .onAppear(perform: load)
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        name = initialName
    }

    private func toggle(_ tag: EquipmentTag) {
        if tags.contains(tag) {
            tags.remove(tag)
        } else {
            tags.insert(tag)
        }
    }

    private func addExercise() {
        let orderedTags = EquipmentTag.allCases.filter(tags.contains)
        do {
            let exercise = try EquipmentLifecycle(context: modelContext).createExercise(
                name: trimmedName,
                loadType: loadType,
                equipmentTypeTags: orderedTags,
                linkedTo: linkTo)
            onCreate?(exercise)
        } catch {
            assertionFailure("Failed to save new exercise: \(error)")
        }
        dismiss()
    }
}
