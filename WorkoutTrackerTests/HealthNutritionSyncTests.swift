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

    private func sync(_ store: FakeHealthStore, _ context: ModelContext, on parts: [HealthPart] = [],
                      clock: (() -> Date)? = nil) async -> HealthSync {
        let sync = HealthSync(store: store, defaults: defaults(), debounce: .milliseconds(20), now: clock ?? { [now] in now })
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

    // MARK: codex-review-c1-n9b

    /// S1: a part switched off while Health is answering does no more work — no rows imported, no save started.
    @Test func aPartTurnedOffWhileHealthAnswersDoesNothingMore() async throws {
        let context = try context()
        let store = FakeHealthStore()
        store.samples = [HealthSample(uuid: UUID(), type: .weight, date: now, value: 81, syncID: nil, isOwn: false)]
        let sync = await sync(store, context)
        // Read: turned off while Health answers the first pass's query.
        store.whileQuerying = { await sync.set(.readWeight, on: false) }
        await sync.set(.readWeight, on: true)
        store.whileQuerying = nil
        await sync.sync()
        #expect(!sync.isOn(.readWeight))
        #expect(try context.fetch(FetchDescriptor<BodyWeightEntry>()).isEmpty, "a late answer imports nothing")

        // Write: turned off while Health says what it holds.
        await sync.set(.writeWeight, on: true)
        try BodyWeightLog.log(value: 80, unit: .kg, at: now, in: context)
        let saves = store.saveCalls
        store.whileQuerying = { await sync.set(.writeWeight, on: false) }
        await sync.sync()
        store.whileQuerying = nil
        await sync.sync()
        #expect(store.saveCalls == saves && own(store, .weight).isEmpty, "no save started after off")
    }

    /// S2: one editor step (0.1 kg, 0.2 lb) and a small food change reach Health.
    @Test func smallEditsReachHealth() async throws {
        let context = try context()
        let store = FakeHealthStore()
        let sync = await sync(store, context, on: [.writeWeight, .writeFood])
        let weight = try BodyWeightLog.log(value: 100, unit: .kg, at: now, in: context)
        try FoodLog.logManual(name: "Rice", serving: nil, nutrition: FoodNutrition(calories: 1_000), meal: .lunch,
                              at: now, in: context)
        await sync.sync()
        try BodyWeightLog.update(weight, value: 100.1, unit: .kg, at: now, in: context)
        let entry = try #require(try context.fetch(FetchDescriptor<FoodEntry>()).first)
        try FoodLog.update(entry, servings: 1, meal: .lunch, calories: 1_000.5, proteinGrams: 0, carbsGrams: 0,
                           fatGrams: 0, at: now, in: context)
        await sync.sync()
        #expect(own(store, .weight).map(\.value) == [100.1])
        #expect(own(store, .energy).map(\.value) == [1_000.5])
        try BodyWeightLog.update(weight, value: 220.6, unit: .lb, at: now, in: context)
        await sync.sync()
        try BodyWeightLog.update(weight, value: 220.8, unit: .lb, at: now, in: context)
        await sync.sync()
        #expect(own(store, .weight).map(\.value) == [weight.normalizedKg])
    }

    /// S3: a save during the last pass of a burst is not left behind — a pass is scheduled for it.
    @Test func aSaveDuringTheLastPassIsSyncedAfterwards() async throws {
        let context = try context()
        let store = FakeHealthStore()
        let sync = await sync(store, context, on: [.writeWeight])
        var logged = 0
        store.whileQuerying = {
            guard logged < 6 else { return }
            logged += 1
            try? BodyWeightLog.log(value: 80 + Double(logged), unit: .kg, at: now, in: context)
            sync.scheduleSync()  // what the save observer does
        }
        await sync.sync()
        store.whileQuerying = nil
        for _ in 0..<100 where own(store, .weight).count < logged { try await Task.sleep(for: .milliseconds(20)) }
        #expect(own(store, .weight).count == logged && logged > 3, "\(own(store, .weight).count) of \(logged)")
    }

    /// S3: the real observer — a save anywhere starts a pass on its own.
    @Test func aSaveStartsAPassWithoutBeingAsked() async throws {
        let context = try context()
        let store = FakeHealthStore()
        let sync = HealthSync(store: store, defaults: defaults(), debounce: .milliseconds(20), now: { [now] in now })
        sync.attach(context)
        await sync.set(.writeWeight, on: true)
        try BodyWeightLog.log(value: 80, unit: .kg, at: now, in: context)
        for _ in 0..<100 where own(store, .weight).isEmpty { try await Task.sleep(for: .milliseconds(20)) }
        #expect(own(store, .weight).map(\.value) == [80])
    }

    /// S4: after the phone's clock went back, an edit still replaces the sample (its version is above Health's).
    @Test func anEditReplacesTheSampleAfterTheClockWentBack() async throws {
        let context = try context()
        let store = FakeHealthStore()
        var clock = now
        let sync = await sync(store, context, on: [.writeWeight], clock: { clock })
        let weight = try BodyWeightLog.log(value: 80, unit: .kg, at: now.addingTimeInterval(-86_400), in: context)
        await sync.sync()
        let first = try #require(own(store, .weight).first)
        clock = now.addingTimeInterval(-3_600)
        try BodyWeightLog.update(weight, value: 79, unit: .kg, at: weight.measuredAt, in: context)
        await sync.sync()
        let second = try #require(own(store, .weight).first)
        #expect(own(store, .weight).count == 1 && second.value == 79)
        #expect((second.version ?? 0) > (first.version ?? 0))
        #expect(weight.healthSampleID == second.uuid, "the id Health holds, read back")
    }

    /// S5: Burned asks Health for the local day as it is now, after a time-zone change.
    @Test func burnedFollowsATimeZoneChange() async throws {
        let context = try context()
        let store = FakeHealthStore()
        var zone = TimeZone(identifier: "America/New_York")!
        let sync = HealthSync(store: store, defaults: defaults(), calendar: {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = zone
            return calendar
        }, now: { [now] in now })
        sync.attach(context, observesSaves: false)
        await sync.set(.readBurned, on: true)
        var york = Calendar(identifier: .gregorian); york.timeZone = zone
        #expect(store.energyQueries.last?.start == york.startOfDay(for: now))
        zone = TimeZone(identifier: "America/Los_Angeles")!
        await sync.refreshBurned(on: now)
        var angeles = Calendar(identifier: .gregorian); angeles.timeZone = zone
        #expect(store.energyQueries.last?.start == angeles.startOfDay(for: now))
        #expect(york.startOfDay(for: now) != angeles.startOfDay(for: now))
    }

    /// S6: renaming an entry renames it in Health.
    @Test func aRenameReachesHealth() async throws {
        let context = try context()
        let store = FakeHealthStore()
        let sync = await sync(store, context, on: [.writeFood])
        try FoodLog.logManual(name: "Lunch", serving: nil, nutrition: FoodNutrition(calories: 600, proteinGrams: 30),
                              meal: .lunch, at: now, in: context)
        await sync.sync()
        let entry = try #require(try context.fetch(FetchDescriptor<FoodEntry>()).first)
        entry.name = "Chicken bowl"
        try context.save()
        await sync.sync()
        #expect(store.samples.filter(\.isOwn).allSatisfy { $0.foodName == "Chicken bowl" })
        #expect(store.samples.filter(\.isOwn).count == 2)
    }

    /// S7: Health's rows follow a unit change; the app's own keep the unit they were entered in.
    @Test func healthsRowsFollowAUnitChange() async throws {
        let context = try context()
        let preferences = AppPreferences(unitPreference: .kg)
        context.insert(preferences)
        try context.save()
        let store = FakeHealthStore()
        store.samples = [HealthSample(uuid: UUID(), type: .weight, date: now, value: 80, syncID: nil, isOwn: false)]
        let sync = await sync(store, context, on: [.readWeight])
        let mine = try BodyWeightLog.log(value: 81, unit: .kg, at: now, in: context)
        preferences.unitPreference = .lb
        try context.save()
        await sync.sync()
        let row = try #require(try context.fetch(FetchDescriptor<BodyWeightEntry>()).first { $0.source == .health })
        #expect(row.unit == .lb && abs(row.value - 176.37) < 0.01 && row.normalizedKg == 80)
        #expect(mine.unit == .kg && mine.value == 81)
    }

    /// T1: Ask AI's prefill (it leaves the phone) takes the weight the user entered, never Health's.
    @Test func askAITakesOnlyAnEnteredWeight() async throws {
        let context = try context()
        try BodyWeightLog.log(value: 80, unit: .kg, at: now.addingTimeInterval(-86_400), in: context)
        context.insert(BodyWeightEntry(measuredAt: now, value: 90, unit: .kg, source: .health, healthSampleID: UUID()))
        try context.save()
        #expect(try NutritionGoalStore.latestWeight(in: context)?.value == 90, "on the phone: Health's is the latest")
        let model = AIRoutineFlowModel()
        model.prefillMissingMeasurements(from: context)
        #expect(model.weightKg == 80)
        #expect(model.trainingProfile(usCustomary: false).weight?.kilograms == 80)

        let healthOnly = try self.context()
        healthOnly.insert(BodyWeightEntry(measuredAt: now, value: 90, unit: .kg, source: .health, healthSampleID: UUID()))
        try healthOnly.save()
        let fresh = AIRoutineFlowModel()
        fresh.prefillMissingMeasurements(from: healthOnly)
        #expect(fresh.weightKg == nil && fresh.trainingProfile(usCustomary: false).weight == nil)
    }
}
