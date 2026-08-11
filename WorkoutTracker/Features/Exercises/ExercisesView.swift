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
                // Same form the mid-workout pickers open (ticket 19).
                NewExerciseSheet()
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
