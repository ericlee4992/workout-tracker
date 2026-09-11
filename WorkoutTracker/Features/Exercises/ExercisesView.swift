import SwiftData
import SwiftUI

// Exercises tab — the full persisted catalog: seeded rows (ticket 04) plus
// user-created exercises (ticket 06) side by side. Seeded rows are read-only
// (D24); only user-created exercises can be renamed.
struct ExercisesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query private var allPreferences: [AppPreferences]
    @State private var searchText = ""
    @State private var showingAddExercise = false
    @State private var renamingExercise: Exercise?
    @State private var renameText = ""
    @State private var presetsExercise: Exercise?
    @State private var loadTypeExercise: Exercise?
    @State private var progressExercise: Exercise?

    private var preferences: AppPreferences? {
        AppPreferences.canonical(of: allPreferences)
    }

    /// Ticket 21: 74 seeded exercises is past the point of scrolling, so the
    /// list filters by body area and equipment type. Display state only (D23),
    /// remembered between visits.
    private var filter: CatalogExerciseFilter {
        CatalogExerciseFilter(
            searchText: searchText,
            bodyArea: preferences?.exerciseBrowseMuscleGroup,
            equipmentTag: preferences?.exerciseBrowseEquipmentTag)
    }

    private var rows: [CatalogExerciseRow] {
        CatalogBrowsing.exercises(exercises.map(CatalogExerciseRow.init), matching: filter)
    }

    private var exercisesByID: [UUID: Exercise] {
        Dictionary(exercises.map { ($0.id, $0) }) { first, _ in first }
    }

    private var bodyAreas: [String] {
        CatalogBrowsing.bodyAreasPresent(in: exercises.compactMap(\.muscleGroup))
    }

    private var filtered: [Exercise] {
        rows.compactMap { exercisesByID[$0.id] }
    }

    var body: some View {
        NavigationStack {
            List {
                if filter.hasActiveFilters {
                    Section {
                        HStack {
                            Label(filterSummary, systemImage: "line.3.horizontal.decrease.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Theme.accent)
                            Spacer()
                            Button("Clear") { clearFilters() }
                                .font(.caption.weight(.semibold))
                                .accessibilityIdentifier("clearExerciseFilters")
                        }
                    }
                    .listRowBackground(Theme.card)
                }
                Section {
                    ForEach(filtered) { exercise in
                        HStack {
                            ExerciseRow(exercise: exercise)
                            if !exercise.isSeeded {
                                Text("Custom")
                                    .font(Theme.label)
                                    .foregroundStyle(Theme.tertiary)
                            }
                        }
                        .contextMenu {
                            // Presets are the user's own data hanging off the
                            // row, so they are offered on seeded exercises too
                            // — unlike renaming, which D24 reserves.
                            Button("Progress…", systemImage: "chart.xyaxis.line") {
                                progressExercise = exercise
                            }
                            Button("Presets…") { presetsExercise = exercise }
                            // Offered on SEEDED exercises too, unlike renaming.
                            // D24 reserves catalog naming, but a wrong load
                            // type is not a naming preference — it ranks the
                            // user's records in the wrong direction, and the
                            // only other escape (a different exercise) splits
                            // their history. The override survives
                            // reconciliation; see `loadTypeUserOverridden`.
                            Button("Load type…") { loadTypeExercise = exercise }
                            if !exercise.isSeeded {
                                Button("Rename…") {
                                    renameText = exercise.name
                                    renamingExercise = exercise
                                }
                            }
                        }
                    }
                    if filtered.isEmpty {
                        Text("No exercises match")
                            .foregroundStyle(Theme.secondary)
                            .accessibilityIdentifier("noExercisesMatch")
                    }
                    Button("Add Exercise…", systemImage: "plus") {
                        showingAddExercise = true
                    }
                    .buttonStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }
                .listRowBackground(Theme.card)
                .listRowSeparatorTint(Theme.hairline)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Exercises")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    filterMenu
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                // Same form the mid-workout pickers open (ticket 19).
                NewExerciseSheet()
            }
            .sheet(item: $presetsExercise) { exercise in
                ExercisePresetsSheet(exercise: exercise)
            }
            .sheet(item: $loadTypeExercise) { exercise in
                EditExerciseLoadTypeSheet(exercise: exercise)
            }
            .sheet(item: $progressExercise) { exercise in
                // No load type and no preset passed. Both used to be handed in
                // from the LIVE exercise, which pooled every variation into one
                // line (D36) and let a D47 correction hide old history. The
                // chart resolves them from what was actually logged.
                NavigationStack {
                    ExerciseProgressView(
                        exerciseID: exercise.id,
                        exerciseName: exercise.name)
                }
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
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Menu("Body Area") {
                BrowseMenuOption(title: "All body areas", isSelected: filter.bodyArea == nil) {
                    write { $0.exerciseBrowseMuscleGroup = nil }
                }
                .accessibilityIdentifier("exerciseFilter.bodyArea.all")
                ForEach(bodyAreas, id: \.self) { area in
                    BrowseMenuOption(title: area, isSelected: filter.bodyArea == area) {
                        write { $0.exerciseBrowseMuscleGroup = area }
                    }
                    .accessibilityIdentifier("exerciseFilter.bodyArea.\(area)")
                }
            }
            Menu("Equipment Type") {
                BrowseMenuOption(title: "All types", isSelected: filter.equipmentTag == nil) {
                    write { $0.exerciseBrowseEquipmentTag = nil }
                }
                .accessibilityIdentifier("exerciseFilter.tag.all")
                ForEach(EquipmentTag.allCases) { tag in
                    BrowseMenuOption(title: tag.label, isSelected: filter.equipmentTag == tag) {
                        write { $0.exerciseBrowseEquipmentTag = tag }
                    }
                    .accessibilityIdentifier("exerciseFilter.tag.\(tag.rawValue)")
                }
            }
            if filter.hasActiveFilters {
                Button("Clear Filters", systemImage: "xmark.circle") { clearFilters() }
            }
        } label: {
            Label(
                "Filter",
                systemImage: filter.hasActiveFilters
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle")
        }
        .accessibilityIdentifier("exerciseFilterMenu")
    }

    private var filterSummary: String {
        [filter.bodyArea, filter.equipmentTag?.label]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private func clearFilters() {
        write {
            $0.exerciseBrowseMuscleGroup = nil
            $0.exerciseBrowseEquipmentTag = nil
        }
    }

    private func write(_ change: (AppPreferences) -> Void) {
        do {
            let preferences = try AppPreferences.canonical(in: modelContext)
            change(preferences)
            preferences.updatedAt = .now
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save exercise filter: \(error)")
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
