import Foundation
import SwiftData

// One template under a launch argument, for the UI tests' captures (UI
// redesign ticket 11, codex-review-11): the editor cannot build a superset,
// and a five-family strip needs six exercises — the review wanted the detail
// captured with a superset chip and a wrapping strip at AccessibilityL.
// Requires `-uiTestReset` too (`WorkoutTrackerStore.fixtureIsEnabled`), so it
// can never seed a real store.

enum TemplateFixture {

    static let launchArgument = "-uiTestTemplate"

    static var isEnabled: Bool {
        WorkoutTrackerStore.fixtureIsEnabled(launchArgument)
    }

    static let templateName = "Whole Body"

    /// Seeded exercise names, in template order, covering every family
    /// (Chest, Back, Shoulders, Arms via Biceps, Legs via Quads) plus one
    /// with none (Core). The first two are a superset.
    static let exerciseNames = [
        "Bench Press", "Lat Pulldown", "Machine Shoulder Press",
        "Dumbbell Curl", "Leg Press", "Abdominal Crunch",
    ]

    /// Idempotent by name: a relaunch inside one test run adds nothing.
    static func seed(in context: ModelContext) throws {
        let name = templateName
        let existing = try context.fetch(
            FetchDescriptor<WorkoutTemplate>(predicate: #Predicate { $0.name == name }))
        guard existing.isEmpty else { return }
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let template = WorkoutTemplate(name: name)
        context.insert(template)
        let superset = UUID()
        for (order, exerciseName) in exerciseNames.enumerated() {
            guard let exercise = exercises.first(where: { $0.name == exerciseName }) else { continue }
            let item = TemplateItem(
                order: order,
                targetRepsBySet: order == 4 ? [12, 10, 8, 6] : [10, 10, 10],
                supersetGroupID: order < 2 ? superset : nil,
                exercise: exercise)
            item.template = template
            context.insert(item)
        }
        try context.save()
    }
}
