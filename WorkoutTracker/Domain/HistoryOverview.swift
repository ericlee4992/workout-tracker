import Foundation
import SwiftData

// Floodlight redesign ticket 05 — what History's list and calendar show about the log as a
// whole: the month card (figures + a strip of every day), workouts grouped by week, and each
// row's marks (families, new-best count, unit badge, volume or distance). Derived on read from
// finished workouts, never stored, so a history edit (D47) cannot leave a stale figure.
//
// Counting rules, shared by the row, the month card and the calendar so they always add up:
// - "Sets" are COMPLETED sets, warmups included — the row's "14 sets", the receipt's count and
//   its ring all count the same rows. (The Workout tab's family tally is the exception: it counts
//   working sets per family.)
// - A workout belongs to the day it STARTED on (as `WorkoutCalendar` and the week card).
// - Weeks follow the calendar's first weekday — the same weeks as Home's "This week".
// - Families read the LIVE `exercise.muscleGroup`: muscle group is not snapshotted (D23 covers
//   names), so an exercise without a group shows no family.

/// A finished workout's recorded cardio distance, in its first segment's unit.
struct HistoryDistance: Hashable {
    var meters: Double
    var unit: CardioDistanceUnit
    var value: Double { meters / unit.metersPerUnit }
}

/// One finished workout as History's list reads it. Plain values: the month/week/day math is
/// testable without a store.
struct HistoryWorkoutFacts: Identifiable, Hashable {
    var id: UUID
    var startedAt: Date
    var durationSeconds: Int
    /// Completed sets, warmups included.
    var sets: Int
    var hasLifting: Bool
    var hasCardio: Bool
    /// Families trained, in workout order (`familySets` below counts them).
    var families: [MuscleFamily] = []
    /// Record scopes (exercise + equipment + variation, D36) with a new best — the receipt's
    /// "New bests" lines — judged against the sets completed before this workout started.
    var newBests: Int = 0
    /// Weighted volume (`RecordsMath.totalVolumeKg`): warmups out, assisted/bodyweight out.
    var volumeKg: Double = 0
    /// Units the completed sets carrying a weight were entered in.
    var units: Set<WeightUnit> = []
    var distance: HistoryDistance?
    var isEdited: Bool = false

    /// The unit badge, only when it says something: "kg + lb" for a workout in both units, or
    /// the one entered unit when it is not the app's. Nothing when every weight was in the app's
    /// unit (the trailing volume already says it).
    func unitBadge(appUnit: WeightUnit) -> String? {
        if units.count > 1 { return "kg + lb" }
        guard let only = units.first, only != appUnit else { return nil }
        return only.rawValue
    }
}

extension HistoryWorkoutFacts {
    /// nil for a workout still running: it is not history yet. `newBests` is filled by
    /// `HistoryOverviewMath.facts(for:finishedEntries:)`, which reads the whole history once.
    init?(workout: Workout) {
        guard !workout.isDeleted, workout.finishedAt != nil else { return nil }
        var families: [MuscleFamily] = []
        var sets = 0
        var units: Set<WeightUnit> = []
        var inputs: [RecordSetInput] = []
        for entry in WorkoutSession.orderedEntries(of: workout) {
            let completed = WorkoutSession.orderedSets(of: entry).filter { $0.completedAt != nil }
            guard !completed.isEmpty else { continue }
            sets += completed.count
            for set in completed {
                if set.weightValue != nil { units.insert(set.weightUnit) }
                // The volume the receipt's tile shows (`WorkoutSummaryBuilder`), without
                // building the whole summary for every row.
                inputs.append(RecordSetInput(
                    loadType: entry.snapshotLoadType, exerciseID: entry.snapshotExerciseID,
                    gymID: entry.snapshotGymID, machineID: entry.snapshotMachineID,
                    modelID: entry.snapshotModelID, freeWeightTag: entry.snapshotFreeWeightTag,
                    presetID: entry.snapshotPresetID, setType: set.type, reps: set.reps,
                    weightValue: set.weightValue, weightUnit: set.weightUnit,
                    normalizedKg: set.normalizedKg, completedAt: set.completedAt))
            }
            if let family = MuscleFamily(muscleGroup: entry.exercise?.muscleGroup), !families.contains(family) {
                families.append(family)
            }
        }
        let cardio = workout.recordedCardio
        let withDistance = cardio.filter { $0.distanceMeters != nil }
        let distance = withDistance.first.map { first in
            HistoryDistance(meters: withDistance.reduce(0) { $0 + ($1.distanceMeters ?? 0) }, unit: first.unit)
        }
        self.init(
            id: workout.id,
            startedAt: workout.startedAt,
            durationSeconds: Int(workout.duration ?? 0),
            sets: sets,
            hasLifting: sets > 0,
            hasCardio: !cardio.isEmpty,
            families: families,
            volumeKg: RecordsMath.totalVolumeKg(among: inputs),
            units: units,
            distance: distance,
            isEdited: workout.historyEditedAt != nil)
    }
}

/// A month's totals (the month card, a month break, the calendar header).
struct HistoryMonthSummary: Hashable {
    var month: Date
    var workouts: Int
    var sets: Int
    var seconds: Int
    var hours: Double { Double(seconds) / 3600 }
}

/// One day of a month, for the heat strip and the calendar cells.
struct HistoryDay: Identifiable, Hashable {
    var id: Date { date }
    var date: Date
    var dayNumber: Int
    var sets: Int
    /// 0 = no workout; 1–4 by the day's sets (`HistoryOverviewMath.intensity`).
    var intensity: Int
    /// The day's workouts, oldest first.
    var workoutIDs: [UUID]
    var hasCardio: Bool
    var hasLifting: Bool
    var isToday: Bool
    var isFuture: Bool
    /// The calendar's first weekday (the strip spaces its weeks and numbers these days).
    var isWeekStart: Bool
}

struct HistoryWeekSection: Identifiable, Hashable {
    var id: Date { start }
    var start: Date
    var title: String
    /// Newest first.
    var workoutIDs: [UUID]
}

struct HistoryMonthSection: Identifiable, Hashable {
    var id: Date { month }
    var month: Date
    var weeks: [HistoryWeekSection]
}

enum HistoryOverviewMath {
    /// Every finished workout's facts, keyed by id, from ONE read of the history: the new-best
    /// count needs each scope's past, so it is computed for all workouts in a single pass.
    static func facts(for workouts: [Workout], finishedEntries: [ExerciseEntry]) -> [UUID: HistoryWorkoutFacts] {
        let bests = SetBadgeMath.newBestCounts(finishedEntries: finishedEntries)
        var result: [UUID: HistoryWorkoutFacts] = [:]
        for workout in workouts {
            guard var facts = HistoryWorkoutFacts(workout: workout) else { continue }
            facts.newBests = bests[workout.id] ?? 0
            result[workout.id] = facts
        }
        return result
    }

    static func monthSummary(_ facts: [HistoryWorkoutFacts], month: Date, calendar: Calendar = .current) -> HistoryMonthSummary {
        let items = facts.filter { calendar.isDate($0.startedAt, equalTo: month, toGranularity: .month) }
        return HistoryMonthSummary(
            month: calendar.dateInterval(of: .month, for: month)?.start ?? month,
            workouts: items.count,
            sets: items.reduce(0) { $0 + $1.sets },
            seconds: items.reduce(0) { $0 + $1.durationSeconds })
    }

    /// How lit a day is: nothing, then four steps by its sets (a typical session is 12–25).
    /// A trained day is never 0, even a cardio-only one with no sets.
    static func intensity(sets: Int, trained: Bool) -> Int {
        guard trained else { return 0 }
        switch sets {
        case ..<12: return 1
        case 12..<20: return 2
        case 20..<28: return 3
        default: return 4
        }
    }

    /// Every day of the month containing `date`.
    static func days(inMonthOf date: Date, facts: [HistoryWorkoutFacts], now: Date,
                     calendar: Calendar = .current) -> [HistoryDay] {
        guard let interval = calendar.dateInterval(of: .month, for: date),
              let count = calendar.range(of: .day, in: .month, for: interval.start)?.count else { return [] }
        let today = calendar.startOfDay(for: now)
        let byDay = Dictionary(grouping: facts) { calendar.startOfDay(for: $0.startedAt) }
        return (0..<count).compactMap { offset -> HistoryDay? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: interval.start) else { return nil }
            let items = (byDay[day] ?? []).sorted { $0.startedAt < $1.startedAt }
            let sets = items.reduce(0) { $0 + $1.sets }
            return HistoryDay(
                date: day, dayNumber: offset + 1, sets: sets,
                intensity: intensity(sets: sets, trained: !items.isEmpty),
                workoutIDs: items.map(\.id),
                hasCardio: items.contains(where: \.hasCardio),
                hasLifting: items.contains(where: \.hasLifting),
                isToday: day == today, isFuture: day > today,
                isWeekStart: calendar.component(.weekday, from: day) == calendar.firstWeekday)
        }
    }

    /// History newest first, grouped into weeks (the calendar's weeks), and the weeks into the
    /// month of their newest workout — a week that crosses a month end stays whole.
    static func sections(_ facts: [HistoryWorkoutFacts], now: Date, calendar: Calendar = .current) -> [HistoryMonthSection] {
        let newestFirst = facts.sorted { $0.startedAt > $1.startedAt }
        var order: [Date] = []
        var byWeek: [Date: [HistoryWorkoutFacts]] = [:]
        for item in newestFirst {
            let start = calendar.dateInterval(of: .weekOfYear, for: item.startedAt)?.start
                ?? calendar.startOfDay(for: item.startedAt)
            if byWeek[start] == nil { order.append(start) }
            byWeek[start, default: []].append(item)
        }
        var months: [HistoryMonthSection] = []
        for start in order {
            guard let items = byWeek[start], let newest = items.first else { continue }
            let month = calendar.dateInterval(of: .month, for: newest.startedAt)?.start ?? newest.startedAt
            let week = HistoryWeekSection(start: start, title: weekTitle(start: start, now: now, calendar: calendar),
                                          workoutIDs: items.map(\.id))
            if months.last?.month == month {
                months[months.count - 1].weeks.append(week)
            } else {
                months.append(HistoryMonthSection(month: month, weeks: [week]))
            }
        }
        return months
    }

    /// "This week", "Last week", "Sep 7 – 13", "Aug 31 – Sep 6".
    static func weekTitle(start: Date, now: Date, calendar: Calendar = .current) -> String {
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        if calendar.isDate(start, inSameDayAs: thisWeek) { return "This week" }
        if let last = calendar.date(byAdding: .day, value: -7, to: thisWeek), calendar.isDate(start, inSameDayAs: last) {
            return "Last week"
        }
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        let monthDay = formatter("MMMd", calendar: calendar)
        if calendar.isDate(start, equalTo: end, toGranularity: .month) {
            return "\(monthDay.string(from: start)) – \(formatter("d", calendar: calendar).string(from: end))"
        }
        return "\(monthDay.string(from: start)) – \(monthDay.string(from: end))"
    }

    private static func formatter(_ template: String, calendar: Calendar) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = calendar.locale ?? .current
        f.timeZone = calendar.timeZone
        f.setLocalizedDateFormatFromTemplate(template)
        return f
    }
}
