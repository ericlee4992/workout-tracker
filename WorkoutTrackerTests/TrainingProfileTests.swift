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

    // MARK: Ticket 05 — Ask AI's form to the training profile

    private let saved = TrainingProfile(goals: "Pull-up by spring", experience: "Intermediate", days: 4, minutes: 45,
                                        height: BodyMeasure(value: 70.5, unit: .inches),
                                        weight: BodyMeasure(value: 180.4, unit: .lb))

    @MainActor private func prefilled(_ profile: TrainingProfile) -> AIRoutineFlowModel {
        let model = AIRoutineFlowModel()
        #expect(model.prefill(from: profile))
        #expect(!model.edited)
        return model
    }

    @MainActor @Test func aFormLeftAsPrefilledIsTheProfileUnchanged() {
        for usCustomary in [true, false] {
            let model = prefilled(saved)
            #expect(model.heightCm == saved.height?.centimetres && model.weightKg == saved.weight?.kilograms)
            // Unchanged: the profile's own decimals and units, whatever the app's units (D52).
            #expect(model.trainingProfile(usCustomary: usCustomary) == saved)
        }
    }

    @MainActor @Test func changedMeasuresAreSavedAsTypedInTheAppsUnits() {
        let model = prefilled(saved)
        model.goals = "  Pull-up by summer \n"
        model.days = 3
        model.heightCm = AIProfileUnits.centimetres(feet: 5, inches: 11)        // typed 5 ft 11 in
        model.weightKg = AIProfileUnits.kilograms(pounds: 175)                  // typed 175 lb
        let us = model.trainingProfile(usCustomary: true)
        #expect(us.goals == "Pull-up by summer")
        #expect(us.days == 3)
        #expect(us.height == BodyMeasure(value: 71, unit: .inches))
        #expect(us.weight == BodyMeasure(value: 175, unit: .lb))
        #expect(us.isValid)

        let metric = prefilled(saved)
        metric.heightCm = 181                                                  // typed 181 cm
        metric.weightKg = nil                                                  // cleared
        let m = metric.trainingProfile(usCustomary: false)
        #expect(m.height == BodyMeasure(value: 181, unit: .cm))
        #expect(m.weight == nil)
        #expect(m.days == saved.days && m.goals == saved.goals)
    }

    /// codex-review-05d F3: a near-integer stored value replaced with the integer is a change — saved as typed.
    @MainActor @Test func replacingANearlyEqualValueIsStillAChange() {
        let stored = TrainingProfile(goals: "Strength", experience: "Beginner", days: 3, minutes: 45,
                                     weight: BodyMeasure(value: 80.0005, unit: .kg))
        let model = prefilled(stored)
        model.weightKg = 80                                                    // typed 80 kg
        #expect(model.trainingProfile(usCustomary: false).weight == BodyMeasure(value: 80, unit: .kg))
    }

    /// codex-review-05d F3/F4: a profile that loads after the tester typed fills nothing in and is no baseline.
    @MainActor @Test func aProfileArrivingAfterAnEditFillsNothingIn() {
        let model = AIRoutineFlowModel()
        model.weightKg = 80                                                    // typed 80 kg before the profile loaded
        #expect(!model.prefill(from: saved))
        #expect(model.goals == "" && model.days == 3 && model.weightKg == 80)
        #expect(model.prefilledFrom == nil)
        #expect(model.trainingProfile(usCustomary: false).weight == BodyMeasure(value: 80, unit: .kg))

        let cleared = AIRoutineFlowModel()
        cleared.goals = "Get"                                                  // typed, then cleared
        cleared.goals = ""
        #expect(!cleared.prefill(from: saved), "typing then clearing is an edit")
        let reverted = AIRoutineFlowModel()
        reverted.days = 5
        reverted.days = 3                                                      // back to the default
        #expect(!reverted.prefill(from: saved))
    }

    @MainActor @Test func aFormWithoutAProfileMakesOne() {
        let model = AIRoutineFlowModel()
        model.goals = "Get fitter"
        model.weightKg = 80
        let p = model.trainingProfile(usCustomary: false)
        #expect(p == TrainingProfile(goals: "Get fitter", experience: "Beginner", days: 3, minutes: 45, height: nil,
                                     weight: BodyMeasure(value: 80, unit: .kg)))
        #expect(p.isValid)
    }
}
