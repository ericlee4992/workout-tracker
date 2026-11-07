import SwiftUI

// PROTOTYPE — T02: New / Edit Template. It was a stock Form: a title hidden by an Edit button,
// 4 + N steppers per exercise and a 90-row "Add Exercise" wall. Now: the name with a live
// family strip and summary; one compact card per exercise: a drag handle (drag to reorder, the
// other cards part to make room), the name, a rest chip and remove on one line, then the rep
// targets as number pills (tap one to adjust it, + adds a set). Tapping the rest chip opens its
// adjuster in the card (Default or a time). "Add Exercise" opens a searchable picker grouped by
// body area; cardio targets are compact cards. Cancel asks before discarding edits (swipe-down
// too). Save stays disabled until there is a name and something to do.
//
// Capture variants (`-screen T02 -variant …`): new, set (set 2 open), rest (rest adjuster open),
// drag (a card mid-drag), discard (Cancel after an edit), unlink (the superset just broken),
// cardio (a cardio target with a distance), long (a long name), picker (Add Exercise open), p2/p3.

struct TemplateEditorSheet: View {
    let templateID: UUID?
    @Environment(Router.self) private var router

    // The capture override (`-axl YES`) wraps the content, so the content's own
    // `dynamicTypeSize` reads (title placement, stacked rows) see it too.
    var body: some View {
        TemplatesEditorContent(templateID: templateID)
            .modifier(TemplatesTypeOverride(size: router.dynamicTypeOverride))
    }
}

/// What a card has open below its pills: one set's stepper, or the rest adjuster.
enum TemplatesCardPanel: Hashable {
    case set(Int)
    case rest
}

/// A card being dragged by its handle: where it started and how far it has moved.
struct TemplatesDrag: Equatable {
    var id: UUID
    var from: Int
    var translation: CGFloat
    /// Card frames when the drag began (the stack's coordinate space).
    var frames: [UUID: CGRect]
}

struct TemplatesEditorContent: View {
    let templateID: UUID?
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.look) private var look
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var draft = Template(id: UUID(), name: "", items: [])
    @State private var original = Template(id: UUID(), name: "", items: [])
    @State private var loaded = false
    @State private var isNew = true
    @State private var confirmDiscard = false
    @State private var showPicker = false
    @State private var panels: [UUID: TemplatesCardPanel] = [:]
    @State private var links = 0
    @State private var drag: TemplatesDrag?
    @State private var cardFrames: [UUID: CGRect] = [:]
    @State private var lifts = 0
    @FocusState private var nameFocused: Bool

    private static let stackSpace = "templatesEditorCards"
    /// The seam between two cards (the superset link).
    private static let seam: CGFloat = 24

    private var sheetTitle: String { isNew ? "New Template" : "Edit Template" }
    private var trimmedName: String { draft.name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isDirty: Bool { loaded && draft != original }
    private var cardioValid: Bool {
        draft.cardio.allSatisfy { plan in
            (1...180).contains(plan.minutes) && (plan.distance.map { $0 > 0 && $0 <= 200 } ?? true)
        }
    }
    private var canSave: Bool {
        !trimmedName.isEmpty && (!draft.items.isEmpty || !draft.cardio.isEmpty) && cardioValid
    }
    private var variant: String? { store.currentScreen == .t02 ? router.variant : nil }

    var body: some View {
        VStack(spacing: 0) {
            // AX sizes: the title leaves the bar (it would truncate between the buttons) and
            // becomes the first line of the content.
            SheetHeader(cancel: cancel, title: typeSize.isAccessibilitySize ? "" : sheetTitle, commit: save,
                        commitEnabled: canSave)
            if loaded { editor }
            Spacer(minLength: 0)
        }
        .lookSheetGround()
        .presentationDetents([.large])
        .interactiveDismissDisabled(isDirty)
        // A centred alert (like Delete Template): iOS 26 draws a confirmation dialog as a popover
        // over the sheet's title.
        .alert("Discard changes?", isPresented: $confirmDiscard) {
            Button("Discard Changes", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) {}
        }
        .sheet(isPresented: $showPicker) {
            TemplatesExercisePickerSheet(addedCounts: addedCounts) { id in addExercise(id) }
                .look(look)
                .modifier(TemplatesTypeOverride(size: router.dynamicTypeOverride))
        }
        .onAppear(perform: load)
        .sensoryFeedback(.impact(weight: .medium), trigger: links)
        .sensoryFeedback(.impact(weight: .medium), trigger: lifts)
        .sensoryFeedback(.selection, trigger: dragTarget)
    }

    private func load() {
        guard !loaded else { return }
        // `-screen T02 -variant new` opens the empty New Template state.
        let asNew = variant == "new"
        let existing = asNew ? nil : store.template(templateID)
        isNew = existing == nil
        draft = existing ?? store.newTemplateDraft()
        original = draft
        loaded = true
        if isNew {
            // Focus once the sheet has risen; again a beat later in case the first came before it
            // could take focus (a slow launch), so the keyboard is always up for a new template.
            for delay in [0.45, 1.2] { DispatchQueue.main.asyncAfter(deadline: .now() + delay) { if !nameFocused { nameFocused = true } } }
        }
        applyVariant()
    }

    private func applyVariant() {
        guard let variant, let first = draft.items.first else { return }
        switch variant {
        case "set" where first.targetReps.count > 1:
            panels[first.id] = .set(1)
        case "rest":
            panels[first.id] = .rest
        case "long":
            draft.name = "Upper Body Power — Chest, Shoulders and Arms"
        case "discard":
            draft.items[0].targetReps[0] = 10
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { confirmDiscard = true }
        case "picker":
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showPicker = true }
        case "cardio":
            if !draft.cardio.isEmpty { draft.cardio[0].distance = 2 }
        case "drag":
            // A card mid-drag: the first card lifted and carried down past the second, which
            // has moved up to make room.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                guard draft.items.count > 2, let a = cardFrames[draft.items[0].id], let b = cardFrames[draft.items[1].id]
                else { return }
                lifts += 1
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.3)) {
                    drag = TemplatesDrag(id: draft.items[0].id, from: 0, translation: b.midY - a.midY + 16, frames: cardFrames)
                }
            }
        default:
            break
        }
    }

    private func cancel() {
        if isDirty { confirmDiscard = true } else { dismiss() }
    }

    private func save() {
        guard canSave else { return }
        var t = draft
        t.name = trimmedName
        store.saveTemplate(t)
        dismiss()
    }

    private var addedCounts: [UUID: Int] {
        Dictionary(draft.items.map { ($0.exerciseID, 1) }, uniquingKeysWith: +)
    }

    private func addExercise(_ exerciseID: UUID) {
        let item = store.newTemplateItem(exerciseID: exerciseID)
        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82)) { draft.items.append(item) }
    }

    // MARK: Editor

    private var editor: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if typeSize.isAccessibilitySize {
                        Text(sheetTitle)
                            .font(look.font.title2)
                            .foregroundStyle(look.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                            .padding(.bottom, -14)
                    }
                    nameBlock
                    exercisesBlock
                    cardioBlock
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 10)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .scrollDisabled(drag != nil)
            .modifier(TemplatesVariantScroll(variant: variant, active: variant != nil))
            .onAppear {
                // Variants whose state sits further down scroll it into view.
                switch variant {
                case "unlink":
                    guard draft.items.count > 4 else { return }
                    let target = draft.items[3].id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { proxy.scrollTo(target, anchor: .center) }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { tapLink(after: 3) }
                case "cardio":
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { proxy.scrollTo("cardio", anchor: .bottom) }
                default:
                    break
                }
            }
        }
    }

    // MARK: Name

    private var nameBlock: some View {
        let families = store.templatesFamilies(items: draft.items)
        return VStack(alignment: .leading, spacing: 12) {
            // A long name (or AccessibilityL) wraps instead of scrolling out of sight; Return ends editing.
            TextField("Template name", text: TemplatesSingleLine.binding($draft.name, onReturn: { nameFocused = false }),
                      prompt: Text("Template name").foregroundStyle(look.textTertiary), axis: .vertical)
                .lineLimit(1...3)
                .font(look.font.title2)
                .foregroundStyle(look.textPrimary)
                .tint(look.actionText)
                .focused($nameFocused)
                .submitLabel(.done)
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
                    .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.6), value: families.contains(family))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(families.isEmpty ? "No muscle groups yet" : families.map(\.label).joined(separator: ", "))
    }

    @ViewBuilder private var summary: some View {
        if !draft.templatesSummary.isEmpty {
            Text(draft.templatesSummary)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(look.textSecondary)
                .contentTransition(.numericText())
                .animation(.snappy, value: draft.setCount)
        }
    }

    // MARK: Exercises

    private var exercisesBlock: some View {
        let letters = Derived.supersetLabels(groups: draft.items.map(\.supersetGroup))
        let letterByID = Dictionary(zip(draft.items.map(\.id), letters).compactMap { id, l in l.map { (id, $0) } },
                                    uniquingKeysWith: { a, _ in a })
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
                    .id(item.id)
                    .transition(reduceMotion ? .opacity : .asymmetric(insertion: .scale(scale: 0.94).combined(with: .opacity),
                                                                       removal: .opacity))
                }
            }
            .coordinateSpace(.named(Self.stackSpace))
            .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: dragTarget)
            TemplatesMakeRow(title: "Add Exercise") { showPicker = true }
                .padding(.top, draft.items.isEmpty ? 0 : 2)
        }
    }

    private func binding(for id: UUID) -> Binding<TemplateItem> {
        Binding(get: { draft.items.first { $0.id == id } ?? TemplateItem(id: id, exerciseID: UUID(), targetReps: []) },
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
                        drag = TemplatesDrag(id: id, from: from, translation: 0, frames: cardFrames)
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
                var items = draft.items
                var moved = items.remove(at: current.from)
                // Dragged out of (or into) a superset: the exercise travels alone.
                moved.supersetGroup = nil
                items.insert(moved, at: to)
                draft.items = Self.normalizedSupersets(items)
            }
            drag = nil
        }
    }

    /// Superset groups stay contiguous runs of two or more; anything else is split.
    static func normalizedSupersets(_ items: [TemplateItem]) -> [TemplateItem] {
        var result = items
        var seen: Set<UUID> = []
        var i = 0
        while i < result.count {
            guard let g = result[i].supersetGroup else { i += 1; continue }
            var j = i
            while j + 1 < result.count, result[j + 1].supersetGroup == g { j += 1 }
            let newGroup: UUID? = j > i ? (seen.contains(g) ? UUID() : g) : nil
            for k in i...j { result[k].supersetGroup = newGroup }
            seen.insert(g)
            i = j + 1
        }
        return result
    }

    private func move(_ id: UUID, by offset: Int) {
        guard let from = draft.items.firstIndex(where: { $0.id == id }) else { return }
        let to = from + offset
        guard draft.items.indices.contains(to) else { return }
        withAnimation(.snappy) {
            draft.items.swapAt(from, to)
            draft.items = Self.normalizedSupersets(draft.items)
        }
    }

    // MARK: Supersets

    private func isLinked(after index: Int) -> Bool {
        guard draft.items.indices.contains(index + 1), let g = draft.items[index].supersetGroup else { return false }
        return draft.items[index + 1].supersetGroup == g
    }

    private func tapLink(after index: Int) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.72)) { toggleSuperset(after: index) }
        links += 1
    }

    /// The seam between two cards: a chain link that binds them into a superset (A, B…), or
    /// splits them again. Linked, the link fills and bridges the two cards.
    private func supersetLink(after index: Int) -> some View {
        let linked = isLinked(after: index)
        return Button { tapLink(after: index) } label: {
            ZStack {
                if linked {
                    Rectangle().fill(look.done).frame(width: 4)
                }
                Image(systemName: "link")
                    .font(.system(.caption, weight: .heavy))
                    .foregroundStyle(linked ? look.onDone : look.textTertiary)
                    .frame(width: 30, height: 30)
                    .background { Circle().fill(linked ? look.done : look.groundSheet) }
                    .overlay {
                        if !linked {
                            Circle().strokeBorder(look.id.isPaperClub ? look.textSecondary : look.dash,
                                                  style: StrokeStyle(lineWidth: 1.5, dash: [3, 2.5]))
                        }
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
        if isLinked(after: index), let g = items[index].supersetGroup {
            var head = index
            while head > 0, items[head - 1].supersetGroup == g { head -= 1 }
            var tail = index + 1
            while tail + 1 < items.count, items[tail + 1].supersetGroup == g { tail += 1 }
            if head == index { items[index].supersetGroup = nil }
            let rest = (index + 1)...tail
            let newGroup: UUID? = rest.count > 1 ? UUID() : nil
            for i in rest { items[i].supersetGroup = newGroup }
        } else {
            let g = items[index].supersetGroup ?? items[index + 1].supersetGroup ?? UUID()
            items[index].supersetGroup = g
            if let old = items[index + 1].supersetGroup, old != g {
                var j = index + 1
                while j < items.count, items[j].supersetGroup == old { items[j].supersetGroup = g; j += 1 }
            } else {
                items[index + 1].supersetGroup = g
            }
        }
        draft.items = items
    }

    private var rowTitleFont: Font {
        switch look.id {
        case .floodlight: Font.system(.headline, weight: .heavy).width(.expanded)
        case .anatomy: .system(.headline, design: .rounded, weight: .bold)
        case .paper, .carbon: .system(.headline, design: .serif, weight: .heavy)
        }
    }

    // MARK: Card

    private func itemCard(_ item: Binding<TemplateItem>, letter: String?, lifted: Bool) -> some View {
        let value = item.wrappedValue
        let name = store.exercise(value.exerciseID)?.name ?? "Missing exercise"
        let panel = panels[value.id]
        let ax = typeSize.isAccessibilitySize
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 4) {
                dragHandle(value)
                // The name only: the pills below are the "N sets · r, r, r reps".
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(name)
                        .font(rowTitleFont)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let letter {
                        TemplatesSupersetTag(letter: letter)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.top, 12)
                .accessibilityElement(children: .combine)
                .accessibilityValue(Format.targets(value.targetReps))
                Spacer(minLength: 8)
                // Default sizes: the rest chip shares the title line; AX sizes: it wraps under the pills.
                if !ax { restChip(item, open: panel == .rest).padding(.top, 5) }
                CardIconButton(look.id == .floodlight ? "minus.circle" : "minus", accessibilityLabel: "Remove exercise") {
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
                case .set(let index) where index < value.targetReps.count:
                    setAdjuster(item, index: index)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                case .rest:
                    restAdjuster(item)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                default:
                    EmptyView()
                }
            }
            .padding(.leading, 44)
        }
        .padding(.leading, 4)
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
                    .strokeBorder(look.id.isPaperClub ? look.actionText : look.textPrimary, lineWidth: 2)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Move up") { move(value.id, by: -1) }
        .accessibilityAction(named: "Move down") { move(value.id, by: 1) }
    }

    private func dragHandle(_ item: TemplateItem) -> some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(.body, weight: .semibold))
            .foregroundStyle(drag?.id == item.id ? look.textPrimary : look.textSecondary)
            .frame(width: 40, height: 44)
            .contentShape(Rectangle())
            .highPriorityGesture(dragGesture(for: item.id))
            .accessibilityLabel("Reorder")
            .accessibilityHint("")
    }

    private func repPills(_ item: Binding<TemplateItem>, panel: TemplatesCardPanel?) -> some View {
        let value = item.wrappedValue
        return TemplatesFlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(Array(value.targetReps.enumerated()), id: \.offset) { index, reps in
                let selected = panel == .set(index)
                Button {
                    withAnimation(.snappy(duration: 0.22)) {
                        panels[value.id] = selected ? nil : .set(index)
                    }
                } label: {
                    TemplatesRepPill(reps: reps, style: selected ? .selected : .plain, large: true)
                }
                .buttonStyle(.lookPressable)
                .accessibilityLabel("Set \(index + 1)")
                .accessibilityValue(reps == 0 ? "No target" : Format.reps(reps))
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: item.wrappedValue.targetReps[index] = min(100, reps + 1)
                    case .decrement: item.wrappedValue.targetReps[index] = max(0, reps - 1)
                    @unknown default: break
                    }
                }
            }
            Button {
                let last = value.targetReps.last ?? 10
                withAnimation(.snappy(duration: 0.25)) {
                    item.wrappedValue.targetReps.append(last == 0 ? 10 : last)
                    panels[value.id] = nil
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(value.targetReps.count < 12 ? look.textPrimary : look.textTertiary)
                    .frame(minWidth: 44, minHeight: 44)
                    .dashedOutline(look.id.isPaperClub ? look.outline : look.dash, radius: look.radius.field + 2,
                                   lineWidth: look.id.isPaperClub ? 2 : 1.5)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.lookPressable)
            .disabled(value.targetReps.count >= 12)
            .accessibilityLabel("Add Set")
        }
    }

    private func setAdjuster(_ item: Binding<TemplateItem>, index: Int) -> some View {
        let binding = Binding<Int>(
            get: { item.wrappedValue.targetReps.indices.contains(index) ? item.wrappedValue.targetReps[index] : 0 },
            set: { if item.wrappedValue.targetReps.indices.contains(index) { item.wrappedValue.targetReps[index] = $0 } })
        let count = item.wrappedValue.targetReps.count
        // AX sizes: the set label sits above its stepper instead of squeezing it.
        let ax = typeSize.isAccessibilitySize
        return (ax ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(spacing: 10))) {
            Text("Set \(index + 1)")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(look.textSecondary)
                .fixedSize()
            HStack(spacing: 10) {
                NumberStepperPill(value: binding, range: 0...100) { $0 == 0 ? "—" : Format.reps($0) }
                Spacer(minLength: 0)
                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        item.wrappedValue.targetReps.remove(at: index)
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

    private func fallbackRest(_ item: TemplateItem) -> Int {
        store.restSettings(for: item.exerciseID).workingSeconds ?? store.settings.workingRestSeconds
    }

    /// The card's rest as a chip: the time, solid when the template sets it, dashed and quiet
    /// when it follows the exercise's default. Tapping opens the adjuster in the card.
    private func restChip(_ item: Binding<TemplateItem>, open: Bool) -> some View {
        let value = item.wrappedValue
        let isDefault = value.restSeconds == nil
        let seconds = value.restSeconds ?? fallbackRest(value)
        return Button {
            withAnimation(.snappy(duration: 0.22)) { panels[value.id] = open ? nil : .rest }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "timer").font(.system(.footnote, weight: .bold))
                Text(Format.rest(seconds)).monospacedDigit()
            }
            .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .bold))
            .foregroundStyle(open ? chipOnSelected : (isDefault ? look.textSecondary : look.textPrimary))
            .padding(.horizontal, 11)
            .frame(minHeight: 34)
            .background { Capsule().fill(open ? chipSelectedFill : (isDefault ? Color.clear : restChipFill)) }
            .overlay {
                if isDefault && !open {
                    Capsule().strokeBorder(look.id.isPaperClub ? look.outline : look.dash, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                } else if look.id.isPaperClub && !open {
                    Capsule().strokeBorder(look.outline, lineWidth: 1.5)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.lookPressable)
        .fixedSize()
        .accessibilityLabel("Rest")
        .accessibilityValue(isDefault ? "Default, \(Format.rest(seconds))" : Format.rest(seconds))
        .accessibilityAddTraits(open ? .isSelected : [])
    }

    private var restChipFill: Color { look.id.isPaperClub ? look.surface : look.controlFill }
    /// Open: the same "selected" treatment as a selected rep pill (A flood, B pearl, C cobalt).
    private var chipSelectedFill: Color { look.id.isPaperClub ? look.action : look.selection }
    private var chipOnSelected: Color { look.id.isPaperClub ? look.onAction : look.onDone }

    /// "Default" (the exercise's own rest) or a time for this template, 0:15 to 10:00.
    private func restAdjuster(_ item: Binding<TemplateItem>) -> some View {
        let value = item.wrappedValue
        let fallback = fallbackRest(value)
        let seconds = Binding<Int>(
            get: { item.wrappedValue.restSeconds ?? fallback },
            set: { item.wrappedValue.restSeconds = $0 })
        let ax = typeSize.isAccessibilitySize
        return (ax ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 10))) {
            Chip("Default", isSelected: value.restSeconds == nil) {
                withAnimation(.snappy(duration: 0.2)) { item.wrappedValue.restSeconds = nil }
            }
            .accessibilityValue(Format.rest(fallback))
            NumberStepperPill(value: seconds, range: 15...600, step: 15) { Format.rest($0) }
                .opacity(value.restSeconds == nil ? 0.6 : 1)
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
            TemplatesMakeRow(title: "Add Cardio Target") {
                let plan = PlannedCardio(id: UUID(), activity: .indoorWalk, minutes: 15, distance: nil, unit: store.distanceUnit)
                withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82)) { draft.cardio.append(plan) }
            }
            .disabled(draft.cardio.count >= 3)
            .id("cardio")
        }
    }

    private func cardioCard(_ plan: Binding<PlannedCardio>) -> some View {
        let value = plan.wrappedValue
        let distanceOn = Binding<Bool>(
            get: { plan.wrappedValue.distance != nil },
            set: { plan.wrappedValue.distance = $0 ? 1 : nil })
        let unitIndex = Binding<Int>(
            get: { plan.wrappedValue.unit == .km ? 0 : 1 },
            set: { plan.wrappedValue.unit = $0 == 0 ? .km : .mi })
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Menu {
                    ForEach(CardioActivity.allCases) { activity in
                        Button { plan.wrappedValue.activity = activity } label: { Label(activity.name, systemImage: activity.symbol) }
                    }
                } label: {
                    HStack(spacing: 10) {
                        IconDisc(symbol: value.activity.symbol, size: 38, context: .onSurface)
                        Text(value.activity.name)
                            .font(rowTitleFont)
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
                CardIconButton(look.id == .floodlight ? "minus.circle" : "minus", accessibilityLabel: "Remove cardio") {
                    withAnimation(reduceMotion ? nil : .snappy) { draft.cardio.removeAll { $0.id == value.id } }
                }
            }
            HStack(spacing: 10) {
                Image(systemName: "timer").font(.system(.subheadline, weight: .semibold)).foregroundStyle(look.textSecondary)
                NumberStepperPill(value: plan.minutes, range: 1...180, step: 5) { "\($0) min" }
                Spacer(minLength: 0)
            }
            LookDivider()
            Toggle(isOn: distanceOn.animation(.snappy)) {
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
                    SegmentedPills(["km", "mi"], selection: unitIndex)
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

// MARK: - Exercise picker (inside the editor)

/// Search, grouped by body area head to toe. Tapping a row adds it (3 × 10) and keeps the
/// picker open so several can be added; added ones carry a check.
struct TemplatesExercisePickerSheet: View {
    var addedCounts: [UUID: Int]
    var onAdd: (UUID) -> Void
    @Environment(Store.self) private var store
    @Environment(\.look) private var look
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var adds = 0
    @State private var local: [UUID: Int] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Add Exercise")
                    .font(look.font.title2)
                    .foregroundStyle(look.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 12)
                GlassCapsuleButton("Done") { dismiss() }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 18)
            .padding(.bottom, 12)
            SearchFieldView(text: $query, prompt: "Search exercises")
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 12)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(store.exerciseSections(query: query), id: \.group) { section in
                        LookList(header: section.group?.label ?? "Uncategorized") {
                            ForEach(section.exercises) { exercise in row(exercise) }
                        }
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .lookSheetGround()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.impact(weight: .light), trigger: adds)
        .onAppear { local = addedCounts }
    }

    private func row(_ exercise: Exercise) -> some View {
        let count = local[exercise.id] ?? 0
        let subtitle: String? = exercise.loadType == .weighted ? exercise.tags.first(where: { $0 != .machine })?.label
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
        .accessibilityValue(count > 0 ? "Added" : "")
    }
}
