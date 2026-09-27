import Foundation
import SwiftData

// Floodlight redesign ticket 06 — the Gyms tab's derived facts: a gym's visits (distinct days),
// last visit and eight-week rhythm, the tab's order, and each machine's use — how often, when last,
// and the best it holds per record scope. Derived on read from finished workouts; nothing here is
// stored. Machine facts read the entry SNAPSHOT (D23): a machine renamed or re-modelled keeps its
// history because the scope is its id.

/// One finished workout, as the gym facts need it.
struct GymVisitInput: Hashable {
    var gymID: UUID?
    var startedAt: Date
}

/// A gym's use: visits are distinct calendar days with a finished workout there (a lift and a run
/// on one day are one visit).
struct GymVisits: Hashable {
    var visits: Int
    var lastVisit: Date?
    /// Visits per week, oldest first; the last element is this week.
    var weekly: [Int]

    static let none = GymVisits(visits: 0, lastVisit: nil, weekly: Array(repeating: 0, count: 8))
}

/// One logged set on a machine, with the workout it belongs to.
struct MachineSetInput: Equatable {
    var workoutID: UUID
    var workoutStartedAt: Date
    var set: RecordSetInput
}

/// The best set of one record scope on a machine: exercise × preset × load type (D36/D20).
struct MachineBest: Identifiable, Equatable {
    var exerciseID: UUID
    var presetID: UUID?
    var loadType: LoadType
    var best: RecordSetInput
    /// Workouts with a completed set in this scope.
    var workouts: Int
    var lastUsed: Date

    var id: String { "\(exerciseID.uuidString)|\(presetID?.uuidString ?? "-")|\(loadType.rawValue)" }

    /// The progress chart's variation for this scope on `machineID`.
    func variation(on machineID: UUID) -> ProgressVariationKey {
        ProgressVariationKey(loadType: loadType, equipment: .machine(machineID), presetID: presetID)
    }
}

/// What a machine has been used for, from its snapshots.
struct MachineUse: Equatable {
    /// Workouts with a completed set on it.
    var workouts: Int
    var lastUsed: Date?
    /// Completed sets, warmups included (the History rows' "sets" count every completed set).
    var sets: Int
    /// One per record scope with an eligible set, most-used first, then most recent.
    var bests: [MachineBest]
    /// When each exercise was last done on it (Exercise grouping shows that exercise's day).
    var lastUsedByExercise: [UUID: Date]

    static let unused = MachineUse(workouts: 0, lastUsed: nil, sets: 0, bests: [], lastUsedByExercise: [:])

    /// The row's best: the most-used scope's, or under Exercise grouping that exercise's.
    func best(for exerciseID: UUID? = nil) -> MachineBest? {
        guard let exerciseID else { return bests.first }
        return bests.first { $0.exerciseID == exerciseID }
    }

    func lastUsed(for exerciseID: UUID? = nil) -> Date? {
        guard let exerciseID else { return lastUsed }
        return lastUsedByExercise[exerciseID]
    }
}

enum GymOverviewMath {
    /// Visits, last visit and the last `weeks` weeks (the phone's weeks, as Home and History).
    static func visits(of gymID: UUID, in workouts: [GymVisitInput], now: Date, weeks: Int = 8,
                       calendar: Calendar = .current) -> GymVisits {
        let days = Set(workouts.filter { $0.gymID == gymID }.map { calendar.startOfDay(for: $0.startedAt) })
        var weekly = Array(repeating: 0, count: weeks)
        if let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start {
            for index in 0..<weeks {
                guard let start = calendar.date(byAdding: .weekOfYear, value: index - (weeks - 1), to: thisWeek),
                      let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else { continue }
                weekly[index] = days.filter { $0 >= start && $0 < end }.count
            }
        }
        return GymVisits(visits: days.count, lastVisit: workouts.filter { $0.gymID == gymID }.map(\.startedAt).max(),
                         weekly: weekly)
    }

    /// The Gyms tab's order: the gym Home is set to, then the most recently visited, then by name.
    static func order(_ gyms: [(id: UUID, name: String)], current: UUID?, lastVisit: [UUID: Date]) -> [UUID] {
        gyms.sorted { a, b in
            if (a.id == current) != (b.id == current) { return a.id == current }
            let la = lastVisit[a.id] ?? .distantPast, lb = lastVisit[b.id] ?? .distantPast
            if la != lb { return la > lb }
            let byName = a.name.localizedStandardCompare(b.name)
            if byName != .orderedSame { return byName == .orderedAscending }
            return a.id.uuidString < b.id.uuidString
        }
        .map(\.id)
    }

    /// Every machine's use, keyed by machine id, from sets whose SNAPSHOT names the machine.
    static func machineUse(_ inputs: [MachineSetInput]) -> [UUID: MachineUse] {
        let completed = inputs.filter { $0.set.completedAt != nil }
        var result: [UUID: MachineUse] = [:]
        for (machineID, sets) in Dictionary(grouping: completed, by: { $0.set.machineID }) {
            guard let machineID else { continue }
            result[machineID] = use(of: sets)
        }
        return result
    }

    private struct ScopeKey: Hashable {
        var exerciseID: UUID
        var presetID: UUID?
        var loadType: LoadType
    }

    private static func use(of sets: [MachineSetInput]) -> MachineUse {
        var lastByExercise: [UUID: Date] = [:]
        for input in sets {
            let exerciseID = input.set.exerciseID
            lastByExercise[exerciseID] = max(lastByExercise[exerciseID] ?? .distantPast, input.workoutStartedAt)
        }
        let eligible = sets.filter { RecordsMath.isEligible($0.set) }
        let scopes = Dictionary(grouping: eligible) {
            ScopeKey(exerciseID: $0.set.exerciseID, presetID: $0.set.presetID, loadType: $0.set.loadType)
        }
        let bests = scopes.compactMap { key, members -> MachineBest? in
            // `outranks` owns the direction (assisted: lower is better), then reps, then the
            // earlier set on a tie. Plain bodyweight ranks by reps, as the records do.
            guard let first = members.first?.set else { return nil }
            let best = members.dropFirst().map(\.set).reduce(first) { incumbent, candidate in
                RecordsMath.outranks(candidate, incumbent) ? candidate : incumbent
            }
            return MachineBest(exerciseID: key.exerciseID, presetID: key.presetID, loadType: key.loadType,
                               best: best, workouts: Set(members.map(\.workoutID)).count,
                               lastUsed: members.map(\.workoutStartedAt).max() ?? .distantPast)
        }
        .sorted { a, b in
            if a.workouts != b.workouts { return a.workouts > b.workouts }
            if a.lastUsed != b.lastUsed { return a.lastUsed > b.lastUsed }
            return a.id < b.id
        }
        return MachineUse(workouts: Set(sets.map(\.workoutID)).count,
                          lastUsed: sets.map(\.workoutStartedAt).max(),
                          sets: sets.count, bests: bests, lastUsedByExercise: lastByExercise)
    }

    /// "Today" / "Yesterday" / a weekday within this week ("Mon") / "Sep 17".
    static func relativeDay(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date),
                                           to: calendar.startOfDay(for: now)).day ?? 0
        if days <= 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        if let week = calendar.dateInterval(of: .weekOfYear, for: now), week.contains(date) {
            return formatter("EEE", calendar: calendar).string(from: date)
        }
        return formatter("MMMd", calendar: calendar).string(from: date)
    }

    private static func formatter(_ template: String, calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }

    /// New Model… from a search: the leading words become the manufacturer when they name one in
    /// the catalog ("life fitness leg press" → Life Fitness / Leg Press); otherwise the whole search
    /// is the model (which word is the maker cannot be told). An all-lowercase word is capitalised;
    /// anything the user capitalised is kept as typed.
    static func newModelPrefill(query: String, manufacturers: [String]) -> (manufacturer: String, model: String) {
        let words = query.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return ("", "") }
        let styled: ([String]) -> String = { words in
            words.map { $0 == $0.lowercased() ? $0.capitalized : $0 }.joined(separator: " ")
        }
        // Longest maker first, so "Life Fitness" wins over a maker called "Life".
        let makers = Set(manufacturers).sorted { $0.count != $1.count ? $0.count > $1.count : $0 < $1 }
        for maker in makers {
            let makerWords = maker.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
            guard !makerWords.isEmpty, words.count > makerWords.count,
                  words.prefix(makerWords.count).map({ $0.lowercased() }) == makerWords else { continue }
            return (maker, styled(Array(words.dropFirst(makerWords.count))))
        }
        return ("", styled(words))
    }
}

// MARK: - Reading the store

extension GymOverviewMath {
    /// Finished workouts as visit inputs.
    static func visitInputs(_ workouts: [Workout]) -> [GymVisitInput] {
        workouts.filter { $0.finishedAt != nil && !$0.isDeleted }
            .map { GymVisitInput(gymID: $0.gym?.id, startedAt: $0.startedAt) }
    }

    /// Every finished set logged on a machine, from the entry snapshots.
    static func machineSetInputs(finishedEntries: [ExerciseEntry]) -> [MachineSetInput] {
        finishedEntries.flatMap { entry -> [MachineSetInput] in
            guard !entry.isDeleted, entry.snapshotMachineID != nil,
                  let workout = entry.workout, !workout.isDeleted, workout.finishedAt != nil
            else { return [] }
            return (entry.sets ?? []).map { set in
                MachineSetInput(workoutID: workout.id, workoutStartedAt: workout.startedAt, set: RecordSetInput(
                    loadType: entry.snapshotLoadType, exerciseID: entry.snapshotExerciseID,
                    gymID: entry.snapshotGymID, machineID: entry.snapshotMachineID,
                    modelID: entry.snapshotModelID, freeWeightTag: entry.snapshotFreeWeightTag,
                    presetID: entry.snapshotPresetID, setType: set.type, reps: set.reps,
                    weightValue: set.weightValue, weightUnit: set.weightUnit,
                    normalizedKg: set.normalizedKg, completedAt: set.completedAt,
                    barWeightValue: set.barWeightValue))
            }
        }
    }

    /// The machine's sets as plain record inputs (the machine page's chart).
    static func recordInputs(of machineID: UUID, in inputs: [MachineSetInput]) -> [RecordSetInput] {
        inputs.filter { $0.set.machineID == machineID }.map(\.set)
    }
}
