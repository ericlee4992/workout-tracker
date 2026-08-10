import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

/// Ticket 17 D1 — the Start screen's gym is remembered across launches. The
/// gym anchors machines, memory, and prefill layers, so resetting to "No gym"
/// every launch quietly disarmed the equipment-aware model.
struct GymSelectionTests {

    private func makeContext() throws -> ModelContext {
        let schema = WorkoutTrackerStore.schema
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    @Test func rememberedGymSurvivesReopen() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("gym-selection-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer {
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(
                    at: URL(fileURLWithPath: url.path + suffix))
            }
        }

        var gymID = UUID()
        try {
            let context = ModelContext(try WorkoutTrackerStore.makeContainer(url: url))
            let gym = Gym(name: "Gangnam Fitness", defaultUnit: .kg)
            context.insert(gym)
            try context.save()
            gymID = gym.id
            try GymSelection.remember(gym, in: context)
        }()

        let context = ModelContext(try WorkoutTrackerStore.makeContainer(url: url))
        let gyms = try context.fetch(FetchDescriptor<Gym>())
        let preferences = try #require(
            AppPreferences.canonical(of: context.fetch(FetchDescriptor<AppPreferences>())))
        #expect(preferences.selectedGymID == gymID)
        #expect(GymSelection.resolve(id: preferences.selectedGymID, among: gyms)?.id == gymID)
    }

    /// "No gym" is a real remembered choice, not a missing one.
    @Test func noGymIsRemembered() throws {
        let context = try makeContext()
        let gym = Gym(name: "Gangnam Fitness")
        context.insert(gym)
        try context.save()

        try GymSelection.remember(gym, in: context)
        try GymSelection.remember(nil, in: context)
        let preferences = try AppPreferences.canonical(in: context)
        #expect(preferences.selectedGymID == nil)
        #expect(GymSelection.resolve(id: nil, among: [gym]) == nil)
    }

    /// Archival is how a gym leaves the pickers — a remembered id must not be
    /// a back door around it, and a deleted gym degrades to "No gym".
    @Test func archivedOrMissingGymResolvesToNoGym() throws {
        let archived = Gym(name: "Closed Gym", archived: true)
        let active = Gym(name: "Open Gym")
        #expect(GymSelection.resolve(id: archived.id, among: [archived, active]) == nil)
        #expect(GymSelection.resolve(id: UUID(), among: [active]) == nil)
        #expect(GymSelection.resolve(id: active.id, among: [archived, active])?.id == active.id)
    }
}
