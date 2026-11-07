import SwiftUI

// PROTOTYPE — A05 "Edit session": one generated day. The name is the title (edit in place);
// its families and figures update live as exercises change. Exercises: drag to reorder (long
// press; VoiceOver "Move up" / "Move down"), swipe to remove, tap a card to open its sets / reps
// / rest steppers and its Remove control (one card at a time, so steppers never pile up). Every
// removal can be undone for a few seconds. "Add exercise" opens a searchable list of what the
// AI may use at this gym. Cardio blocks: activity menu, minutes, remove, "Add cardio".
// Edits apply live, as today; Back keeps them.

/// How the editor should open the first time it appears after a `-screen A05` launch
/// (a reference, so the pushed editor reads the values set just before the push).
@Observable
final class AIEditorLaunch {
    var page: Int?
    var expandsFirst = false
    var showsPicker = false
    /// Capture variant "pickerEmpty": the picker opens with this search.
    var pickerQuery = ""
    /// Capture variant "removed": the second exercise is removed on open (the undo bar shows).
    var removesSecond = false
}

/// Capture variant "pickerEmpty": the search the picker opens with (read once by the sheet).
enum AIPickerLaunch {
    static var query = ""
}

/// The last removal, so it can be undone: the day as it was before.
private struct AIRemoval: Equatable {
    var id = UUID()
    var name: String
    var before: AIRoutineDay
}

struct AIDayEditorView: View {
    let dayID: UUID
    var launch: AIEditorLaunch?
    var onBack: () -> Void

    @Environment(Store.self) private var store
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded: UUID?
    @State private var showsPicker = false
    @State private var launched = false
    @State private var pickerQuery = ""
    @State private var removal: AIRemoval?
    @FocusState private var nameFocused: Bool

    private var day: AIRoutineDay? { store.ai.days.first { $0.id == dayID } }

    var body: some View {
        Group {
            if let day { editor(day) } else { Color.clear }
        }
        .background(look.ground.ignoresSafeArea())
        .safeAreaBar(edge: .top) {
            AITopBar(title: "Edit session", showsSparkle: false, backLabel: "Your week", onBack: onBack)
        }
        .overlay(alignment: .bottom) {
            if let removal {
                AIUndoBar(name: removal.name) { undo(removal) }
                    .padding(.horizontal, look.space.margin)
                    .padding(.bottom, 8)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .id(removal.id)
                    .task(id: removal.id) {
                        try? await Task.sleep(for: .seconds(5))
                        if !Task.isCancelled, self.removal?.id == removal.id {
                            withAnimation(reduceMotion ? nil : .snappy) { self.removal = nil }
                        }
                    }
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: removal?.id)
        .sheet(isPresented: $showsPicker, onDismiss: { pickerQuery = "" }) {
            AIExercisePickerSheet(dayID: dayID, initialQuery: pickerQuery) { exerciseID in
                AIWeekEdits.edited = true
                store.aiAddItem(dayID: dayID, exerciseID: exerciseID)
                if let added = store.ai.days.first(where: { $0.id == dayID })?.items.last {
                    withAnimation(reduceMotion ? nil : .snappy) { expanded = added.id }
                }
            }
            // A sheet does not inherit the prototype's Dynamic Type override: re-apply it outside
            // the sheet's view so its own layout reads the AX size too.
            .modifier(AITypeOverride())
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { nameFocused = false }.fontWeight(.semibold)
            }
        }
    }

    // MARK: Editor

    private func editor(_ day: AIRoutineDay) -> some View {
        ScrollViewReader { proxy in
            List {
                header(day)
                    .aiEditorRow(top: 8, bottom: 14)
                SectionHeader("Strength")
                    .aiEditorRow(top: 8, bottom: 4)
                ForEach(Array(day.items.enumerated()), id: \.element.id) { index, item in
                    AIItemEditorRow(item: item, isExpanded: expanded == item.id,
                                    onToggle: { toggle(item.id) },
                                    onChange: { updated in update(day) { d in
                                        if let i = d.items.firstIndex(where: { $0.id == updated.id }) { d.items[i] = updated }
                                    } },
                                    onRemove: { remove(item.id) })
                        .aiEditorRow()
                        .accessibilityAction(named: "Move up") { move(index, by: -1, in: day) }
                        .accessibilityAction(named: "Move down") { move(index, by: 1, in: day) }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) { remove(item.id) } label: {
                                Label("Remove exercise", systemImage: "trash")
                            }
                            .tint(swipeTint)
                        }
                }
                .onMove { source, destination in
                    AIWeekEdits.edited = true
                    store.aiMoveItem(dayID: day.id, fromOffsets: source, toOffset: destination)
                }
                AIMakeRow(title: "Add exercise", symbol: "plus", isEnabled: day.items.count < 10,
                          limit: day.items.count >= 10 ? "10/10" : nil) {
                    nameFocused = false
                    showsPicker = true
                }
                .aiEditorRow(top: 5, bottom: 10)
                SectionHeader("Cardio")
                    .aiEditorRow(top: 20, bottom: 4)
                    .id("cardio")
                ForEach(day.cardio) { cardio in
                    AICardioEditorRow(cardio: cardio, options: store.aiCardioOptions,
                                      onChange: { updated in update(day) { d in
                                          if let i = d.cardio.firstIndex(where: { $0.id == updated.id }) { d.cardio[i] = updated }
                                      } },
                                      onRemove: { removeCardio(cardio) })
                        .aiEditorRow()
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                removeCardio(cardio)
                            } label: { Label("Remove cardio", systemImage: "trash") }
                                .tint(swipeTint)
                        }
                }
                if !store.aiCardioOptions.isEmpty {
                    Menu {
                        ForEach(store.aiCardioOptions) { activity in
                            Button(activity.name, systemImage: activity.aiSymbol) {
                                AIWeekEdits.edited = true
                                withAnimation(reduceMotion ? nil : .snappy) {
                                    store.aiAddCardio(dayID: day.id, activity: activity)
                                }
                            }
                        }
                    } label: {
                        AIMakeRowFace(title: "Add cardio", symbol: "plus", isEnabled: day.cardio.count < 3,
                                      limit: day.cardio.count >= 3 ? "3/3" : nil)
                    }
                    .disabled(day.cardio.count >= 3)
                    .aiEditorRow(top: 5, bottom: 24)
                    .id("end")
                } else {
                    Color.clear.frame(height: 24).aiEditorRow().id("end")
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 0)
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                guard !launched else { return }
                launched = true
                let page = launch?.page
                if launch?.expandsFirst == true { expanded = day.items.first?.id }
                let picker = launch?.showsPicker == true
                let query = launch?.pickerQuery ?? ""
                let removesSecond = launch?.removesSecond == true
                launch?.removesSecond = false
                launch?.page = nil
                launch?.expandsFirst = false
                launch?.showsPicker = false
                launch?.pickerQuery = ""
                if picker {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        pickerQuery = query
                        showsPicker = true
                    }
                }
                if removesSecond, day.items.count > 1 {
                    let id = day.items[1].id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { remove(id) }
                }
                if let page, page > 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        proxy.scrollTo(page >= 3 ? "end" : "cardio", anchor: page >= 3 ? .bottom : .center)
                    }
                }
            }
        }
    }

    // MARK: Header: name + live figures

    private func header(_ day: AIRoutineDay) -> some View {
        let families = store.aiFamilies(of: day)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                TextField("Session name", text: Binding(
                    get: { store.ai.days.first { $0.id == dayID }?.name ?? "" },
                    set: { name in
                        // Return ends editing (the field wraps, so it would otherwise add a line).
                        if name.contains("\n") { nameFocused = false }
                        update(day) { $0.name = name.replacingOccurrences(of: "\n", with: "") }
                    }), axis: .vertical)
                    .font(look.font.title2)
                    .foregroundStyle(look.textPrimary)
                    .focused($nameFocused)
                    .submitLabel(.done)
                Image(systemName: "pencil")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(look.textSecondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .lookSurface(.field, radius: look.radius.tile - 4)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 12) {
                    familyStrip(families)
                    Spacer(minLength: 4)
                    figures(day)
                }
                VStack(alignment: .leading, spacing: 10) {
                    familyStrip(families)
                    figures(day)
                }
            }
        }
    }

    private func familyStrip(_ families: [MuscleFamily]) -> some View {
        HStack(spacing: look.id.isPaperClub ? 4 : 1) {
            ForEach(families) { family in
                FamilySticker(family: family, lit: true, size: look.id.isPaperClub ? 30 : 32)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7), value: families)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(families.map(\.label).joined(separator: ", "))
    }

    private func figures(_ day: AIRoutineDay) -> some View {
        HStack(spacing: 12) {
            AIInlineFigure(number: day.items.count, label: day.items.count.aiPlural("exercise"), numberFont: look.font.fieldNumber)
            AIInlineFigure(number: day.setCount, label: day.setCount.aiPlural("set"), numberFont: look.font.fieldNumber)
            AIInlineFigure(number: day.estimatedMinutes, label: "min", numberFont: look.font.fieldNumber)
        }
        .animation(.snappy, value: day.setCount)
        .animation(.snappy, value: day.estimatedMinutes)
    }

    // MARK: Mutations (through the Store)

    private func update(_ day: AIRoutineDay, _ change: (inout AIRoutineDay) -> Void) {
        guard var current = store.ai.days.first(where: { $0.id == day.id }) else { return }
        change(&current)
        AIWeekEdits.edited = true
        store.aiUpdateDay(current)
    }

    private func move(_ index: Int, by offset: Int, in day: AIRoutineDay) {
        let target = index + offset
        guard day.items.indices.contains(target) else { return }
        AIWeekEdits.edited = true
        withAnimation(reduceMotion ? nil : .snappy) {
            store.aiMoveItem(dayID: day.id, fromOffsets: IndexSet(integer: index),
                             toOffset: offset > 0 ? target + 1 : target)
        }
    }

    private func undo(_ removal: AIRemoval) {
        withAnimation(reduceMotion ? nil : .snappy) {
            store.aiUpdateDay(removal.before)
            self.removal = nil
        }
    }

    private func removeCardio(_ cardio: PlannedCardio) {
        guard let before = store.ai.days.first(where: { $0.id == dayID }) else { return }
        AIWeekEdits.edited = true
        withAnimation(reduceMotion ? nil : .snappy) {
            store.aiRemoveCardio(dayID: dayID, cardioID: cardio.id)
            removal = AIRemoval(name: cardio.activity.name, before: before)
        }
    }

    private func toggle(_ id: UUID) {
        nameFocused = false
        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)) {
            expanded = expanded == id ? nil : id
        }
    }

    private func remove(_ id: UUID) {
        guard let before = store.ai.days.first(where: { $0.id == dayID }),
              let item = before.items.first(where: { $0.id == id }) else { return }
        AIWeekEdits.edited = true
        withAnimation(reduceMotion ? nil : .snappy) {
            if expanded == id { expanded = nil }
            store.aiRemoveItem(dayID: dayID, itemID: id)
            removal = AIRemoval(name: store.exercise(item.exerciseID)?.name ?? "Exercise", before: before)
        }
    }

    /// Swipe tile: A danger; B a raised graphite tile; C the ink slab (red means heart).
    private var swipeTint: Color {
        switch look.id {
        case .floodlight: look.destructive
        case .anatomy: look.surfaceRaised
        case .paper, .carbon: look.slab
        }
    }
}

// MARK: - Row insets

extension View {
    /// A clear, separator-free List row on the screen margins.
    fileprivate func aiEditorRow(top: CGFloat = 5, bottom: CGFloat = 5) -> some View {
        self
            .listRowInsets(EdgeInsets(top: top, leading: 20, bottom: bottom, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

// MARK: - Exercise row

private struct AIItemEditorRow: View {
    var item: AIRoutineItem
    var isExpanded: Bool
    var onToggle: () -> Void
    var onChange: (AIRoutineItem) -> Void
    var onRemove: () -> Void

    @Environment(Store.self) private var store
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var handle: CGFloat = 20

    /// Everything under the name lines up with it (one left edge inside the card).
    private var indent: CGFloat { handle + 12 }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(look.id == .floodlight ? look.textTertiary : look.textSecondary)
                    .frame(width: handle, alignment: .leading)
                    .frame(minHeight: 26)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.exercise(item.exerciseID)?.name ?? "Exercise")
                        .font(look.id.isPaperClub ? .system(.headline, design: .serif, weight: .heavy) : look.font.headline)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let equipment = store.aiEquipment(exerciseID: item.exerciseID),
                       equipment.label != store.exercise(item.exerciseID)?.name {
                        HStack(spacing: 5) {
                            LookIcon(equipment.symbol, style: .caption)
                            Text(equipment.label)
                        }
                        .font(look.font.footnote)
                        .foregroundStyle(look.textSecondary)
                    }
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.down")
                    .font(.system(.footnote, weight: .bold))
                    .foregroundStyle(look.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .frame(minHeight: 26)
                    .accessibilityHidden(true)
            }
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    steppers
                    AIRemoveButton(title: "Remove exercise", action: onRemove)
                }
                .padding(.top, 14)
                .padding(.leading, indent)
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                summary
                    .padding(.top, 10)
                    .padding(.leading, indent)
                    .transition(.opacity)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(look.surface, in: shape)
        .overlay { edge(shape) }
        .contentShape(shape)
        .onTapGesture(perform: onToggle)
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: isExpanded ? "Collapse" : "Edit sets, reps and rest", onToggle)
        .accessibilityAction(named: "Remove exercise", onRemove)
    }

    /// "3 sets × 10 reps · ⏳ 1:00": numbers big, words small. The × stays in every layout.
    private var summary: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 10) { setsTimesReps; restFigure }
            VStack(alignment: .leading, spacing: 6) { setsTimesReps; restFigure }
            VStack(alignment: .leading, spacing: 4) {
                AIInlineFigure(number: item.sets, label: item.sets.aiPlural("set"), numberFont: look.font.statNumber)
                HStack(alignment: .firstTextBaseline, spacing: 6) { times; repsFigure }
                restFigure
            }
        }
    }

    private var setsTimesReps: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            AIInlineFigure(number: item.sets, label: item.sets.aiPlural("set"), numberFont: look.font.statNumber)
            times
            repsFigure
        }
    }

    private var times: some View {
        Text("×").font(.system(.subheadline, weight: .semibold)).foregroundStyle(look.textSecondary)
            .fixedSize()
            .accessibilityHidden(true)
    }

    private var repsFigure: some View {
        AIInlineFigure(number: item.reps, label: item.reps.aiPlural("rep"), numberFont: look.font.statNumber)
    }

    private var restFigure: some View {
        HStack(spacing: 4) {
            Image(systemName: "hourglass").font(.system(.footnote, weight: .semibold))
            Text(Format.rest(item.restSeconds)).font(.system(.subheadline, weight: .semibold).monospacedDigit())
        }
        .foregroundStyle(look.textSecondary)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rest \(Format.rest(item.restSeconds))")
    }

    private var steppers: some View {
        VStack(alignment: .leading, spacing: 8) {
            stepperRow("Sets", value: item.sets, range: 1...10, step: 1, format: { "\($0)" }) { v in
                var i = item; i.sets = v; onChange(i)
            }
            stepperRow("Reps", value: item.reps, range: 1...50, step: 1, format: { "\($0)" }) { v in
                var i = item; i.reps = v; onChange(i)
            }
            stepperRow("Rest", value: item.restSeconds, range: 0...600, step: 15, format: Format.rest) { v in
                var i = item; i.restSeconds = v; onChange(i)
            }
        }
    }

    private func stepperRow(_ title: String, value: Int, range: ClosedRange<Int>, step: Int,
                            format: @escaping (Int) -> String, set: @escaping (Int) -> Void) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            Text(title)
                .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                .foregroundStyle(look.textSecondary)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            NumberStepperPill(value: Binding(get: { value }, set: set), range: range, step: step, format: format)
                .accessibilityLabel(title)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// C: collapsed cards can be tapped, so they carry the pressable outline; the open card is
    /// marked with the cobalt ring (C's selection). A / B: the open card gets the brighter edge.
    @ViewBuilder private func edge(_ shape: RoundedRectangle) -> some View {
        switch look.id {
        case .floodlight:
            shape.strokeBorder(isExpanded ? look.textPrimary.opacity(0.5) : look.hairline, lineWidth: isExpanded ? 1.5 : 1)
        case .anatomy:
            shape.strokeBorder(isExpanded ? look.textPrimary.opacity(0.35) : look.hairline, lineWidth: isExpanded ? 1.5 : 1)
        case .paper, .carbon:
            shape.strokeBorder(isExpanded ? look.actionText : look.outline, lineWidth: isExpanded ? 2.5 : look.stroke.pressable)
        }
    }
}

/// The remove control inside an opened card: A danger-coloured trash + verb; B no hue (text
/// colour + trash); C the destructive vocabulary — a double-ruled capsule with a solid trash disc.
private struct AIRemoveButton: View {
    var title: String
    var action: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .subheadline) private var disc: CGFloat = 24

    var body: some View {
        Button(action: action) {
            switch look.id {
            case .floodlight, .anatomy:
                HStack(spacing: 6) {
                    Image(systemName: "trash").font(.system(.subheadline, weight: .semibold))
                    Text(title).font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                }
                .foregroundStyle(look.destructive)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(look.id == .anatomy ? look.controlFill : look.surfaceRaised, in: Capsule())
                .contentShape(Capsule())
            case .paper, .carbon:
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                        .font(.system(size: disc * 0.46, weight: .bold))
                        .foregroundStyle(look.surface)
                        .frame(width: disc, height: disc)
                        .background(look.textPrimary, in: Circle())
                    Text(title).font(.system(.subheadline, weight: .bold))
                }
                .foregroundStyle(look.textPrimary)
                .padding(.leading, 7)
                .padding(.trailing, 16)
                .frame(minHeight: 44)
                .background(look.surface, in: Capsule())
                .overlay { Capsule().strokeBorder(look.outline, lineWidth: 2) }
                .overlay { Capsule().inset(by: 4.5).strokeBorder(look.outline, lineWidth: 1.5) }
                .contentShape(Capsule())
            }
        }
        .buttonStyle(.lookPressable)
    }
}

/// A compact remove control (cardio blocks): the trash glyph, never a bare ✕. A danger glyph;
/// B text colour on a quiet disc; C the destructive vocabulary — a solid trash disc inside a
/// double rule. 44 pt target; removal is undoable from the bar.
private struct AIRemoveIconButton: View {
    var accessibilityLabel: String
    var action: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 36

    var body: some View {
        Button(action: action) {
            Group {
                switch look.id {
                case .floodlight:
                    Image(systemName: "trash")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(look.destructive)
                        .frame(width: size, height: size)
                        .background(look.surfaceRaised, in: Circle())
                case .anatomy:
                    Image(systemName: "trash")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(look.textPrimary)
                        .frame(width: size, height: size)
                        .background(look.controlFill, in: Circle())
                case .paper, .carbon:
                    Image(systemName: "trash.fill")
                        .font(.system(size: size * 0.36, weight: .bold))
                        .foregroundStyle(look.surface)
                        .frame(width: size - 11, height: size - 11)
                        .background(look.textPrimary, in: Circle())
                        .frame(width: size, height: size)
                        .overlay { Circle().strokeBorder(look.outline, lineWidth: 1.5) }
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.lookPressable)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// "Lat Pulldown removed · Undo": a floating glass bar for five seconds after a removal.
private struct AIUndoBar: View {
    var name: String
    var undo: () -> Void
    @Environment(\.look) private var look

    var body: some View {
        HStack(spacing: 12) {
            Text("\(name) removed")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(look.textPrimary)
                .lineLimit(2)
            Spacer(minLength: 8)
            Button(action: undo) {
                Label("Undo", systemImage: "arrow.uturn.backward")
                    .font(.system(.subheadline, weight: .bold))
                    .foregroundStyle(look.textPrimary)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .overlay { Capsule().strokeBorder(look.textPrimary.opacity(look.id.isPaperClub ? 1 : 0.45), lineWidth: look.id.isPaperClub ? 2 : 1) }
                    .contentShape(Capsule())
            }
            .buttonStyle(.lookPressable)
        }
        .padding(.leading, 18)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: Capsule())
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Cardio row

private struct AICardioEditorRow: View {
    var cardio: PlannedCardio
    var options: [CardioActivity]
    var onChange: (PlannedCardio) -> Void
    var onRemove: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                stacked
            } else {
                // One line when the name fits whole; otherwise the stepper drops under it
                // (a name never wraps beside the stepper).
                ViewThatFits(in: .horizontal) { oneLine; stacked }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lookSurface(.panel)
    }

    private var oneLine: some View {
        HStack(spacing: 10) {
            activityMenu.fixedSize()
            Spacer(minLength: 4)
            minutes
            AIRemoveIconButton(accessibilityLabel: "Remove cardio", action: onRemove)
        }
    }

    private var stacked: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                activityMenu
                Spacer(minLength: 4)
                AIRemoveIconButton(accessibilityLabel: "Remove cardio", action: onRemove)
            }
            minutes
        }
    }

    private var minutes: some View {
        NumberStepperPill(value: Binding(get: { cardio.minutes }, set: { m in var c = cardio; c.minutes = m; onChange(c) }),
                          range: 5...180, step: 5) { "\($0) min" }
            .fixedSize()
            .accessibilityLabel("Minutes")
    }

    private var activityMenu: some View {
        let choices = options.contains(cardio.activity) ? options : [cardio.activity] + options
        return Menu {
            Picker("Activity", selection: Binding(get: { cardio.activity },
                                                  set: { a in var c = cardio; c.activity = a; onChange(c) })) {
                ForEach(choices) { activity in
                    Label(activity.name, systemImage: activity.aiSymbol).tag(activity)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: cardio.activity.aiSymbol)
                    .font(.system(.title3, weight: .semibold))
                    .frame(width: 28)
                Text(cardio.activity.name)
                    .font(.system(.subheadline, design: look.id == .anatomy ? .rounded : .default, weight: .semibold))
                    .multilineTextAlignment(.leading)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(.caption2, weight: .bold))
                    .foregroundStyle(look.textSecondary)
            }
            .foregroundStyle(look.textPrimary)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Activity, \(cardio.activity.name)")
    }
}

// MARK: - Make rows ("Add exercise", "Add cardio")

private struct AIMakeRow: View {
    var title: String
    var symbol: String
    var isEnabled = true
    var limit: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) { AIMakeRowFace(title: title, symbol: symbol, isEnabled: isEnabled, limit: limit) }
            .buttonStyle(.lookPressable)
            .disabled(!isEnabled)
    }
}

/// The dashed "make one" row. At its limit it goes quiet (faint dotted edge, dim label) and
/// shows the count that stops it ("10/10"), so the off state explains itself without a sentence.
private struct AIMakeRowFace: View {
    var title: String
    var symbol: String
    var isEnabled = true
    var limit: String?
    @Environment(\.look) private var look

    var body: some View {
        let radius = look.radius.row
        HStack(spacing: 8) {
            Image(systemName: symbol).font(.system(.body, weight: .bold))
            Text(title).font(look.id == .anatomy ? look.font.button : .system(.body, weight: .semibold))
            if let limit {
                Text(limit)
                    .font(.system(.footnote, weight: .bold).monospacedDigit())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .overlay { Capsule().strokeBorder(look.textTertiary, lineWidth: 1) }
                    .accessibilityLabel("limit reached, \(limit)")
            }
        }
        .foregroundStyle(isEnabled ? look.textPrimary : look.textTertiary)
        .frame(maxWidth: .infinity, minHeight: 52)
        .dashedOutline(isEnabled ? (look.id.isPaperClub ? look.outline : look.dash) : look.hairline, radius: radius,
                       lineWidth: isEnabled && look.id.isPaperClub ? 2 : 1.5, dash: isEnabled ? [5, 4] : [1.5, 4])
        .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

// MARK: - Exercise picker (Add exercise)

/// Eligible exercises at this gym not yet in the session, by muscle group, searchable. Each row
/// shows the machine (or free-weight equipment) it would use. Tap adds it (3 × 10, 1:00).
struct AIExercisePickerSheet: View {
    let dayID: UUID
    var initialQuery = ""
    var onPick: (UUID) -> Void
    @Environment(Store.self) private var store
    @Environment(\.look) private var look
    @Environment(\.dismiss) private var dismiss
    @State private var query: String
    @Environment(\.dynamicTypeSize) private var typeSize

    private var title: some View {
        Text("Add exercise")
            .font(look.font.navTitle)
            .foregroundStyle(look.textPrimary)
            .accessibilityAddTraits(.isHeader)
            .padding(.horizontal, typeSize.isAccessibilitySize ? 0 : 96)
    }

    init(dayID: UUID, initialQuery: String = "", onPick: @escaping (UUID) -> Void) {
        self.dayID = dayID
        self.initialQuery = initialQuery
        self.onPick = onPick
        _query = State(initialValue: initialQuery)
    }

    var body: some View {
        let sections = store.aiPickerSections(dayID: dayID, query: query)
        VStack(spacing: 0) {
            ZStack {
                if !typeSize.isAccessibilitySize { title }
                HStack {
                    GlassCapsuleButton("Cancel") { dismiss() }
                    Spacer()
                }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 14)
            .padding(.bottom, 10)
            if typeSize.isAccessibilitySize {
                // AX: the title leaves the bar and leads the sheet.
                title
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, look.space.margin)
                    .padding(.bottom, 10)
            }
            SearchFieldView(text: $query, prompt: "Search exercises")
                .padding(.horizontal, look.space.margin)
                .padding(.bottom, 8)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if sections.isEmpty {
                        EmptyStateView(symbol: "magnifyingglass", title: "No matches")
                            .padding(.top, 40)
                    }
                    ForEach(sections, id: \.title) { section in
                        LookList(header: section.title, separatorInset: 54) {
                            ForEach(section.exercises) { exercise in
                                let equipment = store.aiEquipment(exerciseID: exercise.id)
                                // The whole row adds; the plus is a quiet outlined mark (the
                                // action colour stays off list rows).
                                LookRow(exercise.name, subtitle: equipment?.label == exercise.name ? nil : equipment?.label, symbol: equipment?.symbol ?? "figure.strengthtraining.traditional",
                                        showsChevron: false, action: {
                                            onPick(exercise.id)
                                            dismiss()
                                        }) {
                                    Image(systemName: "plus.circle")
                                        .font(.system(.title3, weight: .regular))
                                        .foregroundStyle(look.textSecondary)
                                        .accessibilityHidden(true)
                                }
                                .accessibilityHint("Adds to this session")
                            }
                        }
                    }
                }
                .padding(.horizontal, look.space.margin)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            let launchQuery = AIPickerLaunch.query
            AIPickerLaunch.query = ""
            if query.isEmpty, !(initialQuery.isEmpty && launchQuery.isEmpty) {
                query = initialQuery.isEmpty ? launchQuery : initialQuery
            }
        }
        .lookSheetGround()
        .preferredColorScheme(look.colorScheme)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
