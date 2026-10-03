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

    @Test func fractionsShowAsEntered() {
        #expect(BodyMeasure(value: 82.5, unit: .kg).display == "82.5 kg")
        #expect(BodyMeasure(value: 70.5, unit: .inches).display == "5 ft 10.5 in")
        #expect(BodyMeasure(value: 177.25, unit: .cm).display == "177.25 cm")
        #expect(BodyMeasure(value: 180, unit: .lb).display == "180 lb")
        #expect(BodyMeasure(value: 82.567, unit: .kg).display == "82.567 kg", "a server value's precision is kept")
    }

    @Test func typedNumbersAreReadStrictlyNeverTruncated() {
        #expect(TypedNumber("82.5") == .value(82.5))
        #expect(TypedNumber("82,25") == .value(82.25))
        #expect(TypedNumber("180") == .value(180))
        #expect(TypedNumber("  ") == .empty)
        for bad in ["82.567", "82.", ".5", "abc", "1.2.3", "12345", "-5"] {
            #expect(TypedNumber(bad) == .invalid, "\(bad)")
        }
        #expect(TypedNumber("5.5", decimals: false) == .invalid)
    }

    @Test func feetAndInchesAreReadTogether() {
        var h = MeasureDraft(BodyMeasure(value: 70.5, unit: .inches), kind: .height, imperial: true)
        #expect([h.first, h.second] == ["5", "10.5"])
        // Replace the feet: the inches shown are the inches saved (codex-review-05b #1).
        h.first = ""
        h.first = "6"
        #expect(h.measure == .some(BodyMeasure(value: 82.5, unit: .inches)))
        // Replace the inches, keeping the feet.
        h.second = "3"
        #expect(h.measure == .some(BodyMeasure(value: 75, unit: .inches)))
        // 12 inches or more is not an entry (never clamped or carried).
        h.second = "12"
        #expect(h.measure == nil)
        h.second = "11.99"
        #expect(h.measure == .some(BodyMeasure(value: 83.99, unit: .inches)))
        // Clearing both clears the height.
        h.first = ""; h.second = ""
        #expect(h.measure == .some(nil))
    }

    @Test func anUntouchedFieldKeepsTheStoredValueExactly() {
        let stored = BodyMeasure(value: 82.567, unit: .kg)   // more decimals than the editor accepts
        var w = MeasureDraft(stored, kind: .weight, imperial: false)
        #expect(w.first == "82.567")
        #expect(w.measure == .some(stored), "an unrelated edit and save keep it")
        w.first = "82.567"                                    // retyped identically: still the stored value
        #expect(w.measure == .some(stored))
        w.first = "82.5671"
        #expect(w.measure == nil, "typed precision beyond two decimals is refused, not truncated")
        w.first = "90"
        #expect(w.measure == .some(BodyMeasure(value: 90, unit: .kg)))
    }

    @Test func emptyMeasuresTakeTheAppsUnits() {
        var h = MeasureDraft(nil, kind: .height, imperial: false)
        h.first = "178.5"
        #expect(h.measure == .some(BodyMeasure(value: 178.5, unit: .cm)))
        var w = MeasureDraft(nil, kind: .weight, imperial: true)
        #expect(w.measure == .some(nil))
        w.first = "180"
        #expect(w.measure == .some(BodyMeasure(value: 180, unit: .lb)))
    }

    @Test func goalChecksMatchTheServer() {
        var p = base
        for (goals, ok) in [("   ", false), ("hi\u{0}", false), ("hi\u{7F}", false), ("line one\nline two\tok", true),
                            (String(repeating: "💪🏽", count: 1000), true), (String(repeating: "a", count: 1001), false)] {
            p.goals = goals
            #expect(p.isValid == ok, "\(goals.prefix(10))")
        }
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
