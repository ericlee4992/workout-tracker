import SwiftData
import SwiftUI

struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var searchText = ""
    /// Non-nil while the inline creation form is up (ticket 19).
    @State private var creating: NewExerciseRequest?
    var onSelect: (Exercise) -> Void

    private var filtered: [Exercise] {
        guard !searchText.isEmpty else { return exercises }
        return exercises.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(filtered) { exercise in
                        Button {
                            select(exercise)
                        } label: {
                            ExerciseRow(exercise: exercise)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("exerciseOption.\(exercise.name)")
                    }
                    // Ticket 19: a search that matches nothing is exactly the
                    // moment the movement needs inventing — offer it under the
                    // name already typed rather than making the user clear the
                    // field and start over.
                    if filtered.isEmpty, !trimmedSearch.isEmpty {
                        Button {
                            creating = NewExerciseRequest(name: trimmedSearch)
                        } label: {
                            Label("Create “\(trimmedSearch)”", systemImage: "plus")
                        }
                        .accessibilityIdentifier("createExerciseFromSearch")
                    }
                }
                Section {
                    Button("New Exercise…", systemImage: "plus") {
                        creating = NewExerciseRequest(name: trimmedSearch)
                    }
                    .accessibilityIdentifier("newExercise")
                } footer: {
                    Text("Creating one here adds it to your Exercises tab and selects it for this entry straight away.")
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $creating) { request in
                NewExerciseSheet(initialName: request.name) { exercise in
                    select(exercise)
                }
            }
        }
    }

    /// Selecting closes the creation form first, so the picker is never
    /// dismissed out from under a sheet it is still presenting.
    private func select(_ exercise: Exercise) {
        creating = nil
        onSelect(exercise)
        dismiss()
    }
}

struct ExerciseRow: View {
    var name: String
    var loadType: LoadType
    var tags: [EquipmentTag]

    init(name: String, loadType: LoadType, tags: [EquipmentTag]) {
        self.name = name
        self.loadType = loadType
        self.tags = tags
    }

    init(exercise: Exercise) {
        self.init(
            name: exercise.name, loadType: exercise.loadType,
            tags: exercise.equipmentTypeTags)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.body.weight(.medium))
                Text(tags.map(\.label).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if loadType != .weighted {
                Text(loadType.badge)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Capsule())
                    .foregroundStyle(.secondary)
            }
        }
    }
}
