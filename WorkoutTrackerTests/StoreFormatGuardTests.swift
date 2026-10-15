import CoreData
import CryptoKit
import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

// Public beta ticket 11, deferred (the user, 2026-10-14): the automatic safety copy of each tester's data is built
// together with the first update that changes how the phone stores data — the new build makes the copy before it first
// opens the old store, so nothing has to ship earlier. This guard makes sure that day cannot arrive unnoticed.
//
// The fingerprint is Core Data's own per-entity version hashes for the app's schema: exactly what decides whether
// SwiftData migrates the store on the next launch. Renaming or adding a stored property, changing its type or
// optionality, or adding a model changes it; code-only edits do not.

struct StoreFormatGuardTests {

    /// The stored data format of every TestFlight build so far (1–4; no `@Model` file changed since build 1, `936b18f`).
    static let shippedFingerprint = "9569f6fdb6ee5ee8c69173946f9cd5d62c0b09787a961bc10340b83b23fefeba"

    static func fingerprint() throws -> String {
        let model = try #require(NSManagedObjectModel.makeManagedObjectModel(for: WorkoutTrackerStore.modelTypes))
        let lines = model.entityVersionHashesByName
            .sorted { $0.key < $1.key }
            .map { name, hash in "\(name):\(hash.map { String(format: "%02x", $0) }.joined())" }
        let digest = SHA256.hash(data: Data(lines.joined(separator: "\n").utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    @Test func theStoredDataFormatIsTheShippedOne() throws {
        let current = try Self.fingerprint()
        #expect(current == Self.shippedFingerprint, """
            The stored data format changed: testers' phones will migrate their only copy of their training data on \
            the next update. Before shipping this, build ticket 11 (work-record/public-beta/issues/11-safety-copy.md: \
            an automatic copy of the store before the first open with the new format), follow DEVELOPMENT's migration \
            rules (a legacy-store fixture from the installed commit), get the user's approval, and only then update \
            `shippedFingerprint` to \(current).
            """)
    }

    /// The fingerprint sees a format change (a guard that could never fail would prove nothing).
    @Test func aChangedFormatChangesTheFingerprint() throws {
        let shipped = try #require(NSManagedObjectModel.makeManagedObjectModel(for: WorkoutTrackerStore.modelTypes))
        let withExtra = try #require(NSManagedObjectModel.makeManagedObjectModel(
            for: WorkoutTrackerStore.modelTypes + [FormatProbe.self]))
        #expect(shipped.entityVersionHashesByName != withExtra.entityVersionHashesByName)
        #expect(try Self.fingerprint() == Self.fingerprint(), "stable between runs")
    }
}

/// Never stored: only here to show that one more model changes the fingerprint.
@Model private final class FormatProbe {
    var id = UUID()
    init() {}
}
