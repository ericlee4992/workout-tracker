import CoreData
import CryptoKit
import Foundation
import SwiftData
import Testing

@testable import WorkoutTracker

/// Nutrition N14 (D85): the goal setup's plan from the server — the request, the reply's plausibility check, the
/// draft's ask-once / fall-back behaviour, and generated numbers that stay put until regenerated or Recalculate.
@MainActor
struct GeneratedGoalsTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    private func context() throws -> ModelContext {
        let configuration = ModelConfiguration(schema: WorkoutTrackerStore.schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: WorkoutTrackerStore.schema, configurations: [configuration]))
    }

    private let served = Macros(calories: 2_100, proteinGrams: 160, carbsGrams: 215, fatGrams: 68)

    // MARK: The request and the reply

    @Test func theRequestCarriesTheAnswersOnly() throws {
        var inputs = NutritionGoals.Inputs(weightKg: 68.5, heightCm: 168.04, ageYears: 30, sex: .female,
                                           activity: .moderate, goal: .lose, paceKgPerWeek: 0.35)
        let body = GoalPlanAI.body(inputs, desiredKg: 63.5)
        #expect(Set(body.keys) == ["sex", "ageYears", "heightCm", "weightKg", "activity", "goal", "desiredWeightKg",
                                   "paceKgPerWeek"])
        #expect(body["sex"] as? String == "female" && body["activity"] as? String == "moderate")
        #expect(body["heightCm"] as? Double == 168 && body["desiredWeightKg"] as? Double == 63.5)
        inputs.goal = .maintain
        let maintain = GoalPlanAI.body(inputs, desiredKg: nil)
        #expect(maintain["desiredWeightKg"] == nil && maintain["paceKgPerWeek"] == nil)
        #expect(JSONSerialization.isValidJSONObject(body))
    }

    @Test func aPlausibleReplyIsTakenAndAnythingElseIsNot() {
        #expect(GoalPlanAI.parse(GoalPlanAI.fixtureReply) == served)
        let bad = [
            #"{"calories":400,"protein":100,"carbs":10,"fat":10}"#,
            #"{"calories":2000.5,"protein":100,"carbs":100,"fat":100}"#,
            #"{"calories":2000,"protein":-1,"carbs":100,"fat":100}"#,
            #"{"calories":2000,"protein":1001,"carbs":100,"fat":100}"#,
            #"{"calories":"2000","protein":100,"carbs":100,"fat":100}"#,
            #"{"calories":2000,"protein":true,"carbs":100,"fat":100}"#,
            #"{"calories":2000,"protein":100,"carbs":100}"#,
            "not json",
        ]
        for reply in bad { #expect(GoalPlanAI.parse(Data(reply.utf8)) == nil, "\(reply)") }
    }

    // MARK: The draft

    private func readyDraft(goal: WeightGoal = .lose) -> GoalSetupDraft {
        let draft = GoalSetupDraft(now: date(12), calendar: calendar)
        draft.sex = .female
        draft.birthDate = calendar.date(from: DateComponents(year: 1996, month: 8, day: 2))!
        draft.heightCm = 168
        draft.weightText = "68.5"
        draft.workouts = .some
        draft.goal = goal
        draft.step = .goal
        draft.advance()
        if goal != .maintain { draft.advance(); draft.advance() }
        return draft
    }

    @Test func thePlanPageAsksOnceAndShowsTheServersPlan() async throws {
        let draft = readyDraft()
        #expect(draft.step == .plan && draft.generationRequest != nil)
        var asked = 0
        let generator: GoalSetupDraft.Generator = { inputs, desired in
            asked += 1
            #expect(inputs.paceKgPerWeek == draft.paceKg && desired == draft.desiredKg)
            return self.served
        }
        await draft.generate(with: generator)
        await draft.generate(with: generator)
        #expect(asked == 1)
        #expect(draft.generatedPlan == served && draft.plan == served && !draft.generationFailed)
        let answers = try #require(draft.answers)
        #expect(answers.generated == served)

        // A typed number sits on top of the server's plan, without asking again.
        draft.overrides.proteinGrams = 170
        #expect(draft.plan == Macros(calories: 2_100, proteinGrams: 170, carbsGrams: 215, fatGrams: 68))
        await draft.generate(with: generator)
        #expect(asked == 1)

        // A changed answer (Back, a faster pace) is a new request: the old plan no longer applies.
        draft.step = .pace
        draft.paceKg = try #require(draft.paces).fast
        draft.step = .plan
        #expect(draft.generatedPlan == nil)
        await draft.generate(with: generator)
        #expect(asked == 2)
    }

    @Test func noAnswerFromTheServerFallsBackToTheCalculation() async throws {
        let draft = readyDraft(goal: .maintain)
        var asked = 0
        await draft.generate(with: { _, _ in asked += 1; return nil })
        #expect(draft.generationFailed && draft.generatedPlan == nil)
        #expect(draft.plan?.calories == 2_207, "the on-phone maintenance calories")
        #expect(try #require(draft.answers).generated == nil)
        await draft.generate(with: { _, _ in asked += 1; return nil })
        #expect(asked == 1, "not retried until an answer changes")
    }

    /// codex-review-n14 R5: Back (the request's task cancelled) is not a failure — returning asks again; a real failed
    /// answer is still asked once.
    @Test func aCancelledAskIsNotAFailure() async throws {
        let draft = readyDraft(goal: .maintain)
        var asked = 0
        // Never answers: it only ends by being cancelled, so the outcome does not depend on timing.
        let slow: GoalSetupDraft.Generator = { _, _ in
            asked += 1
            while true { try await Task.sleep(for: .milliseconds(10)) }
        }
        let task = Task { await draft.generate(with: slow) }
        for _ in 0..<1_000 where !draft.isGenerating { try await Task.sleep(for: .milliseconds(5)) }
        #expect(draft.isGenerating && asked == 1)
        task.cancel()
        await task.value
        #expect(!draft.isGenerating && !draft.generationFailed && draft.generatedPlan == nil)
        await draft.generate(with: { _, _ in asked += 1; return self.served })
        #expect(asked == 2 && draft.generatedPlan == served)
    }

    @Test func nothingIsSavedWhileThePlanIsBeingMade() async throws {
        let draft = readyDraft(goal: .maintain)
        var observed: Bool?
        await draft.generate(with: { _, _ in
            observed = draft.isGenerating && draft.answers == nil
            return self.served
        })
        #expect(observed == true)
        #expect(!draft.isGenerating && draft.answers != nil)
    }

    // MARK: The store

    private func commitGenerated(_ context: ModelContext, on day: Int = 10) throws -> NutritionGoal {
        let answers = GoalSetupStore.Answers(
            sex: .male, birthDate: calendar.date(from: DateComponents(year: 1996, month: 11, day: 1))!,
            height: .init(value: 180, unit: .cm), weight: .init(value: 80, unit: .kg), activity: .moderate, goal: .lose,
            desired: .init(value: 75, unit: .kg), paceKgPerWeek: 0.4, generated: served)
        return try #require(try GoalSetupStore.commit(answers, in: context, now: date(day), calendar: calendar))
    }

    @Test func generatedNumbersAreSavedAndStayWhenDetailsChange() throws {
        let context = try context()
        let goal = try commitGenerated(context)
        #expect(goal.generated && goal.calories == 2_100 && goal.proteinGrams == 160)
        #expect(!goal.caloriesOverridden && goal.paceKgPerWeek == 0.4)

        // A new weigh-in, a height change: the stored plan is kept (no recalculation over the server's numbers).
        context.insert(BodyWeightEntry(measuredAt: date(12), value: 78, unit: .kg, createdAt: date(12)))
        try AppPreferences.canonical(in: context).setHeight(value: 182, unit: .cm)
        try context.save()
        let after = try #require(try NutritionGoalStore.update(in: context, now: date(12), calendar: calendar))
        #expect(after.generated && after.calories == 2_100 && after.carbsGrams == 215)
    }

    @Test func aTypedNumberSitsOnTopAndRecalculateGoesBackToTheCalculation() throws {
        let context = try context()
        _ = try commitGenerated(context)
        let typed = try #require(try NutritionGoalStore.update(in: context, now: date(10, 12), calendar: calendar) {
            $0.overrides.fatGrams = 60
        })
        #expect(typed.generated && typed.fatGrams == 60 && typed.fatOverridden && typed.calories == 2_100)

        let calculated = try #require(try NutritionGoalStore.update(in: context, now: date(10, 13), calendar: calendar) {
            $0.overrides = .none
            $0.generated = nil
        })
        #expect(!calculated.generated && !calculated.fatOverridden)
        // 80 kg, 180 cm, 30, male, moderate, −0.4 kg a week: 2,759 − 440.
        #expect(calculated.calories == 2_319)
    }

    @Test func aRunWithoutTheServerReplacesAGeneratedGoalWithACalculatedOne() throws {
        let context = try context()
        _ = try commitGenerated(context)
        var answers = GoalSetupStore.Answers(
            sex: .male, birthDate: calendar.date(from: DateComponents(year: 1996, month: 11, day: 1))!,
            height: .init(value: 180, unit: .cm), weight: .init(value: 80, unit: .kg), activity: .moderate, goal: .lose,
            desired: .init(value: 75, unit: .kg), paceKgPerWeek: 0.4)
        answers.generated = nil
        let goal = try #require(try GoalSetupStore.commit(answers, in: context, now: date(12), calendar: calendar))
        #expect(!goal.generated && goal.calories == 2_319)
    }

    /// codex-review-n14 R4: an entered 80 kg, then a newer 90 kg from Apple Health. The setup shows and sends 80 kg; the
    /// saved goal is made from 80 kg too (the confirmed answer becomes today's weight), generated or calculated.
    @Test func theSavedGoalUsesTheConfirmedWeightNotANewerHealthOne() throws {
        for generated in [nil, served] {
            let context = try context()
            context.insert(BodyWeightEntry(measuredAt: date(8), value: 80, unit: .kg, createdAt: date(8)))
            let health = BodyWeightEntry(measuredAt: date(11), value: 90, unit: .kg, createdAt: date(11))
            health.source = .health
            context.insert(health)
            try context.save()
            let prefill = try GoalSetupStore.prefill(in: context)
            #expect(prefill.weight == .init(value: 80, unit: .kg))
            var answers = GoalSetupStore.Answers(
                sex: .male, birthDate: calendar.date(from: DateComponents(year: 1996, month: 11, day: 1))!,
                height: .init(value: 180, unit: .cm), weight: try #require(prefill.weight), activity: .moderate,
                goal: .lose, desired: .init(value: 75, unit: .kg), paceKgPerWeek: 0.4)
            answers.generated = generated
            let goal = try #require(try GoalSetupStore.commit(answers, in: context, now: date(12), calendar: calendar))
            #expect(goal.weightKg == 80, "the weight the plan was made from")
            #expect(goal.calories == (generated == nil ? 2_319 : 2_100), "as the plan page showed")
            let latest = try #require(try NutritionGoalStore.latestWeight(in: context))
            #expect(latest.value == 80 && latest.source == .app && latest.measuredAt == date(12))
            // A refresh keeps it (the latest weight is now the confirmed one).
            let refreshed = try #require(try NutritionGoalStore.update(in: context, now: date(12, 15), calendar: calendar))
            #expect(refreshed.weightKg == 80 && refreshed.calories == goal.calories)
        }
    }

    @Test func theSetupPrefillsOnlyAWeightEnteredInStacked() throws {
        let context = try context()
        context.insert(BodyWeightEntry(measuredAt: date(8), value: 80, unit: .kg, createdAt: date(8)))
        let health = BodyWeightEntry(measuredAt: date(11), value: 79, unit: .kg, createdAt: date(11))
        health.source = .health
        context.insert(health)
        try context.save()
        #expect(try GoalSetupStore.prefill(in: context).weight == .init(value: 80, unit: .kg))
    }

    @Test func exportCarriesTheMarkerOnlyWhenGenerated() throws {
        let context = try context()
        _ = try commitGenerated(context)
        let collector = ExportCollector(dateFormat: ExportDateFormat(timeZone: calendar.timeZone), appVersion: "test")
        let snapshot = try collector.snapshot(from: context)
        #expect(snapshot.schemaVersion == 14 && snapshot.nutritionGoals?.first?.generated == true)
        #expect(try ExportJSON.decode(try ExportJSON.data(snapshot)) == snapshot)

        let plain = try self.context()
        try GoalSetupStore.commit(.init(
            sex: .male, birthDate: calendar.date(from: DateComponents(year: 1996, month: 11, day: 1))!,
            height: .init(value: 180, unit: .cm), weight: .init(value: 80, unit: .kg), activity: .moderate,
            goal: .maintain), in: plain, now: date(10), calendar: calendar)
        let text = String(decoding: try ExportJSON.data(try collector.snapshot(from: plain)), as: UTF8.self)
        #expect(!text.contains("\"generated\""))
    }
}

/// N14's stored-format change: `Fixtures/Build11.store` is a store in 0.2.0 (11)'s format — written 2026-11-12 by the
/// app at `main` `99bafefd` (the build-11 model) under `-uiTestReset` with the design sample, Personal details, the food
/// sample and diary and the nutrition charts' weigh-ins; its one goal then given a desired weight (170 lb) and a pace
/// (0.4 kg a week) with sqlite3, so the N13 fields travel too. 7 workouts, 58 sets, 18 food entries, 29 weights.
struct GeneratedGoalsMigrationTests {
    private final class BundleMarker {}

    private func fixtureURL() throws -> URL {
        try #require(Bundle(for: BundleMarker.self).url(forResource: "Build11", withExtension: "store"),
                     "the build 11 fixture must ship with the test bundle")
    }

    @Test func theFixtureIsInBuildElevensFormat() throws {
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(type: .sqlite, at: try fixtureURL())
        let hashes = try #require(metadata[NSStoreModelVersionHashesKey] as? [String: Data])
        let hex = { (data: Data) in data.map { String(format: "%02x", $0) }.joined() }
        let lines = hashes.sorted { $0.key < $1.key }.map { "\($0.key):\(hex($0.value))" }
        #expect(hex(Data(SHA256.hash(data: Data(lines.joined(separator: "\n").utf8)))) == StoreFormatGuardTests.build11Fingerprint)
    }

    @Test func theSafetyCopySeesTheChangeBeforeTheOpen() throws {
        let model = NSManagedObjectModel.makeManagedObjectModel(for: WorkoutTrackerStore.modelTypes)
        #expect(SafetyCopies.storeNeedsCopy(at: try fixtureURL(), model: model))
    }

    @Test @MainActor func rowsAndTheGoalSurviveWithTheMarkerOff() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "build-11-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "default.store")
        try FileManager.default.copyItem(at: try fixtureURL(), to: url)
        let context = ModelContext(try WorkoutTrackerStore.makeContainer(url: url))
        #expect(try context.fetchCount(FetchDescriptor<Workout>()) == 7)
        #expect(try context.fetchCount(FetchDescriptor<SetRecord>()) == 58)
        #expect(try context.fetchCount(FetchDescriptor<FoodEntry>()) == 18)
        #expect(try context.fetchCount(FetchDescriptor<BodyWeightEntry>()) == 29)
        let goal = try #require(try context.fetch(FetchDescriptor<NutritionGoal>()).first)
        #expect(goal.calories == 2_763 && goal.goal == .lose && !goal.generated)
        #expect(goal.desiredWeightValue == 170 && goal.desiredWeightUnit == .lb && goal.paceKgPerWeek == 0.4)
        #expect(NutritionGoalStore.choices(of: goal).generated == nil)
    }
}
