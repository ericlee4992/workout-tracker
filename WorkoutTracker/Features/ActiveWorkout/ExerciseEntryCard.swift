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

    /// Environment-free inputs from the workout screen: the next set to do (whole workout), whether
    /// a rest is running, and the New best / First time marks.
    var nextSetID: UUID?
    var isResting: Bool = false
    var badges: [UUID: SetBadge] = [:]

    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            titleRow
            if entry.plannedRestSeconds != nil, !entry.plannedRepsBySet.isEmpty {
                Text("Target: " + TemplateTargets(repsBySet: entry.plannedRepsBySet).summary)
                    .font(look.font.subhead).foregroundStyle(look.textSecondary)
            }
            machineRow
            barRow

            if loadType == .assisted {
                Label("Assisted: lower weight = harder. Records track least assistance.", systemImage: "arrow.down.right.circle")
                    .font(look.font.caption)
                    .foregroundStyle(look.textSecondary)
            }

            SetColumnHeader(weightTitle: weightHeader).padding(.top, 4)

            VStack(spacing: 4) {
                ForEach(orderedSets) { set in
                    LiveSetRow(
                        set: set,
                        index: workingIndex(of: set),
                        loadType: loadType,
                        isNextUp: set.id == nextSetID,
                        isResting: isResting,
                        badge: badges[set.id],
                        onCompletionChanged: { completed in
                            completionChanged(set, completed)
                        },
                        onDelete: { deleteSet(set) })
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .trailing))))
                }
            }

            presetRow

            // Rows are only ever created deliberately (2026-08-22).
            AddSetRow { addSet() }
                .accessibilityIdentifier("addSet")
                .padding(.top, 2)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .lookSurface(.panel)
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
            HStack {
                Chip(barLabel, symbol: "figure.strengthtraining.traditional") { showingBarPicker = true }
                    .accessibilityIdentifier("barPicker")
                    .accessibilityHint("Changes the bar")
                Spacer(minLength: 0)
            }
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
        Chip(title, isSelected: isSelected, action: action)
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

    /// The name (wraps, never truncates) with the superset letter, and the previous-performance
    /// and "…" buttons. No muscle icon beside the name (ticket 11 — the user: "They don't match").
    private var titleRow: some View {
        let ax = dynamicTypeSize.isAccessibilitySize
        return HStack(alignment: ax ? .top : .center, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let member = supersetLabel {
                    TemplateSupersetTag(letter: member)
                        .accessibilityIdentifier("supersetBadge")
                }
                Text(entry.exercise?.name ?? entry.snapshotExerciseName)
                    .font(look.font.cardTitle)
                    .foregroundStyle(look.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier(
                        "entryTitle.\(entry.exercise?.name ?? entry.snapshotExerciseName)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            titleActions.padding(.top, ax ? 4 : 0)
        }
    }

    private var titleActions: some View {
        HStack(spacing: 10) {
            CardIconButton(look.previousPerformanceSymbol, accessibilityLabel: "Previous performance",
                           action: showPerformance)
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
                CardIconFace(symbol: "ellipsis")
            }
            .accessibilityLabel("Exercise options")
        }
    }

    /// The equipment row: the machine (weight-stack glyph) or free weight, with the model under it.
    private var machineRow: some View {
        EquipmentRow(
            title: entry.equipmentDisplayLabel,
            subtitle: entry.machine?.model?.displayName,
            symbol: entry.machine != nil ? LookIcon.machine : "dumbbell",
            action: showMachinePicker)
        .accessibilityIdentifier("entryEquipment")
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
