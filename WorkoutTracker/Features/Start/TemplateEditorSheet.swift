import SwiftData
import SwiftUI

/// New / Edit Template (Floodlight redesign; it was a stock Form with 4 + N steppers per exercise
/// and a 90-row "Add Exercise" wall). Now: the name with a live family strip and summary; one
/// compact card per exercise — a drag handle (drag to reorder), the name, a rest chip and
/// remove, then the rep targets as number pills (tap one to adjust it, + adds a set). The seam
/// between two cards is a chain link that makes (or breaks) a superset. "Add Exercise" opens a
/// searchable picker grouped by body area; cardio targets are compact cards. Cancel asks before
/// discarding edits. Save stays disabled until there is a name and something to do.
struct TemplateEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var template: WorkoutTemplate?
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query private var restOverrides: [ExerciseRestOverride]
    @Query private var allPreferences: [AppPreferences]

    @State private var draft = Draft()
    @State private var original = Draft()
    @State private var loaded = false
    @State private var error: String?
    @State private var confirmDiscard = false
    @State private var showPicker = false
    @State private var panels: [UUID: CardPanel] = [:]
    @State private var drag: CardDrag?
    @State private var cardFrames: [UUID: CGRect] = [:]
    @State private var links = 0
    @State private var lifts = 0
    @FocusState private var nameFocused: Bool

    /// Everything the editor changes; compared with the loaded state to know whether Cancel
    /// would discard anything.
    struct Draft: Equatable {
        var name = ""
        var items: [EditorItem] = []
        var cardio: [PlannedCardio] = []
    }

    struct EditorItem: Identifiable, Equatable {
        var id = UUID()
        var exerciseID: UUID
        /// 0 means no target for that slot.
        var repsBySet: [Int]
        /// Superset membership (D48), carried through the editor so an
        /// ordinary edit does not silently ungroup the template.
        var supersetGroupID: UUID?
        /// nil: the exercise's own rest applies.
        var restSeconds: Int?
        var equipment: EquipmentTag?
    }

    /// What a card has open below its pills: one set's stepper, or the rest adjuster.
    enum CardPanel: Hashable { case set(Int), rest }

    /// A card being dragged by its handle: where it started and how far it has moved.
    struct CardDrag: Equatable {
        var id: UUID
        var from: Int
        var translation: CGFloat
        var frames: [UUID: CGRect]
    }

    private static let stackSpace = "templateEditorCards"
    /// The seam between two cards (the superset link).
    private static let seam: CGFloat = 24

    private var sheetTitle: String { template == nil ? "New Template" : "Edit Template" }
    private var trimmedName: String { draft.name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isDirty: Bool { loaded && draft != original }
    private var canSave: Bool {
        !trimmedName.isEmpty && (!draft.items.isEmpty || !draft.cardio.isEmpty)
            && draft.cardio.allSatisfy(\.isValid) && template?.hasUnknownCardioTargets != true
    }

    var body: some View {
        NavigationStack {
            editor
                .lookScreenBackground()
                .navigationTitle(typeSize.isAccessibilitySize ? "" : sheetTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: cancel)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", action: save)
                            .disabled(!canSave)
                    }
                }
        }
        .lookSheetContext()
        .interactiveDismissDisabled(isDirty)
        // A centred alert (like Delete Template): iOS 26 draws a confirmation dialog as a
        // popover over the sheet's title.
        .alert("Discard changes?", isPresented: $confirmDiscard) {
            Button("Discard Changes", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) {}
        }
        .sheet(isPresented: $showPicker) {
            TemplateExercisePicker(exercises: exercises, addedCounts: addedCounts, onAdd: addExercise)
        }
        .onAppear(perform: load)
        .sensoryFeedback(.impact(weight: .medium), trigger: links)
        .sensoryFeedback(.impact(weight: .medium), trigger: lifts)
        .sensoryFeedback(.selection, trigger: dragTarget)
    }

    // MARK: Load / save

    private func load() {
        guard !loaded else { return }
        if let template {
            draft.name = template.name
            draft.cardio = template.plannedCardio
            draft.items = WorkoutTemplateService.orderedItems(of: template).compactMap { item in
                guard let exercise = item.exercise else { return nil }
                // 0 is the editor's "no target" value for a slot.
                return EditorItem(
                    exerciseID: exercise.id,
                    repsBySet: item.editableTargets.repsBySet.map { $0 ?? 0 },
                    supersetGroupID: item.supersetGroupID, restSeconds: item.plannedRestSeconds,
                    equipment: item.preferredEquipmentTag)
            }
        }
        original = draft
        loaded = true
        if template == nil {
            // Focus once the sheet has risen, so the keyboard is up for a new template.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { if !nameFocused { nameFocused = true } }
        }
    }

    private func cancel() {
        if isDirty { confirmDiscard = true } else { dismiss() }
    }

    private func save() {
        guard canSave else { return }
        let drafts = draft.items.compactMap { item -> TemplateItemDraft? in
            guard let exercise = exercises.first(where: { $0.id == item.exerciseID }) else { return nil }
            return TemplateItemDraft(
                exercise: exercise,
                targetRepsBySet: item.repsBySet.map { $0 == 0 ? nil : $0 },
                // codex-review 2 (critical): omitted here, ANY ordinary edit
                // of a template silently ungrouped its supersets.
                supersetGroupID: item.supersetGroupID, plannedRestSeconds: item.restSeconds,
                preferredEquipmentTag: item.equipment)
        }
        do {
            let service = WorkoutTemplateService(context: modelContext)
            if let template {
                try service.update(template, name: trimmedName, items: drafts, cardio: draft.cardio)
            } else {
                try service.create(name: trimmedName, items: drafts, cardio: draft.cardio)
            }
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private var addedCounts: [UUID: Int] {
        Dictionary(draft.items.map { ($0.exerciseID, 1) }, uniquingKeysWith: +)
    }

    private func addExercise(_ exerciseID: UUID) {
        let item = EditorItem(exerciseID: exerciseID, repsBySet: [10, 10, 10])
        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82)) { draft.items.append(item) }
    }

    private func exercise(_ id: UUID) -> Exercise? { exercises.first { $0.id == id } }

    // MARK: Editor

    private var editor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if typeSize.isAccessibilitySize {
                    // AX sizes: the title leaves the bar (it would truncate between the buttons).
                    Text(sheetTitle)
                        .font(look.font.title2)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.bottom, -14)
                }
                nameBlock
                exercisesBlock
                if template?.hasUnknownCardioTargets == true {
                    Text("Some cardio targets are unavailable in this version. Update the app to edit this template.")
                        .font(look.font.footnote).foregroundStyle(look.textSecondary)
                }
                cardioBlock
                if let error {
                    Text(error).font(look.font.footnote).foregroundStyle(look.destructive)
                }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 10)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .scrollDisabled(drag != nil)
    }

    // MARK: Name

    private var families: [MuscleFamily] {
        MuscleFamily.families(of: draft.items.map { exercise($0.exerciseID)?.muscleGroup })
    }

    private var nameBlock: some View {
        let families = families
        return VStack(alignment: .leading, spacing: 12) {
            TextField("Template name", text: $draft.name,
                      prompt: Text("Template name").foregroundStyle(look.textTertiary))
                .font(look.font.title2)
                .foregroundStyle(look.textPrimary)
                .tint(look.actionText)
                .focused($nameFocused)
                .submitLabel(.done)
                .onSubmit { nameFocused = false }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .frame(minHeight: 58)
                .lookSurface(.field, radius: look.radius.row + 2)
            // All five families, unlit until an exercise trains them: adding one lights its map.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { familyRow(families); summary }
                VStack(alignment: .leading, spacing: 8) { familyRow(families); summary }
            }
        }
    }

    private func familyRow(_ families: [MuscleFamily]) -> some View {
        HStack(spacing: 4) {
            ForEach(MuscleFamily.allCases) { family in
                FamilySticker(family: family, lit: families.contains(family), size: 28)
                    .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.6),
                               value: families.contains(family))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(families.isEmpty ? "No muscle groups yet" : families.map(\.label).joined(separator: ", "))
    }

    /// "5 exercises · 18 sets".
    @ViewBuilder private var summary: some View {
        let sets = draft.items.reduce(0) { $0 + $1.repsBySet.count }
        let parts = [draft.items.isEmpty ? nil : HistoryRendering.pluralized(draft.items.count, "exercise", "exercises"),
                     sets == 0 ? nil : HistoryRendering.pluralized(sets, "set", "sets")].compactMap { $0 }
        if !parts.isEmpty {
            Text(parts.joined(separator: " · "))
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(look.textSecondary)
                .contentTransition(.numericText())
                .animation(.snappy, value: sets)
        }
    }

    // MARK: Exercises

    private var exercisesBlock: some View {
        let letters = Supersets.memberLabels(groupIDs: draft.items.map(\.supersetGroupID))
        let letterByID = Dictionary(zip(draft.items.map(\.id), letters).compactMap { id, letter in letter.map { (id, $0) } },
                                    uniquingKeysWith: { first, _ in first })
        return VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Exercises")
            VStack(spacing: 0) {
                ForEach(Array(draft.items.enumerated()), id: \.element.id) { index, item in
                    let lifted = drag?.id == item.id
                    VStack(spacing: 0) {
                        itemCard(binding(for: item.id), letter: letterByID[item.id], lifted: lifted)
                            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.stackSpace)) } action: {
                                cardFrames[item.id] = $0
                            }
                        if index < draft.items.count - 1 {
                            supersetLink(after: index)
                                .opacity(drag == nil ? 1 : 0)
                        }
                    }
                    .offset(y: displacement(for: item.id, at: index))
                    .zIndex(lifted ? 2 : 0)
                    .transition(reduceMotion ? .opacity : .asymmetric(insertion: .scale(scale: 0.94).combined(with: .opacity),
                                                                       removal: .opacity))
                }
            }
            .coordinateSpace(.named(Self.stackSpace))
            .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: dragTarget)
            TemplateMakeRow(title: "Add Exercise") { showPicker = true }
                .accessibilityIdentifier("addTemplateExercise")
                .padding(.top, draft.items.isEmpty ? 0 : 2)
        }
    }

    private func binding(for id: UUID) -> Binding<EditorItem> {
        Binding(get: { draft.items.first { $0.id == id } ?? EditorItem(id: id, exerciseID: UUID(), repsBySet: []) },
                set: { new in if let i = draft.items.firstIndex(where: { $0.id == id }) { draft.items[i] = new } })
    }

    // MARK: Drag to reorder

    /// Where the lifted card would land (its index in the new order), or nil when nothing is dragged.
    private var dragTarget: Int? {
        guard let drag, let start = drag.frames[drag.id] else { return nil }
        let center = start.midY + drag.translation
        return draft.items.filter { $0.id != drag.id }
            .filter { (drag.frames[$0.id]?.midY ?? .infinity) < center }.count
    }

    /// The lifted card follows the finger; the cards it passes move by one card to open its gap.
    private func displacement(for id: UUID, at index: Int) -> CGFloat {
        guard let drag else { return 0 }
        if id == drag.id { return drag.translation }
        guard let to = dragTarget, let lifted = drag.frames[drag.id] else { return 0 }
        let pitch = lifted.height + Self.seam
        if drag.from < to, index > drag.from, index <= to { return -pitch }
        if to < drag.from, index >= to, index < drag.from { return pitch }
        return 0
    }

    private func dragGesture(for id: UUID) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named(Self.stackSpace))
            .onChanged { value in
                if drag == nil, let from = draft.items.firstIndex(where: { $0.id == id }) {
                    panels = [:]
                    lifts += 1
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.18)) {
                        drag = CardDrag(id: id, from: from, translation: 0, frames: cardFrames)
                    }
                }
                drag?.translation = value.translation.height
            }
            .onEnded { _ in drop() }
    }

    private func drop() {
        guard let current = drag else { return }
        let to = dragTarget ?? current.from
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
            if to != current.from {
                draft.items = Self.moving(draft.items, from: current.from, to: to)
            }
            drag = nil
        }
    }

    /// Moves one card (drag and the VoiceOver Move up / Move down actions share this rule, D48):
    /// a card that lands beside a member of its own superset stays in it — reordering A and B
    /// keeps the pair; dragged away from its group, the exercise travels alone.
    static func moving(_ items: [EditorItem], from: Int, to: Int) -> [EditorItem] {
        guard items.indices.contains(from), from != to else { return items }
        var result = items
        var moved = result.remove(at: from)
        let index = min(max(0, to), result.count)
        if let group = moved.supersetGroupID {
            let before = index > 0 ? result[index - 1].supersetGroupID : nil
            let after = index < result.count ? result[index].supersetGroupID : nil
            if before != group && after != group { moved.supersetGroupID = nil }
        }
        result.insert(moved, at: index)
        return normalizedSupersets(result)
    }

    /// Superset groups stay contiguous runs of two or more (D48); anything else is split.
    static func normalizedSupersets(_ items: [EditorItem]) -> [EditorItem] {
        var result = items
        var seen: Set<UUID> = []
        var i = 0
        while i < result.count {
            guard let group = result[i].supersetGroupID else { i += 1; continue }
            var j = i
            while j + 1 < result.count, result[j + 1].supersetGroupID == group { j += 1 }
            let newGroup: UUID? = j > i ? (seen.contains(group) ? UUID() : group) : nil
            for k in i...j { result[k].supersetGroupID = newGroup }
            seen.insert(group)
            i = j + 1
        }
        return result
    }

    private func move(_ id: UUID, by offset: Int) {
        guard let from = draft.items.firstIndex(where: { $0.id == id }) else { return }
        let to = from + offset
        guard draft.items.indices.contains(to) else { return }
        withAnimation(reduceMotion ? nil : .snappy) {
            draft.items = Self.moving(draft.items, from: from, to: to)
        }
    }

    // MARK: Supersets

    private func isLinked(after index: Int) -> Bool {
        guard draft.items.indices.contains(index + 1), let group = draft.items[index].supersetGroupID else { return false }
        return draft.items[index + 1].supersetGroupID == group
    }

    /// The seam between two cards: a chain link that binds them into a superset (A, B…), or
    /// splits them again. Linked, the link fills and bridges the two cards.
    private func supersetLink(after index: Int) -> some View {
        let linked = isLinked(after: index)
        return Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.72)) { toggleSuperset(after: index) }
            links += 1
        } label: {
            ZStack {
                if linked { Rectangle().fill(look.done).frame(width: 4) }
                Image(systemName: "link")
                    .font(.system(.caption, weight: .heavy))
                    .foregroundStyle(linked ? look.onDone : look.textTertiary)
                    .frame(width: 30, height: 30)
                    .background { Circle().fill(linked ? look.done : look.ground) }
                    .overlay {
                        if !linked { Circle().strokeBorder(look.dash, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2.5])) }
                    }
                    .scaleEffect(linked ? 1.08 : 1)
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(height: Self.seam)
        .frame(maxWidth: .infinity)
        .zIndex(1)
        .accessibilityLabel(linked ? "Break superset" : "Superset with next")
        .accessibilityAddTraits(linked ? .isSelected : [])
    }

    /// Binds item `index` and the next one into one superset run, or splits the run between them.
    private func toggleSuperset(after index: Int) {
        guard draft.items.indices.contains(index + 1) else { return }
        var items = draft.items
        if isLinked(after: index), let group = items[index].supersetGroupID {
            var head = index
            while head > 0, items[head - 1].supersetGroupID == group { head -= 1 }
            var tail = index + 1
            while tail + 1 < items.count, items[tail + 1].supersetGroupID == group { tail += 1 }
            if head == index { items[index].supersetGroupID = nil }
            let rest = (index + 1)...tail
            let newGroup: UUID? = rest.count > 1 ? UUID() : nil
            for i in rest { items[i].supersetGroupID = newGroup }
        } else {
            let group = items[index].supersetGroupID ?? items[index + 1].supersetGroupID ?? UUID()
            items[index].supersetGroupID = group
            if let old = items[index + 1].supersetGroupID, old != group {
                var j = index + 1
                while j < items.count, items[j].supersetGroupID == old { items[j].supersetGroupID = group; j += 1 }
            } else {
                items[index + 1].supersetGroupID = group
            }
        }
        draft.items = items
    }

    // MARK: Card

    private func itemCard(_ item: Binding<EditorItem>, letter: String?, lifted: Bool) -> some View {
        let value = item.wrappedValue
        let panel = panels[value.id]
        let ax = typeSize.isAccessibilitySize
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 4) {
                dragHandle(value)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(exercise(value.exerciseID)?.name ?? "Missing exercise")
                        .font(Font.system(.headline, weight: .heavy).width(.expanded))
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let letter {
                        TemplateSupersetTag(letter: letter)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.top, 12)
                .accessibilityElement(children: .combine)
                .accessibilityValue(TemplateTargets(repsBySet: value.repsBySet.map { $0 == 0 ? nil : $0 }).summary)
                Spacer(minLength: 8)
                // Default sizes: the rest chip shares the title line; AX sizes: it wraps under the pills.
                if !ax { restChip(item, open: panel == .rest).padding(.top, 5) }
                CardIconButton("minus.circle", accessibilityLabel: "Remove exercise") {
                    withAnimation(reduceMotion ? nil : .snappy) {
                        draft.items.removeAll { $0.id == value.id }
                        draft.items = Self.normalizedSupersets(draft.items)
                    }
                }
                .padding(.top, 6)
            }
            VStack(alignment: .leading, spacing: 12) {
                repPills(item, panel: panel)
                if ax { restChip(item, open: panel == .rest) }
                switch panel {
                case .set(let index) where index < value.repsBySet.count:
                    setAdjuster(item, index: index)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                case .rest:
                    restAdjuster(item)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                default:
                    EmptyView()
                }
            }
            .padding(.leading, 48)
        }
        .padding(.leading, 2)
        .padding(.trailing, 14)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
        // Lifted: it rises off the stack (Reduce Motion: an outline instead of the scale).
        .scaleEffect(lifted && !reduceMotion ? 1.03 : 1)
        .shadow(color: .black.opacity(lifted ? (look.isDark ? 0.5 : 0.18) : 0), radius: lifted ? 18 : 0, y: lifted ? 10 : 0)
        .overlay {
            if lifted {
                RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous)
                    .strokeBorder(look.textPrimary, lineWidth: 2)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Move up") { move(value.id, by: -1) }
        .accessibilityAction(named: "Move down") { move(value.id, by: 1) }
    }

    private func dragHandle(_ item: EditorItem) -> some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(.body, weight: .semibold))
            .foregroundStyle(drag?.id == item.id ? look.textPrimary : look.textSecondary)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .highPriorityGesture(dragGesture(for: item.id))
            .accessibilityLabel("Reorder")
    }

    private func repPills(_ item: Binding<EditorItem>, panel: CardPanel?) -> some View {
        let value = item.wrappedValue
        return TemplateFlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(Array(value.repsBySet.enumerated()), id: \.offset) { index, reps in
                let selected = panel == .set(index)
                Button {
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
                        panels[value.id] = selected ? nil : .set(index)
                    }
                } label: {
                    TemplateRepPill(reps: reps, selected: selected)
                }
                .buttonStyle(.lookPressable)
                .accessibilityLabel("Set \(index + 1)")
                .accessibilityValue(reps == 0 ? "No target" : "\(reps) reps")
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: item.wrappedValue.repsBySet[index] = min(100, reps + 1)
                    case .decrement: item.wrappedValue.repsBySet[index] = max(0, reps - 1)
                    @unknown default: break
                    }
                }
            }
            Button {
                // Copies the last slot as it is, "no target" included (the old stepper's rule).
                let last = value.repsBySet.last ?? 10
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
                    item.wrappedValue.repsBySet.append(last)
                    panels[value.id] = nil
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(value.repsBySet.count < 12 ? look.textPrimary : look.textTertiary)
                    .frame(minWidth: 44, minHeight: 44)
                    .dashedOutline(look.dash, radius: look.radius.field + 2)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.lookPressable)
            .disabled(value.repsBySet.count >= 12)
            .accessibilityLabel("Add Set")
        }
    }

    private func setAdjuster(_ item: Binding<EditorItem>, index: Int) -> some View {
        let binding = Binding<Int>(
            get: { item.wrappedValue.repsBySet.indices.contains(index) ? item.wrappedValue.repsBySet[index] : 0 },
            set: { if item.wrappedValue.repsBySet.indices.contains(index) { item.wrappedValue.repsBySet[index] = $0 } })
        let count = item.wrappedValue.repsBySet.count
        // AX sizes: the set label sits above its stepper instead of squeezing it.
        let ax = typeSize.isAccessibilitySize
        return (ax ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(spacing: 10))) {
            Text("Set \(index + 1)")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(look.textSecondary)
                .fixedSize()
            HStack(spacing: 10) {
                NumberStepperPill(value: binding, range: 0...100) { $0 == 0 ? "—" : LookFormat.reps($0) }
                Spacer(minLength: 0)
                Button {
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
                        item.wrappedValue.repsBySet.remove(at: index)
                        panels[item.wrappedValue.id] = nil
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(count > 1 ? look.textPrimary : look.textTertiary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.lookPressable)
                .disabled(count <= 1)
                .accessibilityLabel("Remove set")
            }
        }
    }

    // MARK: Rest

    /// The rest a row gets with no planned rest: the exercise's own working rest, else the
    /// global working default (the order `RestTimerService.durationSeconds` applies).
    private func fallbackRest(_ item: EditorItem) -> Int {
        let override = restOverrides.filter { $0.exerciseID == item.exerciseID }.canonical?.workingRestSeconds
        return override ?? AppPreferences.canonical(of: allPreferences)?.globalWorkingRestSeconds ?? 120
    }

    /// The card's rest as a chip: the time, solid when the template sets it, dashed and quiet
    /// when it follows the exercise's default. Tapping opens the adjuster in the card.
    private func restChip(_ item: Binding<EditorItem>, open: Bool) -> some View {
        let value = item.wrappedValue
        let isDefault = value.restSeconds == nil
        let seconds = value.restSeconds ?? fallbackRest(value)
        return Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) { panels[value.id] = open ? nil : .rest }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "timer").font(.system(.footnote, weight: .bold))
                Text(Format.duration(seconds: seconds)).monospacedDigit()
            }
            .font(.system(.subheadline, weight: .bold))
            .foregroundStyle(open ? look.onDone : (isDefault ? look.textSecondary : look.textPrimary))
            .padding(.horizontal, 11)
            .frame(minHeight: 34)
            .background { Capsule().fill(open ? look.selection : (isDefault ? Color.clear : look.controlFill)) }
            .overlay {
                if isDefault && !open {
                    Capsule().strokeBorder(look.dash, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.lookPressable)
        .fixedSize()
        .accessibilityLabel("Rest")
        .accessibilityValue(isDefault ? "Default, \(Format.duration(seconds: seconds))" : Format.duration(seconds: seconds))
        .accessibilityAddTraits(open ? .isSelected : [])
        .accessibilityIdentifier("templateRest")
    }

    /// "Default" (the exercise's own rest) or a time for this template, 0:00 to 10:00 in 15 s steps
    /// (the range the old editor allowed).
    private func restAdjuster(_ item: Binding<EditorItem>) -> some View {
        let value = item.wrappedValue
        let fallback = fallbackRest(value)
        let seconds = Binding<Int>(
            get: { item.wrappedValue.restSeconds ?? fallback },
            set: { item.wrappedValue.restSeconds = $0 })
        let ax = typeSize.isAccessibilitySize
        return (ax ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 10))) {
            Chip("Default", isSelected: value.restSeconds == nil) {
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) { item.wrappedValue.restSeconds = nil }
            }
            .accessibilityValue(Format.duration(seconds: fallback))
            .accessibilityIdentifier("templateRestDefault")
            NumberStepperPill(value: seconds, range: 0...600, step: 15) { Format.duration(seconds: $0) }
                .opacity(value.restSeconds == nil ? 0.6 : 1)
                .accessibilityIdentifier("templateRestStepper")
            if !ax { Spacer(minLength: 0) }
        }
    }

    // MARK: Cardio

    private var cardioBlock: some View {
        VStack(alignment: .leading, spacing: look.space.header) {
            SectionHeader("Cardio targets")
            ForEach($draft.cardio) { $plan in
                cardioCard($plan)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.95).combined(with: .opacity))
            }
            TemplateMakeRow(title: "Add Cardio Target") {
                let preference = AppPreferences.canonical(of: allPreferences)
                let unit = AppUnitSystem.resolve(preference: preference?.unitPreference).distanceUnit
                let plan = PlannedCardio(activity: CardioActivity.allCases[0], minutes: 15, unit: unit)
                withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82)) { draft.cardio.append(plan) }
            }
            .disabled(draft.cardio.count >= 3)
        }
    }

    private func cardioCard(_ plan: Binding<PlannedCardio>) -> some View {
        let value = plan.wrappedValue
        let distanceOn = Binding<Bool>(
            get: { plan.wrappedValue.distance != nil },
            set: { plan.wrappedValue.distance = $0 ? 1 : nil })
        let unitIndex = Binding<Int>(
            get: { CardioDistanceUnit.allCases.firstIndex(of: plan.wrappedValue.unit) ?? 0 },
            set: { plan.wrappedValue.unit = CardioDistanceUnit.allCases[$0] })
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Menu {
                    ForEach(CardioActivity.allCases) { activity in
                        Button { plan.wrappedValue.activity = activity } label: { Label(activity.name, systemImage: activity.symbol) }
                    }
                } label: {
                    HStack(spacing: 10) {
                        IconDisc(symbol: value.activity.symbol, size: 38, context: .onSurface)
                            .background { Circle().fill(look.surfaceRaised) }
                        Text(value.activity.name)
                            .font(Font.system(.headline, weight: .heavy).width(.expanded))
                            .foregroundStyle(look.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(.caption, weight: .bold))
                            .foregroundStyle(look.textSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("Activity")
                .accessibilityValue(value.activity.name)
                Spacer(minLength: 8)
                CardIconButton("minus.circle", accessibilityLabel: "Remove cardio") {
                    withAnimation(reduceMotion ? nil : .snappy) { draft.cardio.removeAll { $0.id == value.id } }
                }
            }
            HStack(spacing: 10) {
                Image(systemName: "timer").font(.system(.subheadline, weight: .semibold)).foregroundStyle(look.textSecondary)
                NumberStepperPill(value: plan.minutes, range: 1...180) { "\($0) min" }
                Spacer(minLength: 0)
            }
            LookDivider()
            Toggle(isOn: distanceOn.animation(reduceMotion ? nil : .snappy)) {
                Text("Distance target").font(.system(.subheadline, weight: .semibold)).foregroundStyle(look.textPrimary)
            }
            .toggleStyle(.look)
            if value.distance != nil {
                let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                                                          : AnyLayout(HStackLayout(spacing: 10))
                layout {
                    TextField("Distance", value: plan.distance, format: .number,
                              prompt: Text("Distance").foregroundStyle(look.textTertiary))
                        .keyboardType(.decimalPad)
                        .font(look.font.fieldNumber)
                        .foregroundStyle(look.textPrimary)
                        .tint(look.actionText)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .lookSurface(.field)
                    SegmentedPills(CardioDistanceUnit.allCases.map(\.rawValue), selection: unitIndex)
                        .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : 140)
                }
                .transition(.opacity)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
    }
}

// MARK: - Exercise picker

/// Search, grouped by body area head to toe. Tapping a row adds it (3 × 10) and keeps the
/// picker open so several can be added; added ones carry a check.
struct TemplateExercisePicker: View {
    var exercises: [Exercise]
    var addedCounts: [UUID: Int]
    var onAdd: (UUID) -> Void
    @Environment(\.look) private var look
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var adds = 0
    @State private var local: [UUID: Int] = [:]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    SearchFieldView(text: $query, prompt: "Search exercises")
                    ForEach(sections, id: \.title) { section in
                        LookList(header: section.title) {
                            ForEach(section.exercises) { exercise in row(exercise) }
                        }
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
            .lookScreenBackground()
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("templatePickerDone")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.impact(weight: .light), trigger: adds)
        .onAppear { local = addedCounts }
    }

    private struct Section {
        var title: String
        var exercises: [Exercise]
    }

    /// Body areas head to toe (`BodyArea.order`), then any other group, then Uncategorized.
    private var sections: [Section] {
        let tokens = CatalogBrowsing.tokens(query)
        let matching = exercises.filter { CatalogBrowsing.matches(CatalogBrowsing.normalize($0.name), tokens: tokens) }
        let grouped = Dictionary(grouping: matching) { $0.muscleGroup ?? "" }
        let known = BodyArea.order.filter { grouped[$0] != nil }
        let others = grouped.keys.filter { !$0.isEmpty && !BodyArea.order.contains($0) }.sorted()
        var result = (known + others).map { Section(title: $0, exercises: grouped[$0] ?? []) }
        if let none = grouped[""], !none.isEmpty { result.append(Section(title: "Uncategorized", exercises: none)) }
        return result
    }

    private func row(_ exercise: Exercise) -> some View {
        let count = local[exercise.id] ?? 0
        let subtitle: String? = exercise.loadType == .weighted
            ? exercise.equipmentTypeTags.first(where: { $0 != .machine })?.label
            : exercise.loadType.badge
        return LookRow(exercise.name, subtitle: subtitle, showsChevron: false, action: {
            adds += 1
            local[exercise.id, default: 0] += 1
            onAdd(exercise.id)
        }) {
            HStack(spacing: 4) {
                if count > 1 {
                    Text("\(count)").font(.system(.subheadline, weight: .bold)).monospacedDigit()
                        .foregroundStyle(look.textSecondary)
                }
                Image(systemName: count > 0 ? "checkmark.circle.fill" : "plus.circle")
                    .font(.system(.title3, weight: .semibold))
                    .foregroundStyle(count > 0 ? look.done : look.textSecondary)
                    .contentTransition(.symbolEffect(.replace))
                    .celebrate(count)
            }
        }
        .accessibilityLabel(exercise.name)
        .accessibilityValue(count > 0 ? "Added" : "")
    }
}
