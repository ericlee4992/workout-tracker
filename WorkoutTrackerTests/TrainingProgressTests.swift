import Foundation
import Testing
@testable import WorkoutTracker

// Soft redesign S4: the weekly training charts and their pins.
struct TrainingProgressTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        c.firstWeekday = 1
        return c
    }

    private func at(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

    private func input(_ start: String, kg: Double = 0, meters: Double = 0) -> TrainingWeekInput {
        TrainingWeekInput(startedAt: at(start), volumeKg: kg, runMeters: meters)
    }

    /// Saturday Nov 7, 2026; the week starts Sunday Nov 1.
    private var now: Date { at("2026-11-07T20:00:00Z") }

    @Test func workoutsCountPerWeekWithEmptyWeeksAsZero() {
        let inputs = [input("2026-10-19T15:00:00Z"), input("2026-10-21T15:00:00Z"), input("2026-11-03T15:00:00Z")]
        let points = TrainingProgressMath.weekly(inputs, metric: .workoutsPerWeek, now: now, calendar: calendar)
        #expect(points.map(\.value) == [2, 0, 1])   // Oct 18 week, Oct 25 week (none), this week
        #expect(points.last?.weekStart == at("2026-11-01T04:00:00Z"))
    }

    @Test func volumeAndDistanceIgnoreWorkoutsWithoutThem() {
        let inputs = [input("2026-10-27T15:00:00Z", kg: 1000), input("2026-11-02T15:00:00Z", meters: 5000),
                      input("2026-11-04T15:00:00Z", kg: 500, meters: 3000)]
        #expect(TrainingProgressMath.weekly(inputs, metric: .trainingVolume, now: now, calendar: calendar).map(\.value)
                == [1000, 500])
        // Distance starts at its own first week (this one), not the first workout's.
        #expect(TrainingProgressMath.weekly(inputs, metric: .runningDistance, now: now, calendar: calendar).map(\.value)
                == [8000])
    }

    @Test func atMostTwelveWeeksAndNothingWithoutData() {
        let old = (0..<20).map { input(ISO8601DateFormatter().string(from: now.addingTimeInterval(-Double($0) * 7 * 86_400))) }
        #expect(TrainingProgressMath.weekly(old, metric: .workoutsPerWeek, now: now, calendar: calendar).count == 12)
        #expect(TrainingProgressMath.weekly([], metric: .workoutsPerWeek, now: now, calendar: calendar).isEmpty)
        #expect(TrainingProgressMath.weekly([input("2026-11-02T15:00:00Z")], metric: .runningDistance, now: now,
                                            calendar: calendar).isEmpty)
    }

    // MARK: The panel's reading

    /// Three workouts, all in the first (and only) tracked week: one point that is a WEEK, so the panel says "This
    /// week" without the lift/cardio "One session" note (codex-review-s4 #1).
    @Test func aSingleWeekOfSeveralWorkoutsIsNotOneSession() {
        let inputs = [input("2026-11-02T15:00:00Z", kg: 1000), input("2026-11-03T15:00:00Z", kg: 500),
                      input("2026-11-05T15:00:00Z", kg: 250)]
        let workouts = TrainingProgressMath.weekly(inputs, metric: .workoutsPerWeek, now: now, calendar: calendar)
        let reading = ProgressReading.training(workouts, metric: .workoutsPerWeek, weightUnit: .kg, distanceUnit: .km)
        #expect(reading.state == .single)
        #expect(reading.value == "3")
        #expect(reading.caption == "This week")
        #expect(reading.singleNote == nil)

        let volume = TrainingProgressMath.weekly(inputs, metric: .trainingVolume, now: now, calendar: calendar)
        let kg = ProgressReading.training(volume, metric: .trainingVolume, weightUnit: .kg, distanceUnit: .km)
        #expect(kg.unit == "kg" && kg.singleNote == nil)
        #expect(kg.points.first?.value == 1750)
        // Display conversion only: the lb figure is 1,750 kg converted.
        let lb = ProgressReading.training(volume, metric: .trainingVolume, weightUnit: .lb, distanceUnit: .km)
        #expect(abs((lb.points.first?.value ?? 0) - 1750 / 0.45359237) < 0.01)

        // A lift's or an activity's lone point still is one session.
        #expect(ProgressReading(value: "", unit: "", caption: "", points: []).singleNote == "One session")
    }

    @Test func lastWeekJoinsTheCaption() {
        let inputs = [input("2026-10-27T15:00:00Z", meters: 5000), input("2026-11-03T15:00:00Z", meters: 3000)]
        let points = TrainingProgressMath.weekly(inputs, metric: .runningDistance, now: now, calendar: calendar)
        let reading = ProgressReading.training(points, metric: .runningDistance, weightUnit: .kg, distanceUnit: .km)
        #expect(reading.value == "3.0" && reading.unit == "km")
        #expect(reading.caption == "This week · last week 5.0 km")
        #expect(reading.change == nil)
    }

    // MARK: Pins

    @Test func aTrainingPinRoundTripsAndOlderPinsStillDecode() throws {
        let pins = [ProgressPin(subject: .training(.trainingVolume), metric: .time),
                    ProgressPin(subject: .cardio(activity: "outdoorRun"), metric: .distance),
                    ProgressPin(subject: .lift(exerciseID: UUID(), variation: .mostUsed), metric: .bestSet)]
        let decoded = ProgressPinStore.decode(ProgressPinStore.encode(pins))
        #expect(decoded == pins)
    }

    /// An older build knows only `lift` and `cardio`: a training pin is written in the cardio shape with an activity
    /// no build knows, which an older build decodes and quietly skips (D63) instead of failing the whole list. Read
    /// here with a copy of builds 8–9's synthesised pin type, and round-tripped old → new as a downgrade-then-upgrade.
    @Test func aTrainingPinIsWrittenInAShapeOlderBuildsSkip() throws {
        let lift = ProgressPin(subject: .lift(exerciseID: UUID(), variation: .mostUsed), metric: .volume)
        let training = ProgressPin(subject: .training(.workoutsPerWeek), metric: .time)
        let data = ProgressPinStore.encode([lift, training])
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(!json.contains("\"training\""))

        // The older build decodes the whole list; the training pin is a cardio pin with an unknown activity.
        let old = try JSONDecoder().decode([BuildNinePin].self, from: data)
        #expect(old.count == 2)
        #expect(old[0].subject == .lift(exerciseID: lift.exerciseID!, variation: .mostUsed))
        #expect(old[1].subject == .cardio(activity: "training.workoutsPerWeek"))
        #expect(CardioActivity(rawValue: "training.workoutsPerWeek") == nil)

        // It saves the full list again (a Move or Remove there); the next S4 build still has the training pin.
        let back = ProgressPinStore.decode(try JSONEncoder().encode(Array(old.reversed())))
        #expect(back.map(\.id) == [training.id, lift.id])
        #expect(back.first?.training == .workoutsPerWeek)
    }

    @Test func pinsSavedBeforeS4Decode() throws {
        let id = UUID()
        let old = #"[{"id":"\#(UUID().uuidString)","subject":{"lift":{"exerciseID":"\#(id.uuidString)","variation":{"mostUsed":{}}}},"metric":"bestSet"},{"id":"\#(UUID().uuidString)","subject":{"cardio":{"activity":"indoorRun"}},"metric":"pace"}]"#
        let pins = ProgressPinStore.decode(Data(old.utf8))
        #expect(pins.count == 2)
        #expect(pins.first?.exerciseID == id)
        #expect(pins.last?.activity == .indoorRun)
    }
}

/// Builds 8–9's `ProgressPin`, verbatim apart from the name (`main`'s `Domain/ProgressPins.swift`): synthesised
/// Codable, two subject cases. `ProgressPinMetric` and `PinnedLiftVariation` are unchanged since, so they are shared.
private struct BuildNinePin: Codable, Equatable {
    enum Subject: Codable, Equatable {
        case lift(exerciseID: UUID, variation: PinnedLiftVariation)
        case cardio(activity: String)
    }

    var id = UUID()
    var subject: Subject
    var metric: ProgressPinMetric
}
