import CoreData
import CryptoKit
import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

// Public beta ticket 11, deferred (the user, 2026-10-14): the automatic safety copy of each tester's data is built
// together with the first update that changes how the phone stores data — the new build makes the copy before it first
// opens the old store, so nothing has to ship earlier. These guards make such a change hard to ship unnoticed. Three
// layers, because the store holds more than its table structure (codex-review-11 #1):
//
// 1. Structure — Core Data's per-entity version hashes (what decides whether SwiftData migrates the store on open), plus
//    any indexes, which those hashes leave out.
// 2. Stored enum values — the raw strings in rows; renaming or removing one makes old rows unreadable.
// 3. JSON payloads inside `Data` attributes (cardio intervals, route, distance spans; planned cardio) — the column is
//    unchanged when its JSON changes, so fixed samples in today's format must still decode.
//
// Not covered by any test: code that rewrites existing rows on first launch (repairs, backfills, seeding). DEVELOPMENT
// → *When a backup is required* still applies to those. A passing guard never waives that review.

private let ticket = "work-record/public-beta/issues/11-safety-copy.md"

struct StoreFormatGuardTests {

    // MARK: 1. Structure

    /// The structural format of every TestFlight build so far (1–4): no production `@Model` file (Models.swift,
    /// Cardio.swift, WorkoutSensorSample.swift) changed since build 1 (`936b18f`) — equal source, not a measurement of
    /// each shipped binary.
    static let shippedFingerprint = "9569f6fdb6ee5ee8c69173946f9cd5d62c0b09787a961bc10340b83b23fefeba"

    static func fingerprint(of types: [any PersistentModel.Type] = WorkoutTrackerStore.modelTypes) throws -> String {
        let model = try #require(NSManagedObjectModel.makeManagedObjectModel(for: types))
        let hex = { (data: Data) in data.map { String(format: "%02x", $0) }.joined() }
        let lines = model.entities.sorted { ($0.name ?? "") < ($1.name ?? "") }.map { entity -> String in
            var line = "\(entity.name ?? ""):\(hex(entity.versionHash))"
            // Indexes are excluded from Core Data's version hash; added only when present, so the shipped value (no
            // indexes) is unchanged.
            let indexes = entity.indexes.map { index in
                "\(index.name)(\(index.elements.map { "\($0.propertyName ?? "")\($0.isAscending ? "+" : "-")" }.joined(separator: ",")))"
            }.sorted()
            if !indexes.isEmpty { line += "|indexes:" + indexes.joined(separator: ";") }
            return line
        }
        return hex(Data(SHA256.hash(data: Data(lines.joined(separator: "\n").utf8))))
    }

    @Test func theStoredStructureIsTheShippedOne() throws {
        let current = try Self.fingerprint()
        #expect(current == Self.shippedFingerprint, """
            The store's structure differs from what testers' phones hold, so their only copy of their training data \
            would go through a migration on the next update. Stop before shipping: build ticket 11 (\(ticket): an \
            automatic copy of the store before the first open with the new format), follow DEVELOPMENT's migration \
            rules (a legacy-store fixture from the installed commit), get the user's approval, and only then set \
            `shippedFingerprint` to \(current).
            """)
    }

    /// The fingerprint sees a structural change: one more model, through the same function the guard uses.
    @Test func aChangedStructureChangesTheFingerprint() throws {
        #expect(try Self.fingerprint(of: WorkoutTrackerStore.modelTypes + [FormatProbe.self]) != Self.fingerprint())
        #expect(try Self.fingerprint() == Self.fingerprint(), "stable between calls")
    }

    // MARK: 2. Stored enum values

    /// Every raw value stored in a row today. Removing or renaming one leaves old rows unreadable; adding one is readable
    /// by this build but not by an older one a tester might reinstall — both need ticket 11's review before the pin moves.
    static let shippedRawValues: [String: [String]] = [
        "WeightUnit": ["kg", "lb"],
        "SetType": ["warmup", "working", "failure", "drop"],
        "LoadType": ["weighted", "bodyweight", "bodyweightPlus", "assisted"],
        "EquipmentTag": ["machine", "barbell", "dumbbell", "cable", "smith", "bodyweight"],
        "EquipmentCategory": ["selectorized", "plateLoaded", "cable", "rackOrSmith", "bodyweight"],
        "CatalogGrouping": ["manufacturer", "bodyArea", "equipmentType", "alphabetical"],
        "MachineGrouping": ["exercise", "bodyArea", "alphabetical"],
        "RestMode": ["standard", "heartRate"],
        "CardioActivity": ["indoorWalk", "indoorRun", "indoorCycle", "elliptical", "rowing", "stairStepper",
                           "outdoorWalk", "outdoorRun", "outdoorCycle"],
        "CardioDistanceUnit": ["km", "mi"],
        "CardioDistanceSource": ["healthKit", "phoneMotion", "gps", "mixed"],
        "HeartRateSource": ["airPods", "watch", "otherMonitor", "fixture"],
    ]

    private static func rawValues<T: CaseIterable & RawRepresentable>(_: T.Type) -> [String] where T.RawValue == String {
        T.allCases.map(\.rawValue)
    }

    @Test func theStoredEnumValuesAreTheShippedOnes() {
        let current: [String: [String]] = [
            "WeightUnit": Self.rawValues(WeightUnit.self), "SetType": Self.rawValues(SetType.self),
            "LoadType": Self.rawValues(LoadType.self), "EquipmentTag": Self.rawValues(EquipmentTag.self),
            "EquipmentCategory": Self.rawValues(EquipmentCategory.self),
            "CatalogGrouping": Self.rawValues(CatalogGrouping.self), "MachineGrouping": Self.rawValues(MachineGrouping.self),
            "RestMode": Self.rawValues(RestMode.self), "CardioActivity": Self.rawValues(CardioActivity.self),
            "CardioDistanceUnit": Self.rawValues(CardioDistanceUnit.self),
            // Not CaseIterable: each shipped value must still be accepted.
            "CardioDistanceSource": Self.shippedRawValues["CardioDistanceSource"]!
                .filter { CardioDistanceSource(rawValue: $0) != nil },
            "HeartRateSource": Self.rawValues(HeartRateSource.self),
        ]
        for (name, shipped) in Self.shippedRawValues {
            #expect(Set(current[name] ?? []) == Set(shipped), """
                \(name)'s stored values changed (\(shipped) → \(current[name] ?? [])). Rows on testers' phones hold the \
                old strings. Review with ticket 11 (\(ticket)) before shipping, then update `shippedRawValues`.
                """)
        }
        #expect(CardioDistanceSource.mixed.rawValue == "mixed", "a value outside the list would go unnoticed")
    }

    // MARK: 3. JSON payloads in Data attributes

    /// Fixed samples in the format the app writes today (`JSONEncoder` defaults: dates as seconds since 2001).
    /// They must keep decoding to the same values: these are what `intervalsData`, `routeData`, `distanceSpansData` and
    /// `cardioPlanData` hold on testers' phones.
    @Test func storedCardioPayloadsStillDecode() throws {
        let start = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let portion = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let point = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let plan = UUID(uuidString: "99999999-8888-7777-6666-555555555555")!
        let segment = UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!

        let intervals = #"[{"start":700000000,"end":700000060}]"#
        #expect(try decode([CardioInterval].self, intervals)
                == [CardioInterval(start: start, end: start.addingTimeInterval(60))])

        let route = #"[{"id":"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE","latitude":40.75,"longitude":-73.99,"date":700000005,"accuracy":5,"portion":"11111111-2222-3333-4444-555555555555"}]"#
        #expect(try decode([CardioRoutePoint].self, route) == [CardioRoutePoint(
            id: point, latitude: 40.75, longitude: -73.99, date: start.addingTimeInterval(5), accuracy: 5, portion: portion)])

        let spans = #"[{"start":700000000,"readings":{"gps":1200.5},"updatedAt":{"gps":700000100},"selectedSourceRawValue":"gps"}]"#
        #expect(try decode([CardioDistanceSpan].self, spans) == [CardioDistanceSpan(
            start: start, readings: ["gps": 1200.5], updatedAt: ["gps": start.addingTimeInterval(100)],
            selectedSourceRawValue: "gps")])

        let planned = #"[{"activity":"outdoorRun","distance":5,"id":"99999999-8888-7777-6666-555555555555","minutes":30,"segmentID":"12345678-1234-1234-1234-123456789ABC","unit":"km"}]"#
        #expect(CardioPlanStorage.read(Data(planned.utf8)) == [PlannedCardio(
            id: plan, activity: .outdoorRun, minutes: 30, distance: 5, unit: .km, segmentID: segment)])
        #expect(!CardioPlanStorage.hasUnknown(Data(planned.utf8)))

        // Today's encoder writes the same shape (keys and value forms), so the samples stay representative.
        for (value, sample) in [
            (try encodeObject([CardioInterval(start: start, end: start.addingTimeInterval(60))]), intervals),
            (try encodeObject([CardioRoutePoint(id: point, latitude: 40.75, longitude: -73.99,
                                                date: start.addingTimeInterval(5), accuracy: 5, portion: portion)]), route),
            (try encodeObject([CardioDistanceSpan(start: start, readings: ["gps": 1200.5],
                                                  updatedAt: ["gps": start.addingTimeInterval(100)],
                                                  selectedSourceRawValue: "gps")]), spans),
            (try encodeObject([PlannedCardio(id: plan, activity: .outdoorRun, minutes: 30, distance: 5, unit: .km,
                                             segmentID: segment)]), planned),
        ] {
            #expect(value == (try JSONSerialization.jsonObject(with: Data(sample.utf8)) as? NSArray), """
                A stored JSON payload's format changed. Old rows on testers' phones keep the old form: keep decoding \
                it (and review with ticket 11, \(ticket)) before updating this sample.
                """)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    private func encodeObject<T: Encodable>(_ value: T) throws -> NSArray? {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? NSArray
    }
}

/// Never stored: only here to show that one more model changes the fingerprint.
@Model private final class FormatProbe {
    var id = UUID()
    init() {}
}
