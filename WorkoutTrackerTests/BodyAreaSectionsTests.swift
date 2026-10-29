import Foundation
import Testing
@testable import WorkoutTracker

// Public beta ticket 19 — Add Chart groups the logged exercises by body area, with the rule the
// Add Exercise picker already used: head to toe, then other groups A–Z, then Uncategorized.

struct BodyAreaSectionsTests {

    private struct Item: Equatable {
        var name: String
        var group: String?
    }

    @Test func sectionsRunHeadToToeNotAlphabetically() {
        let items = [Item(name: "Squat", group: "Quads"), Item(name: "Curl", group: "Biceps"),
                     Item(name: "Bench", group: "Chest"), Item(name: "Plank", group: "Core")]
        let titles = BodyArea.sections(of: items) { $0.group }.map(\.title)
        #expect(titles == ["Chest", "Biceps", "Quads", "Core"])
    }

    @Test func otherGroupsFollowAToZAndUngroupedComeLast() {
        let items = [Item(name: "A", group: nil), Item(name: "B", group: "Obliques"), Item(name: "C", group: ""),
                     Item(name: "D", group: "Adductors"), Item(name: "E", group: "Back")]
        let sections = BodyArea.sections(of: items) { $0.group }
        #expect(sections.map(\.title) == ["Back", "Adductors", "Obliques", "Uncategorized"])
        #expect(sections.last?.items.map(\.name) == ["A", "C"])
    }

    /// Add Chart passes its rows most recently trained first; a section must not re-sort them.
    @Test func itemsKeepTheirIncomingOrderWithinASection() {
        let items = [Item(name: "Pulldown", group: "Back"), Item(name: "Bench", group: "Chest"),
                     Item(name: "Row", group: "Back"), Item(name: "Deadlift", group: "Back")]
        let back = BodyArea.sections(of: items) { $0.group }.first { $0.title == "Back" }
        #expect(back?.items.map(\.name) == ["Pulldown", "Row", "Deadlift"])
    }

    @Test func noItemsMeansNoSections() {
        #expect(BodyArea.sections(of: [Item]()) { $0.group }.isEmpty)
    }
}
