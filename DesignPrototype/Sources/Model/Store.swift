import Foundation
import Observation

/// All prototype state: the sample data, the live session, the simulated sensors
/// and every flow. Screens read it from `@Environment(Store.self)` and change it
/// only through its methods. One Task owned by the Store ticks at 1 Hz and drives
/// the clock, rest timer, heart rate and cardio; `freezeClock` stops it for captures.
@Observable
final class Store {

    // MARK: - Clock

    /// "Now" for every screen: starts at Thu Sep 24 2026 18:30 and advances with real time.
    private(set) var now: Date = SampleData.today
    /// true = time stands still (deterministic `-screen` captures). Unfreezing continues from `now`.
    var freezeClock = false {
        didSet { if !freezeClock { setClock(now) } }
    }
    @ObservationIgnored private var realAnchor = Date()
    @ObservationIgnored private var clockAnchor = SampleData.today
    @ObservationIgnored private var ticker: Task<Void, Never>?

    // MARK: - Data

    var gyms: [Gym] = []
    var models: [EquipmentModel] = []
    var machines: [Machine] = []
    var exercises: [Exercise] = [] { didSet { exerciseCache = nil } }
    var templates: [Template] = []
    /// Finished workouts (unsorted); use `history` for newest-first.
    private(set) var workouts: [Workout] = [] { didSet { outcomeCache = nil } }
    var settings = AppSettings()
    /// Per-exercise rest overrides (Rest settings sheet).
    private(set) var restOverrides: [UUID: RestSettings] = [:]
    /// The gym chosen on Home (nil = "No gym").
    private(set) var selectedGymID: UUID?

    @ObservationIgnored private var exerciseCache: [UUID: Exercise]?
    @ObservationIgnored private var outcomeCache: [UUID: BestOutcome]?

    // MARK: - Live session

    private(set) var session: LiveSession?
    /// The live workout cover is showing (false = minimised: Home shows "Resume workout").
    var isSessionPresented = false
    private(set) var rest: RestState?
    /// How the last rest ended.
    private(set) var lastRestOutcome: RestOutcome?
    /// Increments on every rest end, skips included.
    private(set) var restEndCount = 0
    /// Increments only when a rest ran out, recovered or hit the cap — the rest-complete
    /// haptic / alarm trigger (a Skip never fires it).
    private(set) var restExpiryCount = 0
    private(set) var heartRate = HeartRateState()
    /// The latest completed set (celebration trigger: watch `.id`; see `freshNewBest`).
    private(set) var lastCompletion: SetCompletion?
    /// A start requested while a workout runs (W05 dialog).
    private(set) var pendingStart: PendingStart?
    /// "Finish It & Start New" found the live workout differs from its template: show the
    /// replacement drift dialog (resolve with `resolveReplacementDrift`, cancel with `keepCurrentWorkout`).
    private(set) var pendingReplacementDrift: TemplateDrift?
    /// Prototype toggle: outdoor GPS is unavailable ("Location unavailable.").
    private(set) var gpsUnavailable = false

    // MARK: - Finish

    /// The receipt to show after Finish (nil = none showing).
    private(set) var finishSummary: FinishSummary?
    /// Drift prompt to show after Finish (nil = none).
    private(set) var pendingDrift: TemplateDrift?

    // MARK: - Flows

    private(set) var ai = AIRoutineFlow()
    private(set) var scan = ScanFlow()
    private(set) var exportState: ExportState = .idle
    /// Prototype switch: the next export fails ("Export failed: …").
    private(set) var exportSimulateFailure = false
    /// New Model's "Suggest exercises with AI" (simulated).
    private(set) var modelSuggest: ModelSuggestState = .idle
    /// Prototype switch: the next suggestion fails with real error copy.
    private(set) var modelSuggestSimulateFailure = false
    /// What the last `reset(to:)` points at.
    private(set) var screenTarget = ScreenTarget()
    private(set) var currentScreen: ScreenID?

    @ObservationIgnored private var aiTask: Task<Void, Never>?
    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private var exportTask: Task<Void, Never>?
    @ObservationIgnored private var modelSuggestTask: Task<Void, Never>?

    // MARK: - Init

    init(screen: ScreenID? = nil, freezeClock: Bool = false) {
        self.freezeClock = freezeClock
        load(SampleData.world())
        startTicker()
        if let screen { reset(to: screen) }
    }

    private func load(_ world: SampleData.World) {
        gyms = world.gyms
        models = world.models
        machines = world.machines
        exercises = world.exercises
        templates = world.templates
        workouts = world.workouts
        settings = world.settings
        restOverrides = world.restSettings
        selectedGymID = SampleData.ironTempleID
        session = nil
        isSessionPresented = false
        rest = nil
        lastRestOutcome = nil
        heartRate = HeartRateState()
        lastCompletion = nil
        pendingStart = nil
        pendingReplacementDrift = nil
        gpsUnavailable = false
        finishSummary = nil
        pendingDrift = nil
        ai = AIRoutineFlow()
        scan = ScanFlow()
        exportState = .idle
        exportSimulateFailure = false
        modelSuggest = .idle
        modelSuggestSimulateFailure = false
        screenTarget = ScreenTarget()
        setClock(SampleData.today)
    }

    // MARK: - Ticker

    private func setClock(_ date: Date) {
        clockAnchor = date
        realAnchor = Date()
        now = date
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                self.tick()
            }
        }
    }

    private func tick() {
        guard !freezeClock else { return }
        let previous = now
        now = clockAnchor.addingTimeInterval(Date().timeIntervalSince(realAnchor))
        let dt = now.timeIntervalSince(previous)
        guard dt > 0, dt < 30, session != nil else { return }
        advanceHeartRate(dt)
        advanceCardio(dt)
        evaluateRest()
    }

    private func advanceHeartRate(_ dt: TimeInterval) {
        guard var s = session else { return }
        switch heartRate.mode {
        case .live:
            // The script steps every few seconds; the reading eases toward the target
            // (script, rest recovery curve or cardio drift) so it never jumps.
            heartRate.scriptElapsed += dt
            while heartRate.scriptElapsed >= HRScript.secondsPerStep {
                heartRate.scriptElapsed -= HRScript.secondsPerStep
                heartRate.scriptStep += 1
            }
            let script = HRScript.bpm(step: heartRate.scriptStep)
            var target = Double(script)
            if rest != nil, let from = heartRate.recoveryFrom {
                let t = now.timeIntervalSince(heartRate.recoveryStart ?? now)
                target = 98 + Double(from - 98) * exp(-t / 45) + 2 * sin(t / 3)
            } else if let cardio = s.unfinishedCardio, cardio.isRunning {
                let t = Double(cardio.activeSeconds(at: now))
                target = min(172, 118 + t / 30 + Double(script - 125) / 6)
            }
            let level = HRScript.eased(heartRate.level ?? Double(heartRate.bpm ?? Int(target.rounded())), toward: target, dt: dt)
            heartRate.level = level
            let bpm = Int(level.rounded())
            heartRate.bpm = bpm
            heartRate.lastSampleAt = now
            s.heartRate.add(bpm, seconds: dt, zone: zone(for: bpm))
            s.activeCalories += CardioSimulator.caloriesPerSecond(bpm: bpm) * dt
        case .stale:
            s.heartRate.addGap(seconds: dt)
        case .none:
            heartRate.bpm = nil
            heartRate.lastSampleAt = nil
            s.heartRate.addGap(seconds: dt)
        }
        session = s
    }

    private func advanceCardio(_ dt: TimeInterval) {
        guard var s = session, let i = s.cardio.firstIndex(where: \.isRunning) else { return }
        var c = s.cardio[i]
        let t = Double(c.activeSeconds(at: now))
        if c.gps == .waiting && t - c.gpsWaitFrom >= CardioSimulator.gpsWaitSeconds { c.gps = .live }
        if c.gps.recordsDistance {
            let speed = CardioSimulator.speed(for: c.activity, at: t)
            c.measuredMeters += speed * dt
            c.currentSpeed = speed
        } else {
            c.currentSpeed = nil
        }
        if c.gps == .live, (c.route.last?.offset ?? -.infinity) + CardioSimulator.routeInterval <= t {
            c.route.append(CardioSimulator.routePoint(at: t, portion: c.routePortion))
        }
        if let bpm = heartRate.current(at: now) {
            c.heartRateSum += bpm
            c.heartRateCount += 1
            c.maxHeartRate = max(c.maxHeartRate ?? 0, bpm)
            c.activeCalories += CardioSimulator.caloriesPerSecond(bpm: bpm) * dt
        }
        s.cardio[i] = c
        session = s
    }

    private func evaluateRest() {
        guard var r = rest else { return }
        if r.mode == .heartRate, !r.isDegraded {
            if case .live = heartRate.feed(at: now) {
                if let bpm = heartRate.bpm, let threshold = r.thresholdBpm, bpm < threshold {
                    finishRest(.recovered(bpm: bpm))
                    return
                }
            } else {
                // No reading: fall back to the timer and say so.
                let standard = restSeconds(entryID: r.entryID, type: setType(entryID: r.entryID, setID: r.setID))
                r.isDegraded = true
                r.mode = .timer
                r.thresholdBpm = nil
                r.totalSeconds = standard
                r.endsAt = r.startedAt.addingTimeInterval(TimeInterval(standard))
                rest = r
            }
        }
        if now >= r.endsAt { finishRest(r.mode == .heartRate ? .cap : .timerDone) }
    }

    private func finishRest(_ outcome: RestOutcome) {
        rest = nil
        heartRate.recoveryFrom = nil
        lastRestOutcome = outcome
        restEndCount += 1
        if outcome != .skipped { restExpiryCount += 1 }
    }

    // MARK: - Lookups

    var exerciseByID: [UUID: Exercise] {
        let list = exercises
        if let exerciseCache { return exerciseCache }
        let map = Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        exerciseCache = map
        return map
    }
    private var machineByID: [UUID: Machine] { Dictionary(machines.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }) }

    func exercise(_ id: UUID?) -> Exercise? { id.flatMap { exerciseByID[$0] } }
    func gym(_ id: UUID?) -> Gym? { id.flatMap { id in gyms.first { $0.id == id } } }
    func machine(_ id: UUID?) -> Machine? { id.flatMap { id in machines.first { $0.id == id } } }
    func model(_ id: UUID?) -> EquipmentModel? { id.flatMap { id in models.first { $0.id == id } } }
    func template(_ id: UUID?) -> Template? { id.flatMap { id in templates.first { $0.id == id } } }
    func workout(_ id: UUID?) -> Workout? { id.flatMap { id in workouts.first { $0.id == id } } }

    var selectedGym: Gym? { gym(selectedGymID) }
    /// Gyms not deleted, by name.
    var activeGyms: [Gym] { gyms.filter { !$0.isDeleted }.sorted { $0.name < $1.name } }
    var deletedGyms: [Gym] { gyms.filter(\.isDeleted) }
    /// Templates alphabetically (the Home grid order).
    var sortedTemplates: [Template] { templates.sorted { $0.name.localizedCompare($1.name) == .orderedAscending } }
    /// Finished workouts, newest first.
    var history: [Workout] { workouts.sorted { $0.startedAt > $1.startedAt } }

    func activeMachines(gymID: UUID?) -> [Machine] {
        machines.filter { $0.gymID == gymID && !$0.isDeleted }.sorted { $0.label.localizedCompare($1.label) == .orderedAscending }
    }
    func deletedMachines(gymID: UUID?) -> [Machine] {
        machines.filter { $0.gymID == gymID && $0.isDeleted }.sorted { $0.label < $1.label }
    }
    /// The exercises a machine serves: its model's, else the recognised ones.
    func exerciseIDs(of machine: Machine) -> [UUID] {
        if let ids = model(machine.modelID)?.exerciseIDs, !ids.isEmpty { return ids }
        return machine.recognizedExerciseIDs
    }
    /// Active machines at a gym that serve an exercise.
    func machines(for exerciseID: UUID, gymID: UUID?) -> [Machine] {
        activeMachines(gymID: gymID).filter { exerciseIDs(of: $0).contains(exerciseID) }
    }
    func modelName(of machine: Machine?) -> String? { model(machine?.modelID)?.displayName }
    /// D51 counterpart: "Log as Dumbbell Bench Press instead".
    func dumbbellCounterpart(of exerciseID: UUID) -> Exercise? {
        guard let name = exercise(exerciseID)?.name, let target = SampleData.dumbbellCounterparts[name] else { return nil }
        return exercise(SampleData.exerciseID(target))
    }

    /// App display unit (Settings).
    var displayUnit: WeightUnit { settings.weightUnit }
    var distanceUnit: DistanceUnit { settings.distanceUnit }
    /// Unit precedence: machine → gym → app.
    func defaultUnit(machine: Machine?, gymID: UUID?) -> WeightUnit {
        machine?.defaultUnit ?? gym(gymID)?.defaultUnit ?? settings.weightUnit
    }
    /// A measured max wins; else 220 − age; else nil (no zones at all).
    var maxHeartRate: Int? {
        if let measured = settings.measuredMaxHeartRate, measured > 0 { return measured }
        return ageBasedMaxHeartRate
    }
    /// 220 − age from the date of birth (188 in the sample), shown beside a measured max (L12).
    var ageBasedMaxHeartRate: Int? {
        guard let birth = settings.birthDate,
              let age = Calendar.app.dateComponents([.year], from: birth, to: now).year else { return nil }
        return 220 - age
    }
    /// true when the max comes from the date of birth (the "edit zones" hint).
    var maxHeartRateIsEstimated: Bool { settings.measuredMaxHeartRate == nil && maxHeartRate != nil }
    func zone(for bpm: Int) -> HeartRateZone? { Derived.zone(bpm: bpm, max: maxHeartRate) }
    var zoneRows: [ZoneRow] { maxHeartRate.map { Derived.zoneRows(max: $0) } ?? [] }

    // MARK: - Derived data

    var weekSummary: WeekSummary { Derived.weekSummary(history: workouts, exercises: exerciseByID, now: now) }
    func monthSummary(for month: Date) -> MonthSummary { Derived.monthSummary(history: workouts, month: month) }
    /// PROPOSED feature (week streak) — not in SPEC/DECISIONS.
    var weekStreak: WeekStreak { Derived.weekStreak(history: workouts, now: now) }
    func templateStats(_ templateID: UUID) -> TemplateStats { Derived.templateStats(templateID: templateID, history: workouts) }
    func gymStats(_ gymID: UUID) -> GymStats { Derived.gymStats(gymID: gymID, history: workouts, machines: machines) }
    func machineStats(_ machineID: UUID) -> MachineStats { Derived.machineStats(machineID: machineID, history: workouts) }
    func calendarMonth(containing date: Date, selected: Date? = nil) -> CalendarMonth {
        Derived.calendarMonth(containing: date, selected: selected, history: workouts, exercises: exerciseByID, now: now)
    }
    func families(ofTemplate id: UUID) -> [MuscleFamily] {
        template(id).map { Derived.families(of: $0, exercises: exerciseByID) } ?? []
    }
    func families(ofWorkout id: UUID) -> [MuscleFamily] {
        workout(id).map { Derived.families(of: $0, exercises: exerciseByID) } ?? []
    }
    func families(exerciseIDs: [UUID]) -> [MuscleFamily] { Derived.families(exerciseIDs: exerciseIDs, exercises: exerciseByID) }
    func volumeKg(ofWorkout id: UUID) -> Double { workout(id).map(Derived.volumeKg(of:)) ?? 0 }

    /// Every history set's record outcome (cached until history changes).
    var bestOutcomes: [UUID: BestOutcome] {
        let list = workouts
        if let outcomeCache { return outcomeCache }
        let map = Derived.bestOutcomes(list)
        outcomeCache = map
        return map
    }
    func bestOutcome(setID: UUID) -> BestOutcome { bestOutcomes[setID] ?? .none }
    /// New bests (PRs) in a finished workout: exercises with at least one new-best set
    /// (several climbing sets in one exercise count once, like the finish summary).
    func newBestCount(workoutID: UUID) -> Int {
        workout(workoutID)?.entries.filter { $0.sets.contains { bestOutcome(setID: $0.id).isNewBest } }.count ?? 0
    }
    func lastTrained(exerciseID: UUID) -> Date? {
        workouts.filter { $0.entries.contains { $0.exerciseID == exerciseID } }.map(\.startedAt).max()
    }
    func hrSlots(workoutID: UUID) -> [HRSlot] {
        guard let w = workout(workoutID), let series = w.heartRate?.series else { return [] }
        return Derived.hrSlots(series: series, durationSeconds: w.durationSeconds)
    }
    func drift(workoutID: UUID) -> TemplateDrift? {
        guard let w = workout(workoutID), let t = template(w.templateID) else { return nil }
        return Derived.drift(template: t, workout: w, exercises: exerciseByID)
    }

    func progressVariations(exerciseID: UUID) -> [ProgressVariation] {
        Derived.progressVariations(exerciseID: exerciseID, history: workouts)
    }
    /// The variation a history entry charts under (per-exercise chart button in Workout Detail).
    func progressVariationID(for entry: WorkoutEntry) -> String { Derived.variationID(for: entry) }

    /// Superset letters for a template's items: item id → "A"/"B" (T01 grouping).
    func supersetLabels(ofTemplate id: UUID) -> [UUID: String] {
        guard let t = template(id) else { return [:] }
        return Self.labelMap(ids: t.items.map(\.id), groups: t.items.map(\.supersetGroup))
    }
    /// Superset letters for a finished workout's entries: entry id → "A"/"B" (H03 grouping).
    func supersetLabels(ofWorkout id: UUID) -> [UUID: String] {
        guard let w = workout(id) else { return [:] }
        return Self.labelMap(ids: w.entries.map(\.id), groups: w.entries.map(\.supersetGroup))
    }
    private static func labelMap(ids: [UUID], groups: [UUID?]) -> [UUID: String] {
        var map: [UUID: String] = [:]
        for (id, label) in zip(ids, Derived.supersetLabels(groups: groups)) { if let label { map[id] = label } }
        return map
    }
    /// The chart series for a variation (nil id = the default: most training days).
    func progressSeries(exerciseID: UUID, variationID: String? = nil) -> ProgressSeries? {
        let variations = progressVariations(exerciseID: exerciseID)
        guard let variation = variations.first(where: { $0.id == variationID }) ?? variations.first else { return nil }
        return Derived.progressSeries(exerciseID: exerciseID, variation: variation, history: workouts)
    }
    func progressChange(_ series: ProgressSeries, metric: ProgressMetric) -> Double? { Derived.change(series, metric: metric) }

    /// Three-layer previous performance for a live entry.
    func previousPerformance(entryID: UUID) -> PreviousPerformance? {
        guard let entry = liveEntry(entryID) else { return nil }
        return previousPerformance(exerciseID: entry.exerciseID, machineID: entry.machineID, tag: entry.freeWeightTag,
                                   presetID: entry.presetID, gymID: session?.gymID)
    }
    func previousPerformance(exerciseID: UUID, machineID: UUID?, tag: EquipmentTag?, presetID: UUID?,
                             gymID: UUID?) -> PreviousPerformance? {
        guard let exercise = exercise(exerciseID) else { return nil }
        return Derived.previousPerformance(exercise: exercise, machine: machine(machineID), tag: tag, presetID: presetID,
                                           gymID: gymID, history: workouts, machines: machineByID)
    }

    /// Exercises grouped by body area, head to toe, then "Uncategorized" (group nil).
    /// Search is token-based and order-independent.
    func exerciseSections(query: String = "") -> [(group: MuscleGroup?, exercises: [Exercise])] {
        let matches = exercises.filter { Self.matches($0.name, query) }
        var sections: [(MuscleGroup?, [Exercise])] = MuscleGroup.allCases.compactMap { group in
            let items = matches.filter { $0.muscleGroup == group }.sorted { $0.name < $1.name }
            return items.isEmpty ? nil : (group, items)
        }
        let loose = matches.filter { $0.muscleGroup == nil }.sorted { $0.name < $1.name }
        if !loose.isEmpty { sections.append((nil, loose)) }
        return sections.map { (group: $0.0, exercises: $0.1) }
    }
    /// Most recently trained exercises at a gym, newest first.
    func recentExercises(gymID: UUID?, limit: Int = 6) -> [Exercise] {
        var seen = Set<UUID>(), result: [Exercise] = []
        for w in history where w.gymID == gymID {
            for e in w.entries where seen.insert(e.exerciseID).inserted {
                if let ex = exercise(e.exerciseID) { result.append(ex) }
            }
        }
        return Array(result.prefix(limit))
    }
    /// Catalog search (manufacturer or model), optional type filter.
    func searchModels(query: String, category: EquipmentCategory? = nil) -> [EquipmentModel] {
        models.filter { Self.matches($0.displayName, query) && (category == nil || $0.category == category) }
            .sorted { $0.displayName < $1.displayName }
    }
    static func matches(_ text: String, _ query: String) -> Bool {
        let tokens = query.lowercased().split(whereSeparator: { $0 == " " || $0 == "-" })
        let haystack = text.lowercased()
        return tokens.allSatisfy { haystack.contains($0) }
    }

    // MARK: - Live: reading

    func liveEntry(_ id: UUID?) -> LiveEntry? { id.flatMap { id in session?.entries.first { $0.id == id } } }
    /// Elapsed seconds (wall time; lifting has no pause).
    var sessionElapsed: Int { session.map { Int(now.timeIntervalSince($0.startedAt)) } ?? 0 }
    /// Typed name, else the template name, else "First Exercise +N", else "Workout".
    var sessionTitle: String {
        guard let s = session else { return "" }
        if let name = s.name { return name }
        if let t = s.templateName { return t }
        let names = s.entries.compactMap { exercise($0.exerciseID)?.name } + s.cardio.map(\.activity.name)
        guard let first = names.first else { return "Workout" }
        return names.count > 1 ? "\(first) +\(names.count - 1)" : first
    }
    /// Volume so far (counted weighted sets).
    var sessionVolumeKg: Double {
        guard let s = session else { return 0 }
        return s.entries.reduce(0) { sum, entry in
            guard loadType(of: entry) == .weighted else { return sum }
            return sum + entry.sets.reduce(0) { acc, set in
                guard set.isCompleted, set.type.countsTowardRecords, let w = entry.total(of: set), let reps = set.reps else { return acc }
                return acc + set.unit.toKg(w) * Double(reps)
            }
        }
    }
    /// The entry holding the most recently completed set (else the first unfinished one).
    var currentEntryID: UUID? {
        guard let s = session else { return nil }
        let latest = s.entries.compactMap { e in e.sets.compactMap(\.completedAt).max().map { (e.id, $0) } }.max { $0.1 < $1.1 }
        return latest?.0 ?? s.entries.first { $0.sets.contains { !$0.isCompleted } }?.id
    }
    /// The first entry after the current one with an unfinished set.
    var nextEntryID: UUID? {
        guard let s = session, let current = currentEntryID, let i = s.entries.firstIndex(where: { $0.id == current }) else { return nil }
        let after = s.entries[(i + 1)...] + s.entries[..<i]
        return after.first { $0.sets.contains { !$0.isCompleted } }?.id
    }
    /// "Next · Set 3 · 110 × 8" for the rest bar.
    var nextSet: NextSetPreview? {
        guard let s = session, let current = currentEntryID, let i = s.entries.firstIndex(where: { $0.id == current }) else { return nil }
        let order = Array(s.entries[i...]) + Array(s.entries[..<i])
        for entry in order {
            guard let set = entry.sets.first(where: { !$0.isCompleted }) else { continue }
            let loadType = loadType(of: entry)
            let value = set.reps.map { SetValue(weight: entry.total(of: set), unit: set.unit, reps: $0, bar: entry.barWeight) }
            let label = set.type == .working ? "Set \(setMarker(entryID: entry.id, setID: set.id))" : set.type.displayName
            return NextSetPreview(entryID: entry.id, setID: set.id, exerciseName: exercise(entry.exerciseID)?.name ?? "",
                                  setLabel: label, value: value, loadType: loadType, isNewExercise: entry.id != current)
        }
        return nil
    }
    /// Sets typed but not ticked (the finish notice: they are discarded).
    var unloggedSetCount: Int {
        session?.entries.reduce(0) { $0 + $1.sets.filter { $0.state == .typed }.count } ?? 0
    }
    /// "W", "F", "D", or the working index ("1", "2"…; failure and drop rows consume a number).
    func setMarker(entryID: UUID, setID: UUID) -> String {
        guard let entry = liveEntry(entryID), let set = entry.sets.first(where: { $0.id == setID }) else { return "" }
        if let marker = set.type.marker { return marker }
        let counted = entry.sets.filter { $0.type != .warmup }
        return "\((counted.firstIndex { $0.id == setID } ?? 0) + 1)"
    }
    /// "A", "B", "C" inside a superset of two or more; nil otherwise.
    func supersetLabel(entryID: UUID) -> String? {
        guard let run = supersetRun(entryID), run.count > 1, let i = run.firstIndex(of: entryID) else { return nil }
        return String(UnicodeScalar(UInt8(65 + i)))
    }
    /// "Last time" for a live row (same machine/tag + preset, same set type and position).
    func previousValue(entryID: UUID, setID: UUID) -> SetValue? {
        guard let entry = liveEntry(entryID), let set = entry.sets.first(where: { $0.id == setID }) else { return nil }
        let ordinal = entry.sets.filter { $0.type == set.type }.firstIndex { $0.id == setID } ?? 0
        return Derived.previousValue(scope: entry.scope, type: set.type, ordinal: ordinal, history: workouts)
    }
    /// The check mark is enabled: reps > 0, plus a weight for weighted / assisted / BW+added.
    func isLoggable(entryID: UUID, setID: UUID) -> Bool {
        guard let entry = liveEntry(entryID), let set = entry.sets.first(where: { $0.id == setID }) else { return false }
        return isLoggable(entry, set)
    }
    private func isLoggable(_ entry: LiveEntry, _ set: LiveSet) -> Bool {
        guard let reps = set.reps, reps > 0 else { return false }
        return !loadType(of: entry).takesWeight || entry.total(of: set) != nil
    }
    /// The load type a live entry logs and ranks under: its D23 snapshot once a set is
    /// completed, else the exercise's current one (drives the WEIGHT / ASSIST column).
    func loadType(entryID: UUID) -> LoadType {
        liveEntry(entryID).map(loadType(of:)) ?? .weighted
    }
    private func loadType(of entry: LiveEntry) -> LoadType {
        entry.snapshotLoadType ?? exercise(entry.exerciseID)?.loadType ?? .weighted
    }
    /// Bar mode is offered for barbell/Smith tags or a rack/Smith model.
    func offersBar(entryID: UUID) -> Bool {
        guard let entry = liveEntry(entryID) else { return false }
        if let tag = entry.freeWeightTag, entry.machineID == nil { return tag.offersBar }
        return model(machine(entry.machineID)?.modelID)?.category == .rackOrSmith
    }

    /// How long a completion counts as "just happened" (L03's celebration moment).
    static let celebrationWindow: TimeInterval = 4
    /// `lastCompletion` within the last few seconds (nil afterwards): L03 has one, L01 (36 s later) does not.
    var freshCompletion: SetCompletion? {
        guard let c = lastCompletion, now.timeIntervalSince(c.at) < Self.celebrationWindow else { return nil }
        return c
    }
    /// A fresh completion that is a new best — show the celebration while non-nil.
    var freshNewBest: SetCompletion? { freshCompletion.flatMap { $0.outcome.isNewBest ? $0 : nil } }

    var hrFeed: HeartRateFeed { heartRate.feed(at: now) }
    /// A fresh reading, or nil.
    var currentBPM: Int? { heartRate.current(at: now) }
    var currentZone: HeartRateZone? { currentBPM.flatMap(zone(for:)) }

    /// The lock-screen Live Activity / Dynamic Island content for the running workout.
    var liveActivity: LiveActivitySnapshot? {
        guard let s = session else { return nil }
        let cardio = s.focus == .cardio ? s.unfinishedCardio : nil
        let current = liveEntry(currentEntryID).flatMap { exercise($0.exerciseID)?.name }
        return LiveActivitySnapshot(
            title: sessionTitle, gymName: gym(s.gymID)?.name, startedAt: s.startedAt, elapsedSeconds: sessionElapsed,
            isCardio: cardio != nil, exerciseName: cardio == nil ? current : nil,
            completedSets: s.completedSetCount, totalSets: s.totalSetCount,
            bpm: currentBPM, zone: currentZone,
            restEndsAt: rest?.endsAt, restRemaining: rest?.remaining(at: now), restTotal: rest?.totalSeconds,
            activity: cardio?.activity, cardioSeconds: cardio?.activeSeconds(at: now), distanceMeters: cardio?.distanceMeters,
            distanceUnit: cardio?.unit ?? distanceUnit, paceSecondsPerUnit: cardio?.paceSecondsPerUnit(at: now),
            isCardioPaused: cardio?.isPaused ?? false)
    }
    /// The Live Activity of another screen state (Z01's cardio variant: `.c02`), from a frozen throwaway store.
    static func liveActivitySample(_ screen: ScreenID) -> LiveActivitySnapshot? {
        Store(screen: screen, freezeClock: true).liveActivity
    }

    func plannedStatus(_ plannedID: UUID) -> PlannedCardioStatus {
        guard let c = session?.cardio.first(where: { $0.plannedID == plannedID }) else { return .notStarted }
        if c.isEnded { return .done }
        return c.isPaused ? .paused : .recording
    }
    /// Target progress 0…1 (active time ÷ planned minutes).
    func plannedProgress(_ plannedID: UUID) -> Double? {
        guard let s = session, let plan = s.plannedCardio.first(where: { $0.id == plannedID }),
              let c = s.cardio.first(where: { $0.plannedID == plannedID }) else { return nil }
        return min(1, Double(c.activeSeconds(at: c.endedAt ?? now)) / Double(plan.minutes * 60))
    }

    // MARK: - Live: starting, minimising

    /// Starts lifting (empty or from a template) at the selected gym. While a
    /// workout runs it records `pendingStart` and returns `.needsConfirmation`.
    @discardableResult
    func startLifting(templateID: UUID? = nil) -> StartResult {
        if session != nil {
            pendingStart = PendingStart(templateID: templateID, activity: nil)
            return .needsConfirmation
        }
        var s = LiveSession(id: UUID(), templateID: templateID, templateName: template(templateID)?.name,
                            gymID: selectedGymID, startedAt: now)
        if let t = template(templateID) {
            for item in t.items {
                var entry = makeEntry(exerciseID: item.exerciseID, gymID: s.gymID, tag: item.equipmentTag, draftCount: item.setCount)
                entry.targetReps = item.targetReps
                entry.plannedRestSeconds = item.restSeconds
                entry.supersetGroup = item.supersetGroup
                s.entries.append(entry)
            }
            s.plannedCardio = t.cardio
        }
        beginSession(s)
        return .started
    }

    /// Starts cardio: a new cardio-only workout, or a new segment in the running one
    /// (which ends any unfinished segment and skips a running rest).
    @discardableResult
    func startCardio(activity: CardioActivity, plannedID: UUID? = nil) -> StartResult {
        if session == nil {
            beginSession(LiveSession(id: UUID(), gymID: selectedGymID, startedAt: now))
        }
        withSession { s in
            if let i = s.cardio.firstIndex(where: { !$0.isEnded }) { self.end(&s.cardio[i]) }
            s.cardio.append(LiveCardio(id: UUID(), activity: activity, startedAt: now, runningSince: now,
                                       unit: settings.distanceUnit, plannedID: plannedID,
                                       gps: activity.isOutdoor ? (gpsUnavailable ? .unavailable : .waiting) : .notNeeded))
            s.focus = .cardio
        }
        if rest != nil { finishRest(.skipped) }
        isSessionPresented = true
        return .started
    }

    private func beginSession(_ s: LiveSession) {
        session = s
        rest = nil
        lastCompletion = nil
        lastRestOutcome = nil
        pendingStart = nil
        pendingReplacementDrift = nil
        finishSummary = nil
        pendingDrift = nil
        // The sensor toggle carries over: no sensor → no reading; stale → an old reading.
        var hr = HeartRateState(source: .airPods, mode: heartRate.mode, scriptStep: HRScript.startStep)
        switch heartRate.mode {
        case .live:
            hr.bpm = HRScript.bpm(step: HRScript.startStep)
            hr.lastSampleAt = now
        case .stale:
            hr.bpm = 124
            hr.lastSampleAt = now.addingTimeInterval(-(HeartRateState.staleAfter + 3))
        case .none:
            break
        }
        heartRate = hr
        isSessionPresented = true
    }

    /// W05 "Finish It & Start New". When the live workout came from a template it now differs
    /// from (and prompts are on), this only sets `pendingReplacementDrift` — show the replacement
    /// drift dialog; otherwise it finishes the running workout (no receipt) and starts the pending one.
    func confirmPendingStart() {
        guard let pending = pendingStart else { return }
        if !settings.suppressTemplatePrompts, let drift = liveDrift {
            pendingReplacementDrift = drift
            return
        }
        replace(with: pending, resolution: nil)
    }
    /// Replacement drift dialog: any resolution finishes the old workout, applies the resolution
    /// to its template, and starts the pending one. `dontAskAgain` turns template prompts off.
    func resolveReplacementDrift(_ resolution: DriftResolution, dontAskAgain: Bool = false) {
        guard let pending = pendingStart, pendingReplacementDrift != nil else { return }
        pendingReplacementDrift = nil
        if dontAskAgain { settings.suppressTemplatePrompts = true }
        replace(with: pending, resolution: resolution)
    }
    /// Replacement drift dialog's cancel, "Keep Current Workout": nothing finishes or starts.
    func keepCurrentWorkout() {
        pendingReplacementDrift = nil
        pendingStart = nil
    }
    private func replace(with pending: PendingStart, resolution: DriftResolution?) {
        let (_, saved) = finishSession(promptDrift: false)
        if let resolution, let saved, let i = templates.firstIndex(where: { $0.id == saved.templateID }) {
            templates[i] = Derived.resolve(resolution, template: templates[i], workout: saved)
        }
        finishSummary = nil  // the replaced workout shows no receipt (real behaviour)
        pendingDrift = nil
        if let activity = pending.activity { startCardio(activity: activity) } else { startLifting(templateID: pending.templateID) }
    }
    /// The live workout's differences from its template if it finished now (nil = none / no template).
    var liveDrift: TemplateDrift? {
        guard let s = session, let t = template(s.templateID), let w = workout(from: s) else { return nil }
        return Derived.drift(template: t, workout: w, exercises: exerciseByID)
    }
    /// W05 "Resume Workout".
    func resumeInsteadOfPending() { pendingStart = nil; pendingReplacementDrift = nil; isSessionPresented = true }
    func cancelPendingStart() { pendingStart = nil; pendingReplacementDrift = nil }
    func resume() { if session != nil { isSessionPresented = true } }
    func minimise() { isSessionPresented = false }
    func setFocus(_ focus: SessionFocus) { withSession { $0.focus = focus } }

    // MARK: - Live: exercises

    /// Adds an exercise (remembered machine at this gym, else its free-weight tag) with one draft row.
    @discardableResult
    func addExercise(_ exerciseID: UUID) -> UUID? {
        guard session != nil else { return nil }
        let entry = makeEntry(exerciseID: exerciseID, gymID: session?.gymID, tag: nil, draftCount: 1)
        withSession { $0.entries.append(entry); $0.focus = .lifting }
        return entry.id
    }

    /// Adds by machine. With one linked exercise (or `exerciseID`) it adds and returns
    /// the entry id; with several and no choice it returns nil (show the machine's list).
    @discardableResult
    func addByMachine(_ machineID: UUID, exerciseID: UUID? = nil) -> UUID? {
        guard session != nil, let m = machine(machineID) else { return nil }
        let ids = exerciseIDs(of: m)
        guard let chosen = exerciseID ?? (ids.count == 1 ? ids[0] : nil) else { return nil }
        let entry = makeEntry(exerciseID: chosen, gymID: m.gymID, tag: nil, draftCount: 1, machineID: machineID)
        withSession { $0.entries.append(entry); $0.focus = .lifting }
        return entry.id
    }

    private func makeEntry(exerciseID: UUID, gymID: UUID?, tag: EquipmentTag?, draftCount: Int,
                           machineID: UUID? = nil) -> LiveEntry {
        let ex = exercise(exerciseID)
        var chosenMachine = machine(machineID)
        var chosenTag = tag
        if chosenMachine == nil && tag == nil {
            chosenMachine = rememberedMachine(exerciseID: exerciseID, gymID: gymID)
            if chosenMachine == nil {
                chosenTag = ex?.tags.first { $0 != .machine }
                if chosenTag == nil {
                    let options = machines(for: exerciseID, gymID: gymID)
                    if options.count == 1 { chosenMachine = options[0] }
                }
            }
        }
        let unit = defaultUnit(machine: chosenMachine, gymID: gymID)
        var entry = LiveEntry(id: UUID(), exerciseID: exerciseID, machineID: chosenMachine?.id,
                              freeWeightTag: chosenMachine == nil ? chosenTag : nil,
                              presetID: chosenMachine?.defaultPresetID, sets: [])
        if chosenMachine == nil, chosenTag?.offersBar == true { entry.barWeight = SampleData.defaultBar(for: unit) }
        entry.sets = (0..<max(0, draftCount)).map { _ in LiveSet(id: UUID(), unit: unit) }
        applyPrefill(&entry)
        return entry
    }

    /// The machine last used for this exercise at this gym (still active).
    private func rememberedMachine(exerciseID: UUID, gymID: UUID?) -> Machine? {
        guard let gymID else { return nil }
        for w in history where w.gymID == gymID {
            if let id = w.entries.first(where: { $0.exerciseID == exerciseID && $0.machineID != nil })?.machineID,
               let m = machine(id), !m.isDeleted { return m }
        }
        return nil
    }

    /// Fills untouched drafts from the latest matching workout (type + position); never overwrites typed rows.
    private func applyPrefill(_ entry: inout LiveEntry) {
        for i in entry.sets.indices where !entry.sets[i].isCompleted && (entry.sets[i].state == .empty || entry.sets[i].isPrefilled) {
            let type = entry.sets[i].type
            let ordinal = entry.sets[..<i].filter { $0.type == type }.count
            if let prev = Derived.previousValue(scope: entry.scope, type: type, ordinal: ordinal, history: workouts) {
                entry.sets[i].unit = prev.unit
                entry.sets[i].weight = fieldValue(total: prev.weight, bar: entry.barWeight)
                entry.sets[i].reps = prev.reps
                entry.sets[i].isPrefilled = true
            } else if entry.sets[i].isPrefilled {
                entry.sets[i].weight = nil
                entry.sets[i].reps = nil
                entry.sets[i].isPrefilled = false
            }
        }
    }
    private func fieldValue(total: Double?, bar: Double?) -> Double? {
        guard let total else { return nil }
        guard let bar else { return total }
        return max(0, (total - bar) / 2)
    }

    // MARK: - Live: sets

    /// Adds a row: inherits the last row's type; carries the last completed set forward, else prefills.
    @discardableResult
    func addSet(entryID: UUID) -> UUID? {
        var newID: UUID?
        withEntry(entryID) { entry in
            let unit = entry.sets.last?.unit ?? self.defaultUnit(machine: self.machine(entry.machineID), gymID: self.session?.gymID)
            var set = LiveSet(id: UUID(), type: entry.sets.last?.type ?? .working, unit: unit)
            if let done = entry.sets.last(where: \.isCompleted) {
                set.weight = done.weight
                set.unit = done.unit
                set.reps = done.reps
                set.isPrefilled = true
                entry.sets.append(set)
            } else {
                entry.sets.append(set)
                self.applyPrefill(&entry)
            }
            newID = set.id
        }
        return newID
    }

    /// Ticks a set: returns the new-best outcome and starts rest (not for drop sets,
    /// and inside a superset only after its last member).
    @discardableResult
    func completeSet(entryID: UUID, setID: UUID) -> SetCompletion? {
        guard let s = session, let entry = s.entries.first(where: { $0.id == entryID }),
              let set = entry.sets.first(where: { $0.id == setID }), !set.isCompleted, isLoggable(entry, set) else { return nil }
        let loadType = loadType(of: entry)
        let value = SetValue(weight: loadType.takesWeight ? entry.total(of: set) : nil, unit: set.unit,
                             reps: set.reps ?? 0, bar: entry.barWeight)
        let earlier = s.entries.filter { $0.scope == entry.scope }.flatMap { e in
            e.sets.filter { $0.isCompleted && $0.type.countsTowardRecords }.compactMap { done in
                done.reps.map { SetValue(weight: e.total(of: done), unit: done.unit, reps: $0, bar: e.barWeight) }
            }
        }
        let outcome = Derived.liveOutcome(value: value, type: set.type, loadType: loadType, scope: entry.scope,
                                          history: workouts, sessionEarlier: earlier)
        withEntry(entryID) { e in
            // D23: the first completed set captures the load type this entry keeps.
            if e.snapshotLoadType == nil { e.snapshotLoadType = loadType }
            if let i = e.sets.firstIndex(where: { $0.id == setID }) { e.sets[i].completedAt = self.now }
        }
        var restStarted = false
        if set.type.startsRestTimer {
            if isLastInSuperset(entryID) {
                startRest(entryID: entryID, setID: setID, type: set.type)
                restStarted = true
            } else if rest != nil {
                finishRest(.skipped)
            }
        }
        let completion = SetCompletion(id: UUID(), entryID: entryID, setID: setID,
                                       exerciseName: exercise(entry.exerciseID)?.name ?? "", value: value,
                                       outcome: outcome, restStarted: restStarted, at: now)
        lastCompletion = completion
        return completion
    }

    func uncompleteSet(entryID: UUID, setID: UUID) {
        withEntry(entryID) { e in
            if let i = e.sets.firstIndex(where: { $0.id == setID }) { e.sets[i].completedAt = nil }
            if !e.isFrozen { e.snapshotLoadType = nil }
        }
        if rest?.setID == setID { rest = nil; heartRate.recoveryFrom = nil }
        if lastCompletion?.setID == setID { lastCompletion = nil }
    }
    func deleteSet(entryID: UUID, setID: UUID) {
        withEntry(entryID) { $0.sets.removeAll { $0.id == setID } }
        if rest?.setID == setID { rest = nil; heartRate.recoveryFrom = nil }
    }
    func setType(_ type: SetType, entryID: UUID, setID: UUID) {
        withSet(entryID, setID) { set, _ in set.type = type }
    }
    func updateWeight(_ value: Double?, entryID: UUID, setID: UUID) {
        withSet(entryID, setID) { set, _ in set.weight = value; set.isPrefilled = false }
    }
    func updateReps(_ value: Int?, entryID: UUID, setID: UUID) {
        withSet(entryID, setID) { set, _ in set.reps = value; set.isPrefilled = false }
    }
    /// Relabels one set's unit without converting its number (disabled in bar mode).
    func toggleUnit(entryID: UUID, setID: UUID) {
        withSet(entryID, setID) { set, entry in
            guard !entry.isBarMode else { return }
            set.unit = set.unit.toggled
        }
    }
    /// Relabels every unfinished set of an entry.
    func setUnit(_ unit: WeightUnit, entryID: UUID) {
        withEntry(entryID) { entry in
            guard !entry.isBarMode else { return }
            for i in entry.sets.indices where !entry.sets[i].isCompleted { entry.sets[i].unit = unit }
        }
    }

    /// Bar mode: `weight` = bar (nil = "No bar — enter total weight"). Totals are
    /// preserved (fields convert between total and per side); the bar sets the unit.
    func setBar(_ weight: Double?, unit: WeightUnit? = nil, entryID: UUID) {
        withEntry(entryID) { entry in self.rebar(&entry, to: weight, unit: unit) }
    }
    /// Changes an entry's bar, converting every row's weight FIELD through its total (in bar mode
    /// the field is per side), so a typed 45 bar + 50 per side stays 145 total. Completed rows are
    /// converted too, or their logged totals would silently change.
    private func rebar(_ entry: inout LiveEntry, to bar: Double?, unit: WeightUnit? = nil) {
        let oldBar = entry.barWeight
        for i in entry.sets.indices {
            let total = entry.sets[i].weight.map { w in oldBar.map { $0 + 2 * w } ?? w }
            if let unit, bar != nil, !entry.sets[i].isCompleted { entry.sets[i].unit = unit }
            entry.sets[i].weight = fieldValue(total: total, bar: bar)
        }
        entry.barWeight = bar
    }
    func toggleBarMode(entryID: UUID) {
        guard let entry = liveEntry(entryID) else { return }
        if entry.isBarMode { setBar(nil, entryID: entryID) } else {
            let unit = entry.sets.last?.unit ?? displayUnit
            setBar(SampleData.defaultBar(for: unit), unit: unit, entryID: entryID)
        }
    }

    // MARK: - Live: equipment, preset, supersets, order

    /// Equipment sheet: a machine, or a free-weight tag. After a completed set the
    /// entry is frozen and the change continues in a new entry (history stays split).
    /// On a frozen entry the chosen preset follows into the new entry; otherwise the new
    /// machine's usual preset is preselected (D38). Weights convert through totals when the
    /// bar appears or goes (typed totals are kept; prefilled rows are re-prefilled).
    func chooseEquipment(machineID: UUID?, tag: EquipmentTag?, entryID: UUID) {
        let frozen = liveEntry(entryID)?.isFrozen ?? false
        changeEntry(entryID) { entry in
            entry.machineID = machineID
            entry.freeWeightTag = machineID == nil ? tag : nil
            let m = self.machine(machineID)
            if let m, !frozen { entry.presetID = m.defaultPresetID ?? entry.presetID }
            let unit = self.defaultUnit(machine: m, gymID: self.session?.gymID)
            let barred = machineID == nil ? (tag?.offersBar ?? false) : self.model(m?.modelID)?.category == .rackOrSmith
            self.rebar(&entry, to: barred ? (entry.barWeight ?? SampleData.defaultBar(for: unit)) : nil)
            for i in entry.sets.indices where entry.sets[i].state != .typed { entry.sets[i].unit = unit }
        }
    }
    /// Preset chip. Frozen entries split, like equipment.
    func choosePreset(_ presetID: UUID?, entryID: UUID) {
        changeEntry(entryID) { $0.presetID = presetID }
    }
    /// D51: switch to the dumbbell counterpart exercise.
    func logAsCounterpart(entryID: UUID) {
        guard let entry = liveEntry(entryID), let target = dumbbellCounterpart(of: entry.exerciseID) else { return }
        changeEntry(entryID) { e in
            e.exerciseID = target.id
            e.machineID = nil
            e.freeWeightTag = .dumbbell
            e.presetID = nil
            self.rebar(&e, to: nil)  // per-side fields become totals
        }
    }

    private func changeEntry(_ entryID: UUID, _ change: @escaping (inout LiveEntry) -> Void) {
        guard let entry = liveEntry(entryID) else { return }
        if entry.isFrozen {
            // Frozen: the change continues in a new entry right after, taking the unfinished rows.
            // It stays in the superset (D48: rest still waits for the run's last member) and
            // keeps the planned rest; it gets its own load-type snapshot at its first completion.
            var next = LiveEntry(id: UUID(), exerciseID: entry.exerciseID, machineID: entry.machineID,
                                 freeWeightTag: entry.freeWeightTag, presetID: entry.presetID,
                                 supersetGroup: entry.supersetGroup, barWeight: entry.barWeight,
                                 sets: entry.sets.filter { !$0.isCompleted }, plannedRestSeconds: entry.plannedRestSeconds)
            if next.sets.isEmpty { next.sets = [LiveSet(id: UUID(), unit: entry.sets.last?.unit ?? displayUnit)] }
            change(&next)
            applyPrefill(&next)
            withSession { s in
                guard let i = s.entries.firstIndex(where: { $0.id == entryID }) else { return }
                s.entries[i].sets.removeAll { !$0.isCompleted }
                s.entries.insert(next, at: i + 1)
                self.pruneSupersets(&s)
            }
        } else {
            withEntry(entryID) { e in
                change(&e)
                self.applyPrefill(&e)
            }
        }
    }

    func supersetWithNext(entryID: UUID) {
        withSession { s in
            guard let i = s.entries.firstIndex(where: { $0.id == entryID }), i + 1 < s.entries.count else { return }
            let group = s.entries[i].supersetGroup ?? s.entries[i + 1].supersetGroup ?? UUID()
            s.entries[i].supersetGroup = group
            s.entries[i + 1].supersetGroup = group
        }
    }
    func breakSuperset(entryID: UUID) {
        guard let group = liveEntry(entryID)?.supersetGroup else { return }
        withSession { s in
            for i in s.entries.indices where s.entries[i].supersetGroup == group { s.entries[i].supersetGroup = nil }
        }
    }
    /// Deletes the exercise and its rows.
    func removeExercise(entryID: UUID) {
        withSession { s in
            s.entries.removeAll { $0.id == entryID }
            self.pruneSupersets(&s)
        }
        if rest?.entryID == entryID { rest = nil; heartRate.recoveryFrom = nil }
    }
    /// Drag to reorder (List.onMove semantics).
    func moveEntries(fromOffsets source: IndexSet, toOffset destination: Int) {
        withSession { s in
            let moving = source.sorted().map { s.entries[$0] }
            let target = destination - source.filter { $0 < destination }.count
            for i in source.sorted(by: >) { s.entries.remove(at: i) }
            s.entries.insert(contentsOf: moving, at: min(target, s.entries.count))
            self.pruneSupersets(&s)
        }
    }
    /// Blank clears back to the derived title.
    func renameWorkout(_ name: String?) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        withSession { $0.name = (trimmed?.isEmpty ?? true) ? nil : trimmed }
    }

    private func supersetRun(_ entryID: UUID) -> [UUID]? {
        guard let s = session, let i = s.entries.firstIndex(where: { $0.id == entryID }),
              let group = s.entries[i].supersetGroup else { return nil }
        var start = i, end = i
        while start > 0, s.entries[start - 1].supersetGroup == group { start -= 1 }
        while end + 1 < s.entries.count, s.entries[end + 1].supersetGroup == group { end += 1 }
        return s.entries[start...end].map(\.id)
    }
    private func isLastInSuperset(_ entryID: UUID) -> Bool {
        guard let run = supersetRun(entryID), run.count > 1 else { return true }
        return run.last == entryID
    }
    private func pruneSupersets(_ s: inout LiveSession) {
        for i in s.entries.indices {
            guard let group = s.entries[i].supersetGroup else { continue }
            let prev = i > 0 && s.entries[i - 1].supersetGroup == group
            let next = i + 1 < s.entries.count && s.entries[i + 1].supersetGroup == group
            if !prev && !next { s.entries[i].supersetGroup = nil }
        }
    }

    // MARK: - Rest

    /// Per-exercise rest settings, with the global defaults filled in.
    func restSettings(for exerciseID: UUID) -> RestSettings {
        restOverrides[exerciseID] ?? RestSettings()
    }
    func setRestSettings(_ value: RestSettings, for exerciseID: UUID) { restOverrides[exerciseID] = value }

    /// Override → template planned rest (working only) → global (warmup / working; failure uses working).
    func restSeconds(entryID: UUID, type: SetType) -> Int {
        let entry = liveEntry(entryID)
        let override = entry.flatMap { restOverrides[$0.exerciseID] }
        if type == .warmup { return override?.warmupSeconds ?? settings.warmupRestSeconds }
        return override?.workingSeconds ?? entry?.plannedRestSeconds ?? settings.workingRestSeconds
    }
    private func setType(entryID: UUID, setID: UUID) -> SetType {
        liveEntry(entryID)?.sets.first { $0.id == setID }?.type ?? .working
    }

    private func startRest(entryID: UUID, setID: UUID, type: SetType) {
        guard let entry = liveEntry(entryID) else { return }
        let seconds = restSeconds(entryID: entryID, type: type)
        let options = restSettings(for: entry.exerciseID)
        heartRate.recoveryFrom = max(currentBPM ?? 132, 128)
        heartRate.recoveryStart = now
        if options.mode == .heartRate {
            if case .live = hrFeed {
                rest = RestState(entryID: entryID, setID: setID, startedAt: now,
                                 endsAt: now.addingTimeInterval(TimeInterval(options.capSeconds)),
                                 totalSeconds: options.capSeconds, mode: .heartRate, thresholdBpm: options.thresholdBpm)
            } else {
                rest = RestState(entryID: entryID, setID: setID, startedAt: now,
                                 endsAt: now.addingTimeInterval(TimeInterval(seconds)), totalSeconds: seconds,
                                 mode: .timer, isDegraded: true)
            }
        } else {
            rest = RestState(entryID: entryID, setID: setID, startedAt: now,
                             endsAt: now.addingTimeInterval(TimeInterval(seconds)), totalSeconds: seconds, mode: .timer)
        }
    }
    /// "+15s"
    func addRest(seconds: Int = 15) {
        guard var r = rest else { return }
        r.endsAt = r.endsAt.addingTimeInterval(TimeInterval(seconds))
        r.totalSeconds += seconds
        rest = r
    }
    func skipRest() { if rest != nil { finishRest(.skipped) } }

    // MARK: - Heart-rate sensor (prototype toggle)

    /// live = readings every second; stale = the feed freezes (stale after 15 s); none = no sensor.
    func setSensor(_ mode: SensorMode) {
        heartRate.mode = mode
        switch mode {
        case .live:
            heartRate.bpm = HRScript.bpm(step: heartRate.scriptStep)
            heartRate.lastSampleAt = now
            heartRate.level = nil
        case .stale:
            if heartRate.bpm == nil { heartRate.bpm = 124 }
            heartRate.lastSampleAt = now.addingTimeInterval(-(HeartRateState.staleAfter + 3))
        case .none:
            heartRate.bpm = nil
            heartRate.lastSampleAt = nil
        }
        evaluateRest()
    }

    // MARK: - Cardio

    func pauseCardio() {
        withSession { s in
            guard let i = s.cardio.firstIndex(where: \.isRunning) else { return }
            s.cardio[i].accumulatedSeconds += self.now.timeIntervalSince(s.cardio[i].runningSince ?? self.now)
            s.cardio[i].runningSince = nil
            s.cardio[i].currentSpeed = nil
        }
    }
    func resumeCardio() {
        withSession { s in
            guard let i = s.cardio.firstIndex(where: \.isPaused) else { return }
            s.cardio[i].runningSince = self.now
            if s.cardio[i].activity.isOutdoor {
                // A new GPS portion: the route never joins across a pause.
                s.cardio[i].gps = self.gpsUnavailable ? .unavailable : .waiting
                s.cardio[i].gpsWaitFrom = s.cardio[i].accumulatedSeconds
                if !s.cardio[i].route.isEmpty { s.cardio[i].routePortion += 1 }
            }
        }
    }
    /// Prototype toggle: GPS lost / back. While unavailable the outdoor segment shows
    /// "Location unavailable.", time keeps recording, distance and route stop; when it comes
    /// back it waits for a fix and starts a new route portion.
    func setGPSUnavailable(_ unavailable: Bool) {
        gpsUnavailable = unavailable
        withSession { s in
            guard let i = s.cardio.firstIndex(where: { !$0.isEnded && $0.activity.isOutdoor }) else { return }
            if unavailable {
                s.cardio[i].gps = .unavailable
                s.cardio[i].currentSpeed = nil
            } else if s.cardio[i].gps == .unavailable {
                s.cardio[i].gps = .waiting
                s.cardio[i].gpsWaitFrom = Double(s.cardio[i].activeSeconds(at: self.now))
                if !s.cardio[i].route.isEmpty { s.cardio[i].routePortion += 1 }
            }
        }
    }
    /// Ends the unfinished segment (no confirmation, like the real app).
    func endCardio() {
        withSession { s in
            guard let i = s.cardio.firstIndex(where: { !$0.isEnded }) else { return }
            self.end(&s.cardio[i])
        }
    }
    private func end(_ c: inout LiveCardio) {
        if let since = c.runningSince { c.accumulatedSeconds += now.timeIntervalSince(since) }
        c.runningSince = nil
        c.endedAt = now
        c.currentSpeed = nil
    }
    /// Starts a planned target as a linked segment (switches to cardio focus, skips rest).
    func startPlannedCardio(_ plannedID: UUID) {
        guard let plan = session?.plannedCardio.first(where: { $0.id == plannedID }) else { return }
        startCardio(activity: plan.activity, plannedID: plannedID)
    }
    /// Manual distance for a live segment (nil clears it back to the measured distance).
    func setManualDistance(_ value: Double?, unit: DistanceUnit, segmentID: UUID) {
        if session?.cardio.contains(where: { $0.id == segmentID }) == true {
            withSession { s in
                guard let i = s.cardio.firstIndex(where: { $0.id == segmentID }) else { return }
                s.cardio[i].manualDistance = value
                s.cardio[i].unit = unit
            }
            return
        }
        // A finished workout's segment: an edit (stamps Edited).
        editWorkout(containingSegment: segmentID) { w in
            guard let i = w.cardio.firstIndex(where: { $0.id == segmentID }) else { return }
            w.cardio[i].manualDistance = value
            w.cardio[i].unit = unit
        }
        if var summary = finishSummary, let i = summary.cardio.firstIndex(where: { $0.id == segmentID }),
           let w = workout(summary.workoutID) {
            summary.cardio[i] = w.cardio.first { $0.id == segmentID } ?? summary.cardio[i]
            finishSummary = summary
        }
    }

    // MARK: - Cancel and finish

    /// "Discard Workout": deletes everything logged in it.
    func cancelWorkout() {
        session = nil
        rest = nil
        isSessionPresented = false
        lastCompletion = nil
        pendingStart = nil
        pendingReplacementDrift = nil
        heartRate.recoveryFrom = nil
    }

    /// Finishes: drops unticked rows and empty entries, saves to history (or not,
    /// when nothing was logged), builds the receipt and detects template drift.
    @discardableResult
    func finish() -> FinishSummary { finishSession(promptDrift: true).summary }

    private func finishSession(promptDrift: Bool) -> (summary: FinishSummary, saved: Workout?) {
        guard let s = session else { return (Derived.notSavedSummary(at: now), nil) }
        defer {
            session = nil
            rest = nil
            isSessionPresented = false
            lastCompletion = nil
            pendingReplacementDrift = nil
            heartRate.recoveryFrom = nil
        }
        guard let workout = workout(from: s) else {
            let summary = Derived.notSavedSummary(at: now)
            finishSummary = summary
            return (summary, nil)
        }
        workouts.append(workout)
        let summary = summaryFor(workout)
        finishSummary = summary
        if promptDrift, let t = template(s.templateID), !settings.suppressTemplatePrompts {
            pendingDrift = Derived.drift(template: t, workout: workout, exercises: exerciseByID)
        }
        return (summary, workout)
    }

    /// The workout a session would save if it finished now (nil = nothing logged). Unfinished
    /// cardio ends at `now`; each entry keeps its D23 load-type snapshot.
    private func workout(from session: LiveSession) -> Workout? {
        var s = session
        for i in s.cardio.indices where !s.cardio[i].isEnded { end(&s.cardio[i]) }
        let gym = gym(s.gymID)
        let entries: [WorkoutEntry] = s.entries.compactMap { live in
            let done = live.sets.filter(\.isCompleted)
            guard !done.isEmpty, let ex = exercise(live.exerciseID) else { return nil }
            let m = machine(live.machineID)
            let loadType = live.snapshotLoadType ?? ex.loadType
            return WorkoutEntry(
                id: live.id, exerciseID: ex.id, exerciseName: ex.name, loadType: loadType, machineID: m?.id,
                machineLabel: m?.label, modelName: modelName(of: m), freeWeightTag: m == nil ? live.freeWeightTag : nil,
                presetID: live.presetID, presetName: ex.presets.first { $0.id == live.presetID }?.name,
                supersetGroup: live.supersetGroup,
                sets: done.map { set in
                    LoggedSet(id: set.id, type: set.type, weight: loadType.takesWeight ? live.total(of: set) : nil,
                              unit: set.unit, reps: set.reps, barWeight: live.barWeight, completedAt: set.completedAt ?? now)
                })
        }
        let segments: [CardioSegment] = s.cardio.compactMap { c in
            let active = c.activeSeconds(at: c.endedAt ?? now)
            guard active > 0 else { return nil }
            return CardioSegment(id: c.id, activity: c.activity, startedAt: c.startedAt, activeSeconds: active,
                                 measuredMeters: c.measuredMeters > 0 ? c.measuredMeters : nil,
                                 manualDistance: c.manualDistance, unit: c.unit, averageHeartRate: c.averageHeartRate,
                                 maxHeartRate: c.maxHeartRate, activeCalories: c.activeCalories > 0 ? Int(c.activeCalories) : nil,
                                 route: c.route, plannedID: c.plannedID)
        }
        guard !entries.isEmpty || !segments.isEmpty else { return nil }
        var log = s.heartRate
        if log.bucketCount > 0 { log.closeBucket() }
        let duration = max(1, Int(now.timeIntervalSince(s.startedAt)))
        let hr: HeartRateSummary? = log.average.map { avg in
            HeartRateSummary(average: avg, maximum: log.maximum, zoneSeconds: maxHeartRate != nil ? log.zoneSeconds : [],
                             series: HeartRateSeries(mean: log.mean, low: log.low, high: log.high), source: heartRate.source)
        }
        let active = s.activeCalories >= 1 ? Int(s.activeCalories) : nil
        return Workout(
            id: s.id, name: s.name, templateID: s.templateID, templateName: s.templateName, startedAt: s.startedAt,
            durationSeconds: duration, gymID: gym?.id, gymName: gym?.name, entries: entries, cardio: segments,
            heartRate: hr, activeCalories: active, basalCalories: active.map { _ in Int(Double(duration) / 60 * 1.65) })
    }

    private func summaryFor(_ workout: Workout) -> FinishSummary {
        Derived.finishSummary(for: workout, history: workouts, exercises: exerciseByID, unit: displayUnit,
                              maxHeartRate: maxHeartRate)
    }
    /// The receipt for any finished workout (e.g. to re-show it).
    func finishSummary(workoutID: UUID) -> FinishSummary? { workout(workoutID).map(summaryFor) }
    func dismissFinish() { finishSummary = nil }

    /// Applies a drift resolution; `dontAskAgain` turns template prompts off in Settings.
    func resolveDrift(_ resolution: DriftResolution, dontAskAgain: Bool = false) {
        defer { pendingDrift = nil }
        if dontAskAgain { settings.suppressTemplatePrompts = true }
        guard let drift = pendingDrift, let w = workout(drift.workoutID),
              let i = templates.firstIndex(where: { $0.id == drift.templateID }) else { return }
        templates[i] = Derived.resolve(resolution, template: templates[i], workout: w)
    }
    func dismissDrift() { pendingDrift = nil }

    /// "Workout Sep 24, 2026"
    func defaultTemplateName(workoutID: UUID) -> String {
        "Workout \(Format.mediumDate(workout(workoutID)?.startedAt ?? now))"
    }
    func canSaveAsTemplate(workoutID: UUID) -> Bool {
        guard let w = workout(workoutID) else { return false }
        return w.setCount > 0 || w.hasCardio
    }
    /// Saves a workout's completed structure as a template; nil when the name is blank or nothing was logged.
    @discardableResult
    func saveAsTemplate(workoutID: UUID, name: String) -> UUID? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, canSaveAsTemplate(workoutID: workoutID), let w = workout(workoutID) else { return nil }
        let t = Derived.template(from: w, name: trimmed)
        templates.append(t)
        return t.id
    }

    // MARK: - Templates

    /// An empty template to edit in a New Template sheet (not stored until `saveTemplate`).
    func newTemplateDraft() -> Template { Template(id: UUID(), name: "", items: []) }
    /// Inserts or replaces by id.
    func saveTemplate(_ template: Template) {
        if let i = templates.firstIndex(where: { $0.id == template.id }) { templates[i] = template } else { templates.append(template) }
    }
    func deleteTemplate(_ id: UUID) { templates.removeAll { $0.id == id } }
    /// A new template item for an editor (3 × 10 by default).
    func newTemplateItem(exerciseID: UUID) -> TemplateItem {
        TemplateItem(id: UUID(), exerciseID: exerciseID, targetReps: [10, 10, 10], restSeconds: nil)
    }

    // MARK: - Gyms and machines

    func selectGym(_ id: UUID?) { selectedGymID = id }
    @discardableResult
    func addGym(name: String, city: String?, unit: WeightUnit?, select: Bool = false) -> UUID {
        let city = city?.trimmingCharacters(in: .whitespaces)
        let gym = Gym(id: UUID(), name: name.trimmingCharacters(in: .whitespaces),
                      city: (city?.isEmpty ?? true) ? nil : city, defaultUnit: unit)
        gyms.append(gym)
        if select { selectedGymID = gym.id }
        return gym.id
    }
    func updateGym(_ gym: Gym) {
        if let i = gyms.firstIndex(where: { $0.id == gym.id }) { gyms[i] = gym }
    }
    /// "Delete" (history keeps the snapshot name).
    func deleteGym(_ id: UUID) {
        if let i = gyms.firstIndex(where: { $0.id == id }) { gyms[i].isDeleted = true }
        if selectedGymID == id { selectedGymID = nil }
    }
    func restoreGym(_ id: UUID) {
        if let i = gyms.firstIndex(where: { $0.id == id }) { gyms[i].isDeleted = false }
    }

    @discardableResult
    func addMachine(gymID: UUID, label: String, modelID: UUID? = nil, exerciseIDs: [UUID] = [],
                    unit: WeightUnit? = nil, presetID: UUID? = nil) -> UUID {
        let m = Machine(id: UUID(), gymID: gymID, label: label.trimmingCharacters(in: .whitespaces), modelID: modelID,
                        recognizedExerciseIDs: model(modelID)?.exerciseIDs.isEmpty == false ? [] : exerciseIDs,
                        defaultUnit: unit, defaultPresetID: presetID)
        machines.append(m)
        return m.id
    }
    func updateMachine(_ machine: Machine) {
        if let i = machines.firstIndex(where: { $0.id == machine.id }) { machines[i] = machine }
    }
    /// "It disappears from this gym. Workouts you already logged with it keep it."
    func deleteMachine(_ id: UUID) {
        if let i = machines.firstIndex(where: { $0.id == id }) { machines[i].isDeleted = true; machines[i].deletedAt = now }
    }
    func restoreMachine(_ id: UUID) {
        if let i = machines.firstIndex(where: { $0.id == id }) { machines[i].isDeleted = false; machines[i].deletedAt = nil }
    }
    /// Past workouts and sets logged on a machine (the Correct Model decision).
    func correctionImpact(machineID: UUID) -> (workouts: Int, sets: Int) {
        let pairs = workouts.flatMap { w in w.entries.filter { $0.machineID == machineID }.map { (w.id, $0) } }
        return (Set(pairs.map(\.0)).count, pairs.reduce(0) { $0 + $1.1.sets.count })
    }
    /// Correct Model: future only, or also rewrite this machine's past snapshots.
    func correctModel(machineID: UUID, to modelID: UUID?, scope: CorrectionScope) {
        guard let i = machines.firstIndex(where: { $0.id == machineID }) else { return }
        machines[i].modelID = modelID
        guard scope == .applyToPast else { return }
        let name = model(modelID)?.displayName
        for w in workouts.indices {
            for e in workouts[w].entries.indices where workouts[w].entries[e].machineID == machineID {
                workouts[w].entries[e].modelName = name
            }
        }
    }
    /// New Model (user-made, alongside the catalog).
    @discardableResult
    func addModel(manufacturer: String, modelName: String, category: EquipmentCategory?, exerciseIDs: [UUID]) -> UUID {
        let m = EquipmentModel(id: UUID(), manufacturer: manufacturer, modelName: modelName, category: category,
                               exerciseIDs: exerciseIDs, isSeeded: false)
        models.append(m)
        return m.id
    }
    /// "Rename Model" (user-made models only; the menu item is hidden for catalog models).
    /// Blank fields or a catalog model are refused (false). History keeps the captured name.
    @discardableResult
    func renameModel(_ modelID: UUID, manufacturer: String, modelName: String) -> Bool {
        let maker = manufacturer.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !maker.isEmpty, !name.isEmpty, let i = models.firstIndex(where: { $0.id == modelID }),
              !models[i].isSeeded else { return false }
        models[i].manufacturer = maker
        models[i].modelName = name
        return true
    }

    /// New Model › "Suggest exercises with AI" (simulated ≈ 1.5 s). Without model-details
    /// consent it only sets `.needsConsent` — show "Send model details to OpenAI?", then call
    /// `allowModelDetailsAndSuggest`. Ends `.suggested` (tick those rows), `.empty` or `.failed`.
    func suggestModelExercises(manufacturer: String, modelName: String) {
        guard settings.modelDetailsConsent else { modelSuggest = .needsConsent; return }
        modelSuggestTask?.cancel()
        modelSuggest = .asking
        let catalog = exercises
        let failing = modelSuggestSimulateFailure
        modelSuggestTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(ModelSuggestSimulator.duration))
            guard let self, !Task.isCancelled, self.modelSuggest == .asking else { return }
            if failing { self.modelSuggest = .failed(AISimulator.failureMessage); return }
            let picks = ModelSuggestSimulator.suggest(manufacturer: manufacturer, modelName: modelName, exercises: catalog)
            self.modelSuggest = picks.isEmpty ? .empty : .suggested(picks)
        }
    }
    /// Consent alert › "Allow and send".
    func allowModelDetailsAndSuggest(manufacturer: String, modelName: String) {
        setConsent(.modelDetails, true)
        suggestModelExercises(manufacturer: manufacturer, modelName: modelName)
    }
    /// Cancel / dismiss (also the consent alert's Cancel): abandons the request.
    func cancelModelSuggestion() {
        modelSuggestTask?.cancel()
        modelSuggest = .idle
    }
    func modelSuggestSetSimulateFailure(_ on: Bool) { modelSuggestSimulateFailure = on }

    // MARK: - Exercises

    @discardableResult
    func createExercise(name: String, loadType: LoadType, muscleGroup: MuscleGroup?, tags: [EquipmentTag]) -> UUID {
        let ex = Exercise(id: UUID(), name: name.trimmingCharacters(in: .whitespaces), loadType: loadType,
                          muscleGroup: muscleGroup, tags: tags, isSeeded: false)
        exercises.append(ex)
        return ex.id
    }
    func renameExercise(_ exerciseID: UUID, to name: String) {
        if let i = exercises.firstIndex(where: { $0.id == exerciseID }) { exercises[i].name = name }
    }
    /// Future sets only; history keeps each entry's snapshot load type, and a live entry that
    /// already has a completed set keeps its D23 snapshot (the change applies to new entries).
    func setLoadType(_ loadType: LoadType, exerciseID: UUID) {
        if let i = exercises.firstIndex(where: { $0.id == exerciseID }) { exercises[i].loadType = loadType }
    }
    /// Adds a preset (case-insensitive duplicates refused → nil).
    @discardableResult
    func addPreset(name: String, exerciseID: UUID) -> UUID? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let i = exercises.firstIndex(where: { $0.id == exerciseID }),
              !exercises[i].presets.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return nil }
        let preset = ExercisePreset(id: UUID(), name: trimmed)
        exercises[i].presets.append(preset)
        return preset.id
    }
    /// Renames a preset; blank or a case-insensitive duplicate of another preset is refused (false).
    @discardableResult
    func renamePreset(_ presetID: UUID, to name: String, exerciseID: UUID) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let i = exercises.firstIndex(where: { $0.id == exerciseID }),
              let p = exercises[i].presets.firstIndex(where: { $0.id == presetID }),
              !exercises[i].presets.contains(where: { $0.id != presetID && $0.name.caseInsensitiveCompare(trimmed) == .orderedSame })
        else { return false }
        exercises[i].presets[p].name = trimmed
        return true
    }
    func deletePreset(_ presetID: UUID, exerciseID: UUID) {
        guard let i = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        exercises[i].presets.removeAll { $0.id == presetID }
    }

    // MARK: - History editing (every edit stamps "Edited")

    private func editWorkout(_ id: UUID, _ change: (inout Workout) -> Void) {
        guard let i = workouts.firstIndex(where: { $0.id == id }) else { return }
        change(&workouts[i])
        workouts[i].editedAt = now
    }
    private func editWorkout(containingSegment segmentID: UUID, _ change: (inout Workout) -> Void) {
        guard let w = workouts.first(where: { $0.cardio.contains { $0.id == segmentID } }) else { return }
        editWorkout(w.id, change)
    }
    func updateLoggedSet(_ set: LoggedSet, workoutID: UUID) {
        editWorkout(workoutID) { w in
            for e in w.entries.indices {
                if let s = w.entries[e].sets.firstIndex(where: { $0.id == set.id }) { w.entries[e].sets[s] = set }
            }
        }
    }
    func deleteLoggedSet(_ setID: UUID, workoutID: UUID) {
        editWorkout(workoutID) { w in
            for e in w.entries.indices { w.entries[e].sets.removeAll { $0.id == setID } }
        }
    }
    /// Adds a set to a past entry (copies the last one).
    @discardableResult
    func addLoggedSet(workoutID: UUID, entryID: UUID) -> UUID? {
        var newID: UUID?
        editWorkout(workoutID) { w in
            guard let e = w.entries.firstIndex(where: { $0.id == entryID }) else { return }
            let last = w.entries[e].sets.last
            let set = LoggedSet(id: UUID(), type: last?.type ?? .working, weight: last?.weight, unit: last?.unit ?? self.displayUnit,
                                reps: last?.reps, barWeight: last?.barWeight,
                                completedAt: (last?.completedAt ?? w.startedAt).addingTimeInterval(60))
            w.entries[e].sets.append(set)
            newID = set.id
        }
        return newID
    }
    /// Adds an exercise to a past workout (no equipment guessed).
    func addExerciseToWorkout(workoutID: UUID, exerciseID: UUID) {
        guard let ex = exercise(exerciseID) else { return }
        editWorkout(workoutID) { w in
            w.entries.append(WorkoutEntry(id: UUID(), exerciseID: ex.id, exerciseName: ex.name, loadType: ex.loadType,
                                          sets: []))
        }
    }
    func removeEntry(_ entryID: UUID, workoutID: UUID) {
        editWorkout(workoutID) { $0.entries.removeAll { $0.id == entryID } }
    }
    /// D47: the entry's load-type menu re-types its snapshot (records re-rank; stamps Edited).
    /// Logged values are kept as entered.
    func retypeEntry(_ entryID: UUID, to loadType: LoadType, workoutID: UUID) {
        guard let entry = workout(workoutID)?.entries.first(where: { $0.id == entryID }), entry.loadType != loadType else { return }
        editWorkout(workoutID) { w in
            guard let e = w.entries.firstIndex(where: { $0.id == entryID }) else { return }
            w.entries[e].loadType = loadType
        }
    }
    func renameHistoryWorkout(_ workoutID: UUID, to name: String?) {
        let trimmed = name?.trimmingCharacters(in: .whitespaces)
        editWorkout(workoutID) { $0.name = (trimmed?.isEmpty ?? true) ? nil : trimmed }
    }
    func setNotes(_ notes: String, workoutID: UUID) { editWorkout(workoutID) { $0.notes = notes } }
    func deleteWorkout(_ workoutID: UUID) { workouts.removeAll { $0.id == workoutID } }
    /// What a delete destroys (for the confirm dialog).
    func deleteImpact(workoutID: UUID) -> (exercises: Int, sets: Int, volumeKg: Double) {
        guard let w = workout(workoutID) else { return (0, 0, 0) }
        return (w.entries.count, w.setCount, Derived.volumeKg(of: w))
    }

    // MARK: - Ask AI for Templates

    /// Opens the flow at step 1 for a gym (default: Home's gym).
    func aiBegin(gymID: UUID? = nil) {
        aiTask?.cancel()
        ai = AIRoutineFlow()
        ai.request.gymID = gymID ?? selectedGymID
        ai.request.consent = settings.routineConsent
    }
    /// Edits the request (goals text, steppers, toggles, consent).
    func aiUpdateRequest(_ change: (inout AIRoutineRequest) -> Void) {
        change(&ai.request)
        if ai.request.consent != settings.routineConsent { settings.routineConsent = ai.request.consent }
    }
    /// Exercises the AI may use: machines at the chosen gym + toggled equipment.
    var aiEligibleExerciseIDs: Set<UUID> {
        var ids = Set(activeMachines(gymID: ai.request.gymID).flatMap { exerciseIDs(of: $0) })
        let tags = Set(ai.request.equipment.flatMap(\.tags))
        for ex in exercises where ex.isSeeded && !Set(ex.tags).isDisjoint(with: tags) { ids.insert(ex.id) }
        return ids
    }
    var aiMachineCount: Int { activeMachines(gymID: ai.request.gymID).count }
    /// Generate is enabled: consent, goals, and something to use.
    var aiCanGenerate: Bool {
        ai.request.consent && ai.request.hasGoals && (!aiEligibleExerciseIDs.isEmpty || !ai.request.cardio.isEmpty)
    }
    func aiNext() {
        switch ai.step {
        case .goals where ai.request.hasGoals: ai.step = .equipment
        case .equipment: aiGenerate()
        default: break
        }
    }
    func aiBack() {
        switch ai.step {
        case .equipment: ai.step = .goals
        case .generating: aiCancelGeneration()
        case .error, .preview: ai.step = .equipment
        default: break
        }
    }
    /// ≈ 3 s with staged progress text, then the week preview (or the error step).
    func aiGenerate(resumeFrom progress: Double = 0) {
        guard aiCanGenerate else { return }
        aiTask?.cancel()
        ai.step = .generating
        ai.error = nil
        ai.progress = progress
        if progress == 0 { ai.progressText = AISimulator.stages(gymName: gym(ai.request.gymID)?.name)[0].text }
        let gymName = gym(ai.request.gymID)?.name
        aiTask = Task { [weak self] in
            do {
                try await AISimulator.run(gymName: gymName, from: progress) { p, text in
                    self?.ai.progress = p
                    self?.ai.progressText = text
                }
                self?.aiFinishGeneration()
            } catch {}
        }
    }
    private func aiFinishGeneration() {
        guard ai.step == .generating else { return }
        ai.progress = 1
        if ai.simulateFailure {
            ai.error = AISimulator.failureMessage
            ai.step = .error
        } else {
            ai.days = SampleData.aiWeek(days: ai.request.daysPerWeek, available: aiEligibleExerciseIDs,
                                        cardio: ai.request.cardio, unit: settings.distanceUnit)
            ai.step = .preview
        }
    }
    func aiCancelGeneration() {
        aiTask?.cancel()
        ai.step = .equipment
        ai.progress = 0
    }
    /// Prototype switch: the next generation fails with real error copy.
    func aiSetSimulateFailure(_ on: Bool) { ai.simulateFailure = on }
    /// "Change preferences": discards the generated week.
    func aiChangePreferences() {
        ai.days = []
        ai.error = nil
        ai.step = .goals
    }
    func aiUpdateDay(_ day: AIRoutineDay) {
        if let i = ai.days.firstIndex(where: { $0.id == day.id }) { ai.days[i] = day }
    }
    /// Adds an exercise to a day (3 × 10, 60 s; at most 10, no repeats).
    func aiAddItem(dayID: UUID, exerciseID: UUID) {
        guard let i = ai.days.firstIndex(where: { $0.id == dayID }), ai.days[i].items.count < 10,
              !ai.days[i].items.contains(where: { $0.exerciseID == exerciseID }) else { return }
        ai.days[i].items.append(AIRoutineItem(id: UUID(), exerciseID: exerciseID, sets: 3, reps: 10, restSeconds: 60))
    }
    func aiRemoveItem(dayID: UUID, itemID: UUID) {
        if let i = ai.days.firstIndex(where: { $0.id == dayID }) { ai.days[i].items.removeAll { $0.id == itemID } }
    }
    func aiMoveItem(dayID: UUID, fromOffsets source: IndexSet, toOffset destination: Int) {
        guard let d = ai.days.firstIndex(where: { $0.id == dayID }) else { return }
        var items = ai.days[d].items
        let moving = source.sorted().map { items[$0] }
        let target = destination - source.filter { $0 < destination }.count
        for i in source.sorted(by: >) { items.remove(at: i) }
        items.insert(contentsOf: moving, at: min(target, items.count))
        ai.days[d].items = items
    }
    /// Adds a 15-minute cardio block (at most 3).
    func aiAddCardio(dayID: UUID, activity: CardioActivity) {
        guard let i = ai.days.firstIndex(where: { $0.id == dayID }), ai.days[i].cardio.count < 3 else { return }
        ai.days[i].cardio.append(PlannedCardio(id: UUID(), activity: activity, minutes: 15, distance: nil, unit: settings.distanceUnit))
    }
    func aiRemoveCardio(dayID: UUID, cardioID: UUID) {
        if let i = ai.days.firstIndex(where: { $0.id == dayID }) { ai.days[i].cardio.removeAll { $0.id == cardioID } }
    }
    /// Saves every session as a template, atomically. Returns the new ids (empty on a validation error).
    @discardableResult
    func aiSave() -> [UUID] {
        let valid = ai.days.allSatisfy { day in
            !day.name.trimmingCharacters(in: .whitespaces).isEmpty && (!day.items.isEmpty || !day.cardio.isEmpty)
                && Set(day.items.map(\.exerciseID)).count == day.items.count && day.items.count <= 10 && day.cardio.count <= 3
        }
        guard valid, !ai.days.isEmpty else {
            ai.error = "Each session needs a name, at least one activity, and no repeated strength exercise (up to 10 exercises and 3 cardio targets)."
            return []
        }
        let gymID = ai.request.gymID ?? selectedGymID
        let new = ai.days.map { day in
            Template(id: UUID(), name: day.name,
                     items: day.items.map { TemplateItem(id: UUID(), exerciseID: $0.exerciseID,
                                                         targetReps: Array(repeating: $0.reps, count: $0.sets),
                                                         restSeconds: $0.restSeconds) },
                     cardio: day.cardio, generatedForGymID: gymID)
        }
        templates.append(contentsOf: new)
        ai.savedTemplateIDs = new.map(\.id)
        ai.error = nil
        ai.step = .saved
        return ai.savedTemplateIDs
    }

    // MARK: - Scan

    func scanBegin(gymID: UUID? = nil) {
        scanTask?.cancel()
        let kind = scan.demoKind
        let failing = scan.simulateFailure
        scan = ScanFlow(step: .camera, gymID: gymID ?? selectedGymID, demoKind: kind)
        scan.simulateFailure = failing
    }
    /// Prototype switch: the next identification fails (`.error` with real copy).
    func scanSetSimulateFailure(_ on: Bool) { scan.simulateFailure = on }
    /// Which result kind the next identification returns (prototype control).
    func scanSetDemoKind(_ kind: ScanKind) { scan.demoKind = kind }
    func scanToggleTorch() { scan.torchOn.toggle() }
    /// Shutter (or a library photo): asks for photo consent first, else identifies.
    func scanShutter() {
        guard scan.step == .camera else { return }
        if settings.photoConsent { scanIdentify() } else { scan.step = .consent }
    }
    /// "Allow photos and continue".
    func scanAllowPhotos() {
        settings.photoConsent = true
        scanIdentify()
    }
    private func scanIdentify(from progress: Double = 0) {
        scanTask?.cancel()
        scan.step = .identifying
        scan.progress = progress
        scan.hasPhoto = true
        scan.error = nil
        scanTask = Task { [weak self] in
            do {
                try await ScanSimulator.run(from: progress) { p in self?.scan.progress = p }
                guard let self, self.scan.step == .identifying else { return }
                if self.scan.simulateFailure {
                    self.scan.error = ScanSimulator.failureMessage
                    self.scan.step = .error
                } else {
                    self.scan.result = ScanSimulator.result(kind: self.scan.demoKind)
                    self.scan.step = .result
                }
            } catch {}
        }
    }
    /// "Take another photo" (busy, result and error states): back to the camera.
    func scanRetake() {
        scanTask?.cancel()
        scan.step = .camera
        scan.result = nil
        scan.progress = 0
        scan.hasPhoto = false
        scan.error = nil
    }
    func scanSelectCandidate(_ candidateID: UUID?) {
        guard var r = scan.result else { return }
        r.selectedCandidateID = candidateID
        if let c = r.selectedCandidate { r.exerciseIDs = c.exerciseIDs }
        scan.result = r
    }
    func scanSetLabel(_ label: String) { scan.result?.label = label }
    /// At most 6 exercises.
    func scanSetExercises(_ ids: [UUID]) { scan.result?.exerciseIDs = Array(ids.prefix(6)) }
    /// "Use generic identity": no model claimed.
    func scanUseGeneric() {
        guard var r = scan.result else { return }
        r.kind = .generic
        r.candidates = []
        r.selectedCandidateID = nil
        r.visibleText = nil
        scan.result = r
    }
    /// The resolution line for the current result (real-app copy).
    var scanResolutionLine: String? { scan.result.map(ScanSimulator.resolutionLine) }
    /// Adds the machine to the scan's gym. Returns its id (nil when the name or exercises are missing).
    @discardableResult
    func scanConfirm() -> UUID? {
        guard let r = scan.result, let gymID = scan.gymID ?? selectedGymID,
              !r.label.trimmingCharacters(in: .whitespaces).isEmpty, !r.exerciseIDs.isEmpty else { return nil }
        var modelID: UUID?
        switch r.kind {
        case .specific, .ambiguous: modelID = r.selectedCandidate?.catalogModelID
        case .newModel:
            if let c = r.selectedCandidate {
                modelID = addModel(manufacturer: c.manufacturer, modelName: c.modelName, category: c.category,
                                   exerciseIDs: r.exerciseIDs)
            }
        case .generic: modelID = nil
        }
        let id = addMachine(gymID: gymID, label: r.label, modelID: modelID, exerciseIDs: r.exerciseIDs)
        scan.confirmedMachineID = id
        scan.step = .confirmed
        return id
    }
    func scanCancel() {
        scanTask?.cancel()
        scan = ScanFlow(demoKind: scan.demoKind, simulateFailure: scan.simulateFailure)
    }

    // MARK: - Settings and export

    func saveAIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        settings.aiKeySaved = true
        settings.aiKeyHint = "sk-…" + String(trimmed.suffix(4))
    }
    func removeAIKey() {
        settings.aiKeySaved = false
        settings.aiKeyHint = ""
    }
    /// Revoking routine consent cancels generation and clears the week; revoking
    /// photo consent cancels a running identification (real behaviour).
    func setConsent(_ kind: AIConsent, _ value: Bool) {
        settings.setConsent(kind, value)
        guard !value else { return }
        switch kind {
        case .routine:
            aiTask?.cancel()
            ai.request.consent = false
            ai.days = []
            if ai.step != .goals { ai.step = .equipment }
        case .photos:
            if scan.step == .identifying { scanRetake() }
        case .modelDetails:
            if modelSuggest == .asking { cancelModelSuggestion() }
        }
    }
    /// "87 workouts · 1,234 sets"
    var exportCounts: (workouts: Int, sets: Int) { (workouts.count, workouts.reduce(0) { $0 + $1.setCount }) }
    /// Simulated export (≈ 0.8 s), then records the date — or, with the failure switch on,
    /// ends `.failed` (the red "Export failed: …" row) and records nothing.
    func export(_ format: ExportFormat) {
        exportTask?.cancel()
        exportState = .exporting(format)
        exportTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(ExportSimulator.duration))
            guard let self, !Task.isCancelled else { return }
            let stamp = Calendar.app.dateComponents([.year, .month, .day, .hour, .minute], from: self.now)
            let name = String(format: "workout-tracker-%04d-%02d-%02d-%02d%02d.%@", stamp.year ?? 0, stamp.month ?? 0,
                              stamp.day ?? 0, stamp.hour ?? 0, stamp.minute ?? 0, format.rawValue)
            if self.exportSimulateFailure {
                self.exportState = .failed(error: ExportSimulator.failureDescription(fileName: name))
                return
            }
            self.settings.lastExportAt = self.now
            self.settings.lastExportFormat = format
            self.exportState = .done(fileName: name)
        }
    }
    func resetExportState() { exportState = .idle }
    /// Prototype switch: the next export fails.
    func exportSetSimulateFailure(_ on: Bool) { exportSimulateFailure = on }

    // MARK: - Mutation helpers

    private func withSession(_ body: (inout LiveSession) -> Void) {
        guard var s = session else { return }
        body(&s)
        session = s
    }
    private func withEntry(_ entryID: UUID, _ body: (inout LiveEntry) -> Void) {
        withSession { s in
            guard let i = s.entries.firstIndex(where: { $0.id == entryID }) else { return }
            body(&s.entries[i])
        }
    }
    private func withSet(_ entryID: UUID, _ setID: UUID, _ body: (inout LiveSet, LiveEntry) -> Void) {
        withEntry(entryID) { entry in
            guard let i = entry.sets.firstIndex(where: { $0.id == setID }) else { return }
            let snapshot = entry
            body(&entry.sets[i], snapshot)
        }
    }

    // MARK: - Screen states

    /// Rebuilds the exact state a screen in screen-list.md shows (fresh sample data,
    /// clock back to Thu 18:30). Used by ScreenIndex and `-screen <ID>`.
    func reset(to screen: ScreenID) {
        aiTask?.cancel()
        scanTask?.cancel()
        exportTask?.cancel()
        modelSuggestTask?.cancel()
        load(SampleData.world())
        currentScreen = screen
        var target = ScreenTarget()
        let iron = SampleData.ironTempleID
        let pushDay = SampleData.templateID("Push Day")
        let chest = SampleData.exerciseID("Seated Chest Press")

        switch screen {
        case .w01, .w04, .z02, .z04, .c01, .h01, .g01, .e01, .e03, .x01, .x02, .x03:
            break
        case .w02:
            buildLivePushDay()
            isSessionPresented = false
        case .w03:
            gyms = []; machines = []; templates = []; workouts = []; selectedGymID = nil
        case .w05:
            buildLivePushDay()
            isSessionPresented = false
            pendingStart = PendingStart(templateID: SampleData.templateID("Whole Body"), activity: nil)
            target.templateID = SampleData.templateID("Whole Body")
        case .t01, .t02:
            target.templateID = pushDay
        case .t03, .t04, .f01:
            let w = finishTodayPushDay(withRun: false)
            target.workoutID = w.id
            target.templateID = pushDay
            if screen == .t03 { pendingDrift = drift(workoutID: w.id) }
        case .f02:
            target.workoutID = finishTodayPushDay(withRun: true).id
        case .f03:
            finishSummary = Derived.notSavedSummary(at: now)
        case .a01, .a02, .a03, .a04, .a05:
            aiBegin(gymID: iron)
            ai.request.goals = "Get stronger on the machines I use and keep some cardio in the week."
            ai.request.experience = .intermediate
            ai.request.daysPerWeek = 3
            ai.request.minutesPerSession = 45
            ai.request.heightCm = 178
            ai.request.weightKg = 76
            if screen != .a01 {
                ai.request.equipment = [.dumbbells, .adjustableBench, .cable]
                ai.request.cardio = [.indoorRun, .indoorCycle]
                ai.request.consent = true
                ai.step = .equipment
            }
            if screen == .a03 {
                ai.step = .generating
                let stage = AISimulator.stages(gymName: SampleData.ironTemple)[1]
                ai.progress = stage.progress
                ai.progressText = stage.text
                if !freezeClock { aiGenerate(resumeFrom: stage.progress) }
            }
            if screen == .a04 || screen == .a05 {
                ai.days = SampleData.aiWeek(days: 3, available: aiEligibleExerciseIDs, cardio: ai.request.cardio,
                                            unit: settings.distanceUnit)
                ai.step = .preview
                target.aiDayID = ai.days.first?.id
            }
        case .l01, .z05, .l06, .l07, .l12:
            buildLivePushDay()
            target.entryID = liveEntryID(chest)
        case .z01:
            // A system surface: the session runs but the live cover is not up.
            // Cardio variant: `Store.liveActivitySample(.c02)`.
            buildLivePushDay()
            isSessionPresented = false
            target.entryID = liveEntryID(chest)
        case .l02, .l09:
            target = buildSetStatesSession()
        case .l03:
            buildLivePushDay(elapsed: 1086)
            target.entryID = liveEntryID(chest)
            target.setID = .stable("live.Seated Chest Press.2")
        case .l04:
            restOverrides[chest] = RestSettings(mode: .heartRate, thresholdBpm: 110, capSeconds: 240)
            buildLivePushDay(elapsed: 1138)
            if var r = rest {
                r.mode = .heartRate
                r.thresholdBpm = 110
                r.totalSeconds = 240
                r.endsAt = r.startedAt.addingTimeInterval(240)
                rest = r
            }
            heartRate.bpm = 124
            heartRate.recoveryFrom = 124
            heartRate.recoveryStart = now
            target.entryID = liveEntryID(chest)
        case .l05, .l08, .l10, .l11:
            buildLivePushDay()
            target.entryID = liveEntryID(chest)
            if screen == .l08 {
                // The frozen chest entry shows the frozen line and preset chips; Lateral Raise
                // (not started) shows "Log as Dumbbell Lateral Raise instead".
                target.secondaryEntryID = liveEntryID(SampleData.exerciseID("Lateral Raise"))
            }
        case .l13:
            buildLivePushDay()
            // Two rows typed but not ticked: they would be discarded on Finish.
            if let entryID = liveEntryID(chest) {
                updateWeight(110, entryID: entryID, setID: .stable("live.Seated Chest Press.3"))
            }
            if let incline = session?.entries.first(where: { $0.exerciseID == SampleData.exerciseID("Incline Chest Press") }),
               let first = incline.sets.first {
                updateReps(10, entryID: incline.id, setID: first.id)
            }
            target.entryID = liveEntryID(chest)
        case .c02, .c03:
            target.segmentID = buildCardioSession(state: screen == .c02 ? .recording : .paused)
        case .c04:
            target.segmentID = buildOutdoorSession()
        case .c05:
            target.segmentID = buildCardioSession(state: .done)
        case .h02:
            target.date = SampleData.date(2026, 9, 21)
        case .h03:
            // Whole Body, Sep 19 (Edited): Bench Press bar breakdowns + warmup, superset A/B with
            // Lat Pulldown, a preset, free weights, an Indoor Cycle segment, two-phase HR, PRs.
            let key = "2026-09-19"
            target.workoutID = SampleData.workoutID(key)
            target.entryID = .stable("entry.\(key).0")
        case .h05:
            let key = "2026-09-17"
            target.workoutID = SampleData.workoutID(key)
            target.entryID = .stable("entry.\(key).0")
            target.setID = .stable("set.\(key).3")
        case .h04:
            target.workoutID = SampleData.workoutID("2026-08-29")
            target.segmentID = .stable("segment.2026-08-29.0")
        case .h06, .e02, .e04:
            target.exerciseID = chest
        case .h07:
            workouts = []
        case .g02:
            gyms = []; machines = []; selectedGymID = nil
        case .g03, .g05, .g06, .g07:
            target.gymID = iron
        case .g04:
            target.gymID = iron
            target.machineID = SampleData.machineID(SampleData.ironTemple, "Chest Press 2")
            // Usual-preset variant: Seated Row (usual preset Narrow grip).
            target.secondaryMachineID = SampleData.machineID(SampleData.ironTemple, "Seated Row")
        case .s01, .s02, .s03, .s04, .s05, .s06:
            scanBegin(gymID: iron)
            target.gymID = iron
            switch screen {
            case .s02:
                settings.photoConsent = false
                scan.step = .consent
            case .s03:
                scan.step = .identifying
                scan.progress = 0.6
                scan.hasPhoto = true
                if !freezeClock { scanIdentify(from: 0.6) }
            case .s04, .s05, .s06:
                let kind: ScanKind = screen == .s04 ? .specific : screen == .s05 ? .ambiguous : .generic
                scan.demoKind = kind
                scan.result = ScanSimulator.result(kind: kind)
                scan.hasPhoto = true
                scan.step = .result
            default:
                break
            }
        case .s07:
            target.gymID = iron
            target.machineID = SampleData.machineID(SampleData.ironTemple, "Lat Pulldown")
        case .e05:
            target.exerciseID = SampleData.exerciseID("Dip")
        case .z03:
            // Rest just ended (recovered); the notification mock sits over the lock screen.
            buildLivePushDay()
            isSessionPresented = false
            rest = nil
            heartRate.recoveryFrom = nil
            lastRestOutcome = .recovered(bpm: 108)
        }
        screenTarget = target
    }

    private func liveEntryID(_ exerciseID: UUID) -> UUID? {
        session?.entries.first { $0.exerciseID == exerciseID }?.id
    }

    /// Fills a live entry's rows: (type, weight field, reps, completed at N s after start, prefilled).
    private func fill(_ exerciseName: String, _ rows: [(SetType, Double?, Int?, Int?, Bool)]) {
        guard let s = session, let unit = liveEntry(liveEntryID(SampleData.exerciseID(exerciseName)))?.sets.first?.unit
                ?? Optional(displayUnit) else { return }
        let start = s.startedAt
        withSession { s in
            guard let i = s.entries.firstIndex(where: { $0.exerciseID == SampleData.exerciseID(exerciseName) }) else { return }
            s.entries[i].sets = rows.enumerated().map { n, row in
                LiveSet(id: .stable("live.\(exerciseName).\(n)"), type: row.0, weight: row.1, unit: unit, reps: row.2,
                        completedAt: row.3.map { start.addingTimeInterval(TimeInterval($0)) }, isPrefilled: row.4)
            }
            if s.entries[i].isFrozen { s.entries[i].snapshotLoadType = self.exercise(s.entries[i].exerciseID)?.loadType }
        }
    }

    /// Replaces the session's heart-rate log with a synthetic one covering `phases` (the
    /// session so far), so finishing a mid-way sample shows a graph, zones and avg / max.
    private func seedHeartRate(seed: UInt64, phases: [SampleData.HRPhase]) {
        let summary = SampleData.heartRate(seed: seed, phases: phases, maxHR: maxHeartRate ?? 185)
        let seconds = phases.reduce(0) { $0 + $1.seconds }
        withSession { $0.heartRate = HeartRateLog(seeded: summary, seconds: seconds) }
    }

    /// L01: Push Day at Iron Temple, 0:18:42 in, 7/18 sets, rest 1:24 of 2:00 after
    /// Seated Chest Press 110 × 8 (a new best), 128 bpm, 96 cal, 4,120 lb so far.
    /// Chest Press 2 was busy, so Machine Shoulder Press went first and was dragged to the
    /// top: the list reads done → current (chest) → next (Incline Chest Press).
    /// Set 3's 110 × 8 is the brief's number: under the real rule a template draft prefills
    /// from last time (Sep 17: 105 × 8 — PREVIOUS still shows it); carry-forward is Add Set only.
    private func buildLivePushDay(elapsed: Int = 1122) {
        selectedGymID = SampleData.ironTempleID
        startLifting(templateID: SampleData.templateID("Push Day"))
        withSession { s in
            s.startedAt = self.now.addingTimeInterval(-TimeInterval(elapsed))
            if let i = s.entries.firstIndex(where: { $0.exerciseID == SampleData.exerciseID("Machine Shoulder Press") }) {
                s.entries.insert(s.entries.remove(at: i), at: 0)
            }
        }
        fill("Machine Shoulder Press", [(.warmup, 40, 12, 150, false), (.working, 70, 12, 330, false),
                                        (.working, 75, 8, 470, false), (.working, 80, 10, 610, false)])
        fill("Seated Chest Press", [(.warmup, 45, 12, 750, false), (.working, 100, 10, 910, false),
                                    (.working, 110, 8, 1086, false), (.working, 110, 8, nil, true)])
        seedHeartRate(seed: 24, phases: [SampleData.HRPhase(seconds: elapsed, spec: SampleData.HRSpec(average: 118, maximum: 151))])
        withSession { $0.activeCalories = elapsed >= 1122 ? 96 : 93 }
        heartRate = HeartRateState(bpm: 128, lastSampleAt: now, source: .airPods, mode: .live,
                                   scriptStep: HRScript.startStep - 1, recoveryFrom: 128, recoveryStart: now)
        if let entry = liveEntryID(SampleData.exerciseID("Seated Chest Press")), let s = session {
            let restStart = s.startedAt.addingTimeInterval(1086)
            let seconds = restSeconds(entryID: entry, type: .working)
            rest = RestState(entryID: entry, setID: .stable("live.Seated Chest Press.2"), startedAt: restStart,
                             endsAt: restStart.addingTimeInterval(TimeInterval(seconds)), totalSeconds: seconds, mode: .timer)
            // Distinct per state (L03 at the instant, L01 36 s later) so `.onChange(of: id)` differs.
            lastCompletion = SetCompletion(
                id: .stable("completion.live.\(elapsed)"), entryID: entry, setID: .stable("live.Seated Chest Press.2"),
                exerciseName: "Seated Chest Press", value: SetValue(weight: 110, unit: .lb, reps: 8),
                outcome: .newBest(previous: SetValue(weight: 105, unit: .lb, reps: 8)), restStarted: true, at: restStart)
        }
        isSessionPresented = true
    }

    /// L02 / L09: the set-row vocabulary on Whole Body — Bench Press (superset A, 45 lb bar)
    /// and Lat Pulldown (B) with W / working / F / D rows, done, typed and prefilled.
    private func buildSetStatesSession() -> ScreenTarget {
        selectedGymID = SampleData.ironTempleID
        startLifting(templateID: SampleData.templateID("Whole Body"))
        withSession { $0.startedAt = self.now.addingTimeInterval(-845) }
        fill("Bench Press", [(.warmup, 25, 10, 240, false), (.working, 45, 8, 420, false),
                             (.failure, 45, 6, 610, false), (.working, 45, 8, nil, true)])
        fill("Lat Pulldown", [(.warmup, 60, 12, 300, false), (.working, 120, 10, 500, false),
                              (.working, 125, 10, nil, false), (.drop, 100, 12, nil, true)])
        heartRate = HeartRateState(bpm: 131, lastSampleAt: now, source: .airPods, mode: .live, scriptStep: 3)
        seedHeartRate(seed: 845, phases: [SampleData.HRPhase(seconds: 845, spec: SampleData.HRSpec(average: 116, maximum: 142))])
        withSession { $0.activeCalories = 71 }
        var target = ScreenTarget()
        target.entryID = liveEntryID(SampleData.exerciseID("Bench Press"))
        target.setID = .stable("live.Lat Pulldown.2")
        target.secondarySetID = .stable("live.Bench Press.3")
        return target
    }

    private func liveEntries(from workout: Workout) -> [LiveEntry] {
        workout.entries.map { e in
            LiveEntry(id: e.id, exerciseID: e.exerciseID, machineID: e.machineID, freeWeightTag: e.freeWeightTag,
                      presetID: e.presetID, supersetGroup: e.supersetGroup, barWeight: e.sets.first?.barWeight,
                      sets: e.sets.map { s in
                          LiveSet(id: s.id, type: s.type, weight: s.barWeight.map { ((s.weight ?? $0) - $0) / 2 } ?? s.weight,
                                  unit: s.unit, reps: s.reps, completedAt: s.completedAt)
                      }, snapshotLoadType: e.loadType)
        }
    }

    /// C02 / C03 / C05: Push Day lifting done, then the planned Indoor Run
    /// (20 min target): recording 12:48, paused at 12:48, or ended at 20:05.
    private func buildCardioSession(state: PlannedCardioStatus) -> UUID? {
        selectedGymID = SampleData.ironTempleID
        let active: TimeInterval = state == .done ? 1205 : 768
        let lifting = SampleData.todayPushDay().build(SampleData.Index(exercises: exercises, gyms: gyms,
                                                                       machines: machines, models: models))
        startLifting(templateID: SampleData.templateID("Push Day"))
        let planID = session?.plannedCardio.first?.id
        let cardioStart = now.addingTimeInterval(-active - (state == .done ? 40 : 0))
        let segmentID = UUID.stable("live.cardio.indoorRun")
        withSession { s in
            s.startedAt = cardioStart.addingTimeInterval(-3130)
            let offset = s.startedAt.timeIntervalSince(lifting.startedAt)
            s.entries = self.liveEntries(from: lifting).map { entry in
                var e = entry
                for i in e.sets.indices { e.sets[i].completedAt = e.sets[i].completedAt?.addingTimeInterval(offset) }
                return e
            }
            let meters = active * 3.08
            s.cardio = [LiveCardio(
                id: segmentID, activity: .indoorRun, startedAt: cardioStart,
                accumulatedSeconds: state == .recording ? 0 : active,
                runningSince: state == .recording ? cardioStart : nil,
                endedAt: state == .done ? self.now.addingTimeInterval(-40) : nil,
                measuredMeters: meters, unit: .mi, currentSpeed: state == .recording ? 3.12 : nil,
                heartRateSum: 146 * Int(active), heartRateCount: Int(active), maxHeartRate: 158,
                activeCalories: active * 0.154, plannedID: planID)]
            s.focus = .cardio
            s.activeCalories = 312 + active * 0.154
        }
        // Lifting (Push Day), then the run (and, when ended, 40 s of cool-down).
        var phases = [SampleData.HRPhase(seconds: 3130, spec: SampleData.HRSpec(average: 124, maximum: 158)),
                      SampleData.HRPhase(seconds: Int(active), spec: SampleData.HRSpec(average: 146, maximum: 158, cardio: true))]
        if state == .done { phases.append(SampleData.HRPhase(seconds: 40, spec: SampleData.HRSpec(average: 128, maximum: 136))) }
        seedHeartRate(seed: 768, phases: phases)
        heartRate = HeartRateState(bpm: state == .done ? 121 : 146, lastSampleAt: now, source: .airPods, mode: .live,
                                   scriptStep: 18)
        return segmentID
    }

    /// C04: Outdoor Run from Home, 8:12 in, 0.94 mi, GPS live (no map during the workout).
    private func buildOutdoorSession() -> UUID? {
        selectedGymID = SampleData.ironTempleID
        startCardio(activity: .outdoorRun)
        let active: TimeInterval = 492
        let segmentID = UUID.stable("live.cardio.outdoorRun")
        withSession { s in
            s.startedAt = self.now.addingTimeInterval(-active)
            s.cardio = [LiveCardio(
                id: segmentID, activity: .outdoorRun, startedAt: s.startedAt, runningSince: s.startedAt,
                measuredMeters: 0.94 * DistanceUnit.mi.metersPerUnit, unit: .mi, currentSpeed: 3.05,
                heartRateSum: 149 * Int(active), heartRateCount: Int(active), maxHeartRate: 161, activeCalories: 64,
                route: stride(from: 0.0, through: active, by: CardioSimulator.routeInterval).map {
                    CardioSimulator.routePoint(at: $0, portion: 0)
                },
                gps: .live)]
            s.activeCalories = 64
        }
        seedHeartRate(seed: 492, phases: [SampleData.HRPhase(seconds: Int(active),
                                                             spec: SampleData.HRSpec(average: 149, maximum: 161, cardio: true))])
        heartRate = HeartRateState(bpm: 149, lastSampleAt: now, source: .airPods, mode: .live, scriptStep: 18)
        return segmentID
    }

    /// F01 / T03 / T04 (and F02 with an outdoor run): today's Push Day is in history
    /// and its receipt is showing.
    @discardableResult
    private func finishTodayPushDay(withRun: Bool) -> Workout {
        let index = SampleData.Index(exercises: exercises, gyms: gyms, machines: machines, models: models)
        let w = SampleData.todayPushDay(withRun: withRun).build(index)
        workouts.append(w)
        finishSummary = summaryFor(w)
        return w
    }
}
