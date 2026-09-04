import Foundation
import SwiftData

// Ticket 07 — the core logging loop as a UI-free service over ModelContext.
// Every mutation persists via an explicit `context.save()` at the defined
// boundary (SPEC "Recording experience"): set completion toggle, set
// add/delete, entry add/delete/move, equipment choice, unit toggle, and
// text-field commit on end-editing. In-progress keystrokes are not
// durability-guaranteed — views hold them in local state until commit.
//
// Views construct a `WorkoutSession` around the environment's ModelContext;
// tests construct one around a disk-backed container's context and reopen
// the store to prove durability.

/// How a finish resolved (A2, ticket 17).
enum WorkoutFinishOutcome: Equatable {
    /// At least one entry survived cleanup carrying a completed set: the
    /// workout is stamped `finishedAt` and is now history.
    case saved
    /// Nothing was ever logged, so the workout was deleted rather than
    /// finished. An empty row in History is litter, not a record — and a
    /// caller that says "saved" about it would be lying.
    case discardedEmpty
}

/// Errors the logging service refuses to paper over.
enum WorkoutSessionError: Error, Equatable {
    /// A1 (ticket 17): completion was attempted on a row that does not carry
    /// the values its load type requires. The UI disables the checkmark until
    /// the row is loggable, so reaching this is a programming error — but the
    /// service is the honest boundary, not the view.
    case setNotLoggable
}

extension ExerciseEntry {
    /// The load type this entry's sets are judged and displayed under. Once
    /// the entry's snapshot is frozen (D19) that snapshot decides — a catalog
    /// reconciliation (D24) or an exercise edit mid-workout must not make
    /// later sets validate under different rules than the ones they enter
    /// history with. A weighted snapshot silently accepting reps-only would
    /// put `— × reps` rows back into history, which is exactly what A1 exists
    /// to prevent. Before the freeze the live exercise still owns the answer.
    var effectiveLoadType: LoadType {
        guard snapshotCapturedAt == nil else { return snapshotLoadType }
        return exercise?.loadType ?? snapshotLoadType
    }
}

struct WorkoutSession {

    let context: ModelContext
    /// Owns rest-timer teardown so ending a workout can never leave a pending
    /// local notification behind (it used to be correct only because every
    /// call site happened to skip the timer first).
    private let restTimer: RestTimerService

    init(
        context: ModelContext,
        notifications: any RestNotificationScheduling = UserNotificationScheduler.shared
    ) {
        self.context = context
        self.restTimer = RestTimerService(context: context, notifications: notifications)
    }

    // MARK: - Lifecycle

    /// Starts a persisted empty workout at `gym` (or no gym). Enforces the
    /// at-most-one-active invariant: any still-active workouts are finished
    /// first (with finish cleanup) — the UI offers Resume before calling this.
    @discardableResult
    func startWorkout(at gym: Gym?, on date: Date = .now) throws -> Workout {
        for stray in try activeWorkouts() {
            try finishInPlace(stray, at: date)
        }
        // D23: the gym's name is snapshotted here, so a later rename cannot
        // rewrite what this workout's history row says.
        let workout = Workout(
            startedAt: date, snapshotGymName: gym?.name, gym: gym)
        context.insert(workout)
        try context.save()
        return workout
    }

    /// Newest-active-wins recovery: returns the most recently started active
    /// workout (nil when none) and auto-finishes older strays, stamping their
    /// `finishedAt` and applying finish cleanup so only completed data
    /// reaches history.
    func resumableWorkout(at date: Date = .now) throws -> Workout? {
        let active = try activeWorkouts()
        guard let newest = active.first else { return nil }
        let strays = active.dropFirst()
        guard !strays.isEmpty else { return newest }
        for stray in strays {
            try finishInPlace(stray, at: date)
        }
        try context.save()
        return newest
    }

    /// Finish: deletes uncompleted draft set rows and entries with zero
    /// completed sets, then stamps `finishedAt` — only completed data
    /// reaches history.
    ///
    /// A2 (ticket 17): when nothing survives that cleanup the workout is
    /// *deleted* instead of finished, and the outcome says so, so the caller
    /// can tell "here is what you logged" from "there was nothing to log"
    /// rather than confirming a save that never happened.
    @discardableResult
    func finish(_ workout: Workout, at date: Date = .now) throws -> WorkoutFinishOutcome {
        let outcome = try finishInPlace(workout, at: date)
        try context.save()
        return outcome
    }

    /// Cancel: deletes the workout and its whole graph (entries cascade to
    /// sets). The UI confirms before calling this.
    /// Names (or un-names, with blank) a workout that is still running. NOT
    /// a history edit: the workout has not been logged yet, so nothing is
    /// marked — `HistoryEditing.rename` is the after-the-fact path (D50).
    ///
    /// Refuses a FINISHED workout (returns false, changes nothing): renaming
    /// logged history without the edit mark is the dishonest case, and the
    /// guard belongs here, not in whichever screen happened to call
    /// (codex-review 02, medium).
    @discardableResult
    func rename(_ workout: Workout, to name: String) throws -> Bool {
        guard !workout.isDeleted, workout.finishedAt == nil else { return false }
        let next = Workout.normalizedName(name)
        guard next != workout.name else { return false }
        workout.name = next
        try context.save()
        return true
    }

    func cancel(_ workout: Workout) throws {
        try restTimer.skip(workout)
        context.delete(workout)
        try context.save()
    }

    /// Active workouts, newest `startedAt` first.
    private func activeWorkouts() throws -> [Workout] {
        try context.fetch(FetchDescriptor<Workout>(
            predicate: #Predicate { $0.finishedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]))
    }

    @discardableResult
    private func finishInPlace(
        _ workout: Workout, at date: Date
    ) throws -> WorkoutFinishOutcome {
        // Ending the workout ends its rest: clearing the persisted timer and
        // cancelling the pending notification are one operation, owned by the
        // rest-timer service.
        try restTimer.skip(workout)
        var survivors = 0
        for entry in workout.entries ?? [] {
            let sets = entry.sets ?? []
            let completed = sets.filter { $0.completedAt != nil }
            for draft in sets where draft.completedAt == nil {
                context.delete(draft)
            }
            if completed.isEmpty {
                context.delete(entry)
            } else {
                survivors += 1
            }
        }
        // A2: Start → Finish with nothing logged used to leave a permanent
        // empty row in History. Nothing survived cleanup → nothing happened.
        guard survivors > 0 else {
            context.delete(workout)
            return .discardedEmpty
        }
        workout.finishedAt = date
        return .saved
    }

    // MARK: - Entries

    /// Appends an entry for `exercise` with one draft set whose unit follows
    /// the precedence chain (machine → gym → app preference).
    @discardableResult
    func addEntry(
        for exercise: Exercise,
        to workout: Workout,
        machine: MachineInstance? = nil,
        freeWeightTag: EquipmentTag? = nil
    ) throws -> ExerciseEntry {
        let order = (Self.orderedEntries(of: workout).last?.order).map { $0 + 1 } ?? 0
        let entry = ExerciseEntry(
            order: order,
            freeWeightTag: machine == nil ? freeWeightTag : nil,
            workout: workout,
            exercise: exercise,
            machine: machine,
            // D38: the machine's usual variation is preselected, never binding.
            preset: usualPreset(of: machine, for: exercise),
            // Provisional values; authoritative capture happens when the
            // first set completes (D23).
            snapshotExerciseID: exercise.id,
            snapshotLoadType: exercise.loadType,
            snapshotExerciseName: exercise.name)
        context.insert(entry)
        let set = SetRecord(order: 0, weightUnit: defaultUnit(for: entry), entry: entry)
        context.insert(set)
        try context.save()
        return entry
    }

    /// The preset if it belongs to this entry's exercise, otherwise nil.
    private func validated(_ preset: ExercisePreset?, for entry: ExerciseEntry) -> ExercisePreset? {
        guard let preset else { return nil }
        let exerciseID = entry.exercise?.id ?? entry.snapshotExerciseID
        return preset.exercise?.id == exerciseID ? preset : nil
    }

    /// Clears weight/reps on draft rows that still hold auto-prefilled values.
    ///
    /// Prefill writes into the draft row itself, so changing the variation (or
    /// the equipment) leaves last session's *other* context sitting in the
    /// inputs, one tap from being logged as this one. A row the user has
    /// touched is left alone — `prefilledAt` is set only by the prefill path
    /// and cleared by any commit.
    ///
    /// The row's **bar** survives this (D39): a bar is equipment, and changing
    /// grip does not put a different bar in the user's hands. Clearing it would
    /// mean re-picking the bar on every preset tap to log the same barbell.
    private func clearUntouchedDrafts(of entry: ExerciseEntry) {
        for set in Self.orderedSets(of: entry)
        where set.completedAt == nil && set.prefilledAt != nil {
            set.weightValue = nil
            set.normalizedKg = nil
            set.reps = nil
            set.prefilledAt = nil
        }
    }

    /// Drops bar mode from an entry's uncompleted rows. Called when the
    /// *equipment* changes: a bar belongs to the barbell it came from, so
    /// carrying a 45 lb bar onto a machine — or onto a Smith, whose carriage
    /// weighs whatever it weighs — would add a bar's weight to sets performed
    /// without one. Completed rows keep theirs; they record what happened.
    private func clearBars(of entry: ExerciseEntry) {
        for set in Self.orderedSets(of: entry) where set.completedAt == nil {
            set.barWeightValue = nil
            set.barNormalizedKg = nil
        }
    }

    /// The machine's usual preset (D38), resolved against the exercise that is
    /// actually being logged — a stale id pointing at another exercise's preset,
    /// or at one since deleted, degrades to "none chosen" rather than attaching
    /// a variation from a different movement.
    func usualPreset(of machine: MachineInstance?, for exercise: Exercise) -> ExercisePreset? {
        guard let presetID = machine?.defaultPresetID else { return nil }
        return (exercise.presets ?? []).first { $0.id == presetID }
    }

    /// Machine-first logging (D7): the exercises linked to `machine`'s
    /// equipment model, resolved from the model's scalar `exerciseIDs` in
    /// link order. Exactly one → the UI auto-fills it with zero extra
    /// prompts; several → the UI offers a chooser restricted to these; empty
    /// (model-less machine, or no link resolves) → the UI falls back to the
    /// full exercise picker.
    func exercisesFor(machine: MachineInstance) throws -> [Exercise] {
        let ids = machine.model?.exerciseIDs ?? []
        guard !ids.isEmpty else { return [] }
        let fetched = try context.fetch(FetchDescriptor<Exercise>(
            predicate: #Predicate { ids.contains($0.id) }))
        let byID = Dictionary(fetched.map { ($0.id, $0) }) { first, _ in first }
        return ids.compactMap { byID[$0] }
    }

    /// Machine-first add (D7): appends an entry with the machine already
    /// set. `exercise` is the machine's single linked exercise (auto-fill),
    /// the one chosen from a multi-exercise station's chooser, or any
    /// exercise from the full picker when the machine has no model.
    @discardableResult
    func addEntry(
        machine: MachineInstance,
        exercise: Exercise,
        to workout: Workout
    ) throws -> ExerciseEntry {
        try addEntry(for: exercise, to: workout, machine: machine)
    }

    /// Deletes an entry, then repairs any superset left holding a single
    /// member.
    ///
    /// codex-review 2 (high): `Supersets.pruneOrphanGroups` existed and NOTHING
    /// CALLED IT — the absence-of-a-caller bug, for the fifth time in this
    /// repo, in a ticket whose own notes warned about that exact shape. A
    /// deleted member left a stale group id that export and template capture
    /// then faithfully preserved.
    func deleteEntry(_ entry: ExerciseEntry) throws {
        let workout = entry.workout
        context.delete(entry)
        if let workout, !workout.isDeleted { Supersets.pruneOrphanGroups(in: workout) }
        if let workout {
            renumber(Self.orderedEntries(of: workout).filter { $0 !== entry })
        }
        try context.save()
    }

    /// Moves `entry` to `index` within its workout's ordered entries.
    /// Reorders a workout's exercises, taking SwiftUI's own move semantics
    /// (`IndexSet` + destination) so the drag gesture needs no translation
    /// layer that could get the off-by-one wrong.
    ///
    /// Replaces a `moveEntry(_:toIndex:)` that existed from milestone 2 and was
    /// never called by anything — dead code kept alive by its own tests. One
    /// mover, used by the one caller that needs it.
    func moveEntries(
        of workout: Workout, fromOffsets source: IndexSet, toOffset destination: Int
    ) throws {
        guard !workout.isDeleted else { return }
        var entries = Self.orderedEntries(of: workout).filter { !$0.isDeleted }
        entries.move(fromOffsets: source, toOffset: destination)
        renumber(entries)
        // D48 groups supersets by ADJACENCY, so a move can split a group or
        // leave one holding a single member. Repairing here keeps a badge from
        // surviving on an exercise that is no longer supersetted.
        Supersets.pruneOrphanGroups(in: workout)
        try context.save()
    }

    /// Equipment choice (D19). Pass a machine, a free-weight tag, or neither.
    /// While the entry is a draft (no set ever completed) the choice edits it
    /// in place. Once frozen, choosing different equipment starts a NEW entry
    /// right after it: uncompleted draft rows move over, completed sets and
    /// the old entry's snapshot stay untouched. Returns the entry now holding
    /// the draft rows (the new entry when a split happened).
    @discardableResult
    func chooseEquipment(
        for entry: ExerciseEntry,
        machine: MachineInstance?,
        freeWeightTag: EquipmentTag?
    ) throws -> ExerciseEntry {
        let tag = machine == nil ? freeWeightTag : nil
        if entry.machine?.id == machine?.id && entry.freeWeightTag == tag {
            return entry // no change
        }
        guard entry.snapshotCapturedAt != nil else {
            entry.machine = machine
            entry.freeWeightTag = tag
            clearBars(of: entry)
            try context.save()
            return entry
        }

        // Frozen: split into a new entry ordered right after the old one. The
        // variation follows the user across the equipment change; the new
        // machine's usual preset does not override a deliberate pick.
        return try split(entry, machine: machine, freeWeightTag: tag, preset: entry.preset)
    }

    /// Picks the variation performed (D36–D38).
    ///
    /// Same freeze rule as equipment (D19), for the same reason: once a set has
    /// completed, its snapshot says which variation it was, and records key on
    /// that. Switching afterwards therefore starts a new entry rather than
    /// relabelling completed work — a wide-grip set must never become a
    /// narrow-grip set because the user changed handles for their next three.
    @discardableResult
    func choosePreset(_ preset: ExercisePreset?, for entry: ExerciseEntry) throws
        -> ExerciseEntry {
        // A preset belongs to one exercise (D37). Accepting a foreign one would
        // snapshot and group a Leg Press variation onto a Seated Row — the
        // service owns that rule, not whichever view happens to call it
        // (codex-review, finding 4).
        let preset = validated(preset, for: entry)
        guard entry.preset?.id != preset?.id else { return entry }
        guard entry.snapshotCapturedAt != nil else {
            entry.preset = preset
            // Values auto-filled for the previous variation are not evidence
            // about this one (finding 3).
            clearUntouchedDrafts(of: entry)
            try context.save()
            return entry
        }

        return try split(
            entry, machine: entry.machine, freeWeightTag: entry.freeWeightTag, preset: preset)
    }

    /// Starts a new entry carrying `machine`/`freeWeightTag`/`preset`, ordered
    /// right after `entry`, and moves its uncompleted rows across.
    ///
    /// One implementation, because there are two ways to change an entry's
    /// context (equipment, D19; variation, D36) and they must behave
    /// identically. They did not: the duplicate let the "inherited values do
    /// not cross a context change" rule be written once and missed once
    /// (codex-review, standards finding 2).
    /// Re-files a draft-or-running entry under its dumbbell counterpart
    /// (milestone 9, ticket 04): the equipment sheet offers "Log as Dumbbell
    /// Bench Press instead" where it used to offer the Dumbbell tag, so the
    /// old split — dumbbell sets under a barbell-named exercise — cannot
    /// re-grow. Same lifecycle rule as `chooseEquipment` (D19): a draft entry
    /// is edited in place; a frozen one gets a NEW entry for the counterpart
    /// and its draft rows move over. The preset is dropped either way — a
    /// preset belongs to its exercise (D37).
    ///
    /// Deliberately NOT a general "switch exercise": it only accepts an entry
    /// whose exercise has a mapped counterpart present in the store, and
    /// returns nil otherwise (codex-review 04). The tag is `.dumbbell` by
    /// definition of the operation, not guessed from the target's tags.
    @discardableResult
    func switchToDumbbellCounterpart(of entry: ExerciseEntry) throws -> ExerciseEntry? {
        guard !entry.isDeleted,
              let sourceID = entry.exercise?.id,
              let targetID = DumbbellCounterparts.counterpart(of: sourceID)
        else { return nil }
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == targetID })
        guard let exercise = try context.fetch(descriptor).first else { return nil }
        let tag: EquipmentTag? = .dumbbell
        guard entry.snapshotCapturedAt != nil else {
            entry.exercise = exercise
            entry.machine = nil
            entry.freeWeightTag = tag
            entry.preset = nil
            // Provisional snapshot, exactly as `addEntry` sets it; the
            // authoritative capture still happens at first completion (D23).
            entry.snapshotExerciseID = exercise.id
            entry.snapshotLoadType = exercise.loadType
            entry.snapshotExerciseName = exercise.name
            clearBars(of: entry)
            clearUntouchedDrafts(of: entry)
            try context.save()
            return entry
        }
        return try split(entry, machine: nil, freeWeightTag: tag, preset: nil, exercise: exercise)
    }

    private func split(
        _ entry: ExerciseEntry,
        machine: MachineInstance?,
        freeWeightTag: EquipmentTag?,
        preset: ExercisePreset?,
        exercise newExercise: Exercise? = nil
    ) throws -> ExerciseEntry {
        guard let workout = entry.workout, let exercise = newExercise ?? entry.exercise else { return entry }
        // The new entry sits right after the old one, so carrying the group id
        // keeps a superset's adjacency run intact (D48). Without this, a
        // split inside a superset severed it and changed when rest was taken
        // (codex-review 04, high). Prune afterwards in case the old entry is
        // left holding a group alone.
        let supersetGroupID = entry.supersetGroupID
        // A preset change leaves the bar in the user's hands; an equipment
        // change does not (see `clearBars`). One split serves both, so the
        // difference has to be read from the arguments rather than assumed.
        let equipmentChanged =
            entry.machine?.id != machine?.id || entry.freeWeightTag != freeWeightTag
        var entries = Self.orderedEntries(of: workout)
        let newEntry = ExerciseEntry(
            order: 0,
            freeWeightTag: machine == nil ? freeWeightTag : nil,
            workout: workout,
            exercise: exercise,
            machine: machine,
            preset: validated(preset, for: entry),
            snapshotExerciseID: exercise.id,
            snapshotLoadType: exercise.loadType,
            snapshotExerciseName: exercise.name)
        newEntry.supersetGroupID = supersetGroupID
        context.insert(newEntry)
        if let position = entries.firstIndex(where: { $0.id == entry.id }) {
            entries.insert(newEntry, at: position + 1)
        } else {
            entries.append(newEntry)
        }
        renumber(entries)
        Supersets.pruneOrphanGroups(in: workout)

        // Draft rows move to the new entry, preserving relative order;
        // completed sets stay behind. Values the row *inherited* — cross-workout
        // prefill or within-session carry-forward — describe the context being
        // left, so the row moves and the false comparison does not (D36).
        let drafts = Self.orderedSets(of: entry).filter { $0.completedAt == nil }
        for (offset, draft) in drafts.enumerated() {
            draft.entry = newEntry
            draft.order = offset
            if equipmentChanged {
                draft.barWeightValue = nil
                draft.barNormalizedKg = nil
            }
            if draft.prefilledAt != nil {
                draft.weightValue = nil
                draft.normalizedKg = nil
                draft.reps = nil
                draft.prefilledAt = nil
            }
        }
        renumber(sets: Self.orderedSets(of: entry))
        if drafts.isEmpty {
            let set = SetRecord(
                order: 0, weightUnit: defaultUnit(for: newEntry), entry: newEntry)
            context.insert(set)
        }
        try context.save()
        return newEntry
    }

    // MARK: - Sets

    /// Appends a draft set.
    ///
    /// B1 (ticket 17) — within-session carry-forward: the row is seeded from
    /// the entry's last **completed** set (weight value, unit, reps) and
    /// arrives uncompleted, so a repeat set costs one tap — the same contract
    /// as ticket 11's cross-workout prefill. On a 4-set exercise the numbers
    /// are typed once.
    ///
    /// With nothing completed yet the old behaviour stands: the last row's
    /// unit as entered (else the precedence chain machine → gym → app
    /// preference) and no values, leaving ticket 11's prefill to populate the
    /// row from previous workouts.
    @discardableResult
    func addSet(to entry: ExerciseEntry) throws -> SetRecord {
        let existing = Self.orderedSets(of: entry)
        let carryForward = existing.last { $0.completedAt != nil }
        // Every inherited field comes from one row. Falling back only the bar
        // to a differently configured draft can pair 45 lb with a kg total.
        let source = carryForward ?? existing.last
        let unit = source?.weightUnit
            ?? defaultUnit(for: entry)
        // The bar comes from the same row as the unit, so the two always agree
        // (D40) — a bar's weight is stated in its own unit, and pairing a 20 kg
        // bar with an lb row would read as a 20 lb one.
        let set = SetRecord(
            order: (existing.last?.order).map { $0 + 1 } ?? 0,
            type: existing.last?.type ?? .working,
            reps: carryForward?.reps,
            weightValue: carryForward?.weightValue,
            weightUnit: unit,
            // Carried from the same source set, so it already matches `unit`.
            normalizedKg: carryForward?.normalizedKg,
            barWeightValue: source?.barWeightValue,
            barNormalizedKg: source?.resolvedBarWeight?.normalizedKg,
            // Carry-forward is inherited too: it comes from a completed set of
            // *this* entry, which is exactly the context a preset switch leaves
            // behind (D36).
            prefilledAt: carryForward == nil ? nil : .now,
            entry: entry)
        context.insert(set)
        try context.save()
        return set
    }

    func deleteSet(_ set: SetRecord) throws {
        let entry = set.entry
        context.delete(set)
        if let entry {
            renumber(sets: Self.orderedSets(of: entry).filter { $0 !== set })
        }
        try context.save()
    }

    /// Set-type cycle: working → warmup → failure → drop → working. The row's
    /// marker is a menu now (E5), so this is the keep-it-honest fallback path
    /// rather than the primary control — it still has to visit every type.
    func cycleSetType(_ set: SetRecord) throws {
        switch set.type {
        case .working: set.type = .warmup
        case .warmup: set.type = .failure
        case .failure: set.type = .drop
        case .drop: set.type = .working
        }
        try context.save()
    }

    /// Direct set-type pick (E5, ticket 17): the row's marker is a menu with
    /// named options, so the type can be chosen instead of cycled blindly.
    func setType(_ type: SetType, of set: SetRecord) throws {
        guard set.type != type else { return }
        set.type = type
        try context.save()
    }

    /// Weight-field commit (end-editing). Empty or unparseable input clears
    /// the draft value; a valid value recomputes `normalizedKg` atomically
    /// through `StoredWeight` (D25).
    func commitWeight(_ text: String, for set: SetRecord) throws {
        if let value = Self.weightValue(from: text),
           let stored = StoredWeight(value: value, unit: set.weightUnit) {
            set.weightValue = stored.value
            set.normalizedKg = stored.normalizedKg
        } else {
            set.weightValue = nil
            set.normalizedKg = nil
        }
        // Typed, not inherited — a context change must not clear this.
        set.prefilledAt = nil
        try context.save()
    }

    /// Reps-field commit (end-editing).
    func commitReps(_ text: String, for set: SetRecord) throws {
        set.reps = Self.repsValue(from: text)
        set.prefilledAt = nil
        try context.save()
    }

    /// kg/lb toggle: reinterprets the as-entered value in the other unit —
    /// never a silent conversion — recomputing `normalizedKg` (D25).
    ///
    /// Refused in bar mode (D40): the row's unit follows its bar, and
    /// reinterpreting "20" in the other unit would turn a 20 kg bar into a
    /// 20 lb one — a different piece of equipment, chosen by a stray tap. The
    /// UI disables the badge, so reaching this is a programming error; the
    /// service is the honest boundary, not the view.
    func toggleUnit(of set: SetRecord) throws {
        guard set.barWeightValue == nil else { return }
        set.weightUnit = set.weightUnit.toggled
        if let value = set.weightValue {
            set.normalizedKg = StoredWeight(value: value, unit: set.weightUnit)?.normalizedKg
        }
        try context.save()
    }

    // MARK: Bar mode (D39–D40)

    /// Whether a bar may be chosen for this entry: barbell and Smith work is
    /// loaded by hanging plates on a bar of known weight, and nothing else in
    /// the app is. A bar row on a cable pulldown would be noise.
    ///
    /// Two ways to be barbell work, because the app offers two ways to record
    /// it: the free-weight tag (D7 — barbells are not machines), and a machine
    /// instance whose catalog model is a rack or Smith (D24's `rackOrSmith`).
    /// Missing the second would hide the bar exactly where it is least
    /// guessable — a Smith carriage's weight is not written on it, and a squat
    /// rack picked from the catalog is a barbell station by any other name.
    static func offersBar(_ entry: ExerciseEntry) -> Bool {
        guard !entry.isDeleted else { return false }
        if let machine = entry.machine {
            return machine.model?.equipmentType == .rackOrSmith
        }
        switch entry.freeWeightTag {
        case .barbell, .smith: return true
        default: return false
        }
    }

    /// Picks the bar for `entry` (D39), or clears bar mode with nil.
    ///
    /// Applies to the entry's **uncompleted** rows only. A completed set keeps
    /// the bar it was logged under for the same reason it keeps its weight —
    /// changing history is not what picking up a different bar means.
    ///
    /// The stored weight is the total either way, so switching modes never
    /// rewrites it: clearing a bar leaves the same total sitting in the field,
    /// and choosing one re-reads that total as bar + plates. The value is
    /// dropped only when it cannot honestly be re-read — a row entered in the
    /// other unit (D25 forbids converting it silently, D40 forbids
    /// reinterpreting it) or a total lighter than the bar itself.
    func chooseBar(_ bar: BarPreset?, for entry: ExerciseEntry) throws {
        try applyBar(bar?.barWeight, for: entry)
    }

    /// Picker entry point: a validated bar travels as one domain value rather
    /// than a loose value/unit pair.
    func chooseBar(_ bar: BarWeight, for entry: ExerciseEntry) throws {
        try applyBar(bar, for: entry)
    }

    func clearBar(for entry: ExerciseEntry) throws {
        try applyBar(nil, for: entry)
    }

    /// Custom-bar entry point: any positive weight in either unit.
    func chooseBar(weight: Double?, unit: WeightUnit, for entry: ExerciseEntry) throws {
        try applyBar(weight.flatMap { BarWeight(value: $0, unit: unit) }, for: entry)
    }

    /// One storage boundary for preset and custom bars. `BarWeight` keeps the
    /// entered value, unit, and normalized value together before any row is
    /// touched, so they are written and carried as one fact.
    private func applyBar(_ bar: BarWeight?, for entry: ExerciseEntry) throws {
        // With every row already logged — the ordinary state after finishing a
        // set, since rows are only ever added deliberately — the pick has
        // nothing to land on, and a control that silently does nothing is the
        // failure mode this codebase keeps rediscovering. Picking a bar is a
        // statement about the next set, so make one.
        if Self.orderedSets(of: entry).allSatisfy({ $0.completedAt != nil }) {
            try addSet(to: entry)
        }
        for set in Self.orderedSets(of: entry) where set.completedAt == nil {
            guard let bar else {
                // Bar cleared: the number in the field was always the total, so
                // it stays exactly as it is and only its *label* changes.
                set.barWeightValue = nil
                set.barNormalizedKg = nil
                continue
            }
            if set.weightUnit != bar.unit
                || (set.weightValue.map { $0 < bar.value } ?? false) {
                set.weightValue = nil
                set.normalizedKg = nil
                set.prefilledAt = nil
            }
            set.weightUnit = bar.unit
            set.barWeightValue = bar.value
            set.barNormalizedKg = bar.normalizedKg
        }
        try context.save()
    }

    /// Plates-per-side commit (end-editing) for a bar-mode row. The text is
    /// what the user hung on **one** end; what gets stored is the total
    /// (`BarbellMath.total`) — the invariant every record in the app depends on.
    ///
    /// A row with no bar has no per-side reading, so the text is its total:
    /// falling through to `commitWeight` keeps a mode change mid-edit from
    /// silently doubling the user's number.
    func commitPerSide(_ text: String, for set: SetRecord) throws {
        guard let barWeight = set.barWeightValue else {
            return try commitWeight(text, for: set)
        }
        if let perSide = Self.weightValue(from: text),
           let stored = StoredWeight(
            value: BarbellMath.total(barWeight: barWeight, platesPerSide: perSide),
            unit: set.weightUnit) {
            set.weightValue = stored.value
            set.normalizedKg = stored.normalizedKg
        } else {
            set.weightValue = nil
            set.normalizedKg = nil
        }
        // Typed, not inherited — a context change must not clear this.
        set.prefilledAt = nil
        try context.save()
    }

    /// The plates a bar-mode row is showing, derived from its stored total.
    /// nil when the row has no bar, no weight yet, or a total lighter than its
    /// own bar (`BarbellMath.platesPerSide` refuses to invent negative plates).
    static func platesPerSide(of set: SetRecord) -> Double? {
        guard !set.isDeleted, let bar = set.barWeightValue, let total = set.weightValue
        else { return nil }
        return BarbellMath.platesPerSide(total: total, barWeight: bar)
    }

    // MARK: Loggability (A1)

    /// A1 (ticket 17) — the honesty gate on completion. A row may only be
    /// logged once it says something true: positive reps always, plus a
    /// weight *value* for every load type that carries one.
    ///
    /// `bodyweight` needs reps alone. `assisted` and `bodyweightPlus` need a
    /// value but accept `0` — zero assistance and zero added weight are both
    /// meaningful (they mirror ticket 12's record eligibility, `RecordsMath.
    /// isEligible`), whereas *nil* is simply an unanswered question.
    static func isLoggable(
        reps: Int?,
        weightValue: Double?,
        loadType: LoadType
    ) -> Bool {
        guard let reps, reps > 0 else { return false }
        switch loadType {
        case .bodyweight:
            return true
        case .weighted, .assisted, .bodyweightPlus:
            return weightValue != nil
        }
    }

    /// The load type a row is logged under (D19/D23) — see
    /// `ExerciseEntry.effectiveLoadType`.
    static func loadType(of set: SetRecord) -> LoadType {
        guard !set.isDeleted, let entry = set.entry, !entry.isDeleted else {
            return .weighted
        }
        return entry.effectiveLoadType
    }

    static func isLoggable(_ set: SetRecord) -> Bool {
        guard !set.isDeleted else { return false }
        return isLoggable(
            reps: set.reps,
            weightValue: set.weightValue,
            loadType: loadType(of: set))
    }

    /// A1, asked of what is on *screen*: the fields commit on end-editing and
    /// the completing tap is itself the commit, so the UI has to judge the
    /// text. Parsing lives here rather than in the view, so the checkmark can
    /// never enable on input the store will then refuse.
    static func isLoggable(
        weightText: String,
        repsText: String,
        loadType: LoadType
    ) -> Bool {
        isLoggable(
            reps: repsValue(from: repsText),
            weightValue: weightValue(from: weightText),
            loadType: loadType)
    }

    /// The weight a field's text stands for: decimal comma accepted, and only
    /// values `StoredWeight` will accept come back — a negative, NaN, or
    /// infinite entry is not a weight, so it reads as *no* value rather than
    /// as a present one the store would silently reject.
    static func weightValue(from text: String) -> Double? {
        guard let value = Double(
                text.trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: ",", with: ".")),
              WeightMath.isValidInput(value) else { return nil }
        return value
    }

    static func repsValue(from text: String) -> Int? {
        Int(text.trimmingCharacters(in: .whitespaces))
    }

    /// Completion toggle. Completing stamps `completedAt`, captures the
    /// entry's context snapshot when it is the first-ever completion (D23),
    /// and upserts GymExerciseMemory. Un-completing clears the stamp only —
    /// the equipment freeze survives (D19).
    ///
    /// A1: completing an empty (or under-specified) row throws
    /// `WorkoutSessionError.setNotLoggable` — an unlogged set is honest, a set
    /// reading `— × —` in history and feeding records is not. The guard only
    /// ever blocks the completing direction; an already-completed row can
    /// always be un-completed.
    func toggleCompletion(of set: SetRecord, at date: Date = .now) throws {
        if set.completedAt == nil {
            guard Self.isLoggable(set) else {
                throw WorkoutSessionError.setNotLoggable
            }
            set.completedAt = date
            if let entry = set.entry {
                if entry.snapshotCapturedAt == nil {
                    captureSnapshot(of: entry, at: date)
                }
                upsertMemory(for: entry, at: date)
            }
        } else {
            set.completedAt = nil
        }
        try context.save()
    }

    // MARK: - Notes

    /// Workout-notes commit (end-editing).
    func commitNotes(_ text: String, for workout: Workout) throws {
        workout.notes = text
        try context.save()
    }

    // MARK: - Snapshot & memory

    /// D23: stable UUIDs + loadType + freeWeightTag + display strings, taken
    /// from the live relationships at first completion and never rewritten.
    private func captureSnapshot(of entry: ExerciseEntry, at date: Date) {
        entry.snapshotCapturedAt = date
        entry.snapshotExerciseID = entry.exercise?.id ?? entry.snapshotExerciseID
        entry.snapshotMachineID = entry.machine?.id
        entry.snapshotModelID = entry.machine?.model?.id
        entry.snapshotGymID = entry.workout?.gym?.id
        entry.snapshotLoadType = entry.exercise?.loadType ?? entry.snapshotLoadType
        entry.snapshotFreeWeightTag = entry.freeWeightTag
        entry.snapshotExerciseName = entry.exercise?.name ?? entry.snapshotExerciseName
        entry.snapshotMachineLabel = entry.machine?.label
        entry.snapshotModelName = entry.machine?.model?.displayName
        entry.snapshotGymName = entry.workout?.gym?.name
        entry.snapshotPresetID = entry.preset?.id
        entry.snapshotPresetName = entry.preset?.name
    }

    /// App-level upsert (no unique constraints under CloudKit): among
    /// existing (gym, exercise) rows the latest `updatedAt` wins (ties by id)
    /// and is updated in place — duplicates are never added to.
    private func upsertMemory(for entry: ExerciseEntry, at date: Date) {
        guard let gymID = entry.workout?.gym?.id,
              let exerciseID = entry.exercise?.id else { return }
        let machineID = entry.machine?.id
        let rows = (try? context.fetch(FetchDescriptor<GymExerciseMemory>(
            predicate: #Predicate { $0.gymID == gymID && $0.exerciseID == exerciseID }
        ))) ?? []
        if let canonical = rows.canonical {
            canonical.machineID = machineID
            canonical.updatedAt = date
        } else {
            context.insert(GymExerciseMemory(
                gymID: gymID, exerciseID: exerciseID, machineID: machineID,
                updatedAt: date))
        }
    }

    // MARK: - Defaults & ordering

    /// Unit-default precedence for a new set (T7, ticket 05 function):
    /// machine → gym → app preference.
    func defaultUnit(for entry: ExerciseEntry) -> WeightUnit {
        let rows = (try? context.fetch(FetchDescriptor<AppPreferences>())) ?? []
        return UnitPrecedence.defaultUnit(
            machine: entry.machine,
            gym: entry.workout?.gym,
            appPreference: AppPreferences.canonical(of: rows)?.unitPreference)
    }

    static func orderedEntries(of workout: Workout) -> [ExerciseEntry] {
        (workout.entries ?? []).sorted { $0.order < $1.order }
    }

    static func orderedSets(of entry: ExerciseEntry) -> [SetRecord] {
        (entry.sets ?? []).sorted { $0.order < $1.order }
    }

    private func renumber(_ entries: [ExerciseEntry]) {
        for (offset, entry) in entries.enumerated() where entry.order != offset {
            entry.order = offset
        }
    }

    private func renumber(sets: [SetRecord]) {
        for (offset, set) in sets.enumerated() where set.order != offset {
            set.order = offset
        }
    }
}
