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
        let workout = Workout(startedAt: date, gym: gym)
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
    func finish(_ workout: Workout, at date: Date = .now) throws {
        try finishInPlace(workout, at: date)
        try context.save()
    }

    /// Cancel: deletes the workout and its whole graph (entries cascade to
    /// sets). The UI confirms before calling this.
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

    private func finishInPlace(_ workout: Workout, at date: Date) throws {
        // Ending the workout ends its rest: clearing the persisted timer and
        // cancelling the pending notification are one operation, owned by the
        // rest-timer service.
        try restTimer.skip(workout)
        for entry in workout.entries ?? [] {
            let sets = entry.sets ?? []
            let completed = sets.filter { $0.completedAt != nil }
            for draft in sets where draft.completedAt == nil {
                context.delete(draft)
            }
            if completed.isEmpty {
                context.delete(entry)
            }
        }
        workout.finishedAt = date
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

    func deleteEntry(_ entry: ExerciseEntry) throws {
        let workout = entry.workout
        context.delete(entry)
        if let workout {
            renumber(Self.orderedEntries(of: workout).filter { $0 !== entry })
        }
        try context.save()
    }

    /// Moves `entry` to `index` within its workout's ordered entries.
    func moveEntry(_ entry: ExerciseEntry, toIndex index: Int) throws {
        guard let workout = entry.workout else { return }
        var entries = Self.orderedEntries(of: workout)
        guard let from = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries.remove(at: from)
        entries.insert(entry, at: max(0, min(index, entries.count)))
        renumber(entries)
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
            try context.save()
            return entry
        }

        // Frozen: split into a new entry ordered right after the old one.
        guard let workout = entry.workout, let exercise = entry.exercise else {
            return entry
        }
        var entries = Self.orderedEntries(of: workout)
        let newEntry = ExerciseEntry(
            order: 0,
            freeWeightTag: tag,
            workout: workout,
            exercise: exercise,
            machine: machine,
            snapshotExerciseID: exercise.id,
            snapshotLoadType: exercise.loadType,
            snapshotExerciseName: exercise.name)
        context.insert(newEntry)
        if let position = entries.firstIndex(where: { $0.id == entry.id }) {
            entries.insert(newEntry, at: position + 1)
        } else {
            entries.append(newEntry)
        }
        renumber(entries)

        // Draft rows move to the new entry, preserving relative order;
        // completed sets stay behind.
        let drafts = Self.orderedSets(of: entry).filter { $0.completedAt == nil }
        for (offset, draft) in drafts.enumerated() {
            draft.entry = newEntry
            draft.order = offset
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

    /// Appends a draft set. Unit: last set's unit as entered, else the
    /// precedence chain (machine → gym → app preference).
    @discardableResult
    func addSet(to entry: ExerciseEntry) throws -> SetRecord {
        let existing = Self.orderedSets(of: entry)
        let unit = existing.last?.weightUnit ?? defaultUnit(for: entry)
        let set = SetRecord(
            order: (existing.last?.order).map { $0 + 1 } ?? 0,
            type: existing.last?.type ?? .working,
            weightUnit: unit,
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

    /// Set-type cycle used by the row's marker button: working → warmup →
    /// failure → working.
    func cycleSetType(_ set: SetRecord) throws {
        switch set.type {
        case .working: set.type = .warmup
        case .warmup: set.type = .failure
        case .failure: set.type = .working
        }
        try context.save()
    }

    /// Weight-field commit (end-editing). Empty or unparseable input clears
    /// the draft value; a valid value recomputes `normalizedKg` atomically
    /// through `StoredWeight` (D25).
    func commitWeight(_ text: String, for set: SetRecord) throws {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")),
           let stored = StoredWeight(value: value, unit: set.weightUnit) {
            set.weightValue = stored.value
            set.normalizedKg = stored.normalizedKg
        } else {
            set.weightValue = nil
            set.normalizedKg = nil
        }
        try context.save()
    }

    /// Reps-field commit (end-editing).
    func commitReps(_ text: String, for set: SetRecord) throws {
        set.reps = Int(text.trimmingCharacters(in: .whitespaces))
        try context.save()
    }

    /// kg/lb toggle: reinterprets the as-entered value in the other unit —
    /// never a silent conversion — recomputing `normalizedKg` (D25).
    func toggleUnit(of set: SetRecord) throws {
        set.weightUnit = set.weightUnit.toggled
        if let value = set.weightValue {
            set.normalizedKg = StoredWeight(value: value, unit: set.weightUnit)?.normalizedKg
        }
        try context.save()
    }

    /// Completion toggle. Completing stamps `completedAt`, captures the
    /// entry's context snapshot when it is the first-ever completion (D23),
    /// and upserts GymExerciseMemory. Un-completing clears the stamp only —
    /// the equipment freeze survives (D19).
    func toggleCompletion(of set: SetRecord, at date: Date = .now) throws {
        if set.completedAt == nil {
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
        if let canonical = rows.max(by: {
            ($0.updatedAt, $0.id.uuidString) < ($1.updatedAt, $1.id.uuidString)
        }) {
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
