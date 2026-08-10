import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

struct TemplateDriftTests {
    private let a = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let b = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let c = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!

    @Test func detectsEverySpecifiedDriftAndAcceptsIdenticalWorkout() {
        let template = [item(a, [10, 8]), item(b, [12])]

        #expect(!TemplateDrift.hasDrift(template: template, workout: template))
        #expect(TemplateDrift.hasDrift(
            template: template,
            workout: template + [item(c, [7])]))
        #expect(TemplateDrift.hasDrift(
            template: template,
            workout: [item(a, [10, 8])]))
        #expect(TemplateDrift.hasDrift(
            template: template,
            workout: [item(b, [12]), item(a, [10, 8])]))
        #expect(TemplateDrift.hasDrift(
            template: template,
            workout: [item(a, [10, 8, 6]), item(b, [12])]))
        #expect(TemplateDrift.hasDrift(
            template: template,
            workout: [item(a, [9, 8]), item(b, [12])]))
    }

    @Test func updateTemplateReplacesStructureAndPreservesMatchedTargets() {
        #expect(TemplateDrift.resolving(
            .updateTemplate, template: original, workout: completed) == [
                item(b, [12, nil]),
                item(a, [10]),
                item(c, [nil]),
                item(a, [5, nil]),
            ])
    }

    @Test func updateValuesOnlyKeepsStructureAndMergesAvailableSlots() {
        #expect(TemplateDrift.resolving(
            .updateValuesOnly, template: original, workout: completed) == [
                item(a, [9, 8]),
                item(b, [15]),
                item(a, [6]),
            ])
    }

    @Test func updateBothUsesCompletedStructureAndValuesExactly() {
        #expect(TemplateDrift.resolving(
            .updateBoth, template: original, workout: completed) == completed)
    }

    @Test func keepOriginalWritesNothing() {
        #expect(TemplateDrift.resolving(
            .keepOriginal, template: original, workout: completed) == original)
    }

    @Test(arguments: TemplateDriftResolution.allCases)
    func serviceAppliesEachResolutionExactly(_ resolution: TemplateDriftResolution) throws {
        let context = try makeContext()
        let exerciseA = Exercise(id: a, name: "A")
        let exerciseB = Exercise(id: b, name: "B")
        let exerciseC = Exercise(id: c, name: "C")
        context.insert(exerciseA)
        context.insert(exerciseB)
        context.insert(exerciseC)
        try context.save()
        let templates = WorkoutTemplateService(context: context)
        let template = try templates.create(name: "Original", items: [
            TemplateItemDraft(exercise: exerciseA, targetRepsBySet: [10, 8]),
            TemplateItemDraft(exercise: exerciseB, targetRepsBySet: [12]),
            TemplateItemDraft(exercise: exerciseA, targetRepsBySet: [5]),
        ])
        let session = WorkoutSession(context: context)
        let workout = try session.startWorkout(at: nil)
        workout.sourceTemplateID = template.id
        try addCompleted([15, 14], exercise: exerciseB, workout: workout, session: session)
        try addCompleted([9], exercise: exerciseA, workout: workout, session: session)
        try addCompleted([7], exercise: exerciseC, workout: workout, session: session)
        try addCompleted([6, 6], exercise: exerciseA, workout: workout, session: session)

        let service = TemplateDriftService(context: context)
        try service.apply(resolution, workout: workout, to: template)

        #expect(service.templateSnapshot(template) == TemplateDrift.resolving(
            resolution, template: original, workout: completed))
    }

    @Test func uncompletedEntriesDoNotCountAsDrift() throws {
        let context = try makeContext()
        let exerciseA = Exercise(id: a, name: "A")
        let exerciseC = Exercise(id: c, name: "C")
        context.insert(exerciseA)
        context.insert(exerciseC)
        try context.save()
        let template = try WorkoutTemplateService(context: context).create(
            name: "A", items: [
                TemplateItemDraft(exercise: exerciseA, targetRepsBySet: [10]),
            ])
        let workout = try WorkoutTemplateService(context: context)
            .start(template, at: nil)
        let session = WorkoutSession(context: context)
        let aEntry = try #require(WorkoutSession.orderedEntries(of: workout).first)
        let aSet = try #require(WorkoutSession.orderedSets(of: aEntry).first)
        // Started rows are empty drafts (defect 4), so matching the template
        // means actually logging its target (A1: weight + reps).
        try session.commitWeight("50", for: aSet)
        try session.commitReps("10", for: aSet)
        try session.toggleCompletion(of: aSet)
        _ = try session.addEntry(for: exerciseC, to: workout)

        #expect(try !TemplateDriftService(context: context)
            .shouldPrompt(for: workout, template: template))
    }

    /// Defect 5 regression: an item whose exercise was deleted (nullify) is
    /// dropped from the template snapshot. "Update values only" must still
    /// write each exercise's completed reps onto ITS OWN item — a positional
    /// zip shifted every later item's targets by one.
    @Test func updateValuesOnlySkipsOrphanedItemsInsteadOfShiftingTargets() throws {
        let context = try makeContext()
        let exerciseA = Exercise(id: a, name: "A")
        let exerciseB = Exercise(id: b, name: "B")
        let exerciseC = Exercise(id: c, name: "C")
        context.insert(exerciseA)
        context.insert(exerciseB)
        context.insert(exerciseC)
        try context.save()
        let templates = WorkoutTemplateService(context: context)
        let template = try templates.create(name: "Original", items: [
            TemplateItemDraft(exercise: exerciseA, targetRepsBySet: [10, 8]),
            TemplateItemDraft(exercise: exerciseB, targetRepsBySet: [12]),
            TemplateItemDraft(exercise: exerciseC, targetRepsBySet: [20, 20]),
        ])
        // The MIDDLE item loses its exercise to a catalog delete.
        context.delete(exerciseB)
        try context.save()
        let items = WorkoutTemplateService.orderedItems(of: template)
        #expect(items.count == 3)
        #expect(items[1].exercise == nil)

        let session = WorkoutSession(context: context)
        let workout = try session.startWorkout(at: nil)
        workout.sourceTemplateID = template.id
        try addCompleted([9, 7], exercise: exerciseA, workout: workout, session: session)
        try addCompleted([15, 14], exercise: exerciseC, workout: workout, session: session)

        let service = TemplateDriftService(context: context)
        try service.apply(.updateValuesOnly, workout: workout, to: template)

        let after = WorkoutTemplateService.orderedItems(of: template)
        #expect(after[0].exercise?.id == a)
        #expect(after[0].targetRepsBySet == [9, 7])
        // The orphan keeps its own values; C's reps must not land on it.
        #expect(after[1].exercise == nil)
        #expect(after[1].targetRepsBySet == [12])
        #expect(after[2].exercise?.id == c)
        #expect(after[2].targetRepsBySet == [15, 14])
        #expect(service.templateSnapshot(template) == [
            item(a, [9, 7]), item(c, [15, 14]),
        ])
    }

    /// Post-review critical regression: start a populated template, complete
    /// NOTHING, and resolve the drift. "Update Template"/"Update Both" used to
    /// delete every item and rebuild from an empty snapshot — the template was
    /// erased while the receipt said nothing was saved. A workout with no
    /// completed entries has no drift to apply, whichever resolution is asked
    /// for, and there is nothing to prompt about either.
    @Test(arguments: TemplateDriftResolution.allCases)
    func emptyTemplateWorkoutNeverTouchesItsTemplate(
        _ resolution: TemplateDriftResolution
    ) throws {
        let context = try makeContext()
        let exerciseA = Exercise(id: a, name: "A")
        let exerciseB = Exercise(id: b, name: "B")
        let exerciseC = Exercise(id: c, name: "C")
        for exercise in [exerciseA, exerciseB, exerciseC] { context.insert(exercise) }
        try context.save()
        let template = try WorkoutTemplateService(context: context).create(
            name: "Push Day", items: [
                TemplateItemDraft(exercise: exerciseA, targetRepsBySet: [10, 8]),
                TemplateItemDraft(exercise: exerciseB, targetRepsBySet: [12]),
                TemplateItemDraft(exercise: exerciseC, targetRepsBySet: [20, 20]),
            ])
        let before = TemplateDriftService(context: context).templateSnapshot(template)
        // Start it and log nothing at all — the rows materialize as drafts.
        let workout = try WorkoutTemplateService(context: context)
            .start(template, at: nil)
        #expect(WorkoutSession.orderedEntries(of: workout).count == 3)

        let service = TemplateDriftService(context: context)
        // Nothing completed → nothing to ask about.
        #expect(try !service.shouldPrompt(for: workout, template: template))

        try service.apply(resolution, workout: workout, to: template)

        #expect(WorkoutTemplateService.orderedItems(of: template).count == 3)
        #expect(service.templateSnapshot(template) == before)
        #expect(service.templateSnapshot(template) == [
            item(a, [10, 8]), item(b, [12]), item(c, [20, 20]),
        ])

        // The whole path (`resolve` = apply + finish) leaves the template
        // intact and discards the empty workout (A2).
        let outcome = try service.resolve(resolution, workout: workout, to: template)
        #expect(outcome == .discardedEmpty)
        #expect(WorkoutTemplateService.orderedItems(of: template).count == 3)
        #expect(service.templateSnapshot(template) == before)
        #expect(try context.fetch(FetchDescriptor<Workout>()).isEmpty)
    }

    @Test func suppressionMeansNoPromptAndLeavesTemplateUnchanged() throws {
        let context = try makeContext()
        let exerciseA = Exercise(id: a, name: "A")
        context.insert(exerciseA)
        context.insert(AppPreferences(driftPromptSuppressed: true))
        try context.save()
        let template = try WorkoutTemplateService(context: context).create(
            name: "A", items: [
                TemplateItemDraft(exercise: exerciseA, targetRepsBySet: [10]),
            ])
        let workout = try WorkoutTemplateService(context: context)
            .start(template, at: nil)
        let session = WorkoutSession(context: context)
        let entry = try #require(WorkoutSession.orderedEntries(of: workout).first)
        let set = try #require(WorkoutSession.orderedSets(of: entry).first)
        try session.commitWeight("50", for: set)
        try session.commitReps("9", for: set)
        try session.toggleCompletion(of: set)
        let service = TemplateDriftService(context: context)

        #expect(try !service.shouldPrompt(for: workout, template: template))
        #expect(service.templateSnapshot(template) == [item(a, [10])])
    }

    private var original: [TemplateDriftItem] {
        [item(a, [10, 8]), item(b, [12]), item(a, [5])]
    }

    private var completed: [TemplateDriftItem] {
        [item(b, [15, 14]), item(a, [9]), item(c, [7]), item(a, [6, 6])]
    }

    private func item(_ id: UUID, _ reps: [Int?]) -> TemplateDriftItem {
        TemplateDriftItem(exerciseID: id, targetRepsBySet: reps)
    }

    private func makeContext() throws -> ModelContext {
        let schema = WorkoutTrackerStore.schema
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(
                schema: schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    private func addCompleted(
        _ reps: [Int],
        exercise: Exercise,
        workout: Workout,
        session: WorkoutSession
    ) throws {
        let entry = try session.addEntry(for: exercise, to: workout)
        while WorkoutSession.orderedSets(of: entry).count < reps.count {
            try session.addSet(to: entry)
        }
        for (index, set) in WorkoutSession.orderedSets(of: entry).enumerated() {
            try session.commitWeight("50", for: set)
            try session.commitReps(String(reps[index]), for: set)
            try session.toggleCompletion(of: set)
        }
    }
}
