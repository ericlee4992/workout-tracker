import SwiftData
import SwiftUI

/// One finished workout (Floodlight redesign ticket 05): the hero, Save as Template…, the
/// Finish tiles, the last same-template comparison, heart rate with zones, the exercises with
/// their editable set lines, cardio, Add Exercise…, notes and Delete Workout…. A native `List`,
/// so set rows keep their swipe-to-delete; every block is a clear row, each exercise (a
/// superset's members together) one Floodlight panel.
struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.look) private var look
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query private var allPreferences: [AppPreferences]
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
    /// The workout's notes (ticket 05, the user's decision 2026-09-27) — a marked edit.
    @State private var editingNotes = false
    @State private var notesText = ""
    /// Ticket 13: "Save as Template…" from History, the finish sheet's flow.
    @State private var namingTemplate = false
    @State private var savedTemplateName: String?
    /// A set just created by Add Exercise or Add Set. If the user leaves without giving it real
    /// values it is removed again (with its exercise when that leaves it empty) — history must
    /// never show a row with nothing in it.
    @State private var pendingNewSet: SetRecord?
    /// The same set, kept apart from the sheet's item: SwiftUI clears `pendingNewSet` before the
    /// sheet's `onDismiss` runs, so the cleanup must not read it (Codex review 05, high).
    @State private var addedSet: SetRecord?
    /// Whole-view convert toggle (D9): nil shows every weight as entered;
    /// a unit renders everything in that unit, plain (D52). Display-only —
    /// storage is never touched.
    @State private var displayUnit: WeightUnit?
    /// Ring families, new bests and the template comparison, and each set's mark — rebuilt when
    /// the workout is edited, not per render (they read each scope's past).
    @State private var receipt: FinishReceipt?
    @State private var marks: [UUID: SetBadge] = [:]
    /// Scrolled past the hero: the workout's title takes over in the bar.
    @State private var titleInBar = false

    /// The app's default weight unit (D2/T7 precedence, app level) — volume and comparison.
    private var appUnit: WeightUnit {
        UnitPrecedence.defaultUnit(
            machineUnit: nil, gymUnit: nil,
            appPreference: AppPreferences.canonical(of: allPreferences)?.unitPreference)
    }

    /// The same summary the finish sheet showed, rebuilt from the stored
    /// workout — so History and the receipt cannot disagree.
    private var summary: WorkoutSummary? {
        workout.isDeleted ? nil : WorkoutSummaryBuilder.summary(for: workout)
    }

    private func rebuildDerived() {
        guard !workout.isDeleted else { receipt = nil; marks = [:]; return }
        receipt = try? FinishReceipt.build(for: workout, in: modelContext)
        let finished = (try? SetBadgeMath.finishedEntries(in: modelContext)) ?? []
        var result: [UUID: SetBadge] = [:]
        for entry in WorkoutSession.orderedEntries(of: workout) {
            for (id, outcome) in SetBadgeMath.receiptMarks(for: entry, finishedEntries: finished).outcomes {
                result[id] = outcome.badge
            }
        }
        marks = result
    }

    var body: some View {
        List {
            if !workout.isDeleted {
                content
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
        .lookScreenBackground()
        .onScrollGeometryChange(for: Bool.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top > (dynamicTypeSize.isAccessibilitySize ? 220 : 130)
        } action: { _, past in
            withAnimation(.easeInOut(duration: 0.18)) { titleInBar = past }
        }
        .navigationTitle(workout.isDeleted ? "" : workout.historyTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(look.ground, for: .navigationBar)
        .toolbarBackgroundVisibility(titleInBar ? .visible : .hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(workout.isDeleted ? "" : workout.historyTitle)
                    .font(look.font.navTitle)
                    .foregroundStyle(look.textPrimary)
                    .lineLimit(1)
                    .opacity(titleInBar ? 1 : 0)
                    .accessibilityHidden(!titleInBar)
            }
            // Units are about weights: no control on a workout with no lifting.
            if !workout.isDeleted, !workout.completedSets.isEmpty {
                ToolbarItem(placement: .topBarTrailing) { unitsMenu }
            }
        }
        .onAppear(perform: rebuildDerived)
        .onChange(of: workout.historyEditedAt) { _, _ in rebuildDerived() }
        .sheet(item: $editingSet) { set in
            EditLoggedSetSheet(record: set, badge: marks[set.id])
        }
        .sheet(item: $pendingNewSet, onDismiss: discardIncompleteAddition) { set in
            EditLoggedSetSheet(record: set, isNew: true)
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
        .alert("Notes", isPresented: $editingNotes) {
            TextField("Notes", text: $notesText, axis: .vertical)
                .accessibilityIdentifier("historyNotesField")
            Button("Save") {
                if HistoryEditing.setNotes(workout, to: notesText) { save() }
            }
            .accessibilityIdentifier("saveHistoryNotes")
            Button("Cancel", role: .cancel) {}
        }
        // On the List, not a row: a `.sheet` inside a List row never presents (STATE gotcha,
        // milestone 3).
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
            Text(HistoryDeleteCopy.set(confirmingSetDelete))
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
            let cardio = workout.recordedCardio.isEmpty ? "" : " Recorded cardio and any routes will also be deleted."
            Text("\(impact.sets) set\(impact.sets == 1 ? "" : "s") across \(impact.exercises) exercise\(impact.exercises == 1 ? "" : "s"), \(Format.weight(impact.volumeKg)) kg of volume, permanently deleted. Records are recalculated without them.\(cardio)")
        }
        .saveAsTemplateFlow(workout: workout, isPresented: $namingTemplate) {
            savedTemplateName = $0
        }
    }

    // MARK: Page

    @ViewBuilder private var content: some View {
        let summary = summary
        let entries = WorkoutSession.orderedEntries(of: workout)
        // Cardio-only (ticket 12, H04): the hero carries the segment with the route; its time is a
        // hero figure, so the tiles start after workout time, and Splits follow them.
        let heroSegment = entries.isEmpty
            ? (workout.recordedCardio.first { $0.route.count > 1 } ?? workout.recordedCardio.first) : nil
        HistoryDetailHero(
            workout: workout,
            ringSets: ringSets(entries),
            families: receipt?.familySets.map(\.family) ?? [],
            newBests: receipt?.bests.count ?? 0,
            unitBadge: HistoryWorkoutFacts(workout: workout)?.unitBadge(appUnit: appUnit),
            onRename: {
                renameText = workout.name ?? ""
                renamingWorkout = true
            })
            .historyPageRow(top: 8, bottom: 6)

        if let heroSegment {
            CardioHistoryHero(segment: heroSegment)
                .historyPageRow(top: 14, bottom: 0)
        }

        if let savedTemplateName {
            // The finish sheet's confirmation line, in place of the button (ticket 13).
            FinishSavedTemplateLine(name: savedTemplateName)
                .historyPageRow(top: 12, bottom: 0)
        } else if WorkoutTemplateService.canSaveAsTemplate(workout) {
            // Ticket 13: offered only when it can succeed (completed sets with a live exercise).
            Button { namingTemplate = true } label: {
                Label("Save as Template…", systemImage: "square.on.square")
            }
            .buttonStyle(.lookSecondary)
            .accessibilityIdentifier("saveAsTemplate")
            .historyPageRow(top: 12, bottom: 0)
        }

        if let summary {
            let tiles = FinishTile.summaryTiles(summary, unit: appUnit) { kind -> String in
                switch kind {
                case .workoutTime: "historyWorkoutTime"
                case .totalVolume: "historyVolume"
                case .activeCalories: "historyActiveCalories"
                case .totalCalories: "historyTotalCalories"
                case .averageHeartRate: "historyAverageHR"
                case .maxHeartRate: "historyMaxHR"
                }
            }.filter { heroSegment == nil || $0.tile.kind != .workoutTime }
            // A cardio-only workout with no calories or heart rate has no tile left: no empty heading.
            if !tiles.isEmpty {
                VStack(alignment: .leading, spacing: look.space.header) {
                    SectionHeader("Workout details")
                    FinishTileGrid(tiles: tiles)
                }
                .historyPageRow(top: 26, bottom: 0)
            }

            if let heroSegment {
                CardioSplitsSection(segment: heroSegment)
                    .historyPageRow(top: 26, bottom: 0)
            }

            if let comparison = receipt?.comparison {
                VStack(alignment: .leading, spacing: look.space.header) {
                    SectionHeader("Last \(comparison.templateName)")
                    ComparisonBars(
                        lastLabel: LookFormat.shortDate(comparison.lastDate),
                        last: WeightMath.convert(comparison.lastVolumeKg, from: .kg, to: appUnit),
                        today: WeightMath.convert(comparison.volumeKg, from: .kg, to: appUnit),
                        unit: appUnit.label)
                }
                .historyPageRow(top: 26, bottom: 0)
            }

            // Milestone 9, ticket 05: what the sensor saw — the graph when a series exists,
            // time in zones under it — in one plate (the receipt's). Older workouts never show
            // an empty chart; their aggregates are the tiles above.
            if summary.hasHeartRateSeries || summary.zoneSeconds.contains(where: { $0 > 0 }) {
                HeartRateSummarySection(summary: summary, sectionIdentifier: "historyHeartRateSection",
                                        zonesIdentifier: "historyZoneCard")
                    .historyPageRow(top: 26, bottom: 0)
            }
        }

        if !entries.isEmpty {
            SectionHeader(workout.recordedCardio.isEmpty ? "Exercises" : "Lifting",
                          trailing: HistoryRendering.pluralized(entries.count, "exercise", "exercises"))
                .historyPageRow(top: 30, bottom: 12)
            ForEach(Array(Supersets.runs(of: workout).enumerated()), id: \.offset) { runIndex, run in
                if runIndex > 0 {
                    Color.clear.frame(height: look.space.group).historyPageRow()
                }
                exercisePanel(run)
            }
        }

        // Add Exercise… sits right under the exercises it adds to.
        VStack(alignment: .leading, spacing: 8) {
            HistoryMakeRow(title: "Add Exercise…") { showExercisePicker = true }
                .accessibilityIdentifier("addHistoryExercise")
            Text("Recorded as defined today, without equipment.")
                .font(look.font.footnote)
                .foregroundStyle(look.textSecondary)
                .padding(.horizontal, 4)
        }
        .historyPageRow(top: 14, bottom: 0)

        let cardioCards = workout.recordedCardio.filter { $0.id != heroSegment?.id }
        if !cardioCards.isEmpty {
            VStack(alignment: .leading, spacing: look.space.header) {
                SectionHeader("Cardio")
                ForEach(cardioCards) { CardioSummaryCard(segment: $0) }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("historyCardioSection")
            .historyPageRow(top: 30, bottom: 0)
        }

        notesSection
            .historyPageRow(top: 30, bottom: 0)

        DestructiveRowButton("Delete Workout…") { confirmingDelete = true }
            .accessibilityIdentifier("deleteWorkout")
            .historyPageRow(top: 30, bottom: 40)
    }

    /// Working sets in workout order with their family — the hero ring. The family reads the
    /// live `muscleGroup` (the documented exception: it is not snapshotted).
    private func ringSets(_ entries: [ExerciseEntry]) -> [MuscleFamily?] {
        entries.flatMap { entry in
            let family = MuscleFamily(muscleGroup: entry.exercise?.muscleGroup)
            return WorkoutSession.orderedSets(of: entry)
                .filter { $0.completedAt != nil && $0.type.countsTowardRecords }
                .map { _ in family }
        }
    }

    // MARK: Exercises

    /// One panel per run: a superset's members share it, lettered A/B.
    @ViewBuilder
    private func exercisePanel(_ run: [ExerciseEntry]) -> some View {
        let lettered = run.count > 1
        ForEach(Array(run.enumerated()), id: \.element.id) { index, entry in
            let sets = WorkoutSession.orderedSets(of: entry).filter { $0.completedAt != nil }
            let isLastEntry = index == run.count - 1
            HistoryEntryHeader(
                entry: entry,
                letter: lettered ? String(Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")[min(index, 25)]) : nil,
                onChart: { chartingEntry = entry }
            ) {
                entryMenu(entry)
            }
            .historyPanelRow(first: index == 0, last: isLastEntry && sets.isEmpty, separatorInset: 0)
            ForEach(Array(sets.enumerated()), id: \.element.id) { setIndex, set in
                Button { editingSet = set } label: {
                    HistorySetLine(
                        record: set,
                        number: sets[...setIndex].filter { $0.type != .warmup }.count,
                        loadType: entry.snapshotLoadType,
                        badge: marks[set.id],
                        displayUnit: displayUnit)
                }
                .buttonStyle(HistoryRowPressStyle())
                .accessibilityIdentifier("historySetLine")
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        confirmingSetDelete = set
                    } label: { Label("Delete", systemImage: "trash") }
                }
                .historyPanelRow(first: false, last: isLastEntry && setIndex == sets.count - 1,
                                 separatorInset: setIndex == 0 ? nil : 62)
            }
            if !isLastEntry {
                Color.clear.frame(height: 8)
                    .historyPanelRow(first: false, last: false, separatorInset: nil)
            }
        }
    }

    /// The exercise's "…": Add Set, its load type (repairs a set logged under the wrong type —
    /// the case correcting the EXERCISE cannot reach, because history is frozen), Remove Exercise.
    private func entryMenu(_ entry: ExerciseEntry) -> some View {
        Menu {
            Button("Add Set", systemImage: "plus") { addSet(to: entry) }
                .accessibilityIdentifier("addHistorySet")
            Picker(selection: Binding(
                get: { entry.snapshotLoadType },
                set: { retype(entry, to: $0) })
            ) {
                ForEach(LoadType.allCases, id: \.self) { Text($0.badge).tag($0) }
            } label: {
                Label("Load type", systemImage: "scalemass")
            }
            .pickerStyle(.menu)
            Divider()
            Button("Remove Exercise", systemImage: "trash", role: .destructive) {
                confirmingEntryDelete = entry
            }
            .accessibilityIdentifier("removeHistoryExercise")
        } label: {
            HistoryIconFace(symbol: "ellipsis")
        }
        .accessibilityLabel("Options")
        .accessibilityIdentifier("historyEntryLoadType")
    }

    // MARK: Notes

    /// The note (tap to edit), or a dashed Add Note… when there is none yet.
    @ViewBuilder private var notesSection: some View {
        if workout.notes.isEmpty {
            HistoryMakeRow(title: "Add Note…", symbol: "square.and.pencil") {
                notesText = ""
                editingNotes = true
            }
            .accessibilityIdentifier("addHistoryNote")
        } else {
            VStack(alignment: .leading, spacing: look.space.header) {
                SectionHeader("Notes")
                Button {
                    notesText = workout.notes
                    editingNotes = true
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Text(workout.notes)
                            .font(look.font.body)
                            .foregroundStyle(look.textPrimary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "pencil")
                            .font(.system(.footnote, weight: .semibold))
                            .foregroundStyle(look.textTertiary)
                    }
                    .padding(16)
                    .lookSurface(.panel)
                }
                .buttonStyle(.lookPressable)
                .accessibilityHint("Edits the note")
                .accessibilityIdentifier("historyNotes")
            }
        }
    }

    // MARK: Units

    /// A quiet capsule naming the current mode ("As entered", "kg", "lb") — display only;
    /// nothing is rewritten (D9/D52).
    private var unitsMenu: some View {
        Menu {
            Picker("Units", selection: $displayUnit) {
                Text("As entered").tag(WeightUnit?.none)
                ForEach(WeightUnit.allCases) { unit in
                    Text("Show in \(unit.rawValue)").tag(WeightUnit?.some(unit))
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(displayUnit?.rawValue ?? "As entered")
                Image(systemName: "chevron.down").font(.system(.caption2, weight: .bold))
            }
            .font(.system(.subheadline, weight: .semibold))
            .foregroundStyle(look.textPrimary)
            .padding(.horizontal, 6)
            .fixedSize()
        }
        .accessibilityLabel(displayUnit?.rawValue ?? "As entered")
        .accessibilityHint("Units")
        .accessibilityIdentifier("historyUnits")
    }

    // MARK: Actions

    private func addExercise(_ exercise: Exercise) {
        guard let pair = HistoryEditing.addEntry(
            for: exercise, to: workout, in: modelContext)
        else { return }
        save()
        // Straight into the editor: the new set has no values yet, and an
        // entry whose sets are all unloggable would render as an exercise with
        // nothing under it.
        addedSet = pair.set
        pendingNewSet = pair.set
    }

    private func addSet(to entry: ExerciseEntry) {
        guard let set = HistoryEditing.addSet(to: entry, in: modelContext) else { return }
        save()
        addedSet = set
        pendingNewSet = set
    }

    /// Called when the editor for a just-added set closes. An addition the user abandoned
    /// leaves nothing behind (its exercise too, when that was all it had).
    private func discardIncompleteAddition() {
        defer { addedSet = nil; pendingNewSet = nil }
        guard let set = addedSet else { return }
        if HistoryEditing.pruneAbandonedSet(set, in: modelContext) {
            save()
            // The prune is unmarked, so nothing else refreshes the cached receipt and marks: an
            // abandoned exercise must not leave its family in the hero (Codex review 05b).
            rebuildDerived()
        }
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
}

/// The set confirmation's words: the existing message, and — when it is the exercise's only
/// set — that the exercise goes too (deleting the last set removes the entry).
enum HistoryDeleteCopy {
    static func set(_ set: SetRecord?) -> String {
        var text = "This set is removed permanently, and records and volume are recalculated without it."
        if let set, !set.isDeleted, let entry = set.entry, !entry.isDeleted,
           (entry.sets ?? []).filter({ !$0.isDeleted }).count == 1 {
            text += " \(entry.snapshotExerciseName) has no other sets, so it is removed from this workout too."
        }
        return text
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
