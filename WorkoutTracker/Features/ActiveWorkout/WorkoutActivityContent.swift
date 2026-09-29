import Foundation
import SwiftData

// Floodlight redesign ticket 11 — what the Lock Screen card and the Dynamic Island are told.
//
// One builder for every pusher: the live screen (with its heart-rate monitor and the rest
// result it saw) and `WorkoutActivityCommands` (a command pressed on the card while the
// workout is minimised or the app is in the background). The rules match the live screen's:
// the next set (`WorkoutSession.nextSet`), its line (the rest bar's, with the unit), last
// time's value (`PerformanceHistory.reference`), the new-best mark (`SetBadgeMath`).

enum WorkoutActivityContent {
    struct Heart {
        var bpm: Int?
        var zone: HeartRateZone?
    }

    static func make(
        for workout: Workout,
        in context: ModelContext,
        heart: Heart?,
        restResult: WorkoutActivityAttributes.RestResult? = nil,
        degradedRestSetID: UUID? = nil,
        now: Date = .now
    ) -> WorkoutActivityAttributes.ContentState {
        let entries = WorkoutSession.orderedEntries(of: workout).filter { !$0.isDeleted }
        let sets = entries.flatMap { WorkoutSession.orderedSets(of: $0) }
        let completed = sets.filter { $0.completedAt != nil }.count
        let restSet = workout.restStartedBySetID.flatMap { id in sets.first { $0.id == id } }

        var state = WorkoutActivityAttributes.ContentState(
            heartRateBpm: heart?.bpm,
            // D45: a zone only with a maximum to compute it against — the monitor's rule.
            zoneLabel: heart?.bpm == nil ? nil : heart?.zone?.label,
            restEndsAt: workout.restEndsAt,
            completedSets: completed,
            currentExercise: currentExercise(workout, entries: entries),
            zoneLevel: heart?.bpm == nil ? nil : heart?.zone?.rawValue,
            totalSets: sets.count,
            restStartedAt: workout.restEndsAt == nil ? nil : workout.restStartedAt,
            workoutTitle: workout.historyTitle)

        if workout.restEndsAt != nil, let restSet {
            state.rest = restKind(for: restSet, in: context, degradedRestSetID: degradedRestSetID)
            if let entry = restSet.entry,
               let badges = try? SetBadgeMath.badges(for: entry, in: context) {
                state.restFollowsNewBest = badges[restSet.id] == .newBest
            }
        }
        state.restResult = restResult
        state.next = nextSet(in: workout, restEntryID: restSet?.entry?.id, context: context)
        if let segment = workout.unfinishedCardio {
            state.cardio = cardio(segment, in: workout, now: now)
        }
        return state
    }

    /// The cardio activity, else the last exercise with a completed set, else the last exercise
    /// (the pre-redesign rule).
    static func currentExercise(_ workout: Workout, entries: [ExerciseEntry]) -> String? {
        if let cardio = workout.unfinishedCardio { return cardio.activity.name }
        return entries.last { entry in
            WorkoutSession.orderedSets(of: entry).contains { $0.completedAt != nil }
        }?.snapshotExerciseName ?? entries.last.map { $0.exercise?.name ?? $0.snapshotExerciseName }
    }

    static func restKind(for set: SetRecord, in context: ModelContext,
                         degradedRestSetID: UUID?) -> WorkoutActivityAttributes.RestKind {
        guard let plan = try? RestTimerService(context: context).restPlan(for: set),
              plan.mode == .heartRate, let rule = plan.rule else { return .timer }
        return degradedRestSetID == set.id ? .fallback : .heartRate(targetBpm: rule.thresholdBpm)
    }

    static func nextSet(in workout: Workout, restEntryID: UUID?,
                        context: ModelContext) -> WorkoutActivityAttributes.NextSet? {
        guard let next = WorkoutSession.nextSet(in: workout), let entry = next.entry else { return nil }
        let name = entry.exercise?.name ?? entry.snapshotExerciseName
        let sets = WorkoutSession.orderedSets(of: entry)
        let number = sets.prefix { $0.id != next.id }.filter { $0.type != .warmup }.count + 1
        let loadType = entry.effectiveLoadType
        var value: SetValue?
        if let reps = next.reps, !loadType.takesWeight || next.weightValue != nil {
            value = SetValue(weight: next.weightValue, unit: next.weightUnit, reps: reps)
        }
        // The rest bar's line, Floodlight's form (the unit stays: no row to carry it here).
        let look = Look.floodlight
        let line: String
        if let restEntryID, restEntryID != entry.id {
            line = look.nextExerciseLabel(name)
        } else if next.type == .warmup {
            line = "Next · Warmup" + (value.map { " · \(look.previousLabel($0, rowUnit: next.weightUnit, loadType: loadType))" } ?? "")
        } else {
            line = look.nextSetLabel(number: number, value: value, rowUnit: next.weightUnit, loadType: loadType)
        }
        let showsWeight = loadType.takesWeight && next.weightValue != nil
        let previous = (try? PerformanceHistory(context: context).reference(for: next))?.displayLabel
        return WorkoutActivityAttributes.NextSet(
            marker: next.type.marker ?? "\(number)",
            supersetLetter: Supersets.memberLabel(for: entry, in: workout),
            exerciseName: name,
            line: line,
            weight: showsWeight ? next.weightValue.map { WeightMath.displayNumber($0) } : nil,
            unit: showsWeight ? next.weightUnit.rawValue : nil,
            reps: next.reps,
            previous: previous)
    }

    static func cardio(_ segment: CardioSegment, in workout: Workout, now: Date) -> WorkoutActivityAttributes.Cardio {
        let active = segment.activeDuration(at: now)
        let unit = segment.unit
        var rate: String?
        var rateUnit: String?
        if let meters = segment.distanceMeters, meters > 0, active > 0 {
            if segment.activity.usesSpeed {
                rate = String(format: "%.1f", meters / active * 3_600 / unit.metersPerUnit)
                rateUnit = "\(unit.rawValue)/h"
            } else if let pace = CardioMath.pace(seconds: active, meters: meters, unit: unit) {
                rate = CardioMath.paceText(pace)
                rateUnit = "/\(unit.rawValue)"
            }
        }
        return WorkoutActivityAttributes.Cardio(
            activity: segment.activity.name,
            symbol: segment.activity.symbol,
            isPaused: !segment.isRunning,
            // Fixed while the segment runs (its active start less the time banked before it), so
            // the 2-second tick does not push a new card for a clock the system already ticks.
            clockStart: segment.activeStartedAt.map { $0.addingTimeInterval(-max(0, segment.accumulatedActiveSeconds)) },
            elapsedSeconds: Int(segment.isRunning ? max(0, segment.accumulatedActiveSeconds) : active),
            distance: segment.distanceMeters.map { String(format: "%.2f", $0 / unit.metersPerUnit) },
            distanceUnit: segment.distanceMeters == nil ? nil : unit.rawValue,
            rate: rate,
            rateUnit: rateUnit,
            targetMinutes: workout.plannedCardio.first { $0.segmentID == segment.id }?.minutes)
    }
}
