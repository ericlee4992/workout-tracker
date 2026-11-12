import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

// Performance P1: the live workout reads the finished history once (`FinishedHistoryCache`) and judges every entry's
// marks against it, instead of each entry reading it on every commit. The marks must be exactly what the per-entry
// read gave, and must follow changes to the history: a value corrected inside a finished workout at once (contents are
// read live), a workout finished or deleted through the counts.
@MainActor
struct FinishedHistoryCacheTests {
    private struct Rig {
        let context: ModelContext
        let session: WorkoutSession
        let press: Exercise
        let row: Exercise
    }

    private func makeRig() throws -> Rig {
        let container = try ModelContainer(
            for: WorkoutTrackerStore.schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let press = Exercise(name: "Chest Press", loadType: .weighted)
        let row = Exercise(name: "Seated Row", loadType: .weighted)
        context.insert(press)
        context.insert(row)
        try context.save()
        return Rig(context: context, session: WorkoutSession(context: context), press: press, row: row)
    }

    @discardableResult
    private func log(_ rig: Rig, _ exercise: Exercise, kg: [Double], at start: Date, finish: Bool = true) throws -> Workout {
        let workout = try rig.session.startWorkout(at: nil, on: start)
        let entry = try rig.session.addEntry(for: exercise, to: workout, machine: nil)
        for (index, value) in kg.enumerated() {
            let set = index == 0
                ? try #require(WorkoutSession.orderedSets(of: entry).first)
                : try rig.session.addSet(to: entry)
            set.weightUnit = .kg
            try rig.session.commitWeight(String(value), for: set)
            try rig.session.commitReps("5", for: set)
            try rig.session.toggleCompletion(of: set, at: start.addingTimeInterval(Double(index + 1) * 60))
        }
        if finish { try rig.session.finish(workout, at: start.addingTimeInterval(3_600)) }
        return workout
    }

    /// The live screen's marks for every entry, both ways.
    private func marks(_ live: Workout, _ rig: Rig, cache: FinishedHistoryCache) throws
        -> (shared: [UUID: SetBadge], perEntry: [UUID: SetBadge]) {
        var shared: [UUID: SetBadge] = [:], perEntry: [UUID: SetBadge] = [:]
        let finished = try cache.finishedEntries(in: rig.context)
        for entry in WorkoutSession.orderedEntries(of: live) {
            shared.merge(SetBadgeMath.badges(for: entry, finishedEntries: finished)) { first, _ in first }
            perEntry.merge(try SetBadgeMath.badges(for: entry, in: rig.context)) { first, _ in first }
        }
        return (shared, perEntry)
    }

    @Test func sharedHistoryMarksEqualPerEntryReadsAndFollowHistoryChanges() throws {
        let rig = try makeRig()
        let day: TimeInterval = 86_400
        let base = Date(timeIntervalSince1970: 1_000_000)
        try log(rig, rig.press, kg: [60, 62.5], at: base)
        let older = try log(rig, rig.row, kg: [50], at: base.addingTimeInterval(day))
        let live = try log(rig, rig.press, kg: [62.5, 65], at: base.addingTimeInterval(5 * day), finish: false)
        let rowEntry = try rig.session.addEntry(for: rig.row, to: live, machine: nil)
        let rowSet = try #require(WorkoutSession.orderedSets(of: rowEntry).first)
        rowSet.weightUnit = .kg
        try rig.session.commitWeight("52.5", for: rowSet)
        try rig.session.commitReps("5", for: rowSet)
        try rig.session.toggleCompletion(of: rowSet, at: base.addingTimeInterval(5 * day + 600))
        let cache = FinishedHistoryCache()

        var result = try marks(live, rig, cache: cache)
        #expect(result.shared == result.perEntry)
        #expect(result.shared.values.filter { $0 == .newBest }.count == 2) // 65 kg on the press, 52.5 kg on the row

        // A correction inside a finished workout counts at once: the row's 50 kg becomes 55 kg.
        let olderSet = try #require(WorkoutSession.orderedEntries(of: older).first.flatMap { $0.sets?.first })
        try rig.session.commitWeight("55", for: olderSet)
        result = try marks(live, rig, cache: cache)
        #expect(result.shared == result.perEntry)
        #expect(result.shared[rowSet.id] == nil, "52.5 kg is no longer a best")

        // A workout deleted from history changes the count, so the list is read again.
        rig.context.delete(older)
        try rig.context.save()
        result = try marks(live, rig, cache: cache)
        #expect(result.shared == result.perEntry)
        #expect(result.shared[rowSet.id] == .firstTime)

        // A workout added to history is read again too (inserted directly: starting one would end the live one).
        let start = base.addingTimeInterval(2 * day)
        let added = Workout(startedAt: start, finishedAt: start.addingTimeInterval(3_600))
        rig.context.insert(added)
        let entry = ExerciseEntry(order: 0, workout: added, exercise: rig.press, snapshotCapturedAt: start,
                                  snapshotExerciseID: rig.press.id, snapshotLoadType: rig.press.loadType,
                                  snapshotExerciseName: rig.press.name)
        rig.context.insert(entry)
        let heavy = SetRecord(order: 0, type: .working, reps: 5, weightValue: 70, weightUnit: .kg,
                              normalizedKg: 70, completedAt: start.addingTimeInterval(60))
        heavy.entry = entry
        rig.context.insert(heavy)
        try rig.context.save()
        result = try marks(live, rig, cache: cache)
        #expect(result.shared == result.perEntry)
        #expect(!result.shared.values.contains(.newBest), "65 kg no longer beats the press's history")
        #expect(result.shared[rowSet.id] == .firstTime)
    }
}
