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

    // MARK: Pins

    @Test func aTrainingPinRoundTripsAndOlderPinsStillDecode() throws {
        let pins = [ProgressPin(subject: .training(.trainingVolume), metric: .time),
                    ProgressPin(subject: .cardio(activity: "outdoorRun"), metric: .distance),
                    ProgressPin(subject: .lift(exerciseID: UUID(), variation: .mostUsed), metric: .bestSet)]
        let decoded = ProgressPinStore.decode(ProgressPinStore.encode(pins))
        #expect(decoded == pins)
    }

    /// An older build knows only `lift` and `cardio`: a training pin is written in the cardio shape with an activity
    /// no build knows, which an older build decodes and quietly skips (D63) instead of failing the whole list.
    @Test func aTrainingPinIsWrittenInAShapeOlderBuildsSkip() throws {
        let data = ProgressPinStore.encode([ProgressPin(subject: .training(.workoutsPerWeek), metric: .time)])
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"cardio\""))
        #expect(json.contains("training.workoutsPerWeek"))
        #expect(!json.contains("\"training\""))
        // Read as an older build would: the subject is cardio with an unknown activity.
        let legacy = try JSONDecoder().decode([LegacyPin].self, from: data)
        #expect(legacy.first?.subject.cardio?.activity == "training.workoutsPerWeek")
        #expect(CardioActivity(rawValue: "training.workoutsPerWeek") == nil)
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

/// The pin shape before S4 (synthesised Codable), to read new data the way an older build does.
private struct LegacyPin: Decodable {
    struct Subject: Decodable {
        struct Cardio: Decodable { var activity: String }
        var cardio: Cardio?
    }
    var id: UUID
    var subject: Subject
    var metric: String
}
