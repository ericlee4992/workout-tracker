import Foundation
import Testing
@testable import WorkoutTracker

/// Public beta ticket 05: the training profile's bounds (Ask AI's) and its units kept as entered (D52).
struct TrainingProfileTests {
    private let base = TrainingProfile(goals: "Get strong", experience: "Intermediate", days: 4, minutes: 45)

    @Test func measuresKeepTheirUnitAndShowAsEntered() {
        #expect(BodyMeasure(value: 70, unit: .inches).display == "5 ft 10 in")
        #expect(BodyMeasure(value: 178, unit: .cm).display == "178 cm")
        #expect(BodyMeasure(value: 180, unit: .lb).display == "180 lb")
        #expect(BodyMeasure(value: 82, unit: .kg).display == "82 kg")
        #expect(abs(BodyMeasure(value: 70, unit: .inches).centimetres - 177.8) < 0.001)
        #expect(abs(BodyMeasure(value: 180, unit: .lb).kilograms - 81.6466266) < 0.0001)
        #expect(BodyMeasure(value: 70, unit: .inches).kilograms.isNaN, "a height has no weight")
    }

    @Test func boundsMatchAskAI() {
        var p = base
        #expect(p.isValid)
        for (days, minutes, ok) in [(1, 15, true), (7, 120, true), (0, 45, false), (8, 45, false), (3, 14, false), (3, 121, false)] {
            p = base; p.days = days; p.minutes = minutes
            #expect(p.isValid == ok, "days \(days), minutes \(minutes)")
        }
        p = base; p.height = BodyMeasure(value: 98, unit: .inches)        // 248.9 cm
        #expect(p.isValid)
        p.height = BodyMeasure(value: 99, unit: .inches)                   // 251.5 cm
        #expect(!p.isValid)
        p = base; p.weight = BodyMeasure(value: 881, unit: .lb)            // 399.6 kg
        #expect(p.isValid)
        p.weight = BodyMeasure(value: 882, unit: .lb)                      // 400.1 kg
        #expect(!p.isValid)
        p = base; p.experience = "Expert"
        #expect(!p.isValid)
        p = base; p.goals = String(repeating: "a", count: 1001)
        #expect(!p.isValid)
    }

    @Test func encodesUnitsAsTheServerTakesThem() throws {
        var p = base
        p.height = BodyMeasure(value: 70, unit: .inches)
        p.weight = BodyMeasure(value: 82.5, unit: .kg)
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(p)) as! [String: Any]
        #expect((json["height"] as? [String: Any])?["unit"] as? String == "in")
        #expect((json["weight"] as? [String: Any])?["value"] as? Double == 82.5)
        #expect(try JSONDecoder().decode(TrainingProfile.self, from: JSONEncoder().encode(p)) == p)
    }
}
