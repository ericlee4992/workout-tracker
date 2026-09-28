import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

// Floodlight ticket 10 — the Ask AI flow's pure pieces and the save's returned ids.

@MainActor
struct AIRoutineFlowMathTests {
    private let chest = UUID(), back = UUID(), curl = UUID(), plank = UUID()
    private var groups: [UUID: String] { [chest: "Chest", back: "Back", curl: "Biceps", plank: "Core"] }

    private func item(_ id: UUID, sets: Int, reps: Int = 10, rest: Int = 60) -> AIRoutineStrength {
        AIRoutineStrength(exerciseID: id, sets: sets, reps: reps, restSeconds: rest)
    }

    // MARK: Goal phrases

    @Test func phrasesAddAndRemoveThemselves() {
        #expect(AIGoalPhrase.strength.toggled(in: "") == "Build strength.")
        #expect(AIGoalPhrase.muscle.toggled(in: "Build strength.") == "Build strength. Build muscle.")
        #expect(AIGoalPhrase.endurance.toggled(in: "Get fitter") == "Get fitter. Improve endurance.")
        #expect(AIGoalPhrase.strength.toggled(in: "Build strength. Build muscle.") == "Build muscle.")
        #expect(AIGoalPhrase.fatLoss.isIn("I want to lose fat soon"))
        #expect(!AIGoalPhrase.fatLoss.isIn("Build muscle."))
    }

    // MARK: Profile units

    @Test func profileUnitsRoundTrip() {
        let cm = AIProfileUnits.centimetres(feet: 5, inches: 11)
        #expect(abs(cm - 180.34) < 0.01)
        #expect(AIProfileUnits.feetInches(cm: cm) == (5, 11))
        #expect(AIProfileUnits.feetInches(cm: 182.9).feet == 6)
        #expect(abs(AIProfileUnits.kilograms(pounds: 180) - 81.6466) < 0.001)
        #expect(Int(AIProfileUnits.pounds(kg: 81.6466).rounded()) == 180)
        #expect(AIProfileUnits.parse("1 80a") == 180)
        #expect(AIProfileUnits.parse("") == nil)
        #expect(AIProfileUnits.text(179.6) == "180")
        #expect(AIProfileUnits.text(nil) == "")
    }

    // MARK: Stages

    @Test func stagesAdvanceOnTheirTimesAndHoldAtNinety() {
        #expect(AIRoutineStages.stage(at: 0, gymName: "Iron Temple").text == "Building your week…")
        #expect(AIRoutineStages.stage(at: 1.0, gymName: "Iron Temple").text == "Checking equipment at Iron Temple…")
        #expect(AIRoutineStages.stage(at: 1.0, gymName: nil).text == "Checking your equipment…")
        #expect(AIRoutineStages.stage(at: 2.0, gymName: nil).progress == 0.65)
        #expect(AIRoutineStages.stage(at: 60, gymName: nil).progress == 0.9)
        #expect(AIRoutineStages.stages(gymName: nil).map(\.progress) == [0.08, 0.35, 0.65, 0.9])
    }

    // MARK: Readouts

    @Test func sessionMinutesAreTheValidatorsEstimate() throws {
        let day = AIRoutineDay(name: "Day 1", strength: [item(chest, sets: 3, rest: 90), item(back, sets: 4, rest: 60)],
                               cardio: [AIRoutineCardio(activity: .rowing, minutes: 10)])
        // 3×45 + 2×90 + 60 = 375; 4×45 + 3×60 + 60 = 420; + 600 = 1395 s ≈ 23 min.
        #expect(AIRoutineReadouts.minutes(of: day) == 23)
        #expect(AIRoutineReadouts.sets(of: day) == 7)
        // The same estimate decides validation: 23 min passes a 20-minute request (≤ 25 min).
        let options = [chest, back].map { RoutineExerciseOption(id: $0, name: "x", muscleGroup: "Chest", equipment: nil) }
        let request = AIRoutineRequest(goals: "g", experience: "Beginner", days: 1, minutes: 20, heightCm: nil,
                                       weightKg: nil, exercises: options, cardioActivities: [.rowing])
        _ = try AIRoutine(sessions: [day]).validated(for: request)
    }

    @Test func familySharesLeadWithTheBiggestAndSkipCore() {
        let day = AIRoutineDay(name: "Pull", strength: [item(chest, sets: 2), item(back, sets: 4), item(curl, sets: 3),
                                                        item(plank, sets: 3)], cardio: [])
        #expect(AIRoutineReadouts.familyCounts(of: day, groups: groups).map(\.family) == [.chest, .back, .arms])
        #expect(AIRoutineReadouts.familyShares(of: day, groups: groups).map(\.family) == [.back, .arms, .chest])
        let tie = AIRoutineDay(name: "Tie", strength: [item(back, sets: 3), item(chest, sets: 3)], cardio: [])
        #expect(AIRoutineReadouts.familyShares(of: tie, groups: groups).map(\.family) == [.chest, .back], "ties head to toe")
    }

    @Test func weekCountsKeepEveryFamily() {
        let days = [AIRoutineDay(name: "A", strength: [item(chest, sets: 3)], cardio: []),
                    AIRoutineDay(name: "B", strength: [item(chest, sets: 2), item(curl, sets: 4)], cardio: [])]
        let counts = AIRoutineReadouts.weekFamilyCounts(days, groups: groups)
        #expect(counts.map(\.family) == MuscleFamily.allCases)
        #expect(counts.map(\.sets) == [5, 0, 0, 4, 0])
    }

    @Test func eligibleFamiliesComeFromTheOptions() {
        let options = [RoutineExerciseOption(id: chest, name: "Press", muscleGroup: "Chest", equipment: nil),
                       RoutineExerciseOption(id: plank, name: "Plank", muscleGroup: "Core", equipment: nil),
                       RoutineExerciseOption(id: curl, name: "Curl", muscleGroup: "Biceps", equipment: .dumbbell)]
        #expect(AIRoutineReadouts.eligibleFamilies(options) == [.chest, .arms])
    }

    @Test func requestLineLeavesOutAGymTheStageNames() {
        #expect(AIRoutineReadouts.requestLine(gymName: "Iron Temple", days: 3, minutes: 45) == "Iron Temple · 3 days · 45 min")
        #expect(AIRoutineReadouts.requestLine(gymName: "Iron Temple", days: 1, minutes: 30,
                                              omittingGymIn: "Checking equipment at Iron Temple…") == "1 day · 30 min")
        #expect(AIRoutineReadouts.requestLine(gymName: nil, days: 2, minutes: 60) == "2 days · 60 min")
    }

    @Test func errorTextSplitsWhatFromWhatToDo() {
        let offline = AIRoutineErrorText.split("Could not reach OpenAI. Check your connection or continue manually.")
        #expect(offline.what == "Could not reach OpenAI.")
        #expect(offline.next == "Check your connection.")
        #expect(AIRoutineErrorText.split("AI returned an invalid session.").next == nil)
    }

    // MARK: Save

    /// The Saved step lists what was saved: the save returns the new templates' ids in order.
    @Test func saveReturnsTheNewTemplateIDsInSessionOrder() throws {
        let container = try ModelContainer(for: WorkoutTrackerStore.schema,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let press = Exercise(name: "Seated Chest Press")
        context.insert(press)
        try context.save()
        let option = RoutineExerciseOption(id: press.id, name: press.name, muscleGroup: "Chest", equipment: nil)
        let request = AIRoutineRequest(goals: "g", experience: "Beginner", days: 2, minutes: 45, heightCm: nil,
                                       weightKg: nil, exercises: [option], cardioActivities: [])
        let routine = AIRoutine(sessions: [AIRoutineDay(name: "Day 1", strength: [item(press.id, sets: 3)], cardio: []),
                                           AIRoutineDay(name: "Day 2", strength: [item(press.id, sets: 2)], cardio: [])])
        let ids = try AIRoutinePersistence.save(routine, request: request, gymID: nil, extras: [], in: container)
        let saved = try container.mainContext.fetch(FetchDescriptor<WorkoutTemplate>())
        #expect(ids.count == 2)
        #expect(ids.compactMap { id in saved.first { $0.id == id }?.name } == ["Day 1", "Day 2"])
    }
}
