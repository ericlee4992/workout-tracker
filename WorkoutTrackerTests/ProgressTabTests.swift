import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

/// Public beta ticket 16 (D63): the Progress tab's pins and the cardio progress numbers.
struct ProgressPinTests {

    @Test func pinsRoundTripThroughTheStoreInOrder() throws {
        let defaults = try #require(UserDefaults(suiteName: "ProgressPinTests-\(UUID())"))
        let machine = UUID(), preset = UUID()
        let pins = [
            ProgressPin(subject: .lift(exerciseID: UUID(), variation: .mostUsed), metric: .bestSet),
            ProgressPin(subject: .cardio(activity: CardioActivity.rowing.rawValue), metric: .pace),
            ProgressPin(subject: .lift(exerciseID: UUID(), variation: .fixed(
                loadType: .assisted, machineID: machine, freeWeightTag: nil, presetID: preset)), metric: .bestSet),
            ProgressPin(subject: .lift(exerciseID: UUID(), variation: .fixed(
                loadType: .weighted, machineID: nil, freeWeightTag: .barbell, presetID: nil)), metric: .e1rm),
        ]
        ProgressPinStore.save(pins, defaults)
        #expect(ProgressPinStore.load(defaults) == pins)
    }

    /// A view preference must never block launch: unreadable or missing data reads as no pins.
    @Test func unreadableDataIsNoPins() {
        #expect(ProgressPinStore.decode(nil).isEmpty)
        #expect(ProgressPinStore.decode(Data()).isEmpty)
        #expect(ProgressPinStore.decode(Data("not json".utf8)).isEmpty)
    }

    /// An activity a later build no longer knows decodes, and reads as no activity (the tab hides it).
    @Test func anUnknownActivityDecodesAndIsSkipped() throws {
        let pin = ProgressPin(subject: .cardio(activity: "zipline"), metric: .distance)
        let decoded = ProgressPinStore.decode(ProgressPinStore.encode([pin]))
        #expect(decoded == [pin])
        #expect(decoded.first?.activity == nil)
    }

    @Test func movesStayInRange() {
        let a = ProgressPin(subject: .cardio(activity: "rowing"), metric: .distance)
        let b = ProgressPin(subject: .cardio(activity: "outdoorRun"), metric: .distance)
        let c = ProgressPin(subject: .cardio(activity: "indoorCycle"), metric: .distance)
        #expect(ProgressPinStore.move(b.id, by: -1, in: [a, b, c]).map(\.id) == [b.id, a.id, c.id])
        #expect(ProgressPinStore.move(b.id, by: 1, in: [a, b, c]).map(\.id) == [a.id, c.id, b.id])
        #expect(ProgressPinStore.move(a.id, by: -1, in: [a, b, c]).map(\.id) == [a.id, b.id, c.id])
        #expect(ProgressPinStore.move(c.id, by: 1, in: [a, b, c]).map(\.id) == [a.id, b.id, c.id])
    }

    /// Volume and 1RM are weighted only (D20): a Most-used pin that moves to an assisted variation shows Best set.
    @Test func shownMetricFallsBackWhereTheVariationCannotDrawIt() {
        let lift = ProgressPin(subject: .lift(exerciseID: UUID(), variation: .mostUsed), metric: .volume)
        #expect(lift.shownMetric(loadType: .weighted) == .volume)
        #expect(lift.shownMetric(loadType: .assisted) == .bestSet)
        #expect(lift.shownMetric(loadType: .bodyweight) == .bestSet)
        let cardio = ProgressPin(subject: .cardio(activity: "rowing"), metric: .bestSet)
        #expect(cardio.shownMetric(loadType: nil) == .distance)
    }

    /// No heart-rate view (the user, D63); cycling says Speed where the others say Pace.
    @Test func cardioMetricsAreDistancePaceTime() {
        #expect(ProgressPinMetric.cardio == [.distance, .pace, .time])
        #expect(ProgressPinMetric.pace.title(for: .indoorCycle) == "Speed")
        #expect(ProgressPinMetric.pace.title(for: .outdoorRun) == "Pace")
    }

    @Test func aFixedVariationResolvesToItselfAndMostUsedToTheMostTrained() {
        let exercise = UUID(), machineA = UUID(), machineB = UUID()
        func set(_ machine: UUID, day: Int) -> RecordSetInput {
            RecordSetInput(loadType: .weighted, exerciseID: exercise, machineID: machine, setType: .working, reps: 8,
                           weightValue: 50, weightUnit: .kg, normalizedKg: 50,
                           completedAt: Date(timeIntervalSince1970: Double(day) * 86_400))
        }
        let sets = [set(machineA, day: 1), set(machineB, day: 2), set(machineB, day: 3)]
        let b = ProgressVariationKey(loadType: .weighted, equipment: .machine(machineB), presetID: nil)
        let a = ProgressVariationKey(loadType: .weighted, equipment: .machine(machineA), presetID: nil)
        #expect(PinnedLiftVariation.mostUsed.resolve(in: sets) == b)
        #expect(PinnedLiftVariation(a).resolve(in: sets) == a)
        #expect(PinnedLiftVariation.mostUsed.resolve(in: []) == nil)
    }
}

@MainActor
struct CardioProgressMathTests {
    private let context: ModelContext
    private let base = Date(timeIntervalSince1970: 1_790_000_000)

    init() throws {
        let schema = WorkoutTrackerStore.schema
        context = ModelContext(try ModelContainer(
            for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]))
    }

    /// A finished workout with one segment per (activity, metres, active seconds, bpm).
    @discardableResult
    private func workout(day: Int, finished: Bool = true,
                         _ segments: [(CardioActivity, Double?, Double, Int?)]) -> Workout {
        let start = base.addingTimeInterval(Double(day) * 86_400)
        let workout = Workout(startedAt: start, finishedAt: finished ? start.addingTimeInterval(3_600) : nil)
        context.insert(workout)
        for (order, item) in segments.enumerated() {
            let segment = CardioSegment(activity: item.0, order: order, workout: workout,
                                        at: start.addingTimeInterval(Double(order) * 600), unit: .km)
            context.insert(segment)
            segment.accumulatedActiveSeconds = item.2
            segment.activeStartedAt = nil
            segment.endedAt = start.addingTimeInterval(Double(order) * 600 + item.2)
            segment.lastCheckpointAt = segment.endedAt!
            segment.automaticDistanceMeters = item.1
            if let bpm = item.3 { segment.heartRateCount = 10; segment.heartRateTotal = bpm * 10 }
        }
        return workout
    }

    private var workouts: [Workout] { (try? context.fetch(FetchDescriptor<Workout>())) ?? [] }

    /// "Run, lift, run" is one run that day: segments of one activity in one workout combine.
    @Test func aWorkoutsSegmentsOfOneActivityAreOneSession() {
        workout(day: 1, [(.outdoorRun, 2_000, 600, 140), (.rowing, 1_000, 300, nil), (.outdoorRun, 3_000, 900, 160)])
        let sessions = CardioProgressMath.sessions(in: workouts, activity: .outdoorRun)
        #expect(sessions.count == 1)
        #expect(sessions.first?.meters == 5_000)
        #expect(sessions.first?.seconds == 1_500)
        #expect(sessions.first?.heartRate == 150)
    }

    @Test func anUnfinishedWorkoutIsNotASession() {
        workout(day: 1, finished: false, [(.outdoorRun, 2_000, 600, nil)])
        #expect(CardioProgressMath.sessions(in: workouts, activity: .outdoorRun).isEmpty)
    }

    @Test func valuesAreInTheAppsUnitWithRowingPacePer500Metres() {
        let run = CardioProgressSession(workoutID: UUID(), date: base, meters: 5_000, seconds: 1_500, heartRate: nil)
        #expect(CardioProgressMath.value(run, metric: .distance, activity: .outdoorRun, unit: .km) == 5)
        #expect(abs((CardioProgressMath.value(run, metric: .distance, activity: .outdoorRun, unit: .mi) ?? 0) - 3.10686) < 0.0001)
        #expect(CardioProgressMath.value(run, metric: .pace, activity: .outdoorRun, unit: .km) == 300)    // 5:00 /km
        #expect(CardioProgressMath.value(run, metric: .time, activity: .outdoorRun, unit: .km) == 25)
        let row = CardioProgressSession(workoutID: UUID(), date: base, meters: 2_000, seconds: 480, heartRate: nil)
        #expect(CardioProgressMath.value(row, metric: .pace, activity: .rowing, unit: .mi) == 120)        // 2:00 /500 m
        #expect(CardioProgressMath.paceLabel(.rowing, unit: .mi) == "/500 m")
        let ride = CardioProgressSession(workoutID: UUID(), date: base, meters: 20_000, seconds: 3_600, heartRate: nil)
        #expect(CardioProgressMath.value(ride, metric: .pace, activity: .indoorCycle, unit: .km) == 20)   // km/h
    }

    /// No distance: nothing for distance or pace, but the session still has a time.
    @Test func aSessionWithoutDistanceChartsOnlyTime() {
        let s = CardioProgressSession(workoutID: UUID(), date: base, meters: nil, seconds: 600, heartRate: nil)
        #expect(CardioProgressMath.value(s, metric: .distance, activity: .rowing, unit: .km) == nil)
        #expect(CardioProgressMath.value(s, metric: .pace, activity: .rowing, unit: .km) == nil)
        #expect(CardioProgressMath.value(s, metric: .time, activity: .rowing, unit: .km) == 10)
    }

    /// New bests beat every earlier session — the first is not one, a tie is not one; pace improves downward.
    @Test func bestsAndChangeFollowEachMetricsDirection() {
        let ids = (0..<4).map { _ in UUID() }
        let sessions = [(4_000.0, 1_500.0), (5_000, 1_500), (5_000, 1_400), (4_500, 1_300)].enumerated().map { i, v in
            CardioProgressSession(workoutID: ids[i], date: base.addingTimeInterval(Double(i) * 86_400),
                                  meters: v.0, seconds: v.1, heartRate: nil)
        }
        let distance = CardioProgressMath.points(sessions, metric: .distance, activity: .outdoorRun, unit: .km)
        #expect(distance.map(\.isBest) == [false, true, false, false])
        #expect(CardioProgressMath.change(distance, metric: .distance, activity: .outdoorRun) == .fraction(0.125))
        #expect(!CardioProgressMath.latestIsBest(distance, metric: .distance, activity: .outdoorRun))

        let pace = CardioProgressMath.points(sessions, metric: .pace, activity: .outdoorRun, unit: .km)
        // 375, 300, 280, ≈288.9 s/km: faster is smaller.
        #expect(pace.map(\.isBest) == [false, true, true, false])
        guard case .paceSeconds(let faster)? = CardioProgressMath.change(pace, metric: .pace, activity: .outdoorRun) else {
            Issue.record("pace change should be in seconds"); return
        }
        #expect(abs(faster - (375 - 1_300.0 / 4.5)) < 0.0001)
        #expect(faster > 0)

        let best = CardioProgressMath.bests(sessions, activity: .outdoorRun, unit: .km)
        #expect(best.longest?.workoutID == ids[1])          // the earliest of the two 5 km sessions
        #expect(best.fastest?.workoutID == ids[2])
        #expect(best.longestTime?.workoutID == ids[0])      // 1,500 s first, then a tie
    }

    @Test func oneSessionHasNoChangeAndNoBestCaption() {
        let one = [CardioProgressSession(workoutID: UUID(), date: base, meters: 5_000, seconds: 1_500, heartRate: nil)]
        let points = CardioProgressMath.points(one, metric: .distance, activity: .outdoorRun, unit: .km)
        #expect(CardioProgressMath.change(points, metric: .distance, activity: .outdoorRun) == nil)
        #expect(!CardioProgressMath.latestIsBest(points, metric: .distance, activity: .outdoorRun))
    }

    @Test func activitiesListMostSessionsFirst() {
        workout(day: 1, [(.rowing, 1_000, 300, nil)])
        workout(day: 2, [(.outdoorRun, 3_000, 900, nil)])
        workout(day: 3, [(.outdoorRun, 3_000, 900, nil), (.outdoorRun, 1_000, 300, nil)])
        workout(day: 4, finished: false, [(.indoorCycle, 1_000, 300, nil)])
        let list = CardioProgressMath.activities(in: workouts)
        #expect(list.map(\.activity) == [.outdoorRun, .rowing])
        #expect(list.map(\.sessions) == [2, 1])
    }
}
