import SwiftData
import SwiftUI

struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var searchText = ""
    /// Non-nil while the inline creation form is up (ticket 19).
    @State private var creating: NewExerciseRequest?
    var onSelect: (Exercise) -> Void

    /// Same multi-token matching the catalog pickers use (ticket 21), so
    /// "incline press" finds "Incline Bench Press" here too.
    private var filtered: [Exercise] {
        let tokens = CatalogBrowsing.tokens(searchText)
        guard !tokens.isEmpty else { return exercises }
        return exercises.filter {
            CatalogBrowsing.matches(CatalogBrowsing.normalize($0.name), tokens: tokens)
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
                .listRowBackground(Theme.card)
                Section {
                    Button("New Exercise…", systemImage: "plus") {
                        creating = NewExerciseRequest(name: trimmedSearch)
                    }
                    .buttonStyle(.secondary)
                    .accessibilityIdentifier("newExercise")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
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
    /// The exercise's `muscleGroup` (ticket 21) — the same vocabulary the
    /// filters group by, shown so a filtered list explains itself.
    var bodyArea: String?

    init(name: String, loadType: LoadType, tags: [EquipmentTag], bodyArea: String? = nil) {
        self.name = name
        self.loadType = loadType
        self.tags = tags
        self.bodyArea = bodyArea
    }

    init(exercise: Exercise) {
        self.init(
            name: exercise.name, loadType: exercise.loadType,
            tags: exercise.equipmentTypeTags, bodyArea: exercise.muscleGroup)
    }

    /// UI redesign ticket 08: the body area as a caption beside the name, the
    /// equipment tags as chips, the load type as a chip when it is not the
    /// default. The chips flow in a `WrapLayout`: a four-tag row wraps instead
    /// of clipping at any size (codex-review-08), a chip never breaks
    /// mid-word. At accessibility sizes the load-type chip joins that flow
    /// instead of squeezing the row. Ticket 11 removed the muscle icon the row
    /// wore beside the name — the user: "I want them gone … they don't match";
    /// the caption still says the body area, so a filtered list explains itself.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        HStack(spacing: Theme.Space.medium) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(Theme.cardTitle)
                WrapLayout {
                    if let bodyArea {
                        Text(bodyArea)
                            .font(.caption)
                            .foregroundStyle(Theme.secondary)
                    }
                    ForEach(tags) { tag in
                        Chip { Text(tag.label).fixedSize() }
                    }
                    if stacked, loadType != .weighted {
                        Chip(tint: Theme.accent) { Text(loadType.badge).fixedSize() }
                    }
                }
            }
            Spacer(minLength: 0)
            if !stacked, loadType != .weighted {
                Chip(tint: Theme.accent) { Text(loadType.badge).fixedSize() }
            }
        }
        .padding(.vertical, 2)
    }
}
