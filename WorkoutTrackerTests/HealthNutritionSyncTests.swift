import Foundation
import SwiftData
import Testing

@testable import WorkoutTracker

/// Nutrition N9b (D74): Apple Health, with Health faked. The app's writes follow logs, edits and deletes by their sync
/// ids; its own samples never come back as "Apple Health" weights; units stay as entered; each part works when Health
/// refused another; a repeated pass writes nothing.
@MainActor
struct HealthNutritionSyncTests {
    private let now = Date(timeIntervalSince1970: 1_794_300_000)

    private func context() throws -> ModelContext {
        let configuration = ModelConfiguration(schema: WorkoutTrackerStore.schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: WorkoutTrackerStore.schema, configurations: [configuration]))
    }

    private func defaults() -> UserDefaults {
        let name = "HealthNutritionSyncTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func sync(_ store: FakeHealthStore, _ context: ModelContext, on parts: [HealthPart] = []) async -> HealthSync {
        let sync = HealthSync(store: store, defaults: defaults(), now: { [now] in now })
        sync.attach(context, observesSaves: false)
        for part in parts { await sync.set(part, on: true) }
        return sync
    }

    private func own(_ store: FakeHealthStore, _ type: HealthType) -> [HealthSample] {
        store.samples.filter { $0.type == type && $0.isOwn }
    }

    // MARK: Writing body weight

    @Test func aLoggedWeightIsSavedInKilogramsAndFollowsItsEditAndDelete() async throws {
        let context = try context()
        let store = FakeHealthStore()
        let sync = await sync(store, context, on: [.writeWeight])
        #expect(store.asked.count == 1 && store.asked[0].share == [.weight] && store.asked[0].read.isEmpty)

        let entry = try BodyWeightLog.log(value: 176.4, unit: .lb, at: now, in: context)
        await sync.sync()
        var samples = own(store, .weight)
        #expect(samples.count == 1)
        #expect(abs(samples[0].value - entry.normalizedKg) < 0.0001, "Health gets kg; the entry keeps lb")
        #expect(entry.value == 176.4 && entry.unit == .lb)
        #expect(samples[0].syncID == HealthSyncID.weight(entry.id))
        #expect(entry.healthSampleID == samples[0].uuid)

        try BodyWeightLog.update(entry, value: 80, unit: .kg, at: now.addingTimeInterval(-60), in: context)
        await sync.sync()
        samples = own(store, .weight)
        #expect(samples.count == 1, "replaced by its sync id, not duplicated")
        #expect(samples[0].value == 80 && samples[0].date == now.addingTimeInterval(-60))
        #expect(entry.healthSampleID == samples[0].uuid)

        try BodyWeightLog.delete(entry, in: context)
        await sync.sync()
        #expect(own(store, .weight).isEmpty)
    }

    @Test func aRepeatedPassWritesNothing() async throws {
        let context = try context()
        let store = FakeHealthStore()
        let sync = await sync(store, context, on: [.writeWeight, .writeFood])
        try BodyWeightLog.log(value: 80, unit: .kg, at: now, in: context)
        try FoodLog.logManual(name: "Oats", serving: nil, nutrition: FoodNutrition(calories: 300, proteinGrams: 10),
                              meal: .breakfast, at: now, in: context)
        await sync.sync()
        let saves = store.saveCalls
        let samples = store.samples
        await sync.sync()
        await sync.sync()
        #expect(store.saveCalls == saves)
        #expect(store.samples == samples)
    }

    // MARK: Writing food

    @Test func eachFoodEntryWritesItsTotalsAndFollowsEditsAndDeletes() async throws {
        let context = try context()
        let store = FakeHealthStore()
        let sync = await sync(store, context, on: [.writeFood])
        #expect(store.asked.last?.share == [.energy, .protein, .carbs, .fat])
        let receipt = try FoodLog.logManual(
            name: "Chicken wrap", serving: nil,
            nutrition: FoodNutrition(calories: 300, proteinGrams: 20, carbsGrams: 30, fatGrams: 0), meal: .lunch,
            at: now, in: context)
        let entry = try #require(try context.fetch(FetchDescriptor<FoodEntry>()).first)
        try FoodLog.update(entry, servings: 2, meal: .lunch, calories: 300, proteinGrams: 20, carbsGrams: 30,
                           fatGrams: 0, at: now, in: context)
        await sync.sync()
        #expect(own(store, .energy).map(\.value) == [600], "per serving × servings")
        #expect(own(store, .protein).map(\.value) == [40])
        #expect(own(store, .carbs).map(\.value) == [60])
        #expect(own(store, .fat).isEmpty, "a zero macro is not written")
        #expect(own(store, .energy).first?.syncID == HealthSyncID.food(entry.id, .energy))
        #expect(entry.healthSampleID == own(store, .energy).first?.uuid)

        try FoodLog.update(entry, servings: 1, meal: .lunch, calories: 250, proteinGrams: 0, carbsGrams: 30,
                           fatGrams: 5, at: now, in: context)
        await sync.sync()
        #expect(own(store, .energy).map(\.value) == [250])
        #expect(own(store, .protein).isEmpty, "a macro edited to zero leaves Health")
        #expect(own(store, .fat).map(\.value) == [5])

        try FoodLog.undo(receipt, in: context)
        await sync.sync()
        #expect(store.samples.filter(\.isOwn).isEmpty, "Undo deletes it from Health too")
    }

    @Test func aDeletedEntryRestoredByUndoIsWrittenAgain() async throws {
        let context = try context()
        let store = FakeHealthStore()
        let sync = await sync(store, context, on: [.writeFood])
        try FoodLog.logManual(name: "Apple", serving: nil, nutrition: FoodNutrition(calories: 95), meal: .snacks,
                              at: now, in: context)
        let entry = try #require(try context.fetch(FetchDescriptor<FoodEntry>()).first)
        await sync.sync()
        let copy = try FoodLog.delete(entry, in: context)
        await sync.sync()
        #expect(own(store, .energy).isEmpty)
        try FoodLog.restore(copy, in: context)
        await sync.sync()
        #expect(own(store, .energy).map(\.value) == [95])
    }

    @Test func turningWritingOnAgainBringsHealthBackInLine() async throws {
        let context = try context()
        let store = FakeHealthStore()
        let sync = await sync(store, context, on: [.writeFood])
        try FoodLog.logManual(name: "Rice", serving: nil, nutrition: FoodNutrition(calories: 200), meal: .dinner,
                              at: now, in: context)
        let entry = try #require(try context.fetch(FetchDescriptor<FoodEntry>()).first)
        await sync.sync()
        await sync.set(.writeFood, on: false)
        _ = try FoodLog.delete(entry, in: context)
        try FoodLog.logManual(name: "Beans", serving: nil, nutrition: FoodNutrition(calories: 150), meal: .dinner,
                              at: now, in: context)
        await sync.sync()
        #expect(own(store, .energy).map(\.value) == [200], "off: Health is left as it was")
        await sync.set(.writeFood, on: true)
        #expect(own(store, .energy).map(\.value) == [150])
    }

    @Test func anotherAppsSamplesAreNeverTouched() async throws {
        let context = try context()
        let store = FakeHealthStore()
        let theirs = HealthSample(uuid: UUID(), type: .energy, date: now, value: 500,
                                  syncID: HealthSyncID.food(UUID(), .energy), isOwn: false)
        store.samples = [theirs]
        _ = await sync(store, context, on: [.writeFood])
        #expect(store.samples == [theirs])
    }

    // MARK: Reading body weight

    @Test func healthsWeightsAreShownAndTheAppsOwnAreNot() async throws {
        let context = try context()
        let store = FakeHealthStore()
        let scale = HealthSample(uuid: UUID(), type: .weight, date: now.addingTimeInterval(-86_400), value: 81.2,
                                 syncID: nil, isOwn: false)
        let old = HealthSample(uuid: UUID(), type: .weight, date: now.addingTimeInterval(-400 * 86_400), value: 90,
                               syncID: nil, isOwn: false)
        store.samples = [scale, old]
        let sync = await sync(store, context, on: [.writeWeight, .readWeight])
        let mine = try BodyWeightLog.log(value: 80, unit: .kg, at: now, in: context)
        await sync.sync()
        #expect(own(store, .weight).count == 1)
        var rows = try context.fetch(FetchDescriptor<BodyWeightEntry>())
        let fromHealth = rows.filter { $0.source == .health }
        #expect(fromHealth.map(\.healthSampleID) == [scale.uuid], "own write skipped; older than a year skipped")
        #expect(fromHealth.first?.normalizedKg == 81.2)
        #expect(rows.count == 2 && rows.contains { $0.id == mine.id })

        store.samples.removeAll { $0.uuid == scale.uuid }
        await sync.sync()
        rows = try context.fetch(FetchDescriptor<BodyWeightEntry>())
        #expect(rows.filter { $0.source == .health }.isEmpty, "deleted in Health → gone here")

        store.samples.append(scale)
        await sync.sync()
        #expect(try context.fetch(FetchDescriptor<BodyWeightEntry>()).filter { $0.source == .health }.count == 1)
        await sync.set(.readWeight, on: false)
        rows = try context.fetch(FetchDescriptor<BodyWeightEntry>())
        #expect(rows.map(\.id) == [mine.id], "off: Health's rows leave; the app's stay")
    }

    @Test func ownSamplesAreRecognisedByTheirHealthIDsToo() {
        let id = UUID()
        let entry = HealthSample(uuid: id, type: .weight, date: .now, value: 80, syncID: nil, isOwn: false)
        let other = HealthSample(uuid: UUID(), type: .weight, date: .now, value: 81, syncID: nil, isOwn: false)
        let tagged = HealthSample(uuid: UUID(), type: .weight, date: .now, value: 82,
                                  syncID: HealthSyncID.weight(UUID()), isOwn: false)
        #expect(HealthSyncPlan.readings([entry, other, tagged], ownIDs: [id]) == [other])
    }

    @Test func healthsWeightsUseTheAppsUnitSystem() async throws {
        let context = try context()
        context.insert(AppPreferences(unitPreference: .lb))
        try context.save()
        let store = FakeHealthStore()
        store.samples = [HealthSample(uuid: UUID(), type: .weight, date: now, value: 80, syncID: nil, isOwn: false)]
        _ = await sync(store, context, on: [.readWeight])
        let row = try #require(try context.fetch(FetchDescriptor<BodyWeightEntry>()).first)
        #expect(row.unit == .lb && abs(row.value - 176.37) < 0.01 && abs(row.normalizedKg - 80) < 0.0001)
    }

    // MARK: Each part on its own

    @Test func eachPartWorksWhenHealthRefusedAnother() async throws {
        let context = try context()
        let store = FakeHealthStore()
        store.refused = [.weight, .fat]
        let sync = await sync(store, context, on: [.writeWeight, .writeFood])
        #expect(sync.isRefused(.writeWeight) && sync.isRefused(.writeFood))
        try BodyWeightLog.log(value: 80, unit: .kg, at: now, in: context)
        try FoodLog.logManual(name: "Toast", serving: nil,
                              nutrition: FoodNutrition(calories: 120, proteinGrams: 4, fatGrams: 2), meal: .breakfast,
                              at: now, in: context)
        await sync.sync()
        #expect(own(store, .weight).isEmpty)
        #expect(own(store, .energy).map(\.value) == [120] && own(store, .protein).map(\.value) == [4])
        #expect(own(store, .fat).isEmpty)
        #expect(sync.failure == nil)
    }

    @Test func aFailedSaveIsSaidAndTheNextPassCatchesUp() async throws {
        let context = try context()
        let store = FakeHealthStore()
        let sync = await sync(store, context, on: [.writeFood])
        try FoodLog.logManual(name: "Soup", serving: nil, nutrition: FoodNutrition(calories: 180), meal: .lunch,
                              at: now, in: context)
        store.failsNextSave = true
        await sync.sync()
        #expect(sync.failure == HealthSyncCopy.syncFailed)
        await sync.sync()
        #expect(sync.failure == nil && own(store, .energy).map(\.value) == [180])
    }

    @Test func noPartIsOnUntilTurnedOnAndNothingIsAskedBefore() async throws {
        let context = try context()
        let store = FakeHealthStore()
        let sync = await sync(store, context)
        try BodyWeightLog.log(value: 80, unit: .kg, at: now, in: context)
        await sync.sync()
        #expect(store.asked.isEmpty && store.samples.isEmpty && !sync.anyOn)
    }

    // MARK: Burned

    @Test func burnedIsHealthsActiveEnergyAndNeverLessThanTheWorkouts() async throws {
        let context = try context()
        let store = FakeHealthStore()
        store.activeEnergyByDay[Calendar.current.startOfDay(for: now)] = 412
        let sync = await sync(store, context)
        #expect(sync.burned(on: now) == nil)
        await sync.set(.readBurned, on: true)
        #expect(store.asked.last?.read == [.activeEnergy] && store.asked.last?.share.isEmpty == true)
        #expect(sync.burned(on: now) == 412)
        #expect(FoodDayMath.burned(workouts: 320, health: sync.burned(on: now)) == 412)
        #expect(FoodDayMath.burned(workouts: 320, health: 0) == 320, "a refused read reads 0")
        #expect(FoodDayMath.burned(workouts: 320, health: nil) == 320)
        await sync.set(.readBurned, on: false)
        #expect(sync.burned(on: now) == nil)
    }

    @Test func syncIDsNameTheirType() {
        let id = UUID()
        #expect(HealthSyncID.type(of: HealthSyncID.weight(id)) == .weight)
        for type in [HealthType.energy, .protein, .carbs, .fat] {
            #expect(HealthSyncID.type(of: HealthSyncID.food(id, type)) == type)
        }
        #expect(HealthSyncID.type(of: "other.app.weight") == nil)
    }

    @Test func switchesPersist() async throws {
        let context = try context()
        let store = FakeHealthStore()
        let defaults = defaults()
        let first = HealthSync(store: store, defaults: defaults)
        first.attach(context, observesSaves: false)
        await first.set(.writeFood, on: true)
        #expect(HealthSync(store: store, defaults: defaults).enabled == [.writeFood])
    }
}
