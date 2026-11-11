import Foundation
import Observation
import SwiftData

// Nutrition N9b (D74): Apple Health — read body weight (shown with the app's own entries), write body weight, write food
// totals (calories, protein, carbs, fat), read the day's active energy as Burned on Today (D71: shown, never added).
// Each part is its own switch on Profile → Apple Health, asks Health's permission when first turned on, and works when
// the others are denied.
//
// The sync is a RECONCILE, not a hook on each write path: food is logged from a dozen places (Log food, Undo, Restore,
// scans, the editors), and every one of them must reach Health. Each pass compares what the app holds with the
// samples this app wrote to Health — found by their sync identifiers (`HealthSyncID`) — and saves what differs and
// deletes what has no entry any more. Health's own sync versioning replaces a sample saved again under the same sync
// identifier, so an edit is one save and a repeated pass writes nothing. Turning a write part off stops the app touching
// Health for it; turning it on again brings Health back in line (including deletes made meanwhile).
//
// Each written sample's Health id goes back on its entry (`healthSampleID`, D74), read back from Health after the save
// rather than assumed from it: reading weights skips samples with those ids, samples that carry this app's sync
// identifiers, and samples from this app — so the app's own writes never come back as "Apple Health" entries.
//
// Health's data stays on the phone (the approved usage string): weights read from Health feed what the phone shows and
// calculates, never a request to the server — `NutritionGoalStore.latestEnteredWeight` is the one for those.

/// The Health data types the app reads or writes for N9b (workouts and the live heart rate are elsewhere).
enum HealthType: String, CaseIterable, Sendable {
    case weight, energy, protein, carbs, fat, activeEnergy
}

/// The four switches on Profile → Apple Health.
enum HealthPart: String, CaseIterable, Identifiable, Sendable {
    case readWeight, readBurned, writeWeight, writeFood
    var id: String { rawValue }

    /// The types this part asks permission to save.
    var shares: Set<HealthType> {
        switch self {
        case .readWeight, .readBurned: []
        case .writeWeight: [.weight]
        case .writeFood: [.energy, .protein, .carbs, .fat]
        }
    }

    /// The types this part asks permission to read.
    var reads: Set<HealthType> {
        switch self {
        case .readWeight: [.weight]
        case .readBurned: [.activeEnergy]
        case .writeWeight, .writeFood: []
        }
    }

    var defaultsKey: String { "health.\(rawValue)" }
}

/// One Health sample as the sync sees it: weight in kg, energy in kcal, macros in grams.
struct HealthSample: Equatable, Sendable {
    var uuid: UUID
    var type: HealthType
    var date: Date
    var value: Double
    /// `HKMetadataKeySyncIdentifier`, when the sample has one.
    var syncID: String?
    /// Written by this app (its source is this app).
    var isOwn: Bool
    /// `HKMetadataKeySyncVersion`, when the sample has one.
    var version: Int? = nil
    /// `HKMetadataKeyFoodType`, when the sample has one.
    var foodName: String? = nil
}

/// A sample the app wants in Health.
struct HealthWrite: Equatable, Sendable {
    var syncID: String
    var type: HealthType
    var date: Date
    var value: Double
    /// `HKMetadataKeyFoodType`: the entry's name, so Health lists the food by name.
    var foodName: String?
    /// `HKMetadataKeySyncVersion`; the plan sets it above the version already in Health (codex-review-c1-n9b S4).
    var version: Int = 0
}

/// The app's sync identifiers: `stacked.weight.<entry id>` and `stacked.food.<entry id>.<type>`. Stable per entry and
/// type, so saving again replaces the sample in Health. Changing the format strands every sample already written (the
/// next pass would write each again beside its old copy).
enum HealthSyncID {
    static let prefix = "stacked."
    static func weight(_ entry: UUID) -> String { "\(prefix)weight.\(entry.uuidString)" }
    static func food(_ entry: UUID, _ type: HealthType) -> String { "\(prefix)food.\(entry.uuidString).\(type.rawValue)" }
    static func isApps(_ syncID: String?) -> Bool { syncID?.hasPrefix(prefix) == true }
    /// The type a sync id was written for: weight, or a food id's last part.
    static func type(of syncID: String) -> HealthType? {
        if syncID.hasPrefix("\(prefix)weight.") { return .weight }
        guard syncID.hasPrefix("\(prefix)food."), let last = syncID.split(separator: ".").last else { return nil }
        return HealthType(rawValue: String(last))
    }
}

/// Health behind a protocol, so the sync is tested with a fake and UI tests never reach the real store.
@MainActor
protocol HealthStoring: AnyObject {
    var isAvailable: Bool { get }
    /// Shows Health's permission sheet for these types (only the ones not asked before).
    func requestAuthorization(share: Set<HealthType>, read: Set<HealthType>) async throws
    /// Whether Health lets the app save this type (Health never says whether reading was allowed).
    func canWrite(_ type: HealthType) -> Bool
    /// Samples of a type since `start` (all time when nil); `ownOnly` limits them to this app's.
    func samples(_ type: HealthType, from start: Date?, ownOnly: Bool) async throws -> [HealthSample]
    /// Saves the samples, each under its own sync version (a higher version replaces the sample with the same sync id).
    /// Says nothing about which replacements Health accepted: the sync reads Health again to learn the samples' ids.
    func save(_ writes: [HealthWrite]) async throws
    /// Deletes this app's samples of a type with these sync identifiers.
    func delete(_ type: HealthType, syncIDs: [String]) async throws
    /// Active energy between the two instants in kcal, Health's de-duplicated sum across sources.
    func activeEnergy(from start: Date, to end: Date) async throws -> Double
}

// MARK: - The plan (pure)

enum HealthSyncPlan {
    /// The app's own weights as Health samples. Weights read from Health are never written back.
    static func weightWrites(_ entries: [BodyWeightEntry]) -> [HealthWrite] {
        entries.filter { $0.source == .app }.map {
            HealthWrite(syncID: HealthSyncID.weight($0.id), type: .weight, date: $0.measuredAt, value: $0.normalizedKg)
        }
    }

    /// Each food entry's totals (per serving × servings) as up to four samples at the time it was eaten. Calories are
    /// always written (a zero-calorie entry still says it was eaten); a macro only when above zero.
    static func foodWrites(_ entries: [FoodEntry]) -> [HealthWrite] {
        entries.flatMap { entry -> [HealthWrite] in
            let totals = NutritionMath.totals(of: entry)
            let values: [(HealthType, Double)] = [(.energy, totals.calories), (.protein, totals.proteinGrams),
                                                   (.carbs, totals.carbsGrams), (.fat, totals.fatGrams)]
            return values.compactMap { type, value in
                guard value.isFinite, value >= 0, type == .energy || value > 0 else { return nil }
                return HealthWrite(syncID: HealthSyncID.food(entry.id, type), type: type, date: entry.loggedAt,
                                   value: value, foodName: entry.name.isEmpty ? nil : entry.name)
            }
        }
    }

    struct Diff: Equatable {
        var save: [HealthWrite]
        /// Sync ids to delete before saving (no entry any more, or a duplicate).
        var delete: [String]
        /// Writes already in Health as they should be: sync id → that sample's Health id.
        var matched: [String: UUID]

        var isEmpty: Bool { save.isEmpty && delete.isEmpty }
    }

    /// What to change so this app's samples in Health are exactly `desired`. Only `existing` samples with this app's
    /// sync ids count; anyone else's are never touched. Each save's version is above both `baseVersion` (the clock) and
    /// the version Health holds for that sync id, so it replaces the sample even after the phone's clock went back.
    static func diff(desired: [HealthWrite], existing: [HealthSample], baseVersion: Int) -> Diff {
        let mine = Dictionary(grouping: existing.filter { $0.isOwn && HealthSyncID.isApps($0.syncID) }, by: { $0.syncID! })
        let wanted = Set(desired.map(\.syncID))
        var save: [HealthWrite] = []
        var delete = mine.keys.filter { !wanted.contains($0) }
        var matched: [String: UUID] = [:]
        for var write in desired {
            let copies = mine[write.syncID] ?? []
            if copies.count == 1, let sample = copies.first, same(sample, write) {
                matched[write.syncID] = sample.uuid
            } else {
                if copies.count > 1 { delete.append(write.syncID) }
                write.version = max(baseVersion, (copies.compactMap(\.version).max() ?? 0) + 1)
                save.append(write)
            }
        }
        return Diff(save: save, delete: delete.sorted(), matched: matched)
    }

    /// The sample already says what the write says: the same instant (Health keeps dates to the millisecond), the same
    /// value to within floating-point conversion — never a display rounding, so a 0.1 kg edit reaches Health
    /// (codex-review-c1-n9b S2) — and the same food name.
    static func same(_ sample: HealthSample, _ write: HealthWrite) -> Bool {
        abs(sample.date.timeIntervalSince(write.date)) < 0.001
            && abs(sample.value - write.value) <= 1e-9 * max(1, abs(write.value))
            && sample.foodName == write.foodName
    }

    /// Health's weights to show: everyone's but this app's (by Health id, sync id or source).
    static func readings(_ samples: [HealthSample], ownIDs: Set<UUID>) -> [HealthSample] {
        samples.filter { $0.type == .weight && !$0.isOwn && !HealthSyncID.isApps($0.syncID) && !ownIDs.contains($0.uuid) }
    }

    /// How the app's "Apple Health" rows follow Health's readings: new readings to insert, rows whose reading is gone.
    static func mirror(readings: [HealthSample], rows: [BodyWeightEntry]) -> (insert: [HealthSample], delete: [BodyWeightEntry]) {
        let ids = Set(readings.map(\.uuid))
        let have = Set(rows.compactMap(\.healthSampleID))
        let delete = rows.filter { row in row.healthSampleID.map { !ids.contains($0) } ?? true }
        var seen = Set<UUID>()
        let insert = readings.filter { !have.contains($0.uuid) && seen.insert($0.uuid).inserted }
        return (insert, delete)
    }
}

// MARK: - The sync

@MainActor
@Observable
final class HealthSync {
    /// Health's weights shown in the app: the last year's (older readings drop off the list).
    static let readingWindow: TimeInterval = 365 * 86_400

    let store: HealthStoring?
    private(set) var enabled: Set<HealthPart>
    /// Today's active energy read from Health, keyed by its local start of day.
    private(set) var burned: [Date: Double] = [:]
    /// The part whose Health permission sheet is up.
    private(set) var requesting: HealthPart?
    /// The last pass's failure, said on the Apple Health page; nil after a pass that worked.
    private(set) var failure: String?
    /// Bumped after a permission answer, so the page re-reads what Health allows.
    private(set) var authorizationRevision = 0

    @ObservationIgnored private let defaults: UserDefaults
    /// Read at each use, so a time-zone change moves the day's bounds (codex-review-c1-n9b S5).
    @ObservationIgnored private let calendar: () -> Calendar
    @ObservationIgnored private let debounce: Duration
    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var syncing = false
    @ObservationIgnored private var dirty = false
    @ObservationIgnored private var pending: Task<Void, Never>?
    @ObservationIgnored private var observer: NSObjectProtocol?
    @ObservationIgnored private var now: () -> Date
    /// Bumped whenever a part is switched: work for that part begun before the switch is dropped after its next await
    /// (a late answer must not import rows or start saves for a part now off — codex-review-c1-n9b S1).
    @ObservationIgnored private var generations: [HealthPart: Int] = [:]
    /// The latest Burned request: an older answer arriving after it (a time-zone change, Today and the switch both
    /// asking) never replaces it (codex-review-c1-n9b-b R2-S1).
    @ObservationIgnored private var burnedRequest = 0

    init(store: HealthStoring?, defaults: UserDefaults = .standard, calendar: @escaping () -> Calendar = { .current },
         debounce: Duration = .seconds(1), now: @escaping () -> Date = { .now }) {
        self.store = store
        self.defaults = defaults
        self.calendar = calendar
        self.debounce = debounce
        self.now = now
        enabled = Set(HealthPart.allCases.filter { defaults.bool(forKey: $0.defaultsKey) })
    }

    var isAvailable: Bool { store?.isAvailable == true }
    func isOn(_ part: HealthPart) -> Bool { enabled.contains(part) }
    var anyOn: Bool { !enabled.isEmpty }

    /// A write part whose types Health has not all allowed (it was turned on and some were refused). Reading has no
    /// such answer: Health shows a refused read as "no data".
    func isRefused(_ part: HealthPart) -> Bool {
        _ = authorizationRevision
        guard isOn(part), let store, !part.shares.isEmpty else { return false }
        return !part.shares.allSatisfy(store.canWrite)
    }

    /// Follows this context's store: a pass now, and a pass shortly after every save anywhere in the app. Tests may pass
    /// `observesSaves: false` and run each pass themselves.
    func attach(_ context: ModelContext, observesSaves: Bool = true) {
        self.context = context
        guard observesSaves else { return }
        if observer == nil {
            observer = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil,
                                                              queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scheduleSync() }
            }
        }
        scheduleSync(after: .zero)
    }

    /// A pass soon: saves come in bursts (a meal logs several entries), so they share one pass. During a pass, the
    /// pass runs again (or, past its limit, schedules this).
    func scheduleSync(after delay: Duration? = nil) {
        guard anyOn else { return }
        if syncing { dirty = true; return }
        pending?.cancel()
        let wait = delay ?? debounce
        pending = Task { [weak self] in
            try? await Task.sleep(for: wait)
            guard !Task.isCancelled else { return }
            await self?.sync()
        }
    }

    /// Turns a part on (asking Health first) or off. Off: reading weights removes Health's rows from the app; writing
    /// leaves what is already in Health. Either way, work for the part still under way is dropped.
    func set(_ part: HealthPart, on: Bool) async {
        guard let store, store.isAvailable else { return }
        generations[part, default: 0] += 1
        if on {
            requesting = part
            defer { requesting = nil; authorizationRevision += 1 }
            do {
                try await store.requestAuthorization(share: part.shares, read: part.reads)
            } catch {
                failure = HealthSyncCopy.permissionFailed
                return
            }
            enabled.insert(part)
            defaults.set(true, forKey: part.defaultsKey)
            failure = nil
            if part == .readBurned { await refreshBurned(on: now()) }
            await sync()
        } else {
            enabled.remove(part)
            defaults.set(false, forKey: part.defaultsKey)
            switch part {
            case .readWeight: removeReadings()
            case .readBurned: burned = [:]
            case .writeWeight, .writeFood: break
            }
        }
    }

    /// The day's active energy from Health, nil when reading it is off or nothing was read.
    func burned(on day: Date) -> Double? {
        guard isOn(.readBurned) else { return nil }
        return burned[calendar().startOfDay(for: day)]
    }

    func refreshBurned(on day: Date) async {
        guard isOn(.readBurned), let store, store.isAvailable else { return }
        burnedRequest += 1
        let request = burnedRequest
        let generation = generations[.readBurned, default: 0]
        let calendar = calendar()
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }
        // A refused read and a quiet day both read as 0 — Health does not say which (D74: the other parts go on).
        // Only the latest request publishes, and only while the part is still on and the asking task still wants it.
        guard let value = try? await store.activeEnergy(from: start, to: min(end, max(now(), start))),
              request == burnedRequest, current(.readBurned, generation), !Task.isCancelled else { return }
        burned = [start: value]
    }

    /// Passes over every part that is on. A save during a pass (the app's own included) runs another, which finds
    /// nothing to change; past three in a row the rest waits for a scheduled pass, so nothing is left behind
    /// (codex-review-c1-n9b S3).
    func sync() async {
        guard let store, store.isAvailable, let context, anyOn else { return }
        if syncing { dirty = true; return }
        syncing = true
        var passes = 0
        repeat {
            dirty = false
            passes += 1
            do {
                if isOn(.writeWeight) { try await writeWeights(store, context) }
                if isOn(.writeFood) { try await writeFood(store, context) }
                if isOn(.readWeight) { try await readWeights(store, context) }
                failure = nil
            } catch is CancellationError {
                // A part was switched during the pass: its work was dropped; the others run next pass.
                dirty = true
            } catch {
                failure = HealthSyncCopy.syncFailed
            }
        } while dirty && passes < 3
        syncing = false
        if dirty {
            dirty = false
            scheduleSync()
        }
    }

    // MARK: Passes

    private func current(_ part: HealthPart, _ generation: Int) -> Bool {
        isOn(part) && generations[part, default: 0] == generation
    }

    /// After every await: stop if the part was switched meanwhile.
    private func check(_ part: HealthPart, _ generation: Int) throws {
        guard current(part, generation) else { throw CancellationError() }
    }

    private func writeWeights(_ store: HealthStoring, _ context: ModelContext) async throws {
        guard store.canWrite(.weight) else { return }
        let generation = generations[.writeWeight, default: 0]
        let desired = HealthSyncPlan.weightWrites(try context.fetch(FetchDescriptor<BodyWeightEntry>()))
        let ids = try await reconcile(.writeWeight, generation, types: [.weight], desired: desired, store)
        // Fetched again: an entry may have been deleted while Health answered.
        var changed = false
        for entry in try context.fetch(FetchDescriptor<BodyWeightEntry>()) where entry.source == .app {
            if let id = ids[HealthSyncID.weight(entry.id)], entry.healthSampleID != id {
                entry.healthSampleID = id
                changed = true
            }
        }
        if changed { try context.save() }
    }

    private func writeFood(_ store: HealthStoring, _ context: ModelContext) async throws {
        let types = HealthPart.writeFood.shares.filter(store.canWrite)
        guard !types.isEmpty else { return }
        let generation = generations[.writeFood, default: 0]
        let desired = HealthSyncPlan.foodWrites(try context.fetch(FetchDescriptor<FoodEntry>())).filter { types.contains($0.type) }
        let ids = try await reconcile(.writeFood, generation, types: types, desired: desired, store)
        // The entry's Health id is its calories sample's (the one sample every entry writes). Fetched again, as above.
        var changed = false
        for entry in try context.fetch(FetchDescriptor<FoodEntry>()) {
            if let id = ids[HealthSyncID.food(entry.id, .energy)], entry.healthSampleID != id {
                entry.healthSampleID = id
                changed = true
            }
        }
        if changed { try context.save() }
    }

    /// Brings this app's samples of these types in line with `desired`: deletes, then saves, then reads Health again
    /// and returns the ids of the samples that now match (a save Health did not take shows up as unmatched, and the
    /// next pass tries again — codex-review-c1-n9b S4).
    private func reconcile(_ part: HealthPart, _ generation: Int, types: Set<HealthType>, desired: [HealthWrite],
                           _ store: HealthStoring) async throws -> [String: UUID] {
        let version = Int(now().timeIntervalSince1970 * 1_000)
        let diff = HealthSyncPlan.diff(desired: desired, existing: try await own(types, part, generation, store),
                                       baseVersion: version)
        guard !diff.isEmpty else { return diff.matched }
        for type in HealthType.allCases where types.contains(type) {
            let deletes = diff.delete.filter { HealthSyncID.type(of: $0) == type }
            guard !deletes.isEmpty else { continue }
            try await store.delete(type, syncIDs: deletes)
            try check(part, generation)
        }
        if !diff.save.isEmpty { try await store.save(diff.save) }
        try check(part, generation)
        return HealthSyncPlan.diff(desired: desired, existing: try await own(types, part, generation, store),
                                   baseVersion: version).matched
    }

    private func own(_ types: Set<HealthType>, _ part: HealthPart, _ generation: Int,
                     _ store: HealthStoring) async throws -> [HealthSample] {
        var samples: [HealthSample] = []
        for type in HealthType.allCases where types.contains(type) {
            samples += try await store.samples(type, from: nil, ownOnly: true)
            try check(part, generation)
        }
        return samples
    }

    private func readWeights(_ store: HealthStoring, _ context: ModelContext) async throws {
        let generation = generations[.readWeight, default: 0]
        let since = now().addingTimeInterval(-Self.readingWindow)
        let samples = try await store.samples(.weight, from: since, ownOnly: false)
        try check(.readWeight, generation)
        // Fetched after the answer, so no row deleted meanwhile is touched.
        let all = try context.fetch(FetchDescriptor<BodyWeightEntry>())
        let ownIDs = Set(all.filter { $0.source == .app }.compactMap(\.healthSampleID))
        let rows = all.filter { $0.source == .health }
        let plan = HealthSyncPlan.mirror(readings: HealthSyncPlan.readings(samples, ownIDs: ownIDs), rows: rows)
        let unit = Self.weightUnit(in: context)
        // Health's rows follow the unit system (codex-review-c1-n9b S7); kilograms stay exact. The app's own weights
        // keep the unit they were entered in.
        let deleted = Set(plan.delete.map(\.id))
        let inOtherUnit = rows.filter { !deleted.contains($0.id) && $0.unit != unit }
        guard !plan.insert.isEmpty || !plan.delete.isEmpty || !inOtherUnit.isEmpty else { return }
        for row in plan.delete { context.delete(row) }
        for row in inOtherUnit {
            row.value = WeightMath.convert(row.normalizedKg, from: .kg, to: unit)
            row.unit = unit
        }
        for reading in plan.insert {
            let entry = BodyWeightEntry(measuredAt: reading.date, value: WeightMath.convert(reading.value, from: .kg, to: unit),
                                        unit: unit, source: .health, healthSampleID: reading.uuid, createdAt: now())
            entry.normalizedKg = reading.value
            context.insert(entry)
        }
        try context.save()
    }

    /// Turning reading off: Health's rows leave the app (Health still has them).
    private func removeReadings() {
        guard let context else { return }
        do {
            let rows = try context.fetch(FetchDescriptor<BodyWeightEntry>()).filter { $0.source == .health }
            guard !rows.isEmpty else { return }
            for row in rows { context.delete(row) }
            try context.save()
        } catch {
            failure = HealthSyncCopy.syncFailed
        }
    }

    /// Health's weights are shown in the app's unit system (Health does not say which unit they were entered in).
    private static func weightUnit(in context: ModelContext) -> WeightUnit {
        let preferences = (try? context.fetch(FetchDescriptor<AppPreferences>())).flatMap(AppPreferences.canonical(of:))
        return AppUnitSystem.resolve(preference: preferences?.unitPreference) == .usCustomary ? .lb : .kg
    }
}

enum HealthSyncCopy {
    static let permissionFailed = "Couldn't ask Health for permission. Try again."
    static let syncFailed = "Couldn't update Apple Health. It will try again."
}

extension FoodDayMath {
    /// Burned on Today (D71, N9b): Health's active energy for the day when it is read — it already counts the app's own
    /// workouts saved there — else the app's workouts; the larger, so a workout not yet in Health is never lost.
    static func burned(workouts: Double, health: Double?) -> Double {
        max(workouts, health ?? 0)
    }
}
