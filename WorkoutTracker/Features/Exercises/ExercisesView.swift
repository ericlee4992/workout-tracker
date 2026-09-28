import SwiftData
import SwiftUI

/// The Exercises tab (Floodlight ticket 08, E01): the persisted catalog — seeded rows (ticket 04)
/// and user-created exercises (ticket 06) side by side. Search, the five family maps as a filter
/// (the bold element), then the catalog in sections: body area head to toe, last trained, or A–Z.
/// Each row shows the user's relationship with the exercise — its best set by load type and when
/// it was last trained — and opens the exercise (E02). The long-press menu keeps the shortcuts.
/// Seeded rows are read-only (D24); only user-created exercises can be renamed.
struct ExercisesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query private var allPreferences: [AppPreferences]
    /// Finished workouts: the rows' readouts refresh when one is logged or edited.
    @Query(filter: #Predicate<Workout> { $0.finishedAt != nil }) private var finished: [Workout]
    /// Group by is a per-device display preference, like Appearance (no schema field).
    @AppStorage("exerciseGrouping") private var grouping: ExercisesGrouping = .bodyArea
    @State private var searchText = ""
    @State private var path = NavigationPath()
    @State private var titleInBar = false
    @State private var newExercise: NewExerciseRequest?
    @State private var renamingExercise: Exercise?
    @State private var renameText = ""
    @State private var presetsExercise: Exercise?
    @State private var loadTypeExercise: Exercise?
    @State private var progressExercise: Exercise?

    private var preferences: AppPreferences? {
        AppPreferences.canonical(of: allPreferences)
    }

    /// The family chosen in the strip, remembered between visits in the body-area preference
    /// (ticket 21's field; a value saved before the strip opens on its family). Display state
    /// only (D23).
    private var family: MuscleFamily? {
        ExerciseCatalog.family(stored: preferences?.exerciseBrowseMuscleGroup)
    }

    private var equipmentTag: EquipmentTag? { preferences?.exerciseBrowseEquipmentTag }
    private var hasFilters: Bool { family != nil || equipmentTag != nil }

    /// Search and equipment (ticket 21's rules, D24: an untagged row is never hidden), then the family.
    private var listed: [Exercise] {
        let filter = CatalogExerciseFilter(searchText: searchText, bodyArea: nil, equipmentTag: equipmentTag)
        let ids = Set(CatalogBrowsing.exercises(exercises.map(CatalogExerciseRow.init), matching: filter).map(\.id))
        return exercises.filter { ids.contains($0.id) && ExerciseCatalog.matches(muscleGroup: $0.muscleGroup, family: family) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            // Read so a logged or edited workout re-renders the rows' readouts.
            let _ = finished.count
            let logged = (try? ExerciseOverview.loggedSets(in: modelContext)) ?? [:]
            let stats = Dictionary(uniqueKeysWithValues: exercises.map {
                ($0.id, ExerciseOverview.stat(of: logged[$0.id] ?? [], currentLoadType: $0.loadType))
            })
            list(stats: stats)
                .lookScreenBackground()
                .exercisesInlineTitle("Exercises", visible: titleInBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { filterMenu }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { newExercise = NewExerciseRequest() } label: {
                            Image(systemName: "plus")
                                .font(.system(.body, weight: .semibold))
                                .foregroundStyle(look.textPrimary)
                        }
                        .accessibilityLabel("Add Exercise…")
                        .accessibilityIdentifier("addExerciseToolbar")
                    }
                }
                .navigationDestination(for: ExerciseDetailLink.self) { link in
                    ExerciseDetailView(exerciseID: link.exerciseID)
                }
                .sheet(item: $newExercise) { request in
                    // Same form the mid-workout pickers open (ticket 19). From here, Add opens the
                    // new exercise (user decision 4, ticket 08) once the sheet has closed.
                    NewExerciseSheet(initialName: request.name) { exercise in
                        let id = exercise.id
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            path.append(ExerciseDetailLink(exerciseID: id))
                        }
                    }
                }
                .sheet(item: $presetsExercise) { ExercisePresetsSheet(exercise: $0) }
                .sheet(item: $loadTypeExercise) { EditExerciseLoadTypeSheet(exercise: $0) }
                .sheet(item: $progressExercise) { exercise in
                    // No load type and no preset passed: the chart resolves them from what was
                    // actually logged (D36, D47).
                    NavigationStack {
                        ExerciseProgressView(exerciseID: exercise.id, exerciseName: exercise.name)
                    }
                }
                .alert(
                    "Rename Exercise",
                    isPresented: Binding(get: { renamingExercise != nil }, set: { if !$0 { renamingExercise = nil } }),
                    presenting: renamingExercise
                ) { exercise in
                    TextField("Name", text: $renameText)
                    Button("Save") { rename(exercise) }
                    Button("Cancel", role: .cancel) {}
                }
        }
    }

    // MARK: List

    private func list(stats: [UUID: ExerciseStat]) -> some View {
        let shown = listed
        let items = shown.map {
            ExerciseCatalogItem(id: $0.id, name: $0.name, muscleGroup: $0.muscleGroup, lastTrained: stats[$0.id]?.lastTrained)
        }
        let sections = ExerciseCatalog.sections(items, by: grouping, now: .now)
        let byID = Dictionary(shown.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let unit = preferences?.unitPreference
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // While searching or filtering the count follows what is listed.
                LookNavTitle("Exercises", subtitle: shown.isEmpty ? nil
                             : "\(shown.count) exercise\(shown.count == 1 ? "" : "s")")
                    .padding(.top, 2)
                    .padding(.bottom, 18)
                SearchFieldView(text: $searchText, prompt: "Search exercises", identifier: "exerciseSearch")
                    .padding(.bottom, 14)
                ExercisesFamilyStrip(selection: Binding(get: { family }, set: { choose($0) }))
                if hasFilters {
                    filterSummary
                        .padding(.top, 10)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                if sections.isEmpty {
                    noMatch.padding(.top, 20)
                } else {
                    VStack(alignment: .leading, spacing: 28) {
                        ForEach(sections) { section in
                            VStack(alignment: .leading, spacing: 10) {
                                ExercisesSectionHeader(title: section.title, family: section.family,
                                                       showsMark: section.showsMark, count: section.items.count)
                                LookList(separatorInset: 14) {
                                    ForEach(section.items.compactMap { byID[$0.id] }) { exercise in
                                        row(exercise, stat: stats[exercise.id], unit: unit)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 28)
                    MakeRow(title: "Add Exercise…") { newExercise = NewExerciseRequest() }
                        .accessibilityIdentifier("addExercise")
                        .padding(.top, 28)
                }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.bottom, 40)
            .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: family)
            .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: equipmentTag)
            .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: grouping)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .onScrollGeometryChange(for: Bool.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top > (typeSize.isAccessibilitySize ? 90 : 60)
        } action: { _, past in
            withAnimation(.easeInOut(duration: 0.18)) { titleInBar = past }
        }
        .sensoryFeedback(.selection, trigger: family)
        .sensoryFeedback(.selection, trigger: grouping)
    }

    private func row(_ exercise: Exercise, stat: ExerciseStat?, unit: WeightUnit?) -> some View {
        ExercisesCatalogRow(exercise: exercise, stat: stat, unit: unit) {
            path.append(ExerciseDetailLink(exerciseID: exercise.id))
        }
        .accessibilityIdentifier("exerciseRow.\(exercise.name)")
        .contextMenu {
            Button("Progress…", systemImage: "chart.xyaxis.line") { progressExercise = exercise }
            // Presets are the user's own data hanging off the row, so they are offered on seeded
            // exercises too — unlike renaming, which D24 reserves.
            Button("Presets…", systemImage: "slider.horizontal.3") { presetsExercise = exercise }
            // Offered on SEEDED exercises too: a wrong load type ranks the user's records in the
            // wrong direction, and the only other escape (a different exercise) splits their
            // history. The override survives reconciliation; see `loadTypeUserOverridden`.
            Button("Load type…", systemImage: exercise.loadType.pickerSymbol) { loadTypeExercise = exercise }
            if !exercise.isSeeded {
                Button("Rename…", systemImage: "pencil") {
                    renameText = exercise.name
                    renamingExercise = exercise
                }
            }
        }
    }

    // MARK: Filters

    private var filterMenu: some View {
        Menu {
            Picker("Group by", selection: $grouping) {
                ForEach(ExercisesGrouping.allCases) { option in
                    Label(option.title, systemImage: option.symbol).tag(option)
                        .accessibilityIdentifier("exerciseGrouping.\(option.rawValue)")
                }
            }
            .pickerStyle(.inline)
            Menu("Equipment Type") {
                BrowseMenuOption(title: "All types", isSelected: equipmentTag == nil) {
                    write { $0.exerciseBrowseEquipmentTag = nil }
                }
                .accessibilityIdentifier("exerciseFilter.tag.all")
                ForEach(EquipmentTag.allCases) { tag in
                    BrowseMenuOption(title: tag.label, isSelected: equipmentTag == tag) {
                        write { $0.exerciseBrowseEquipmentTag = tag }
                    }
                    .accessibilityIdentifier("exerciseFilter.tag.\(tag.rawValue)")
                }
            }
            if hasFilters {
                Button("Clear Filters", systemImage: "xmark.circle") { clearFilters() }
            }
        } label: {
            Image(systemName: hasFilters || grouping != .bodyArea
                  ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(look.textPrimary)
        }
        .accessibilityLabel("Filter")
        .accessibilityIdentifier("exerciseFilterMenu")
    }

    private var filterSummary: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .font(.system(.footnote, weight: .semibold))
            Text([family?.label, equipmentTag?.label].compactMap { $0 }.joined(separator: " · "))
                .font(.system(.footnote, weight: .semibold))
            Spacer(minLength: 8)
            Button("Clear") { clearFilters() }
                .font(.system(.footnote, weight: .bold))
                .frame(minHeight: 44)
                .buttonStyle(.plain)
                .accessibilityIdentifier("clearExerciseFilters")
        }
        .foregroundStyle(look.textPrimary)
        .padding(.leading, 4)
    }

    private func choose(_ family: MuscleFamily?) {
        write { $0.exerciseBrowseMuscleGroup = family?.rawValue }
    }

    private func clearFilters() {
        let clear = {
            write {
                $0.exerciseBrowseMuscleGroup = nil
                $0.exerciseBrowseEquipmentTag = nil
            }
        }
        if reduceMotion { clear() } else { withAnimation(.snappy(duration: 0.3)) { clear() } }
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

    // MARK: No match

    /// The search matched nothing: the state's only action takes the filled treatment.
    private var noMatch: some View {
        let name = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(spacing: 22) {
            VStack(spacing: 12) {
                IconDisc(symbol: "magnifyingglass", size: 56, context: .make)
                Text("No exercises match")
                    .font(look.font.tileTitle)
                    .foregroundStyle(look.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("noExercisesMatch")
            if !name.isEmpty {
                PrimaryButton("Add “\(name)”…", symbol: "plus") {
                    newExercise = NewExerciseRequest(name: name)
                }
                .accessibilityIdentifier("addTypedExercise")
            } else {
                MakeRow(title: "Add Exercise…") { newExercise = NewExerciseRequest() }
                    .accessibilityIdentifier("addExercise")
            }
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity)
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

extension ExercisesGrouping {
    var symbol: String {
        switch self {
        case .bodyArea: "figure.arms.open"
        case .lastTrained: "clock.arrow.circlepath"
        case .alphabetical: "textformat.abc"
        }
    }
}

// MARK: - Catalog row

/// Name; equipment in words, the load badge when not Weighted, Custom; trailing, the best set by
/// load type (the burst when the latest session set it) over when it was last trained. No leading
/// glyph: the equipment is already in words (no per-exercise icons — the user's rule).
struct ExercisesCatalogRow: View {
    var exercise: Exercise
    var stat: ExerciseStat?
    var unit: WeightUnit?
    var action: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let ax = typeSize.isAccessibilitySize
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(look.exercisesRowTitle)
                        .foregroundStyle(look.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    details
                    if ax, let last = stat?.lastTrained {
                        WrapLayout(spacing: 8, lineSpacing: 4) {
                            if let best = bestValue { best }
                            lastTrained(last)
                        }
                    }
                }
                Spacer(minLength: 8)
                if !ax, let last = stat?.lastTrained {
                    VStack(alignment: .trailing, spacing: 3) {
                        if let best = bestValue { best }
                        lastTrained(last)
                    }
                    .fixedSize()
                }
                Image(systemName: "chevron.right")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(look.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        }
        .buttonStyle(ExercisesRowPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder private var details: some View {
        let equipment = exercise.equipmentLine
        let badge = exercise.loadType == .weighted ? nil : exercise.loadType.badge
        if !equipment.isEmpty || badge != nil || !exercise.isSeeded {
            // One line whenever it fits (a wrap layout handed exactly its own width by the row's
            // second pass broke "Machine  Assisted" onto two lines); wraps only when it must.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) { detailItems(equipment: equipment, badge: badge) }
                WrapLayout(spacing: 6, lineSpacing: 4) { detailItems(equipment: equipment, badge: badge) }
            }
        }
    }

    @ViewBuilder private func detailItems(equipment: String, badge: String?) -> some View {
        if !equipment.isEmpty {
            Text(equipment).font(look.font.footnote).foregroundStyle(look.textSecondary).fixedSize()
        }
        if let badge { ExercisesTag(badge) }
        if !exercise.isSeeded { ExercisesTag("Custom") }
    }

    private var bestValue: ExercisesBestValue? {
        guard let best = stat?.best, let value = SetValue(best) else { return nil }
        return ExercisesBestValue(value: value, loadType: exercise.loadType, userUnit: unit, marked: stat?.lastWasNewBest ?? false)
    }

    private func lastTrained(_ date: Date) -> some View {
        Text(ExerciseDates.relative(date, now: .now))
            .font(look.font.footnote)
            .foregroundStyle(look.textTertiary)
    }

    private var spoken: String {
        var parts = [exercise.name]
        if !exercise.equipmentLine.isEmpty { parts.append(exercise.equipmentLine) }
        if exercise.loadType != .weighted { parts.append(exercise.loadType.badge) }
        if !exercise.isSeeded { parts.append("Custom") }
        if let best = stat?.best, let value = SetValue(best) {
            parts.append((stat?.lastWasNewBest ?? false ? "New best, set last session, " : "Best ")
                         + ExerciseValueText.spoken(value, loadType: exercise.loadType))
        }
        if let last = stat?.lastTrained { parts.append("Last trained \(ExerciseDates.relative(last, now: .now))") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Inline title

extension View {
    /// The screen's inline title in the look's nav face, faded in once the large title has
    /// scrolled away; the bar's ground shows with it.
    func exercisesInlineTitle(_ title: String, visible: Bool) -> some View {
        modifier(ExercisesInlineTitle(title: title, visible: visible))
    }
}

private struct ExercisesInlineTitle: ViewModifier {
    var title: String
    var visible: Bool
    @Environment(\.look) private var look

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(look.ground, for: .navigationBar)
            .toolbarBackgroundVisibility(visible ? .visible : .hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(look.font.navTitle)
                        .foregroundStyle(look.textPrimary)
                        .lineLimit(1)
                        .opacity(visible ? 1 : 0)
                        .accessibilityHidden(!visible)
                }
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
