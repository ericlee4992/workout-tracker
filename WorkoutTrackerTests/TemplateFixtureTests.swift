import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

// Ticket 11's capture fixture: it must actually produce what the review
// asked to see — every family and a superset — or the captures prove nothing.
struct TemplateFixtureTests {

    @Test @MainActor func everyFixtureExerciseIsSeeded() throws {
        let seeded = Set(try SeedCatalog.bundled().exercises.map(\.name))
        for name in TemplateFixture.exerciseNames {
            #expect(seeded.contains(name), "\(name) is not in the seed catalog")
        }
    }

    @Test @MainActor func fixtureCoversEveryFamilyAndOneSuperset() throws {
        let container = try ModelContainer(
            for: WorkoutTrackerStore.schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = container.mainContext
        try CatalogSeeder.reconcile(try SeedCatalog.bundled(), in: context)
        try TemplateFixture.seed(in: context)
        try TemplateFixture.seed(in: context)   // idempotent

        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        #expect(templates.count == 1)
        let items = WorkoutTemplateService.orderedItems(of: try #require(templates.first))
        #expect(items.count == TemplateFixture.exerciseNames.count)
        #expect(MuscleFamily.families(of: items.map { $0.exercise?.muscleGroup }) == MuscleFamily.allCases)
        #expect(Supersets.memberLabels(groupIDs: items.map(\.supersetGroupID)) == ["A", "B", nil, nil, nil, nil])
    }

    /// Never without `-uiTestReset`: the argument alone must not seed a real store.
    @Test func requiresTheThrowawayStore() {
        #expect(!WorkoutTrackerStore.fixtureIsEnabled(TemplateFixture.launchArgument, in: ["-uiTestTemplate"]))
        #expect(WorkoutTrackerStore.fixtureIsEnabled(TemplateFixture.launchArgument, in: ["-uiTestReset", "-uiTestTemplate"]))
    }
}
