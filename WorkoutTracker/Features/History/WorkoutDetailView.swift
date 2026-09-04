import SwiftData
import SwiftUI

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var workout: Workout
    /// The set being corrected, if any (milestone 8, ticket 03).
    @State private var editingSet: SetRecord?
    @State private var confirmingDelete = false
    /// The set a swipe is proposing to delete. codex-review (high): the swipe
    /// used to delete immediately. This phone holds the only copy of the user's
    /// training history, and ticket 03 says the destructive paths confirm —
    /// which was true of the workout and not of the set.
    @State private var confirmingSetDelete: SetRecord?
    /// Adding an exercise to a past session (requested 2026-08-29).
    @State private var showExercisePicker = false
    /// The entry a delete is proposing to remove, with all its sets.
    @State private var confirmingEntryDelete: ExerciseEntry?
    /// The entry whose progress chart is open (milestone 9, ticket 01). The
    /// chart opens on THIS session's variation — snapshot type, tag and preset
    /// — rather than the most-trained one, because that is what the user is
    /// looking at.
    @State private var chartingEntry: ExerciseEntry?
    /// Renaming a logged workout (milestone 9, ticket 02) — a marked edit (D47).
    @State private var renamingWorkout = false
    @State private var renameText = ""
    /// A set just created by "Add Exercise". If the user leaves without giving
    /// it real values, the whole entry is removed — history must never show an
    /// exercise with nothing under it.
    @State private var pendingNewSet: SetRecord?
    /// Whole-view convert toggle (D9): nil shows every weight as entered;
    /// a unit renders everything in that unit with conversions ≈-marked.
    /// Display-only — storage is never touched.
    @State private var displayUnit: WeightUnit?

    var body: some View {
        List {
            Section {
                Button {
                    renameText = workout.isDeleted ? "" : (workout.name ?? "")
                    renamingWorkout = true
                } label: {
                    LabeledContent("Name") {
                        HStack(spacing: 4) {
                            Text(workout.isDeleted ? "" : workout.historyTitle)
                                .lineLimit(1)
                            Image(systemName: "pencil")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("historyWorkoutName")
                HStack {
                    Label(workout.historyGymName ?? "No gym", systemImage: "mappin.and.ellipse")
                    Spacer()
                    // E3 (ticket 17): seconds below a minute, here too.
                    Text(workout.durationLabel ?? "—")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }

            ForEach(WorkoutSession.orderedEntries(of: workout)) { entry in
                Section {
                    let sets = WorkoutSession.orderedSets(of: entry)
                        .filter { $0.completedAt != nil }
                    ForEach(Array(sets.enumerated()), id: \.element.id) { pair in
                        setLine(index: pair.offset, set: pair.element)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("historySetLine")
                            .contentShape(Rectangle())
                            .onTapGesture { editingSet = pair.element }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    confirmingSetDelete = pair.element
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                } header: {
                    // Snapshot display strings ONLY (D23) — never the live
                    // exercise/machine/model relationships.
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(entry.snapshotExerciseName)
                            Spacer()
                            Button {
                                chartingEntry = entry
                            } label: {
                                Image(systemName: "chart.xyaxis.line")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Progress chart")
                            .accessibilityIdentifier("historyEntryChart")
                            // Repairs a set logged under the wrong load type —
                            // the case correcting the EXERCISE cannot reach,
                            // because history is frozen (codex-review).
                            Menu {
                                ForEach(LoadType.allCases, id: \.self) { type in
                                    Button {
                                        retype(entry, to: type)
                                    } label: {
                                        Label(
                                            type.badge,
                                            systemImage: entry.snapshotLoadType == type
                                                ? "checkmark" : "")
                                    }
                                }
                                Divider()
                                Button("Remove Exercise", systemImage: "trash", role: .destructive) {
                                    confirmingEntryDelete = entry
                                }
                                .accessibilityIdentifier("removeHistoryExercise")
                            } label: {
                                Text(entry.snapshotLoadType.badge)
                                    .font(.caption2)
                                    .textCase(nil)
                            }
                            .accessibilityIdentifier("historyEntryLoadType")
                        }
                        Text(entry.snapshotEquipmentLabel)
                            .font(.caption2)
                            .textCase(nil)
                            .foregroundStyle(.secondary)
                        // D51: a reclassified row says what it was, on the row.
                        if let from = entry.reclassifiedFromExerciseName, let when = entry.reclassifiedAt {
                            Text("Reclassified from \(from) · \(when.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption2)
                                .textCase(nil)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("historyReclassifiedMark")
                        }
                    }
                }
            }

            // Milestone 9, ticket 05: what the sensor saw, for any workout that
            // has it. Aggregates for every workout that recorded them; the
            // graph only when a series exists — older workouts never show an
            // empty chart.
            if !workout.isDeleted, let summary = heartRateSummary, summary.hasHeartRate {
                Section("Heart rate") {
                    if let average = summary.averageHeartRate {
                        LabeledContent("Average") { Text("\(average) BPM").monospacedDigit() }
                    }
                    if let maximum = summary.maxHeartRate {
                        LabeledContent("Maximum") { Text("\(maximum) BPM").monospacedDigit() }
                    }
                    if let calories = summary.activeEnergyKilocalories {
                        LabeledContent("Active calories") { Text("\(Int(calories.rounded())) CAL").monospacedDigit() }
                    }
                    if let total = summary.totalEnergyKilocalories {
                        LabeledContent("Total calories") { Text("\(Int(total.rounded())) CAL").monospacedDigit() }
                    }
                }
                .accessibilityIdentifier("historyHeartRateSection")
                if summary.hasHeartRateSeries, let interval = summary.heartRateSeriesIntervalSeconds {
                    HeartRateSummarySection(
                        series: summary.heartRateSeries,
                        intervalSeconds: interval,
                        durationSeconds: Int(summary.duration.rounded(.up)),
                        averageBpm: summary.averageHeartRate,
                        maxBpm: summary.maxHeartRate)
                }
            }

            Section {
                Button("Add Exercise…", systemImage: "plus") {
                    showExercisePicker = true
                }
                .accessibilityIdentifier("addHistoryExercise")
            } footer: {
                Text("Recorded as defined today, without equipment.")
            }

            if let edited = workout.isDeleted ? nil : workout.historyEditedAt {
                Section {
                    Label(
                        "Edited \(edited.formatted(date: .abbreviated, time: .shortened))",
                        systemImage: "pencil.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("historyEditedMark")
                }
            }

        }
        .navigationTitle(workout.startedAt.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingSet) { set in
            EditLoggedSetSheet(record: set)
        }
        .alert("Workout Name", isPresented: $renamingWorkout) {
            TextField(workout.isDeleted ? "" : workout.derivedTitle, text: $renameText)
                .accessibilityIdentifier("workoutNameField")
            Button("Save") {
                // Marked as an edit: a logged workout that changes what it is
                // called is history changing, and says so (D50). Saved
                // explicitly like every other edit on this screen — relying on
                // autosave here could lose both the name and the mark
                // (codex-review 02, high).
                if HistoryEditing.rename(workout, to: renameText) { save() }
            }
            .accessibilityIdentifier("saveWorkoutName")
            Button("Cancel", role: .cancel) {}
        }
        // On the List, not the Section: a `.sheet` on a Section inside a List
        // never presents (STATE gotcha, milestone 3).
        .sheet(item: $chartingEntry) { entry in
            NavigationStack {
                ExerciseProgressView(
                    exerciseID: entry.snapshotExerciseID,
                    exerciseName: entry.snapshotExerciseName,
                    initialVariation: ProgressVariationKey(
                        loadType: entry.snapshotLoadType,
                        equipment: ProgressEquipment(
                            machineID: entry.snapshotMachineID,
                            freeWeightTag: entry.snapshotFreeWeightTag),
                        presetID: entry.snapshotPresetID))
            }
        }
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerSheet { exercise in
                addExercise(exercise)
            }
        }
        .sheet(item: $pendingNewSet, onDismiss: discardIncompleteAddition) { set in
            EditLoggedSetSheet(record: set)
        }
        .confirmationDialog(
            "Remove this exercise?",
            isPresented: Binding(
                get: { confirmingEntryDelete != nil },
                set: { if !$0 { confirmingEntryDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Remove Exercise", role: .destructive) { deleteConfirmedEntry() }
            Button("Cancel", role: .cancel) { confirmingEntryDelete = nil }
        } message: {
            if let entry = confirmingEntryDelete, !entry.isDeleted {
                let count = (entry.sets ?? []).filter { !$0.isDeleted }.count
                Text("\(entry.snapshotExerciseName) and its \(count) set\(count == 1 ? "" : "s") will be permanently removed from this workout. Records are recalculated without them.")
            }
        }
        .confirmationDialog(
            "Delete this set?",
            isPresented: Binding(
                get: { confirmingSetDelete != nil },
                set: { if !$0 { confirmingSetDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete Set", role: .destructive) {
                if let set = confirmingSetDelete { deleteSet(set) }
                confirmingSetDelete = nil
            }
            Button("Cancel", role: .cancel) { confirmingSetDelete = nil }
        } message: {
            Text("This set is removed permanently, and records and volume are recalculated without it.")
        }
        .confirmationDialog(
            "Delete this workout?", isPresented: $confirmingDelete, titleVisibility: .visible
        ) {
            Button("Delete Workout", role: .destructive) { deleteWorkout() }
            Button("Cancel", role: .cancel) {}
        } message: {
            // Names what is lost. This phone holds the only copy of the user's
            // training history, so "are you sure?" about an unknown quantity is
            // not good enough.
            let impact = HistoryEditing.impact(ofDeleting: workout)
            // D47 requires the confirmation to NAME what is destroyed, volume
            // included — it was computed and never shown (codex-review, high).
            Text("\(impact.sets) set\(impact.sets == 1 ? "" : "s") across \(impact.exercises) exercise\(impact.exercises == 1 ? "" : "s"), \(Format.weight(impact.volumeKg)) kg of volume, permanently deleted. Records are recalculated without them.")
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Delete Workout…", systemImage: "trash", role: .destructive) {
                        confirmingDelete = true
                    }
                    .accessibilityIdentifier("deleteWorkout")
                    Divider()
                    Picker("Units", selection: $displayUnit) {
                        Text("As entered").tag(WeightUnit?.none)
                        ForEach(WeightUnit.allCases) { unit in
                            Text("Show in \(unit.rawValue)").tag(WeightUnit?.some(unit))
                        }
                    }
                } label: {
                    Label(displayUnit?.rawValue ?? "As entered", systemImage: "scalemass")
                }
                .accessibilityIdentifier("workoutDetailMenu")
            }
        }
    }

    private func addExercise(_ exercise: Exercise) {
        guard let pair = HistoryEditing.addEntry(
            for: exercise, to: workout, in: modelContext)
        else { return }
        save()
        // Straight into the editor: the new set has no values yet, and an
        // entry whose sets are all unloggable would render as an exercise with
        // nothing under it.
        pendingNewSet = pair.set
    }

    /// Called when the editor for a just-added exercise closes. An addition the
    /// user abandoned leaves nothing behind.
    private func discardIncompleteAddition() {
        defer { pendingNewSet = nil }
        guard let set = pendingNewSet, !set.isDeleted else { return }
        guard !WorkoutSession.isLoggable(set) else { return }
        if let entry = set.entry, !entry.isDeleted {
            HistoryEditing.deleteEntry(entry, in: modelContext)
        }
        save()
    }

    private func deleteConfirmedEntry() {
        defer { confirmingEntryDelete = nil }
        guard let entry = confirmingEntryDelete else { return }
        HistoryEditing.deleteEntry(entry, in: modelContext)
        save()
    }

    private func retype(_ entry: ExerciseEntry, to loadType: LoadType) {
        guard HistoryEditing.retype(entry, to: loadType) else { return }
        save()
    }

    private func deleteSet(_ set: SetRecord) {
        let entry = HistoryEditing.deleteSet(set, in: modelContext)
        if let entry { HistoryEditing.pruneIfEmpty(entry, in: modelContext) }
        save()
    }

    private func deleteWorkout() {
        modelContext.delete(workout)
        save()
        dismiss()
    }

    private func save() {
        do { try modelContext.save() }
        catch { assertionFailure("Failed to save history edit: \(error)") }
    }

    /// The same summary the finish sheet showed, rebuilt from the stored
    /// workout — so History and the receipt cannot disagree.
    private var heartRateSummary: WorkoutSummary? {
        workout.isDeleted ? nil : WorkoutSummaryBuilder.summary(for: workout)
    }

    /// Weight text for a set under the current toggle: as entered by default,
    /// ≈-marked when rendered in the other unit (WeightMath, D25).
    private func weightLabel(for set: SetRecord) -> String {
        guard let value = set.weightValue,
              let stored = StoredWeight(value: value, unit: set.weightUnit) else {
            return "—"
        }
        return WeightMath.displayLabel(for: stored, in: displayUnit ?? stored.unit)
    }

    private func setLine(index: Int, set: SetRecord) -> some View {
        HStack(spacing: 10) {
            Text(set.type.marker ?? "\(index + 1)")
                .font(.subheadline.weight(.semibold))
                // Same marker tints as the active workout (W/F/D), so a `D`
                // in history means what it meant while logging (D26).
                .foregroundStyle(set.type.markerColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(weightLabel(for: set)) × \(set.reps.map(String.init) ?? "—")")
                    .font(.body)
                if let breakdown = barBreakdown(for: set) {
                    Text(breakdown)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    /// D39: how a bar-mode set was loaded — `45 + 45 × 2 = 135 lb`. The weight
    /// above it is the total, and always was; this only says where it came from.
    ///
    /// Shown as entered only. Under the convert toggle the numbers above are
    /// ≈ values (D9/D25), and an ≈ sum of two ≈ parts reads as arithmetic the
    /// app is claiming rather than reporting.
    private func barBreakdown(for set: SetRecord) -> String? {
        guard displayUnit == nil || displayUnit == set.weightUnit,
              let bar = set.barWeightValue, let total = set.weightValue
        else { return nil }
        return BarbellMath.breakdownLabel(
            barWeight: bar, total: total, unit: set.weightUnit)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: WorkoutTrackerStore.schema,
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    let workout = Workout(
        startedAt: .now.addingTimeInterval(-3600), finishedAt: .now,
        snapshotGymName: "Gold's Gym Gangnam",
        gym: Gym(name: "Gold's Gym Gangnam", city: "Seoul", defaultUnit: .kg))
    container.mainContext.insert(workout)
    let entry = ExerciseEntry(
        order: 0, workout: workout,
        snapshotCapturedAt: .now,
        snapshotExerciseID: UUID(),
        snapshotLoadType: .weighted,
        snapshotExerciseName: "Seated Chest Press",
        snapshotMachineLabel: "Chest Press #1",
        snapshotModelName: "Life Fitness Insignia Chest Press")
    container.mainContext.insert(entry)
    container.mainContext.insert(SetRecord(
        order: 0, type: .warmup, reps: 12, weightValue: 40,
        normalizedKg: 40, completedAt: .now, entry: entry))
    container.mainContext.insert(SetRecord(
        order: 1, reps: 10, weightValue: 60,
        normalizedKg: 60, completedAt: .now, entry: entry))
    return NavigationStack {
        WorkoutDetailView(workout: workout)
    }
    .modelContainer(container)
}
