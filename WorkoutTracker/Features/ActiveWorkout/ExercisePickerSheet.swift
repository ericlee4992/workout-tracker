import SwiftData
import SwiftUI

/// Add Exercise (Floodlight redesign): search, the exercises recently done at this gym first,
/// then every exercise grouped head to toe by body area under a family colour mark (never a
/// mark per row). Tapping a row adds it (the tap is the commit); Cancel adds nothing. No match
/// offers "Create “…”" under the typed name (ticket 19).
struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.look) private var look
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var searchText = ""
    /// Non-nil while the inline creation form is up (ticket 19).
    @State private var creating: NewExerciseRequest?
    /// The workout's gym: "Recent at <gym>" leads the list.
    var gym: Gym? = nil
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

    /// Body areas head to toe (`BodyArea.order`), then any other group, then Uncategorized.
    private var sections: [(title: String, exercises: [Exercise])] {
        let grouped = Dictionary(grouping: filtered) { $0.muscleGroup ?? "" }
        let known = BodyArea.order.filter { grouped[$0] != nil }
        let others = grouped.keys.filter { !$0.isEmpty && !BodyArea.order.contains($0) }.sorted()
        var result = (known + others).map { (title: $0, exercises: grouped[$0] ?? []) }
        if let none = grouped[""], !none.isEmpty { result.append((title: "Uncategorized", exercises: none)) }
        return result
    }

    private var recent: [Exercise] {
        guard trimmedSearch.isEmpty, let gym, !gym.isDeleted else { return [] }
        return LiveRecentSection.exercises(at: gym, in: modelContext)
    }

    var body: some View {
        NavigationStack {
            List {
                if let gym, !recent.isEmpty {
                    Section {
                        ForEach(recent) { exercise in row(exercise, identifier: "recentOption.\(exercise.name)") }
                    } header: {
                        LookSectionLabel(title: "Recent at \(gym.name)", symbol: "clock.arrow.circlepath")
                    }
                    .lookListRows()
                }
                ForEach(sections, id: \.title) { section in
                    Section {
                        ForEach(section.exercises) { exercise in row(exercise, identifier: "exerciseOption.\(exercise.name)") }
                    } header: {
                        LookSectionLabel(title: section.title, family: MuscleFamily(muscleGroup: section.title))
                    }
                    .lookListRows()
                }
                // Ticket 19: a search that matches nothing is exactly the moment the movement
                // needs inventing — offer it under the name already typed.
                if filtered.isEmpty, !trimmedSearch.isEmpty {
                    Section {
                        Button {
                            creating = NewExerciseRequest(name: trimmedSearch)
                        } label: {
                            Label("Create “\(trimmedSearch)”", systemImage: "plus")
                                .font(.system(.body, weight: .semibold))
                                .foregroundStyle(look.actionText)
                        }
                        .accessibilityIdentifier("createExerciseFromSearch")
                    }
                    .lookListRows()
                }
                Section {
                    Button {
                        creating = NewExerciseRequest(name: trimmedSearch)
                    } label: {
                        Label("New Exercise…", systemImage: "plus")
                    }
                    .buttonStyle(.lookSecondary)
                    .accessibilityIdentifier("newExercise")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }
            }
            .lookGroupedList()
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

    private func row(_ exercise: Exercise, identifier: String) -> some View {
        Button { select(exercise) } label: { ExerciseRow(exercise: exercise) }
            .buttonStyle(.plain)
            .accessibilityIdentifier(identifier)
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

    @Environment(\.look) private var look

    var body: some View {
        let stacked = dynamicTypeSize.isAccessibilitySize
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if !detail.isEmpty {
                    Text(detail)
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if stacked, loadType != .weighted { badge }
            }
            Spacer(minLength: 0)
            if !stacked, loadType != .weighted { badge }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    /// "Chest · Machine · Cable": the body area, then the equipment tags.
    private var detail: String {
        ([bodyArea].compactMap { $0 } + tags.map(\.label)).joined(separator: " · ")
    }

    /// A non-default load type as a small outlined tag (the default, weighted, carries none).
    private var badge: some View {
        Text(loadType.badge)
            .font(.system(.caption, weight: .semibold))
            .foregroundStyle(look.textPrimary)
            .padding(.horizontal, 8)
            .frame(minHeight: 24)
            .overlay { Capsule().strokeBorder(look.hairline, lineWidth: 1) }
            .fixedSize()
    }
}
