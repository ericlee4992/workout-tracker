import Foundation
import SwiftData

/// Every finished workout's entries (`SetBadgeMath.finishedEntries`), read once and shared by the live workout's
/// history readings: the New best / First time marks, the fresh-best band, the Lock Screen card and each row's
/// PREVIOUS.
///
/// Performance P1: each of those read and ordered the whole history on its own, on every committed value and for
/// every row — about 2 s per commit on 150 workouts, the freeze while typing during a workout.
///
/// The list is MEMBERSHIP only. Sets, values and snapshots are read from the entries when they are used, so a
/// correction inside a finished workout still counts at once. Membership changes only when a workout finishes or
/// is deleted or an entry is added or removed, and each of those changes a count; the counts are checked (SQL
/// COUNTs, cheap) before every use, and the list is read again when either differs. The live workout's own
/// entries change the entry count too, which only costs one extra read. An add and a remove between two uses would
/// cancel out; only a History edit does both, and History cannot be reached while the live workout is on screen —
/// the screen owns the cache, so minimising and reopening it starts a new one.
@MainActor
final class FinishedHistoryCache {
    private var key: Key?
    private var entries: [ExerciseEntry] = []

    private struct Key: Equatable {
        var finishedWorkouts: Int
        var entries: Int
    }

    init() {}

    func finishedEntries(in context: ModelContext) throws -> [ExerciseEntry] {
        let current = Key(
            finishedWorkouts: try context.fetchCount(
                FetchDescriptor<Workout>(predicate: #Predicate { $0.finishedAt != nil })),
            entries: try context.fetchCount(FetchDescriptor<ExerciseEntry>()))
        if current == key { return entries }
        entries = try SetBadgeMath.finishedEntries(in: context)
        key = current
        return entries
    }
}
