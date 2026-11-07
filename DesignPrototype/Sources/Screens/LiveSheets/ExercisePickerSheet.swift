import SwiftUI

// PROTOTYPE — L06 Add Exercise, over the live workout. Search, body-area filter chips, the
// exercises recently trained at this gym first (last best + when), then every exercise grouped
// head to toe under section titles with the family's colour mark (never a mark per row).
// Each row says what it would be logged on here (the machine at this gym, else its free
// weight), so the list answers "what can I do at this gym?". Tapping a row adds it (commit
// on tap): its check pops in, then the sheet closes. Cancel adds nothing. No match offers
// "Create “…”". Variants: "p2", "search" (query "press"), "create", "legs" (filter).

struct ExercisePickerSheet: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var query = ""
    @State private var filter: LiveSheetsBodyFilter = .all
    @State private var page: Int?
    @State private var justAdded: UUID?
    @State private var addCount = 0

    private var gymID: UUID? { store.session?.gymID ?? store.selectedGymID }
    private var gymName: String? { store.gym(gymID)?.name }

    var body: some View {
        VStack(spacing: 0) {
            LiveSheetsHeader(title: "Add Exercise", leading: .cancel { router.dismissSheet() })
            VStack(spacing: 4) {
                SearchFieldView(text: $query, prompt: "Search exercises")
                    .padding(.horizontal, look.space.margin)
                filterChips
            }
            .padding(.bottom, 4)
            LookDivider()
            LiveSheetsScroll(page: page) {
                VStack(alignment: .leading, spacing: 24) {
                    if !recents.isEmpty, let gymName {
                        VStack(alignment: .leading, spacing: 8) {
                            LiveSheetsSectionHeader(title: "Recent at \(gymName)", symbol: "clock.arrow.circlepath")
                            sectionList(recents, showsLastDone: true)
                        }
                    }
                    ForEach(sections, id: \.title) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            LiveSheetsSectionHeader(title: section.title, family: section.family)
                            sectionList(section.exercises, showsLastDone: false)
                        }
                    }
                    if sections.isEmpty && recents.isEmpty { noMatch }
                    newExerciseRow
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 16)
                .padding(.bottom, 48)
            }
        }
        .liveSheetsPresentation(look)
        .presentationDetents([.large])
        .sensoryFeedback(.success, trigger: addCount)
        .onAppear(perform: applyVariant)
    }

    // MARK: Filter

    private var filterChips: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(LiveSheetsBodyFilter.allCases, id: \.self) { item in
                        Chip(item.title, isSelected: filter == item) {
                            if reduceMotion { filter = item } else { withAnimation(.snappy(duration: 0.25)) { filter = item } }
                        }
                        .id(item)
                    }
                }
                .padding(.horizontal, look.space.margin)
            }
            // The selected chip is always in view (e.g. Legs, past the screen edge).
            .onChange(of: filter) { _, item in
                if reduceMotion { proxy.scrollTo(item) } else { withAnimation(.snappy) { proxy.scrollTo(item) } }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { proxy.scrollTo(filter) }
            }
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: filter)
    }

    // MARK: Data

    private var recents: [Exercise] {
        guard store.session != nil || gymID != nil else { return [] }
        return store.recentExercises(gymID: gymID, limit: 5)
            .filter { Store.matches($0.name, query) && filter.includes($0.muscleGroup) }
    }

    private var sections: [(title: String, family: MuscleFamily?, exercises: [Exercise])] {
        store.exerciseSections(query: query)
            .filter { filter.includes($0.group) }
            .map { (title: $0.group?.label ?? "Uncategorized", family: $0.group?.family, exercises: $0.exercises) }
    }

    /// What this exercise would be logged on here: the machines at this gym, else its free weights.
    private func equipmentLine(_ exercise: Exercise) -> (glyph: LiveSheetsGlyphKind, text: String) {
        let machines = store.machines(for: exercise.id, gymID: gymID)
        if !machines.isEmpty {
            // A machine named after its movement ("Leg Press") would only repeat the title, so
            // it reads as plain "Machine"; other machines that serve it are named.
            let labels = machines.map(\.label).filter { $0.localizedCaseInsensitiveCompare(exercise.name) != .orderedSame }
            return (.machine, labels.isEmpty ? EquipmentTag.machine.label : labels.joined(separator: ", "))
        }
        let free = exercise.tags.filter { $0 != .machine }
        if let first = free.first {
            return (LiveSheetsGlyphKind.of(first), free.map(\.label).joined(separator: ", "))
        }
        return (.machine, EquipmentTag.machine.label)
    }

    // MARK: Rows

    /// One section: a glyph only on the rows whose equipment differs from the section's norm.
    private func sectionList(_ exercises: [Exercise], showsLastDone: Bool) -> some View {
        let lines = exercises.map(equipmentLine)
        let glyphs = LiveSheetsGlyphKind.exceptions(lines.map(\.glyph))
        let reserves = glyphs.contains { $0 != nil }
        return LookList(separatorInset: reserves ? 54 : 16) {
            ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                row(exercise, glyph: glyphs[index], reservesGlyph: reserves, showsLastDone: showsLastDone)
            }
        }
    }

    private func row(_ exercise: Exercise, glyph: LiveSheetsGlyphKind?, reservesGlyph: Bool, showsLastDone: Bool) -> some View {
        let equipment = equipmentLine(exercise)
        let badge = exercise.loadType == .weighted ? nil : exercise.loadType.badge
        let last = showsLastDone ? store.liveSheetsLastLog(exerciseID: exercise.id, gymID: gymID) : nil
        return LiveSheetsExerciseRow(
            title: exercise.name,
            subtitle: [equipment.text.isEmpty ? nil : equipment.text, badge].compactMap { $0 }.joined(separator: " · "),
            glyph: glyph,
            reservesGlyph: reservesGlyph,
            trailing: last.map { look.lastDoneLabel($0.date, now: store.now) },
            trailingValue: last?.best.map { look.previousLabel($0, rowUnit: store.defaultUnit(machine: nil, gymID: gymID),
                                                               loadType: exercise.loadType) },
            inWorkout: store.liveSheetsExerciseInSession(exercise.id),
            isAdded: justAdded == exercise.id
        ) {
            add(exercise.id)
        }
    }

    private var noMatch: some View {
        let name = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return LookList {
            LiveSheetsExerciseRow(title: "Create “\(name)”", subtitle: nil, glyph: .symbol("plus"),
                                  trailing: nil, isAdded: false) {
                let id = store.createExercise(name: name, loadType: .weighted, muscleGroup: nil, tags: [])
                add(id)
            }
        }
        .opacity(name.isEmpty ? 0 : 1)
    }

    private var newExerciseRow: some View {
        Button {
            router.present(.newExercise)
        } label: {
            HStack(spacing: 12) {
                IconDisc(symbol: "plus", size: 34, context: .make)
                Text("New Exercise…").font(.system(.body, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(look.textPrimary)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .dashedOutline(look.id.isPaperClub ? look.outline : look.dash, radius: look.radius.row,
                           lineWidth: look.id.isPaperClub ? 2 : 1.5, dash: [6, 4])
            .contentShape(Rectangle())
        }
        .buttonStyle(.lookPressable)
    }

    // MARK: Actions

    private func add(_ exerciseID: UUID) {
        guard justAdded == nil else { return }
        store.addExercise(exerciseID)
        addCount += 1
        if reduceMotion {
            router.dismissSheet()
            return
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { justAdded = exerciseID }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) { router.dismissSheet() }
    }

    private func applyVariant() {
        let variant = LiveSheetsVariant.consume([.l06], store: store, router: router)
        page = LiveSheetsVariant.page(variant)
        if LiveSheetsVariant.has(variant, "search") { query = "press" }
        if LiveSheetsVariant.has(variant, "create") { query = "Landmine Row" }
        if LiveSheetsVariant.has(variant, "legs") { filter = .family(.legs) }
    }
}

// MARK: - Body-area filter

enum LiveSheetsBodyFilter: Hashable, CaseIterable {
    case all
    case family(MuscleFamily)
    case core

    static var allCases: [LiveSheetsBodyFilter] { [.all] + MuscleFamily.allCases.map { .family($0) } + [.core] }

    var title: String {
        switch self {
        case .all: "All"
        case .family(let family): family.label
        case .core: MuscleGroup.core.label
        }
    }

    func includes(_ group: MuscleGroup?) -> Bool {
        switch self {
        case .all: true
        case .family(let family): group?.family == family
        case .core: group == .core
        }
    }
}

// MARK: - Exercise row

/// Name, what it is logged on here, and (for recents / a machine's page) your last best and
/// when. The glyph shows only where the equipment differs from its section (`reservesGlyph`
/// keeps the column aligned). With `showsAdd` the row ends in the same plus as Add by Machine
/// (a lit check once it is in this workout). The check pops in on the row you tapped before
/// the sheet closes.
struct LiveSheetsExerciseRow: View {
    var title: String
    var subtitle: String?
    var glyph: LiveSheetsGlyphKind?
    var reservesGlyph = false
    var trailing: String?
    /// A number above the trailing date (the last best, "270 × 10").
    var trailingValue: String? = nil
    /// Already logged in this workout: a small lit check (after the name, or as the trailing
    /// mark when the row shows a plus).
    var inWorkout: Bool = false
    var isAdded: Bool
    var showsAdd = false
    var action: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var glyphColumn: CGFloat = 26
    @ScaledMetric(relativeTo: .body) private var mark: CGFloat = 17
    @ScaledMetric(relativeTo: .body) private var bigMark: CGFloat = 26

    init(title: String, subtitle: String?, glyph: LiveSheetsGlyphKind?, reservesGlyph: Bool = false,
         trailing: String?, trailingValue: String? = nil, inWorkout: Bool = false, isAdded: Bool,
         showsAdd: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.glyph = glyph
        self.reservesGlyph = reservesGlyph || glyph != nil
        self.trailing = trailing
        self.trailingValue = trailingValue
        self.inWorkout = inWorkout
        self.isAdded = isAdded
        self.showsAdd = showsAdd
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if reservesGlyph {
                    Group {
                        if let glyph { LiveSheetsGlyph(glyph) } else { Color.clear }
                    }
                    .foregroundStyle(look.id.isPaperClub ? look.textPrimary : look.textSecondary)
                    .frame(width: glyphColumn)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(title)
                            .font(.system(.body, design: look.id == .anatomy ? .rounded : .default,
                                          weight: look.id == .paper || look.id == .carbon ? .medium : .semibold))
                            .foregroundStyle(look.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        if inWorkout && !showsAdd {
                            LiveSheetsInWorkoutMark(size: mark)
                        }
                    }
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(look.font.footnote)
                            .foregroundStyle(look.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if typeSize.isAccessibilitySize, trailing != nil || trailingValue != nil {
                        HStack(spacing: 8) {
                            if let trailingValue { valueText(trailingValue) }
                            if let trailing { Text(trailing).font(look.font.footnote).foregroundStyle(look.textTertiary) }
                        }
                    }
                }
                Spacer(minLength: 8)
                if !typeSize.isAccessibilitySize, trailing != nil || trailingValue != nil {
                    VStack(alignment: .trailing, spacing: 2) {
                        if let trailingValue { valueText(trailingValue) }
                        if let trailing {
                            Text(trailing).font(look.font.footnote).foregroundStyle(look.textTertiary)
                        }
                    }
                    .opacity(isAdded && !showsAdd ? 0 : 1)
                }
                if isAdded {
                    LiveSheetsAddedCheck()
                } else if showsAdd {
                    if inWorkout {
                        LiveSheetsInWorkoutMark(size: bigMark)
                    } else {
                        Image(systemName: "plus")
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(look.id.isPaperClub ? look.textPrimary : look.textSecondary)
                            .frame(minWidth: 20)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        }
        .buttonStyle(LiveSheetsRowPressStyle())
        .accessibilityLabel([title, inWorkout ? "In this workout" : nil, subtitle, trailingValue, trailing]
            .compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(isAdded ? .isSelected : [])
    }

    private func valueText(_ text: String) -> some View {
        Text(text)
            .font(look.id == .anatomy ? .system(.subheadline, design: .rounded, weight: .heavy).monospacedDigit()
                  : Font.system(.subheadline, weight: .heavy).width(look.id == .floodlight || look.id.isPaperClub ? .expanded : .standard).monospacedDigit())
            .foregroundStyle(look.textPrimary)
            .lineLimit(1)
    }
}
