import SwiftData
import SwiftUI

extension ExerciseEntry {
    /// Display label for the entry's current equipment choice.
    var equipmentDisplayLabel: String {
        if let machine { return machine.label }
        if let freeWeightTag { return freeWeightTag.label }
        return "Choose equipment"
    }
}

extension SetType {
    /// The marker's tint, shared by the active workout and history detail so
    /// a `D` never means one thing on one screen and another elsewhere.
    /// Set types retain their own meaning; completed work uses the accent.
    var markerColor: Color {
        switch self {
        case .warmup: Theme.warmup
        case .working: Theme.text
        case .failure: Theme.danger
        case .drop: Theme.drop
        }
    }
}

struct ExerciseEntryCard: View {
    @Environment(\.modelContext) private var modelContext
    var entry: ExerciseEntry
    var showMachinePicker: () -> Void
    var showPerformance: () -> Void
    var completionChanged: (SetRecord, Bool) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showingRestSettings = false
    @State private var showingBarPicker = false

    private var session: WorkoutSession { WorkoutSession(context: modelContext) }

    private var orderedSets: [SetRecord] {
        entry.isDeleted ? [] : WorkoutSession.orderedSets(of: entry)
    }

    /// D19/D23: the snapshot's load type once the entry is frozen, so the
    /// rules the rows validate and render under cannot change under a
    /// half-logged exercise.
    private var loadType: LoadType {
        entry.isDeleted ? .weighted : entry.effectiveLoadType
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            titleRow
            machineRow
            barRow

            if loadType == .assisted {
                Label("Assisted: lower weight = harder. Records track least assistance.", systemImage: "arrow.down.right.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !dynamicTypeSize.isAccessibilitySize { columnHeaders }

            ForEach(orderedSets) { set in
                SetRowView(
                    set: set,
                    index: workingIndex(of: set),
                    loadType: loadType,
                    onCompletionChanged: { completed in
                        completionChanged(set, completed)
                    },
                    onDelete: { deleteSet(set) })
            }

            presetRow

            Button {
                addSet()
            } label: {
                Label("Add Set", systemImage: "plus")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondary)
            .accessibilityIdentifier("addSet")
            .padding(.top, 2)
        }
        .padding(Theme.Space.inset)
        .card()
        .padding(.horizontal)
        .sheet(isPresented: $showingRestSettings) {
            if let exercise = entry.exercise {
                ExerciseRestSettingsSheet(exercise: exercise)
            }
        }
        .sheet(isPresented: $showingBarPicker) {
            BarPickerSheet(
                barWeight: currentBar,
                initialUnit: currentBar?.unit ?? draftUnit,
                onSelect: chooseBar)
        }
    }

    /// D39: the bar this entry's plates go on. Offered wherever the entry is
    /// barbell work — the barbell/Smith tags, or a rack/Smith catalog machine
    /// (`WorkoutSession.offersBar`). A bar row on a cable pulldown would be
    /// noise.
    @ViewBuilder
    private var barRow: some View {
        if WorkoutSession.offersBar(entry) {
            Button {
                showingBarPicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.caption)
                    Text(barLabel)
                        .font(.subheadline.weight(.medium))
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Theme.fill)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.field))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("barPicker")
        }
    }

    private var barLabel: String {
        guard let bar = currentBar else { return "No bar — enter total weight" }
        return "Bar: \(WeightMath.displayNumber(bar.value)) \(bar.unit.rawValue)"
    }

    /// The bar the user is typing against: the first row still to be logged,
    /// falling back to the last row once everything is completed. Completed
    /// rows keep whatever bar they were logged under, so this describes the
    /// *input*, which is what the picker and the column header are about.
    private var currentBar: BarWeight? {
        draftOrLastSet?.resolvedBarWeight
    }

    private var draftUnit: WeightUnit {
        draftOrLastSet?.weightUnit ?? session.defaultUnit(for: entry)
    }

    private var draftOrLastSet: SetRecord? {
        let sets = orderedSets
        return sets.first { $0.completedAt == nil } ?? sets.last
    }

    private func chooseBar(_ bar: BarWeight?) {
        do {
            if let bar {
                try session.chooseBar(bar, for: entry)
            } else {
                try session.clearBar(for: entry)
            }
        } catch {
            assertionFailure("Failed to choose bar: \(error)")
        }
    }

    /// D36–D38: the variation performed. Chips rather than a menu because this
    /// is switched mid-workout with one hand — and because seeing the
    /// alternatives is the point: the user is choosing which record table this
    /// set belongs to.
    @ViewBuilder
    private var presetRow: some View {
        let presets = orderedPresets
        if !presets.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presets) { preset in
                        presetChip(preset.name, isSelected: selectedPresetID == preset.id) {
                            choose(preset)
                        }
                        .accessibilityIdentifier("presetChip.\(preset.name)")
                    }
                    // Escape hatch: the user did something the presets do not
                    // describe, and pretending otherwise would file the set
                    // under a variation they did not perform.
                    presetChip("None", isSelected: selectedPresetID == nil) {
                        choose(nil)
                    }
                    .accessibilityIdentifier("presetChip.None")
                }
                .padding(.vertical, 1)
            }
        }
    }

    private func presetChip(
        _ title: String, isSelected: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Chip(tint: Theme.secondary, selected: isSelected) {
                Text(title)
            }
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
    }

    /// The exercise's presets, in the order the user arranged them.
    private var orderedPresets: [ExercisePreset] {
        guard !entry.isDeleted, let exercise = entry.exercise else { return [] }
        return (exercise.presets ?? []).sorted { ($0.order, $0.name) < ($1.order, $1.name) }
    }

    /// What is selected right now: the live pick while the entry is a draft,
    /// the frozen snapshot once a set has completed (D19/D23).
    private var selectedPresetID: UUID? {
        entry.snapshotCapturedAt == nil ? entry.preset?.id : entry.snapshotPresetID
    }

    private func choose(_ preset: ExercisePreset?) {
        do {
            // Switching after a set has completed splits the entry rather than
            // relabelling completed work — the service owns that rule.
            try session.choosePreset(preset, for: entry)
        } catch {
            assertionFailure("Failed to choose preset: \(error)")
        }
    }

    /// A/B/C position when this entry is in a superset of two or more.
    private var supersetLabel: String? {
        guard !entry.isDeleted, let workout = entry.workout, !workout.isDeleted
        else { return nil }
        return Supersets.memberLabel(for: entry, in: workout)
    }

    /// Groups this entry with the one after it. "With next" rather than a
    /// multi-select: the pair is what a superset almost always is, and building
    /// a selection mode for the rare three-way would cost more screen than it
    /// earns. A third exercise joins by supersetting the second with it.
    private func groupWithNext() {
        guard !entry.isDeleted, let workout = entry.workout, !workout.isDeleted else { return }
        let entries = WorkoutSession.orderedEntries(of: workout).filter { !$0.isDeleted }
        guard let index = entries.firstIndex(where: { $0.id == entry.id }),
              index + 1 < entries.count
        else { return }
        let next = entries[index + 1]
        // Join whichever side already has a group, so A+B then B+C reads as one
        // A/B/C superset rather than two rival pairs.
        if let mine = entry.supersetGroupID {
            next.supersetGroupID = mine
        } else if let theirs = next.supersetGroupID {
            entry.supersetGroupID = theirs
        } else {
            Supersets.group([entry, next])
        }
        save()
    }

    private func ungroup() {
        guard !entry.isDeleted, let workout = entry.workout, !workout.isDeleted else { return }
        Supersets.ungroup(entry, in: workout)
        save()
    }

    private func save() {
        do { try modelContext.save() }
        catch { assertionFailure("Failed to save superset change: \(error)") }
    }

    private var titleRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                MuscleIcon(group: entry.exercise?.muscleGroup)
                if let member = supersetLabel {
                    Chip(tint: Theme.accent, selected: true) { Text(member) }
                        .accessibilityIdentifier("supersetBadge")
                        .accessibilityLabel("Superset position \(member)")
                }
                Text(entry.exercise?.name ?? entry.snapshotExerciseName)
                    .font(Theme.cardTitle)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(
                        "entryTitle.\(entry.exercise?.name ?? entry.snapshotExerciseName)")
                Spacer()
                if !dynamicTypeSize.isAccessibilitySize { titleActions }
            }
            if dynamicTypeSize.isAccessibilitySize {
                HStack { Spacer(); titleActions }
            }
        }
    }

    private var titleActions: some View {
        HStack(spacing: 12) {
            Menu {
                if entry.exercise != nil {
                    Button("Rest Durations…", systemImage: "timer") {
                        showingRestSettings = true
                    }
                }
                // Offered whether or not this entry is ALREADY grouped.
                // codex-review 2 (high): hiding it once grouped meant B could
                // not add C, so the resolution's three-member claim was false.
                Button("Superset with next", systemImage: "arrow.triangle.merge") {
                    groupWithNext()
                }
                .accessibilityIdentifier("supersetWithNext")
                if supersetLabel != nil {
                    Button("Break superset", systemImage: "arrow.triangle.branch") {
                        ungroup()
                    }
                    .accessibilityIdentifier("breakSuperset")
                }
                Button("Delete Exercise", systemImage: "trash", role: .destructive) {
                    deleteEntry()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Exercise options")
            Button(action: showPerformance) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundStyle(.tint)
            }
            .accessibilityLabel("Previous performance")
        }
    }

    private var machineRow: some View {
        Button(action: showMachinePicker) {
            HStack(spacing: 6) {
                Image(systemName: entry.machine != nil ? "gearshape.2" : "dumbbell")
                    .font(.caption)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.equipmentDisplayLabel)
                        .font(.subheadline.weight(.medium))
                    if let model = entry.machine?.model {
                        Text(model.displayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Theme.fill)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.field))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("entryEquipment")
    }

    private var columnHeaders: some View {
        HStack(spacing: 8) {
            Text("SET").frame(width: 34)
            Text("PREVIOUS").frame(maxWidth: .infinity, alignment: .leading)
            Text(weightHeader).frame(width: 88)
            Text("REPS").frame(width: 48)
            Color.clear.frame(width: 30)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(Theme.tertiary)
        .padding(.top, 8)
    }

    /// In bar mode the field takes the plates on **one** end, so the header has
    /// to say so — a column labelled WEIGHT that means half the plates and none
    /// of the bar is how a 135 lb set gets logged as 45.
    private var weightHeader: String {
        if currentBar != nil { return "PER SIDE" }
        return loadType == .assisted ? "ASSIST" : "WEIGHT"
    }

    /// The number a marker-less row shows. Only warmups sit outside the
    /// count — failure and drop rows are numbered work like any other, they
    /// just display their letter instead of the number (D26).
    private func workingIndex(of set: SetRecord) -> Int {
        var index = 0
        for s in orderedSets {
            if s.type != .warmup { index += 1 }
            if s.id == set.id { break }
        }
        return index
    }

    // MARK: Actions

    private func addSet() {
        do {
            try session.addSet(to: entry)
        } catch {
            assertionFailure("Failed to add set: \(error)")
        }
    }

    private func deleteSet(_ set: SetRecord) {
        do {
            try session.deleteSet(set)
        } catch {
            assertionFailure("Failed to delete set: \(error)")
        }
    }

    private func deleteEntry() {
        do {
            try session.deleteEntry(entry)
        } catch {
            assertionFailure("Failed to delete entry: \(error)")
        }
    }
}

struct SetRowView: View {
    @Environment(\.modelContext) private var modelContext
    var set: SetRecord
    var index: Int
    /// The entry's load type — decides which fields this row must carry
    /// before it may be logged (A1).
    var loadType: LoadType
    /// Called after either completion direction so the rest timer can start,
    /// replace, or cancel its persisted source.
    var onCompletionChanged: (Bool) -> Void
    var onDelete: () -> Void

    // In-progress keystrokes live here; they hit the store only on commit
    // (end-editing / completion) — SPEC's durability boundary.
    @State private var weightText: String
    @State private var repsText: String
    @State private var previousLabel = "—"
    @State private var isDirty = false
    /// Swipe-to-delete: how far the row is currently pulled left (≤ 0) and
    /// whether it has settled open. Only an open row's button is tappable, so
    /// a half-swipe can never delete anything.
    @State private var swipeOffset: CGFloat = 0
    @State private var isSwipeOpen = false
    @FocusState private var focusedField: Field?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var markerSize = 34.0

    private static let swipeDeleteWidth: CGFloat = 88

    private enum Field { case weight, reps }

    private var session: WorkoutSession { WorkoutSession(context: modelContext) }

    init(
        set: SetRecord, index: Int, loadType: LoadType,
        onCompletionChanged: @escaping (Bool) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.set = set
        self.index = index
        self.loadType = loadType
        self.onCompletionChanged = onCompletionChanged
        self.onDelete = onDelete
        _weightText = State(initialValue: Self.weightFieldText(for: set))
        _repsText = State(initialValue: set.reps.map(String.init) ?? "")
    }

    private var isCompleted: Bool { !set.isDeleted && set.completedAt != nil }

    /// The two facts that define what the weight field means. Watching only the
    /// numeric bar value misses 15 lb → 15 kg, even though that unit change must
    /// invalidate the old plate input.
    private struct BarInputContext: Equatable {
        var weight: Double?
        var unit: WeightUnit
    }

    private var barInputContext: BarInputContext {
        BarInputContext(
            weight: set.isDeleted ? nil : set.barWeightValue,
            unit: set.isDeleted ? .kg : set.weightUnit)
    }

    /// The bar this row is loaded on (D39), or nil when its field is the total.
    private var barWeight: Double? {
        // `set` first in a computed property's body reads as a setter clause.
        return self.set.isDeleted ? nil : self.set.barWeightValue
    }

    /// What the weight field shows for a row: the plates on one end in bar
    /// mode, the total otherwise. The stored weight is the total either way, so
    /// bar mode has to divide it back out (`BarbellMath.platesPerSide`).
    ///
    /// Formatted through `WeightMath.displayNumber`, not `Format.weight`: the
    /// latter renders to one decimal, and halving an odd total puts a second
    /// one there (47.5 → 23.75 a side). Committing "23.8" would log a set the
    /// user never performed — the field's text becomes the stored value the
    /// moment they tap the checkmark.
    private static func weightFieldText(for set: SetRecord) -> String {
        guard let bar = set.barWeightValue else {
            return set.weightValue.map(Format.weight) ?? ""
        }
        guard let total = set.weightValue,
              let perSide = BarbellMath.platesPerSide(total: total, barWeight: bar)
        else { return "" }
        return WeightMath.displayNumber(perSide)
    }

    /// Deleting a set was already possible from the row's menu, but nobody
    /// finds a menu they don't know is there. The swipe is the discoverable
    /// half of the same action — both call `WorkoutSession.deleteSet`.
    var body: some View {
        ZStack(alignment: .trailing) {
            if swipeOffset < 0 { swipeDeleteButton }
            rowContent
                // Opaque, so the delete button stays hidden behind the row
                // until the swipe pulls it out from under.
                .background(isCompleted ? Theme.accent.opacity(0.08) : Color.clear)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.field))
                .offset(x: swipeOffset)
                .gesture(swipeToDelete)
        }
        .onChange(of: focusedField) { previous, _ in
            // Field commit on end-editing (SPEC durability boundary).
            switch previous {
            case .weight: commitWeight()
            case .reps: commitReps()
            case nil: break
            }
        }
        .onChange(of: weightText) { _, _ in
            if focusedField == .weight { isDirty = true }
        }
        .onChange(of: repsText) { _, _ in
            if focusedField == .reps { isDirty = true }
        }
        // Picking or clearing a bar changes what the field *means*, so the text
        // is re-read from the row. `chooseBar` may have kept the total (it can
        // be re-read as bar + plates) or dropped it (it was in another unit, or
        // lighter than the bar itself); only the row knows which.
        .onChange(of: barInputContext) { _, _ in
            guard !set.isDeleted else { return }
            weightText = Self.weightFieldText(for: set)
        }
        // Preset/equipment changes select a different history context. The
        // session clears untouched inherited values in the model; mirror that
        // into these local TextField states before stale values can be logged.
        .onChange(of: prefillTaskID) { _, _ in
            guard !set.isDeleted, !isDirty else { return }
            weightText = Self.weightFieldText(for: set)
            repsText = set.reps.map(String.init) ?? ""
        }
        .task(id: prefillTaskID) {
            loadPreviousAndPrefill()
        }
        // B3: decimalPad/numberPad have no return key, so the keyboard used
        // to cover the lower rows with no way out. Only the focused row
        // contributes a bar, or every row would stack one.
        .toolbar {
            if focusedField != nil {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    // Clearing focus runs the same end-editing commit as
                    // tapping away (ticket 07's durability boundary).
                    Button("Done") { focusedField = nil }
                        .accessibilityIdentifier("keyboardDone")
                }
            }
        }
    }

    private var swipeToDelete: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                // Vertical drags belong to the scroll view, not to us.
                guard abs(value.translation.width) > abs(value.translation.height)
                else { return }
                swipeOffset = settledOffset(after: value.translation.width)
            }
            .onEnded { value in
                setSwipeOpen(
                    settledOffset(after: value.translation.width)
                        < -Self.swipeDeleteWidth / 2)
            }
    }

    private func settledOffset(after translation: CGFloat) -> CGFloat {
        let base: CGFloat = isSwipeOpen ? -Self.swipeDeleteWidth : 0
        return min(0, max(-Self.swipeDeleteWidth, base + translation))
    }

    private func setSwipeOpen(_ open: Bool) {
        isSwipeOpen = open
        withAnimation(.snappy) {
            swipeOffset = open ? -Self.swipeDeleteWidth : 0
        }
    }

    private var swipeDeleteButton: some View {
        Button(role: .destructive) {
            setSwipeOpen(false)
            onDelete()
        } label: {
            Image(systemName: "trash")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: Self.swipeDeleteWidth - 10, height: 34)
                .background(Theme.danger, in: RoundedRectangle(cornerRadius: Theme.Radius.field))
        }
        .buttonStyle(.plain)
        .allowsHitTesting(isSwipeOpen)
        .accessibilityIdentifier("setRow.swipeDelete")
        .accessibilityLabel("Delete set")
    }

    private var rowContent: some View {
        fieldsRow
            .padding(.vertical, 5)
            .sensoryFeedback(.setComplete, trigger: isCompleted) { _, completed in completed }
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.65), value: isCompleted)
    }

    private var totalCaption: String? {
        guard let barWeight else { return nil }
        guard let perSide = WorkoutSession.weightValue(from: weightText) else {
            // No plates typed yet: say what the bar alone weighs rather than
            // claiming a total the user has not entered.
            return "\(WeightMath.displayNumber(barWeight)) \(set.weightUnit.rawValue) bar"
        }
        return BarbellMath.totalLabel(
            barWeight: barWeight, platesPerSide: perSide, unit: set.weightUnit)
    }

    private var previousText: some View {
        Text(previousLabel)
            .font(.footnote)
            .foregroundStyle(Theme.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("setRow.previous")
    }

    private var fieldsRow: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        setTypeButton
                        previousText
                        completeButton
                    }
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(barWeight != nil ? "PER SIDE" : (loadType == .assisted ? "ASSIST" : "WEIGHT"))
                                .font(Theme.label)
                                .foregroundStyle(Theme.secondary)
                            weightInput
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("REPS").font(Theme.label).foregroundStyle(Theme.secondary)
                            repsInput
                        }
                        .frame(maxWidth: 100)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    setTypeButton
                    previousText
                    weightInput
                    repsInput
                    completeButton.frame(width: 30)
                }
            }
        }
        .font(.subheadline.weight(.semibold))
        .monospacedDigit()
        .contextMenu {
            Button("Delete Set", systemImage: "trash", role: .destructive) { onDelete() }
        }
    }

    private var weightInput: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                TextField("–", text: $weightText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .weight)
                    .multilineTextAlignment(.center)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .accessibilityIdentifier("setRow.weight")

                Button {
                    toggleUnit()
                } label: {
                    UnitBadge(unit: set.isDeleted ? .kg : set.weightUnit)
                }
                .buttonStyle(.plain)
                // The unit follows the selected bar; input remains plates per side.
                .disabled(barWeight != nil)
                .accessibilityIdentifier("setRow.unit")
                .accessibilityHint(
                    barWeight == nil ? "" : "The unit follows the bar. Change the bar to log in the other unit.")
            }
            if let totalCaption {
                Text(totalCaption)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.bottom, 7)
                    .accessibilityIdentifier("setRow.total")
            }
        }
        .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 88)
        .background(Theme.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.field))
    }

    private var repsInput: some View {
        TextField("–", text: $repsText)
            .keyboardType(.numberPad)
            .focused($focusedField, equals: .reps)
            .multilineTextAlignment(.center)
            .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 48)
            .padding(.vertical, 10)
            .background(Theme.fill)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.field))
            .accessibilityIdentifier("setRow.reps")
    }

    /// E5: the marker is a menu of named set types — the old control cycled
    /// blindly through them and announced itself as "1". The compact
    /// W/#/F/D visual keeps its footprint, plus a small chevron so it reads
    /// as something with options rather than as a plain number.
    private var setTypeButton: some View {
        Menu {
            ForEach(SetType.allCases, id: \.self) { type in
                Button {
                    apply(type)
                } label: {
                    if !set.isDeleted, set.type == type {
                        Label(type.displayName, systemImage: "checkmark")
                    } else {
                        Text(type.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 1) {
                Text(set.isDeleted ? "" : (set.type.marker ?? "\(index)"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isCompleted ? Theme.onAccent : markerColor)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .frame(width: markerSize, height: markerSize)
            .background(isCompleted ? Theme.accent : Theme.fill, in: Circle())
        }
        .accessibilityIdentifier("setRow.setType")
        .accessibilityLabel(
            "Set type: \(set.isDeleted ? "" : set.type.displayName.lowercased())")
    }

    private var markerColor: Color {
        // `set` first in a computed property's body reads as a setter clause.
        return self.set.isDeleted ? .primary : self.set.type.markerColor
    }

    /// A1: the checkmark is live only once the row says something true —
    /// judged on what is *on screen*, since the fields commit on end-editing
    /// and the tap itself is the commit. An already-completed row stays
    /// tappable so it can always be un-completed.
    /// The domain owns the parsing as well as the rule, so "the checkmark is
    /// live" and "the store will accept this" can never disagree — a negative
    /// or NaN weight used to enable the tap and then do nothing.
    private var canComplete: Bool {
        isCompleted || WorkoutSession.isLoggable(
            weightText: weightText, repsText: repsText, loadType: loadType)
    }

    private var completeButton: some View {
        Button {
            toggleCompletion()
        } label: {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(completeTint)
                .scaleEffect(isCompleted ? 1 : 0.88)
        }
        .buttonStyle(.plain)
        .disabled(!canComplete)
        .accessibilityIdentifier("setRow.complete")
        .accessibilityLabel("Complete set")
        .accessibilityValue(isCompleted ? "Completed" : "Not completed")
        .accessibilityHint(canComplete ? "" : incompleteHint)
    }

    private var completeTint: Color {
        if isCompleted { return Theme.accent }
        return canComplete ? .secondary : Color(.quaternaryLabel)
    }

    private var incompleteHint: String {
        loadType == .bodyweight
            ? "Enter reps to log this set"
            : "Enter \(loadType == .assisted ? "assistance" : "weight") and reps to log this set"
    }

    // MARK: Commits

    /// One commit path for the weight field, whatever the field currently
    /// means. `commitPerSide` computes the total from the row's bar, and falls
    /// through to `commitWeight` when there is no bar — so a mode change
    /// mid-edit can never double or halve the user's number.
    private func commitWeight() {
        guard !set.isDeleted else { return }
        do {
            try session.commitPerSide(weightText, for: set)
        } catch {
            assertionFailure("Failed to commit weight: \(error)")
        }
    }

    private func commitReps() {
        guard !set.isDeleted else { return }
        do {
            try session.commitReps(repsText, for: set)
        } catch {
            assertionFailure("Failed to commit reps: \(error)")
        }
    }

    private func toggleUnit() {
        guard !set.isDeleted else { return }
        isDirty = true
        do {
            // Commit any in-progress weight text first so the toggle applies
            // to what is on screen.
            try session.commitPerSide(weightText, for: set)
            try session.toggleUnit(of: set)
        } catch {
            assertionFailure("Failed to toggle unit: \(error)")
        }
    }

    private func apply(_ type: SetType) {
        guard !set.isDeleted else { return }
        do {
            try session.setType(type, of: set)
        } catch {
            assertionFailure("Failed to set the set type: \(error)")
        }
    }

    private func toggleCompletion() {
        guard !set.isDeleted, canComplete else { return }
        do {
            // Completion is a commit boundary: on-screen values first.
            try session.commitPerSide(weightText, for: set)
            try session.commitReps(repsText, for: set)
            try session.toggleCompletion(of: set)
        } catch WorkoutSessionError.setNotLoggable {
            // A1: the button is disabled until the row is loggable, so this
            // is unreachable — and silently ignoring it beats logging a set
            // that says nothing.
        } catch {
            assertionFailure("Failed to toggle completion: \(error)")
        }
        let completed = set.completedAt != nil
        if completed {
            focusedField = nil
        }
        onCompletionChanged(completed)
    }

    /// Snapshot-keyed ticket-11 query. The label always shows the selected
    /// historical row; values are applied only while this draft remains
    /// untouched, so a delayed refresh can never clobber typing.
    private func loadPreviousAndPrefill() {
        guard !set.isDeleted else { return }
        do {
            let history = PerformanceHistory(context: modelContext)
            guard let candidate = try history.prefill(for: set) else {
                previousLabel = "—"
                return
            }
            previousLabel = candidate.displayLabel
            guard try history.applyPrefill(candidate, to: set, isDirty: isDirty) else {
                return
            }
            // Read the field back off the row rather than off the candidate:
            // the prefill carries the bar too, so in bar mode the field must
            // show the plates it implies, not last session's total.
            weightText = Self.weightFieldText(for: set)
            repsText = String(candidate.reps)
        } catch {
            assertionFailure("Failed to load previous performance: \(error)")
        }
    }

    /// Changing equipment, preset, set type, or type-relative order selects a new
    /// candidate. A dirty row still refreshes its PREVIOUS reference label
    /// but `loadPreviousAndPrefill` refuses to overwrite its inputs.
    private var prefillTaskID: String {
        let entry = set.entry
        return [
            set.id.uuidString,
            String(set.order),
            set.type.rawValue,
            entry?.machine?.id.uuidString ?? "no-machine",
            entry?.freeWeightTag?.rawValue ?? "no-tag",
            entry?.preset?.id.uuidString ?? "no-preset",
        ].joined(separator: "|")
    }
}
