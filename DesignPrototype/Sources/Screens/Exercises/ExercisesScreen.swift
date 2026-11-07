import SwiftUI

// PROTOTYPE — E01 Exercises (tab root). Search, the five family maps as a filter index (the
// screen's bold element: tap a family and only it stays lit), then the catalog grouped head to
// toe. Each SECTION header carries its family's colour mark; rows carry no leading icon at all
// (the user removed per-exercise icons: "They don't match") — the name, its equipment and load
// type in words, and the user's own relationship with the exercise: its best set (by load type)
// and when it was last trained. Tapping
// a row opens the exercise (E02). Group by (body area / last trained by week / A–Z) and
// Equipment Type live in the filter menu; Add Exercise… is in the toolbar and at the end of
// the list, and a search with no match offers to add what was typed.

struct ExercisesScreen: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var query = ""
    @State private var family: MuscleFamily?
    @State private var equipment: EquipmentTag?
    @State private var grouping: ExercisesGrouping = .bodyArea
    @State private var page = 0
    @State private var scroll = ScrollPosition(edge: .top)
    @State private var titleVisible = false
    @State private var renaming: Exercise?
    @State private var renameText = ""

    private var hasFilters: Bool { family != nil || equipment != nil }

    var body: some View {
        let stats = store.exercisesCatalogStats()
        let sections = makeSections(filteredExercises, stats: stats)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // While searching or filtering the count follows what is listed.
                LookNavTitle("Exercises", subtitle: filteredExercises.isEmpty ? nil
                             : Format.count(filteredExercises.count, "exercise"))
                    .padding(.top, 2)
                    .padding(.bottom, 18)
                SearchFieldView(text: $query, prompt: "Search exercises")
                    .padding(.bottom, 14)
                ExercisesFamilyStrip(selection: familyBinding)
                if hasFilters {
                    filterSummary
                        .padding(.top, 10)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                if sections.isEmpty {
                    noMatch.padding(.top, 20)
                } else {
                    // A plain VStack (56 rows is cheap): its content size is exact, so p2 / p3 paging lands true.
                    VStack(alignment: .leading, spacing: 28) {
                        ForEach(sections) { section in
                            sectionView(section, stats: stats)
                        }
                    }
                    .padding(.top, 28)
                }
                if !sections.isEmpty {
                    ExercisesMakeRow(title: "Add Exercise…") { router.present(.newExercise) }
                        .padding(.top, 28)
                }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.bottom, 40)
            .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: family)
            .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: equipment)
            .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: grouping)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .scrollPosition($scroll)
        .exercisesPaging(page, position: $scroll)
        .exercisesScrolledPast(60, into: $titleVisible)
        .lookScreenBackground()
        .proposalScreen("exercises")
        .exercisesInlineTitle("Exercises", visible: titleVisible)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { filterMenu }
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.present(.newExercise) } label: {
                    Image(systemName: "plus")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(look.textPrimary)
                }
                .accessibilityLabel("Add Exercise…")
            }
        }
        .sensoryFeedback(.selection, trigger: family)
        .sensoryFeedback(.selection, trigger: grouping)
        .alert("Rename Exercise", isPresented: renameShown) {
            TextField("Name", text: $renameText)
            Button("Save") {
                let trimmed = renameText.trimmingCharacters(in: .whitespaces)
                if let renaming, !trimmed.isEmpty { store.renameExercise(renaming.id, to: trimmed) }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
        .onAppear(perform: applyVariant)
    }

    // MARK: Filtering and grouping

    private var familyBinding: Binding<MuscleFamily?> {
        Binding(get: { family }, set: { family = $0 })
    }

    /// D24: a row that lacks a body area or a tag is never hidden by that filter.
    private var filteredExercises: [Exercise] {
        store.exercises.filter { exercise in
            Store.matches(exercise.name, query)
                && (family == nil || exercise.muscleGroup == nil || exercise.family == family)
                && (equipment == nil || exercise.tags.isEmpty || exercise.tags.contains(equipment!))
        }
    }

    private func makeSections(_ list: [Exercise], stats: [UUID: ExercisesCatalogStat]) -> [ExercisesSection] {
        let byName: (Exercise, Exercise) -> Bool = { $0.name.localizedCompare($1.name) == .orderedAscending }
        switch grouping {
        case .bodyArea:
            var sections: [ExercisesSection] = MuscleGroup.allCases.compactMap { group in
                let items = list.filter { $0.muscleGroup == group }.sorted(by: byName)
                return items.isEmpty ? nil : ExercisesSection(id: group.rawValue, title: group.label, family: group.family,
                                                               exercises: items)
            }
            let loose = list.filter { $0.muscleGroup == nil }.sorted(by: byName)
            if !loose.isEmpty {
                sections.append(ExercisesSection(id: "uncategorized", title: "Uncategorized", family: nil, exercises: loose))
            }
            return sections
        case .lastTrained:
            let trained = list.filter { stats[$0.id]?.lastTrained != nil }.sorted {
                let a = stats[$0.id]?.lastTrained ?? .distantPast, b = stats[$1.id]?.lastTrained ?? .distantPast
                return a == b ? byName($0, $1) : a > b
            }
            let untrained = list.filter { stats[$0.id]?.lastTrained == nil }.sorted(by: byName)
            // Recency buckets: this week, last week, earlier (weeks as the Home week widget counts them).
            let cal = Calendar.app
            let thisWeek = cal.dateInterval(of: .weekOfYear, for: store.now)
            let lastWeek = thisWeek.flatMap { cal.dateInterval(of: .weekOfYear, for: $0.start.addingTimeInterval(-1)) }
            func bucket(_ exercise: Exercise) -> Int {
                guard let date = stats[exercise.id]?.lastTrained else { return 3 }
                if thisWeek?.contains(date) == true { return 0 }
                if lastWeek?.contains(date) == true { return 1 }
                return 2
            }
            var sections: [ExercisesSection] = []
            for (index, title) in ["This week", "Last week", "Earlier"].enumerated() {
                let items = trained.filter { bucket($0) == index }
                if !items.isEmpty {
                    sections.append(ExercisesSection(id: "recent-\(index)", title: title, family: nil, showsMark: false,
                                                     exercises: items))
                }
            }
            if !untrained.isEmpty {
                sections.append(ExercisesSection(id: "untrained", title: "Not trained yet", family: nil, showsMark: false,
                                                 exercises: untrained))
            }
            return sections
        case .alphabetical:
            let grouped = Dictionary(grouping: list) { String($0.name.prefix(1)).uppercased() }
            return grouped.keys.sorted().map { letter in
                ExercisesSection(id: "letter-\(letter)", title: letter, family: nil, showsMark: false,
                                 exercises: (grouped[letter] ?? []).sorted(by: byName))
            }
        }
    }

    // MARK: Sections

    private func sectionView(_ section: ExercisesSection, stats: [UUID: ExercisesCatalogStat]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ExercisesSectionHeader(title: section.title, family: section.family, showsMark: section.showsMark,
                                   count: section.exercises.count)
            LookList(separatorInset: 14) {
                ForEach(section.exercises) { exercise in
                    ExercisesCatalogRow(exercise: exercise, stat: stats[exercise.id], unit: store.displayUnit, now: store.now) {
                        router.push(.exerciseDetail(exerciseID: exercise.id))
                    }
                    .contextMenu { rowMenu(exercise) }
                }
            }
        }
        .transition(.opacity)
    }

    @ViewBuilder private func rowMenu(_ exercise: Exercise) -> some View {
        Button("Progress…", systemImage: "chart.xyaxis.line") {
            router.push(.progress(exerciseID: exercise.id, variationID: nil))
        }
        Button("Presets…", systemImage: "slider.horizontal.3") { router.present(.presets(exerciseID: exercise.id)) }
        Button("Load type…", systemImage: exercise.loadType.exercisesSymbol) { router.present(.loadType(exerciseID: exercise.id)) }
        if !exercise.isSeeded {
            Button("Rename…", systemImage: "pencil") {
                renameText = exercise.name
                renaming = exercise
            }
        }
    }

    private var renameShown: Binding<Bool> {
        Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
    }

    // MARK: Filters

    private var filterMenu: some View {
        Menu {
            Section("Group by") {
                Picker("Group by", selection: $grouping) {
                    ForEach(ExercisesGrouping.allCases) { option in
                        Label(option.title, systemImage: option.symbol).tag(option)
                    }
                }
                .pickerStyle(.inline)
            }
            Menu("Equipment Type") {
                Picker("Equipment Type", selection: $equipment) {
                    Text("All types").tag(EquipmentTag?.none)
                    ForEach(EquipmentTag.allCases) { tag in
                        Text(tag.label).tag(Optional(tag))
                    }
                }
                .pickerStyle(.inline)
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
    }

    private var filterSummary: some View {
        let parts = [family?.label, equipment?.label].compactMap { $0 }
        return HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .font(.system(.footnote, weight: .semibold))
            Text(parts.joined(separator: " · "))
                .font(.system(.footnote, weight: .semibold))
            Spacer(minLength: 8)
            Button("Clear") { clearFilters() }
                .font(.system(.footnote, weight: .bold))
                .frame(minHeight: 44)
                .buttonStyle(.plain)
        }
        .foregroundStyle(look.id.isPaperClub ? look.actionText : look.textPrimary)
        .padding(.leading, 4)
    }

    private func clearFilters() {
        if reduceMotion { family = nil; equipment = nil } else {
            withAnimation(.snappy(duration: 0.3)) { family = nil; equipment = nil }
        }
    }

    // MARK: No match

    /// No match: the screen state's only action takes the look's primary treatment.
    private var noMatch: some View {
        let name = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(spacing: 22) {
            VStack(spacing: 12) {
                IconDisc(symbol: "magnifyingglass", size: 56, context: .make)
                Text("No exercises match")
                    .font(look.id.isPaperClub ? look.font.title3 : look.font.tileTitle)
                    .foregroundStyle(look.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)
            if !name.isEmpty {
                PrimaryButton("Add “\(name)”…", symbol: "plus") {
                    ExercisesDraft.pendingName = name
                    router.present(.newExercise)
                }
            }
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity)
    }

    // MARK: Variants

    private func applyVariant() {
        guard let variant = ExercisesVariant.consume(.e01, store: store, router: router) else { return }
        page = ExercisesVariant.page(variant)
        if ExercisesVariant.has(variant, "search") { query = "press" }
        if ExercisesVariant.has(variant, "empty") { query = "Zercher Squat" }
        if ExercisesVariant.has(variant, "arms") { family = .arms }
        if ExercisesVariant.has(variant, "machine") { equipment = .machine }
        if ExercisesVariant.has(variant, "recent") { grouping = .lastTrained }
        if ExercisesVariant.has(variant, "az") { grouping = .alphabetical }
    }
}

// MARK: - Family filter strip (the bold element)

/// The five families as map tiles. Tap one to show only its exercises: it stays lit and washes
/// in its colour, the others go unlit. Tap it again to show everything.
struct ExercisesFamilyStrip: View {
    @Binding var selection: MuscleFamily?
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption) private var axMap: CGFloat = 34
    /// Families lit so far by the entry motion (they light head to toe once; Reduce Motion: at
    /// once). Kept here rather than in MuscleMap's own delay so a filter chosen during the
    /// entry motion is never overridden by it.
    @State private var awake: Set<MuscleFamily> = []

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Array(MuscleFamily.allCases.enumerated()), id: \.element) { index, family in
                        tile(family, index: index, stacked: false)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ForEach(Array(MuscleFamily.allCases.enumerated()), id: \.element) { index, family in
                        tile(family, index: index, stacked: true)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .onAppear {
            guard awake.isEmpty else { return }
            if reduceMotion { awake = Set(MuscleFamily.allCases); return }
            for (index, family) in MuscleFamily.allCases.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1 + 0.07 * Double(index)) { awake.insert(family) }
            }
        }
    }

    private func tile(_ family: MuscleFamily, index: Int, stacked: Bool) -> some View {
        let selected = selection == family
        let lit = awake.contains(family) && (selection == nil || selected)
        let shape = RoundedRectangle(cornerRadius: look.radius.row + 2, style: .continuous)
        return Button {
            if reduceMotion { selection = selected ? nil : family } else {
                withAnimation(.snappy(duration: 0.3)) { selection = selected ? nil : family }
            }
        } label: {
            Group {
                if stacked {
                    VStack(spacing: 5) {
                        MuscleMap(family: family, lit: lit, size: 46)
                        name(family, lit: selection == nil || selected)
                    }
                    .padding(.top, 9)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity)
                } else {
                    HStack(spacing: 10) {
                        MuscleMap(family: family, lit: lit, size: axMap)
                        name(family, lit: selection == nil || selected)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                }
            }
            .background(selected ? look.familyTint(family) : look.surface, in: shape)
            .overlay {
                if selected {
                    shape.strokeBorder(look.id.isPaperClub ? look.outline : look.textPrimary,
                                       lineWidth: look.id.isPaperClub ? look.stroke.primary : 2)
                } else if look.id.isPaperClub {
                    shape.strokeBorder(look.outline, lineWidth: 1.5)
                } else {
                    shape.strokeBorder(look.hairline, lineWidth: 1)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.lookPressable)
        .accessibilityLabel(family.label)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint(selected ? "Shows every body area" : "Shows only \(family.label)")
    }

    private func name(_ family: MuscleFamily, lit: Bool) -> some View {
        Text(family.label)
            .font(.system(.caption, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
            .foregroundStyle(lit ? look.textPrimary : look.textTertiary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

// MARK: - Catalog row

/// Name, equipment, load type (when not plain weight), Custom · best set over when it was last
/// trained. No leading glyph: the equipment is already in words. The best is formatted by load
/// type and carries the look's new-best mark only when the last session set it
/// (`ExercisesCatalogStat.lastWasNewBest`: never a tie, never a first time).
struct ExercisesCatalogRow: View {
    var exercise: Exercise
    var stat: ExercisesCatalogStat?
    var unit: WeightUnit
    var now: Date
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
                        HStack(spacing: 8) {
                            if let best = stat?.best { bestValue(best) }
                            Text(ExercisesDates.relative(last, now: now))
                                .font(look.font.footnote)
                                .foregroundStyle(look.textTertiary)
                        }
                    }
                }
                Spacer(minLength: 8)
                if !ax, let last = stat?.lastTrained {
                    // Short by construction (unit only when it differs, "Mon" / "Sep 19"), so it
                    // keeps its size and the name wraps only when it truly must.
                    VStack(alignment: .trailing, spacing: 3) {
                        if let best = stat?.best { bestValue(best) }
                        Text(ExercisesDates.relative(last, now: now))
                            .font(look.font.footnote)
                            .foregroundStyle(look.textTertiary)
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
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder private var details: some View {
        let equipment = exercise.exercisesEquipmentLine
        let badge = exercise.loadType == .weighted ? nil : exercise.loadType.badge
        if !equipment.isEmpty || badge != nil || !exercise.isSeeded {
            ExercisesFlowLayout(spacing: 6, lineSpacing: 4) {
                if !equipment.isEmpty {
                    Text(equipment).font(look.font.footnote).foregroundStyle(look.textSecondary)
                }
                if let badge { ExercisesTag(badge) }
                if !exercise.isSeeded { ExercisesTag("Custom") }
            }
        }
    }

    private func bestValue(_ best: SetValue) -> some View {
        ExercisesBestValue(value: best, loadType: exercise.loadType, rowUnit: unit, style: .row,
                           marked: stat?.lastWasNewBest ?? false)
    }

    private var accessibilityText: String {
        var parts = [exercise.name]
        let equipment = exercise.exercisesEquipmentLine
        if !equipment.isEmpty { parts.append(equipment) }
        if exercise.loadType != .weighted { parts.append(exercise.loadType.badge) }
        if !exercise.isSeeded { parts.append("Custom") }
        if let best = stat?.best {
            parts.append((stat?.lastWasNewBest ?? false ? "New best, set last session, " : "Best ")
                         + ExercisesValue.spoken(best, loadType: exercise.loadType))
        }
        if let last = stat?.lastTrained { parts.append("Last trained \(ExercisesDates.relative(last, now: now))") }
        return parts.joined(separator: ", ")
    }
}
