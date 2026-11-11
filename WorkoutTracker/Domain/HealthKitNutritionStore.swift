import Foundation
import HealthKit

// Nutrition N9b: the real Health store behind `HealthStoring`. Food is written as plain quantity samples (calories,
// protein, carbs, fat), each with its sync identifier, sync version and the food's name. A food correlation grouping
// them would also work (Health replaces samples inside one by sync id); plain samples were chosen as the simpler shape:
// each type stands alone, so a type Health refused simply is not written, and a macro edited to zero is one delete
// (codex-review-c1-n9b corrected the earlier reason given here).

@MainActor
final class HealthKitNutritionStore: HealthStoring {
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    static func quantityType(_ type: HealthType) -> HKQuantityType {
        switch type {
        case .weight: HKQuantityType(.bodyMass)
        case .energy: HKQuantityType(.dietaryEnergyConsumed)
        case .protein: HKQuantityType(.dietaryProtein)
        case .carbs: HKQuantityType(.dietaryCarbohydrates)
        case .fat: HKQuantityType(.dietaryFatTotal)
        case .activeEnergy: HKQuantityType(.activeEnergyBurned)
        }
    }

    static func unit(_ type: HealthType) -> HKUnit {
        switch type {
        case .weight: .gramUnit(with: .kilo)
        case .energy, .activeEnergy: .kilocalorie()
        case .protein, .carbs, .fat: .gram()
        }
    }

    func requestAuthorization(share: Set<HealthType>, read: Set<HealthType>) async throws {
        try await store.requestAuthorization(toShare: Set(share.map(Self.quantityType)),
                                             read: Set(read.map { Self.quantityType($0) as HKObjectType }))
    }

    func canWrite(_ type: HealthType) -> Bool {
        store.authorizationStatus(for: Self.quantityType(type)) == .sharingAuthorized
    }

    func samples(_ type: HealthType, from start: Date?, ownOnly: Bool) async throws -> [HealthSample] {
        var predicates: [NSPredicate] = []
        if let start { predicates.append(HKQuery.predicateForSamples(withStart: start, end: nil)) }
        if ownOnly { predicates.append(HKQuery.predicateForObjects(from: HKSource.default())) }
        let predicate = predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: Self.quantityType(type), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)])
        let own = HKSource.default().bundleIdentifier
        let unit = Self.unit(type)
        return try await descriptor.result(for: store).map { sample in
            HealthSample(uuid: sample.uuid, type: type, date: sample.startDate, value: sample.quantity.doubleValue(for: unit),
                         syncID: sample.metadata?[HKMetadataKeySyncIdentifier] as? String,
                         isOwn: sample.sourceRevision.source.bundleIdentifier == own,
                         version: (sample.metadata?[HKMetadataKeySyncVersion] as? NSNumber)?.intValue,
                         foodName: sample.metadata?[HKMetadataKeyFoodType] as? String)
        }
    }

    func save(_ writes: [HealthWrite]) async throws {
        guard !writes.isEmpty else { return }
        let samples = writes.map { write in
            var metadata: [String: Any] = [HKMetadataKeySyncIdentifier: write.syncID,
                                           HKMetadataKeySyncVersion: NSNumber(value: write.version)]
            if let name = write.foodName { metadata[HKMetadataKeyFoodType] = name }
            if write.type == .weight { metadata[HKMetadataKeyWasUserEntered] = true }
            return HKQuantitySample(type: Self.quantityType(write.type),
                                    quantity: HKQuantity(unit: Self.unit(write.type), doubleValue: write.value),
                                    start: write.date, end: write.date, metadata: metadata)
        }
        try await store.save(samples)
    }

    func delete(_ type: HealthType, syncIDs: [String]) async throws {
        guard !syncIDs.isEmpty else { return }
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier, allowedValues: syncIDs),
            HKQuery.predicateForObjects(from: HKSource.default()),
        ])
        let store = store
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.deleteObjects(of: Self.quantityType(type), predicate: predicate) { _, _, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    func activeEnergy(from start: Date, to end: Date) async throws -> Double {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: Self.quantityType(.activeEnergy), predicate: predicate),
            options: .cumulativeSum)
        do {
            return try await descriptor.result(for: store)?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        } catch let error as HKError where error.code == .errorNoData {
            return 0
        }
    }
}

/// A Health stand-in: unit tests drive the sync with it, and UI tests use it instead of the real store (they never
/// reach Health's permission sheet). Behaves like Health where the sync relies on it: a save under an existing sync id
/// of this app replaces that sample; deletes touch only this app's samples.
@MainActor
final class FakeHealthStore: HealthStoring {
    var isAvailable = true
    var samples: [HealthSample] = []
    /// Types Health refused to let the app save.
    var refused: Set<HealthType> = []
    var activeEnergyByDay: [Date: Double] = [:]
    private(set) var asked: [(share: Set<HealthType>, read: Set<HealthType>)] = []
    private(set) var saveCalls = 0
    private(set) var energyQueries: [(start: Date, end: Date)] = []
    var failsNextSave = false
    var calendar = Calendar.current
    /// Runs inside every sample query, before it answers — a test's stand-in for Health taking its time (a switch
    /// turned, an entry saved meanwhile).
    var whileQuerying: (@MainActor () async -> Void)?

    func requestAuthorization(share: Set<HealthType>, read: Set<HealthType>) async throws {
        asked.append((share, read))
    }

    func canWrite(_ type: HealthType) -> Bool { !refused.contains(type) }

    func samples(_ type: HealthType, from start: Date?, ownOnly: Bool) async throws -> [HealthSample] {
        if let whileQuerying { await whileQuerying() }
        return samples.filter { sample in
            sample.type == type && (start.map { sample.date >= $0 } ?? true) && (!ownOnly || sample.isOwn)
        }
            .sorted { $0.date < $1.date }
    }

    /// Like Health: a sample with this app's sync id is replaced only by a higher version; a lower or equal one is not
    /// stored.
    func save(_ writes: [HealthWrite]) async throws {
        saveCalls += 1
        if failsNextSave {
            failsNextSave = false
            throw CocoaError(.fileWriteUnknown)
        }
        for write in writes {
            precondition(!refused.contains(write.type), "saved a refused type")
            let held = samples.filter { $0.isOwn && $0.syncID == write.syncID }.compactMap(\.version).max()
            if let held, write.version <= held { continue }
            samples.removeAll { $0.isOwn && $0.syncID == write.syncID }
            samples.append(HealthSample(uuid: UUID(), type: write.type, date: write.date, value: write.value,
                                        syncID: write.syncID, isOwn: true, version: write.version,
                                        foodName: write.foodName))
        }
    }

    func delete(_ type: HealthType, syncIDs: [String]) async throws {
        samples.removeAll { $0.type == type && $0.isOwn && syncIDs.contains($0.syncID ?? "") }
    }

    func activeEnergy(from start: Date, to end: Date) async throws -> Double {
        energyQueries.append((start, end))
        return activeEnergyByDay[calendar.startOfDay(for: start)] ?? 0
    }
}

// MARK: - This launch's sync

/// UI tests' Health (`-uiTestHealthSample`): two weights from a scale this week and 412 cal of active energy today.
/// With `-uiTestHealthOn` too, every part starts on; with `-uiTestHealthRefused`, Health refuses saving food.
@MainActor
enum HealthFixture {
    static let argument = "-uiTestHealthSample"
    static let onArgument = "-uiTestHealthOn"
    static let refusedArgument = "-uiTestHealthRefused"
    static let burnedToday: Double = 412

    static var isEnabled: Bool { WorkoutTrackerStore.fixtureIsEnabled(argument) }

    static func store(now: Date = .now, calendar: Calendar = .current) -> FakeHealthStore {
        let store = FakeHealthStore()
        store.calendar = calendar
        let day: TimeInterval = 86_400
        store.samples = [
            HealthSample(uuid: UUID(), type: .weight, date: now.addingTimeInterval(-2 * day), value: 81.2, syncID: nil,
                         isOwn: false),
            HealthSample(uuid: UUID(), type: .weight, date: now.addingTimeInterval(-5 * day), value: 81.6, syncID: nil,
                         isOwn: false),
        ]
        store.activeEnergyByDay[calendar.startOfDay(for: now)] = burnedToday
        if ProcessInfo.processInfo.arguments.contains(refusedArgument) { store.refused = [.energy, .protein, .carbs, .fat] }
        return store
    }
}

extension HealthSync {
    /// The real Health for the user's app; a fake one with throwaway switches under UI tests, so a test never meets
    /// Health's permission sheet or writes to the Simulator's Health.
    static func forThisLaunch() -> HealthSync {
        guard WorkoutTrackerStore.isUITestReset else { return HealthSync(store: HealthKitNutritionStore()) }
        let suite = "uitest.health"
        UserDefaults().removePersistentDomain(forName: suite)
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        let store = HealthFixture.isEnabled ? HealthFixture.store() : FakeHealthStore()
        if HealthFixture.isEnabled, ProcessInfo.processInfo.arguments.contains(HealthFixture.onArgument) {
            for part in HealthPart.allCases { defaults.set(true, forKey: part.defaultsKey) }
        }
        return HealthSync(store: store, defaults: defaults)
    }
}
