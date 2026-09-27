import Foundation
import Testing
@testable import WorkoutTracker

// Floodlight ticket 02 (Codex review 02/02b): the template editor's reorder rule, shared by drag
// and the VoiceOver Move up / Move down actions. Supersets (D48) must never be lost or merged
// silently by a reorder.
struct TemplateEditorMoveTests {
    typealias Item = TemplateEditorSheet.EditorItem

    private func item(_ group: UUID?) -> Item {
        Item(exerciseID: UUID(), repsBySet: [10], supersetGroupID: group)
    }

    private func groups(_ items: [Item]) -> [UUID?] { items.map(\.supersetGroupID) }

    @Test func reorderingAPairKeepsIt() {
        let g = UUID()
        let items = [item(g), item(g)]
        let moved = TemplateEditorSheet.moving(items, from: 1, to: 0)
        #expect(moved.map(\.id) == [items[1].id, items[0].id])
        #expect(moved[0].supersetGroupID != nil && moved[0].supersetGroupID == moved[1].supersetGroupID)
    }

    @Test func draggedAwayItTravelsAloneAndTheSingletonDissolves() {
        let g = UUID()
        let items = [item(g), item(g), item(nil)]
        let moved = TemplateEditorSheet.moving(items, from: 1, to: 2)
        #expect(moved.map(\.id) == [items[0].id, items[2].id, items[1].id])
        #expect(groups(moved) == [nil, nil, nil])
    }

    @Test func droppedBetweenAPairItJoinsIt() {
        let g = UUID()
        let items = [item(g), item(g), item(nil)]
        let moved = TemplateEditorSheet.moving(items, from: 2, to: 1)
        #expect(moved.map(\.id) == [items[0].id, items[2].id, items[1].id])
        #expect(moved.allSatisfy { $0.supersetGroupID != nil && $0.supersetGroupID == moved[0].supersetGroupID })
    }

    /// Two separated runs can share one id in a stored template (the old editor kept ids when a
    /// run was interrupted). They are two supersets, and a reorder must treat them as two.
    @Test func separatedRunsWithOneIDStayDistinct() {
        let g = UUID()
        let items = [item(g), item(g), item(nil), item(g), item(g)]
        // B dropped between C and D joins C/D (a drop inside a pair); A is left alone.
        let joined = TemplateEditorSheet.moving(items, from: 1, to: 3)
        #expect(joined.map(\.id) == [items[0].id, items[2].id, items[3].id, items[1].id, items[4].id])
        #expect(joined[0].supersetGroupID == nil && joined[1].supersetGroupID == nil)
        #expect(joined[2].supersetGroupID != nil)
        #expect(joined[2].supersetGroupID == joined[3].supersetGroupID && joined[3].supersetGroupID == joined[4].supersetGroupID)

        // X moved to the front: A/B and C/D end up adjacent but stay two supersets.
        let adjacent = TemplateEditorSheet.moving(items, from: 2, to: 0)
        #expect(adjacent[0].supersetGroupID == nil)
        #expect(adjacent[1].supersetGroupID != nil && adjacent[1].supersetGroupID == adjacent[2].supersetGroupID)
        #expect(adjacent[3].supersetGroupID != nil && adjacent[3].supersetGroupID == adjacent[4].supersetGroupID)
        #expect(adjacent[2].supersetGroupID != adjacent[3].supersetGroupID)
    }
}
