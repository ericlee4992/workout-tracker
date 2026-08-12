import Testing

@testable import WorkoutTracker

// The movement-label default (user, 2026-08-12): CLAUDE.md keeps fallback
// selection in `Domain/` and unit-tested, which is where the review put it back
// (codex-review, standards finding 1).

struct MachineLabelDefaultsTests {

    @Test func aSingleExerciseModelIsNamedAfterTheMovement() {
        #expect(
            MachineLabelDefaults.label(
                modelName: "Insignia Series Chest Press",
                exerciseNames: ["Seated Chest Press"]) == "Seated Chest Press")
    }

    /// A station serving five movements has no single answer, so it keeps the
    /// model name rather than picking one for the user to undo.
    @Test func aMultiExerciseStationKeepsItsModelName() {
        #expect(
            MachineLabelDefaults.label(
                modelName: "5 Station",
                exerciseNames: ["Cable Crossover", "Lat Pulldown", "Low Row"]) == "5 Station")
    }

    @Test func aModelServingNothingKeepsItsModelName() {
        #expect(
            MachineLabelDefaults.label(modelName: "Corner machine", exerciseNames: [])
                == "Corner machine")
        // A blank or whitespace movement name is not a name.
        #expect(
            MachineLabelDefaults.label(modelName: "Corner machine", exerciseNames: ["  "])
                == "Corner machine")
    }

    @Test func theMovementNameIsTrimmed() {
        #expect(
            MachineLabelDefaults.label(
                modelName: "Whatever", exerciseNames: [" Leg Press \n"]) == "Leg Press")
    }
}
