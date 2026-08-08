import SwiftData
import SwiftUI

// Exercises tab — reads the seeded catalog from the SwiftData store
// (ticket 04). The rest of the prototype UI still runs on SampleStore
// until ticket 07 rewires it.
struct ExercisesView: View {
    @Query(
        filter: #Predicate<Exercise> { $0.isSeeded },
        sort: \Exercise.name
    ) private var exercises: [Exercise]
    @State private var searchText = ""

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
                        ExerciseRow(exercise: exercise)
                    }
                } footer: {
                    Text("Picking a machine during a workout selects its exercise automatically — this list is for browsing and free-weight logging.")
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Exercises")
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
    return ExercisesView()
        .modelContainer(container)
}
