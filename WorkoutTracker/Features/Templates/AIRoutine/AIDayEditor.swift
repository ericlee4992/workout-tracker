import SwiftUI

/// A05 "Edit session" (Floodlight ticket 10): one generated day. The name is the title (edit in
/// place); its families and figures update live. Exercises: drag to reorder (VoiceOver "Move up" /
/// "Move down"), swipe to remove, tap a card to open its sets / reps / rest steppers and Remove (one
/// card at a time). Every removal can be undone for five seconds. "Add exercise" opens a searchable
/// list of what the AI may use at this gym. Cardio: activity menu, minutes, remove, "Add cardio".
/// Edits apply live, as before; Back keeps them.
struct AIDayEditor: View {
    let dayID: UUID
    var model: AIRoutineFlowModel
    /// What the AI was allowed to use (the sent request): the picker's list and the cardio menu.
    var options: [RoutineExerciseOption]
    var activities: [CardioActivity]
    var names: [UUID: String]
    var groups: [UUID: String]
    /// Machine label per exercise at the routine's gym (the equipment line).
    var machineLabels: [UUID: String]
    var onBack: () -> Void

    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded: UUID?
    @State private var showsPicker = false
    @State private var removal: Removal?
    @FocusState private var nameFocused: Bool

    private struct Removal: Equatable {
        var id = UUID()
        var name: String
        var before: AIRoutineDay
    }

    var body: some View {
        Group {
            if let day = model.day(dayID) { editor(day) } else { Color.clear }
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
        .sheet(isPresented: $showsPicker) {
            AIExercisePickerSheet(options: available, groups: groups, machineLabels: machineLabels) { exerciseID in
                add(exerciseID)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { nameFocused = false }.fontWeight(.semibold)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    /// Eligible exercises not yet in the session.
    private var available: [RoutineExerciseOption] {
        let used = Set(model.day(dayID)?.strength.map(\.exerciseID) ?? [])
        return options.filter { !used.contains($0.id) }
    }

    // MARK: Editor

    private func editor(_ day: AIRoutineDay) -> some View {
        List {
            header(day).editorRow(top: 8, bottom: 14)
            SectionHeader("Strength").editorRow(top: 8, bottom: 4)
            ForEach(Array(day.strength.enumerated()), id: \.element.id) { index, item in
                AIItemEditorRow(item: item, name: names[item.exerciseID] ?? "Exercise",
                                equipment: equipmentLine(item.exerciseID),
                                isExpanded: expanded == item.id,
                                onToggle: { toggle(item.id) },
                                onChange: { updated in
                                    update { d in
                                        if let i = d.strength.firstIndex(where: { $0.id == updated.id }) { d.strength[i] = updated }
                                    }
                                },
                                onRemove: { remove(item.id) })
                    .editorRow()
                    .accessibilityIdentifier("routineItem.\(index)")
                    .accessibilityAction(named: "Move up") { move(index, by: -1) }
                    .accessibilityAction(named: "Move down") { move(index, by: 1) }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { remove(item.id) } label: {
                            Label("Remove exercise", systemImage: "trash")
                        }
                        .tint(look.destructive)
                    }
            }
            .onMove { source, destination in
                update { $0.strength.move(fromOffsets: source, toOffset: destination) }
            }
            AIMakeRow(title: "Add exercise", symbol: "plus", isEnabled: day.strength.count < 10 && !available.isEmpty,
                      limit: day.strength.count >= 10 ? "10/10" : nil) {
                nameFocused = false
                showsPicker = true
            }
            .accessibilityIdentifier("routineAddExercise")
            .editorRow(top: 5, bottom: 10)
            // No cardio sent and none in the session: no Cardio section (a bare header offers nothing).
            if !day.cardio.isEmpty || !activities.isEmpty {
                SectionHeader("Cardio").editorRow(top: 20, bottom: 4)
            }
            ForEach(day.cardio) { cardio in
                AICardioEditorRow(cardio: cardio, options: activities,
                                  onChange: { updated in
                                      update { d in
                                          if let i = d.cardio.firstIndex(where: { $0.id == updated.id }) { d.cardio[i] = updated }
                                      }
                                  },
                                  onRemove: { removeCardio(cardio) })
                    .editorRow()
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { removeCardio(cardio) } label: {
                            Label("Remove cardio", systemImage: "trash")
                        }
                        .tint(look.destructive)
                    }
            }
            if !activities.isEmpty {
                Menu {
                    ForEach(activities) { activity in
                        Button(activity.name, systemImage: activity.aiSymbol) {
                            withAnimation(reduceMotion ? nil : .snappy) {
                                update { $0.cardio.append(AIRoutineCardio(activity: activity, minutes: 15)) }
                            }
                        }
                    }
                } label: {
                    AIMakeRowFace(title: "Add cardio", symbol: "plus", isEnabled: day.cardio.count < 3,
                                  limit: day.cardio.count >= 3 ? "3/3" : nil)
                }
                .disabled(day.cardio.count >= 3)
                .accessibilityIdentifier("routineAddCardio")
                .editorRow(top: 5, bottom: 24)
            } else {
                Color.clear.frame(height: 24).editorRow()
                    .accessibilityIdentifier("routineEditorEnd")
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Header: name + live figures

    private func header(_ day: AIRoutineDay) -> some View {
        let families = AIRoutineReadouts.familyCounts(of: day, groups: groups).map(\.family)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                TextField("Session name", text: Binding(
                    get: { model.day(dayID)?.name ?? "" },
                    set: { name in
                        // Return ends editing (the field wraps, so it would otherwise add a line).
                        if name.contains("\n") { nameFocused = false }
                        update { $0.name = name.replacingOccurrences(of: "\n", with: "") }
                    }), axis: .vertical)
                    .font(look.font.title2)
                    .foregroundStyle(look.textPrimary)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .accessibilityIdentifier("routineSessionName")
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
        HStack(spacing: 1) {
            ForEach(families) { family in
                FamilySticker(family: family, lit: true, size: 32)
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7), value: families)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(families.map(\.label).joined(separator: ", "))
    }

    private func figures(_ day: AIRoutineDay) -> some View {
        let sets = AIRoutineReadouts.sets(of: day)
        let minutes = AIRoutineReadouts.minutes(of: day)
        return HStack(spacing: 12) {
            AIInlineFigure(number: day.strength.count, label: day.strength.count.aiPlural("exercise"), numberFont: look.font.fieldNumber)
            AIInlineFigure(number: sets, label: sets.aiPlural("set"), numberFont: look.font.fieldNumber)
            AIInlineFigure(number: minutes, label: "min", numberFont: look.font.fieldNumber)
        }
        .animation(reduceMotion ? nil : .snappy, value: sets)
        .animation(reduceMotion ? nil : .snappy, value: minutes)
    }

    /// The machine at the routine's gym, else the free-weight equipment the option was sent with.
    private func equipmentLine(_ exerciseID: UUID) -> (label: String, symbol: String)? {
        if let label = machineLabels[exerciseID] { return (label, LookIcon.machine) }
        guard let tag = options.first(where: { $0.id == exerciseID })?.equipment else { return nil }
        return (tag.label, tag.historySymbol)
    }

    // MARK: Mutations

    private func update(_ change: (inout AIRoutineDay) -> Void) {
        guard var day = model.day(dayID) else { return }
        change(&day)
        model.update(day)
    }

    private func add(_ exerciseID: UUID) {
        guard let day = model.day(dayID), day.strength.count < 10,
              !day.strength.contains(where: { $0.exerciseID == exerciseID }) else { return }
        let item = AIRoutineStrength(exerciseID: exerciseID, sets: 3, reps: 10, restSeconds: 60)
        update { $0.strength.append(item) }
        withAnimation(reduceMotion ? nil : .snappy) { expanded = item.id }
    }

    private func move(_ index: Int, by offset: Int) {
        guard let day = model.day(dayID) else { return }
        let target = index + offset
        guard day.strength.indices.contains(target) else { return }
        withAnimation(reduceMotion ? nil : .snappy) {
            update { $0.strength.move(fromOffsets: IndexSet(integer: index), toOffset: offset > 0 ? target + 1 : target) }
        }
    }

    private func undo(_ removal: Removal) {
        withAnimation(reduceMotion ? nil : .snappy) {
            model.update(removal.before)
            self.removal = nil
        }
    }

    private func removeCardio(_ cardio: AIRoutineCardio) {
        guard let before = model.day(dayID) else { return }
        withAnimation(reduceMotion ? nil : .snappy) {
            update { $0.cardio.removeAll { $0.id == cardio.id } }
            removal = Removal(name: cardio.activity.name, before: before)
        }
    }

    private func toggle(_ id: UUID) {
        nameFocused = false
        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)) {
            expanded = expanded == id ? nil : id
        }
    }

    private func remove(_ id: UUID) {
        guard let before = model.day(dayID), let item = before.strength.first(where: { $0.id == id }) else { return }
        withAnimation(reduceMotion ? nil : .snappy) {
            if expanded == id { expanded = nil }
            update { $0.strength.removeAll { $0.id == id } }
            removal = Removal(name: names[item.exerciseID] ?? "Exercise", before: before)
        }
    }
}

extension View {
    /// A clear, separator-free List row on the screen margins.
    fileprivate func editorRow(top: CGFloat = 5, bottom: CGFloat = 5) -> some View {
        self
            .listRowInsets(EdgeInsets(top: top, leading: 20, bottom: bottom, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

// MARK: - Exercise row

private struct AIItemEditorRow: View {
    var item: AIRoutineStrength
    var name: String
    var equipment: (label: String, symbol: String)?
    var isExpanded: Bool
    var onToggle: () -> Void
    var onChange: (AIRoutineStrength) -> Void
    var onRemove: () -> Void

    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var handle: CGFloat = 20

    /// Everything under the name lines up with it.
    private var indent: CGFloat { handle + 12 }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: look.radius.panel, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(look.textTertiary)
                    .frame(width: handle, alignment: .leading)
                    .frame(minHeight: 26)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(look.font.headline)
                        .foregroundStyle(look.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let equipment, equipment.label != name {
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
                        .accessibilityIdentifier("routineRemoveItem")
                }
                .padding(.top, 14)
                .padding(.leading, indent)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
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
        .overlay {
            shape.strokeBorder(isExpanded ? look.textPrimary.opacity(0.5) : look.hairline, lineWidth: isExpanded ? 1.5 : 1)
        }
        .contentShape(shape)
        .onTapGesture(perform: onToggle)
        .accessibilityElement(children: .contain)
        // The card is named by its exercise (a container's label is otherwise empty).
        .accessibilityLabel(name)
        .accessibilityAction(named: isExpanded ? "Collapse" : "Edit sets, reps and rest", onToggle)
        .accessibilityAction(named: "Remove exercise", onRemove)
    }

    /// "3 sets × 10 reps · ⏳ 1:00": numbers big, words small.
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
            Text(Format.duration(seconds: item.restSeconds)).font(.system(.subheadline, weight: .semibold).monospacedDigit())
        }
        .foregroundStyle(look.textSecondary)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rest \(Format.duration(seconds: item.restSeconds))")
    }

    private var steppers: some View {
        VStack(alignment: .leading, spacing: 8) {
            stepperRow("Sets", value: item.sets, range: 1...10, step: 1, format: { "\($0)" }) { v in
                var i = item; i.sets = v; onChange(i)
            }
            stepperRow("Reps", value: item.reps, range: 1...50, step: 1, format: { "\($0)" }) { v in
                var i = item; i.reps = v; onChange(i)
            }
            stepperRow("Rest", value: item.restSeconds, range: 0...600, step: 15, format: { Format.duration(seconds: $0) }) { v in
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
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(look.textSecondary)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            NumberStepperPill(value: Binding(get: { value }, set: set), range: range, step: step, format: format)
                .accessibilityLabel(title)
                .accessibilityIdentifier("routineStepper.\(title)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The remove control inside an opened card: danger-coloured trash + verb.
private struct AIRemoveButton: View {
    var title: String
    var action: () -> Void
    @Environment(\.look) private var look

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "trash").font(.system(.subheadline, weight: .semibold))
                Text(title).font(.system(.subheadline, weight: .semibold))
            }
            .foregroundStyle(look.destructive)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(look.surfaceRaised, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.lookPressable)
    }
}

/// A compact remove control (cardio blocks): the trash glyph, 44 pt target; undoable from the bar.
private struct AIRemoveIconButton: View {
    var accessibilityLabel: String
    var action: () -> Void
    @Environment(\.look) private var look
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 36

    var body: some View {
        Button(action: action) {
            Image(systemName: "trash")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(look.destructive)
                .frame(width: size, height: size)
                .background(look.surfaceRaised, in: Circle())
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
                    .overlay { Capsule().strokeBorder(look.textPrimary.opacity(0.45), lineWidth: 1) }
                    .contentShape(Capsule())
            }
            .buttonStyle(.lookPressable)
            .accessibilityIdentifier("routineUndo")
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
    var cardio: AIRoutineCardio
    var options: [CardioActivity]
    var onChange: (AIRoutineCardio) -> Void
    var onRemove: () -> Void
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                stacked
            } else {
                // One line when the name fits whole; otherwise the stepper drops under it.
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
                          range: 1...180, step: 5) { "\($0) min" }
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
                    .font(.system(.subheadline, weight: .semibold))
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

/// The dashed "make one" row. At its limit it goes quiet (faint dotted edge, dim label) and shows the
/// count that stops it ("10/10"), so the off state explains itself.
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
            Text(title).font(.system(.body, weight: .semibold))
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
        .dashedOutline(isEnabled ? look.dash : look.hairline, radius: radius,
                       lineWidth: 1.5, dash: isEnabled ? [5, 4] : [1.5, 4])
        .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

// MARK: - Exercise picker (Add exercise)

/// Eligible exercises not yet in the session, by muscle group head to toe, searchable. Each row
/// shows the machine (or free-weight equipment) it would use. Tap adds it (3 × 10, 1:00).
struct AIExercisePickerSheet: View {
    var options: [RoutineExerciseOption]
    var groups: [UUID: String]
    var machineLabels: [UUID: String]
    var onPick: (UUID) -> Void
    @Environment(\.look) private var look
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var query = ""

    /// Sections by muscle group in body-area order (then Uncategorized); every search token must
    /// appear in the name.
    private var sections: [(title: String, options: [RoutineExerciseOption])] {
        let tokens = query.lowercased().split(whereSeparator: \.isWhitespace)
        let matches = options.filter { option in tokens.allSatisfy { option.name.lowercased().contains($0) } }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let grouped = Dictionary(grouping: matches) { $0.muscleGroup.isEmpty ? "Uncategorized" : $0.muscleGroup }
        let order = BodyArea.order + grouped.keys.filter { !BodyArea.order.contains($0) && $0 != "Uncategorized" }.sorted()
            + ["Uncategorized"]
        return order.compactMap { title in grouped[title].map { (title, $0) } }
    }

    private var title: some View {
        Text("Add exercise")
            .font(look.font.navTitle)
            .foregroundStyle(look.textPrimary)
            .accessibilityAddTraits(.isHeader)
            .padding(.horizontal, typeSize.isAccessibilitySize ? 0 : 96)
    }

    var body: some View {
        let sections = sections
        VStack(spacing: 0) {
            ZStack {
                if !typeSize.isAccessibilitySize { title }
                HStack {
                    GlassCapsuleButton("Cancel") { dismiss() }
                        .accessibilityIdentifier("routinePickerCancel")
                    Spacer()
                }
            }
            .padding(.horizontal, look.space.margin)
            .padding(.top, 14)
            .padding(.bottom, 10)
            if typeSize.isAccessibilitySize {
                title
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, look.space.margin)
                    .padding(.bottom, 10)
            }
            SearchFieldView(text: $query, prompt: "Search exercises", identifier: "routinePickerSearch")
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
                            ForEach(section.options) { option in
                                let equipment = machineLabels[option.id].map { ($0, LookIcon.machine) }
                                    ?? option.equipment.map { ($0.label, $0.historySymbol) }
                                LookRow(option.name, subtitle: equipment?.0 == option.name ? nil : equipment?.0,
                                        symbol: equipment?.1 ?? "figure.strengthtraining.traditional",
                                        showsChevron: false, action: {
                                            onPick(option.id)
                                            dismiss()
                                        }) {
                                    Image(systemName: "plus.circle")
                                        .font(.system(.title3, weight: .regular))
                                        .foregroundStyle(look.textSecondary)
                                        .accessibilityHidden(true)
                                }
                                .accessibilityHint("Adds to this session")
                                .accessibilityIdentifier("routinePick.\(option.name)")
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
        .lookSheetGround()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
