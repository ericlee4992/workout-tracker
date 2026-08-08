import SwiftData
import SwiftUI

// Exercises tab — the full persisted catalog: seeded rows (ticket 04) plus
// user-created exercises (ticket 06) side by side. Seeded rows are read-only
// (D24); only user-created exercises can be renamed.
struct ExercisesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var searchText = ""
    @State private var showingAddExercise = false
    @State private var renamingExercise: Exercise?
    @State private var renameText = ""

    private var filtered: [Exercise] {
        guard !searchText.isEmpty else { return exercises }
        return exercises.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(filtered) { exercise in
                        HStack {
                            ExerciseRow(exercise: exercise)
                            if !exercise.isSeeded {
                                Text("Custom")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .contextMenu {
                            // Seeded rows are read-only (D24) — no actions.
                            if !exercise.isSeeded {
                                Button("Rename…") {
                                    renameText = exercise.name
                                    renamingExercise = exercise
                                }
                            }
                        }
                    }
                    Button("Add Exercise…", systemImage: "plus") {
                        showingAddExercise = true
                    }
                } footer: {
                    Text("Picking a machine during a workout selects its exercise automatically — this list is for browsing and free-weight logging.")
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Exercises")
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseSheet()
            }
            .alert(
                "Rename Exercise",
                isPresented: Binding(
                    get: { renamingExercise != nil },
                    set: { if !$0 { renamingExercise = nil } }
                ),
                presenting: renamingExercise
            ) { exercise in
                TextField("Name", text: $renameText)
                Button("Save") { rename(exercise) }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("Only your own exercises can be renamed — the built-in catalog is read-only.")
            }
        }
    }

    private func rename(_ exercise: Exercise) {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !exercise.isSeeded else { return }
        do {
            try EquipmentLifecycle(context: modelContext).rename(exercise, to: trimmed)
        } catch {
            assertionFailure("Failed to rename exercise: \(error)")
        }
    }
}

/// User-created exercise creation (ticket 06): name, load type (all four),
/// equipment tags. Lands in the user ID space (`isSeeded == false`).
private struct AddExerciseSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var loadType: LoadType = .weighted
    @State private var tags: Set<EquipmentTag> = []

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                }
                Section {
                    Picker("Load type", selection: $loadType) {
                        ForEach(LoadType.allCases, id: \.self) { type in
                            Text(type.badge).tag(type)
                        }
                    }
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
                }
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
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
        modelContext.insert(Exercise(
            name: trimmedName,
            loadType: loadType,
            equipmentTypeTags: orderedTags,
            isSeeded: false))
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save new exercise: \(error)")
        }
        dismiss()
    }
}

#Preview {
    let schema = WorkoutTrackerStore.schema
    let container = try! ModelContainer(
        for: schema,
        configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
    if let catalog = try? SeedCatalog.bundled() {
        try? CatalogSeeder.reconcile(catalog, in: container.mainContext)
    }
    container.mainContext.insert(Exercise(
        name: "Landmine Press", loadType: .weighted,
        equipmentTypeTags: [.barbell], isSeeded: false))
    return ExercisesView()
        .modelContainer(container)
}
