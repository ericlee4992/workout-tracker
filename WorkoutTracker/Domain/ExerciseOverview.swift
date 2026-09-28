import Foundation
import SwiftData

// Floodlight ticket 08 — the Exercises area's readouts: the catalog row's best and last-trained
// date, the detail page's stats, recent workouts, machines and preset use, the catalog's
// grouping and family filter, and the one value formatter the area uses. Nothing new is
// stored; everything is derived on read from FINISHED workouts in SNAPSHOT terms (D23).

// MARK: - Inputs

/// One completed set of a finished workout, in snapshot terms, with its workout.
struct ExerciseLoggedSet: Equatable {
    var setID: UUID
    var workoutID: UUID
    var workoutStartedAt: Date
    /// `loadType` is the entry's snapshot load type — the type the set was logged under.
    var input: RecordSetInput
}

// MARK: - Results

/// One exercise's relationship with the user (the catalog row and the detail stats).
struct ExerciseStat: Equatable {
    var workouts = 0
    var lastTrained: Date?
    /// Completed sets that are not warmups.
    var workingSets = 0
    /// The best eligible set on any equipment among sets logged under the exercise's CURRENT
    /// load type. A set logged under another type ranks the other way (D23), so it never mixes in.
    var best: RecordSetInput?
    /// The best was set in the latest workout that trained the exercise AND an earlier workout
    /// already had an eligible set it beat. A tie keeps the earlier set (so it is never marked), and
    /// a first-ever set is "first time", not a best.
    var lastWasNewBest = false
}

enum ExerciseOverview {

    // MARK: Stats

    static func stat(of sets: [ExerciseLoggedSet], currentLoadType: LoadType) -> ExerciseStat {
        let completed = sets.filter { $0.input.completedAt != nil }
        guard !completed.isEmpty else { return ExerciseStat() }
        var stat = ExerciseStat()
        stat.workouts = Set(completed.map(\.workoutID)).count
        let latest = completed.max { $0.workoutStartedAt < $1.workoutStartedAt }
        stat.lastTrained = latest?.workoutStartedAt
        stat.workingSets = completed.filter { $0.input.setType != .warmup }.count
        let eligible = completed
            .filter { $0.input.loadType == currentLoadType && RecordsMath.isEligible($0.input) }
            .sorted { ($0.input.completedAt ?? .distantPast) < ($1.input.completedAt ?? .distantPast) }
        var best: ExerciseLoggedSet?
        for item in eligible where best.map({ RecordsMath.outranks(item.input, $0.input) }) ?? true {
            best = item
        }
        stat.best = best?.input
        if let best, let latest {
            let earlier = Set(eligible.map(\.workoutID)).subtracting([best.workoutID])
            stat.lastWasNewBest = best.workoutID == latest.workoutID && !earlier.isEmpty
        }
        return stat
    }

    /// One progress variation's readout by WORKOUT (the chart groups by day; a day can hold two
    /// workouts and one workout can cross midnight): its sets scoped to the variation, then `stat`
    /// under the variation's load type — so its `lastWasNewBest` means the latest workout on this
    /// variation set the best and an earlier workout had an eligible set.
    static func variationStat(of sets: [ExerciseLoggedSet], variation: ProgressVariationKey) -> ExerciseStat {
        let scoped = sets.filter { ProgressSeriesMath.scoped([$0.input], to: variation).count == 1 }
        return stat(of: scoped, currentLoadType: variation.loadType)
    }

    /// The best eligible set among `inputs` of `loadType` (ties keep the earlier set).
    static func best(_ inputs: [RecordSetInput], loadType: LoadType) -> RecordSetInput? {
        inputs
            .filter { $0.loadType == loadType && RecordsMath.isEligible($0) }
            .sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
            .reduce(nil as RecordSetInput?) { incumbent, set in
                guard let incumbent else { return set }
                return RecordsMath.outranks(set, incumbent) ? set : incumbent
            }
    }

    // MARK: Presets

    /// Workouts per preset (a preset used twice in one workout counts once).
    static func presetUsage(_ sets: [ExerciseLoggedSet]) -> [UUID: Int] {
        var workouts: [UUID: Set<UUID>] = [:]
        for set in sets {
            guard let preset = set.input.presetID else { continue }
            workouts[preset, default: []].insert(set.workoutID)
        }
        return workouts.mapValues(\.count)
    }

    /// Each preset's best eligible set on any equipment, under the current load type.
    static func presetBests(_ sets: [ExerciseLoggedSet], currentLoadType: LoadType) -> [UUID: RecordSetInput] {
        let byPreset = Dictionary(grouping: sets.filter { $0.input.presetID != nil }) { $0.input.presetID! }
        return byPreset.compactMapValues { best($0.map(\.input), loadType: currentLoadType) }
    }

    // MARK: Machines

    /// A machine that serves the exercise, or one it was logged on, with its use for it.
    struct MachineUse: Equatable, Identifiable {
        var id: UUID { machineID }
        var machineID: UUID
        var label: String
        var gymName: String?
        var workouts: Int
        var best: RecordSetInput?
    }

    /// Live machines (not archived, at a live gym) that serve the exercise or that it was logged
    /// on; most used first, then gym, then label.
    static func machineUses(
        exerciseID: UUID, currentLoadType: LoadType, sets: [ExerciseLoggedSet], machines: [MachineInstance]
    ) -> [MachineUse] {
        let live = machines.filter { !$0.archived && $0.gym?.archived != true }
        let logged = Dictionary(grouping: sets.filter { $0.input.machineID != nil }) { $0.input.machineID! }
        return live
            .filter { $0.supportedExerciseIDs.contains(exerciseID) || logged[$0.id] != nil }
            .map { machine in
                let used = logged[machine.id] ?? []
                return MachineUse(
                    machineID: machine.id, label: machine.label, gymName: machine.gym?.name,
                    workouts: Set(used.map(\.workoutID)).count,
                    best: best(used.map(\.input), loadType: currentLoadType))
            }
            .sorted {
                if $0.workouts != $1.workouts { return $0.workouts > $1.workouts }
                if $0.gymName != $1.gymName { return ($0.gymName ?? "") < ($1.gymName ?? "") }
                return $0.label.localizedStandardCompare($1.label) == .orderedAscending
            }
    }
}

// MARK: - Catalog grouping and filtering (E01)

enum ExercisesGrouping: String, CaseIterable, Identifiable {
    case bodyArea, lastTrained, alphabetical

    var id: String { rawValue }
    var title: String {
        switch self {
        case .bodyArea: "Body area"
        case .lastTrained: "Last trained"
        case .alphabetical: "A–Z"
        }
    }
}

/// What the catalog list needs of one exercise.
struct ExerciseCatalogItem: Identifiable, Equatable {
    var id: UUID
    var name: String
    var muscleGroup: String?
    var lastTrained: Date?
}

struct ExerciseCatalogSection: Identifiable, Equatable {
    var id: String
    var title: String
    /// The body area's family, for the header's colour mark (body-area grouping only).
    var family: MuscleFamily?
    /// false: no mark slot at all (last-trained buckets, A–Z letters).
    var showsMark: Bool
    var items: [ExerciseCatalogItem]
}

enum ExerciseCatalog {
    /// The family a stored filter value names: the family's own name, or — a value saved before
    /// the family strip — a body area, which opens on its family ("Biceps" → Arms).
    static func family(stored value: String?) -> MuscleFamily? {
        guard let value else { return nil }
        return MuscleFamily(rawValue: value) ?? MuscleFamily(muscleGroup: value)
    }

    /// D24: a row with no body area is never hidden by the body filter. Core, Neck and Full Body
    /// belong to no family, so a chosen family hides them like any other family's rows.
    static func matches(muscleGroup: String?, family: MuscleFamily?) -> Bool {
        guard let family, let muscleGroup else { return true }
        return MuscleFamily(muscleGroup: muscleGroup) == family
    }

    static func sections(
        _ items: [ExerciseCatalogItem], by grouping: ExercisesGrouping,
        now: Date, calendar: Calendar = .current
    ) -> [ExerciseCatalogSection] {
        let byName: (ExerciseCatalogItem, ExerciseCatalogItem) -> Bool = {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        switch grouping {
        case .bodyArea:
            let areas = CatalogBrowsing.bodyAreasPresent(in: items.compactMap(\.muscleGroup))
            var sections = areas.map { area in
                ExerciseCatalogSection(
                    id: "area-\(area)", title: area, family: MuscleFamily(muscleGroup: area), showsMark: true,
                    items: items.filter { $0.muscleGroup == area }.sorted(by: byName))
            }
            let loose = items.filter { $0.muscleGroup == nil }.sorted(by: byName)
            if !loose.isEmpty {
                sections.append(ExerciseCatalogSection(
                    id: "uncategorized", title: "Uncategorized", family: nil, showsMark: true, items: loose))
            }
            return sections
        case .lastTrained:
            // Weeks as the Home week card counts them (the calendar's own week).
            let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)
            let lastWeek = thisWeek.flatMap { calendar.dateInterval(of: .weekOfYear, for: $0.start.addingTimeInterval(-1)) }
            func bucket(_ item: ExerciseCatalogItem) -> Int {
                guard let date = item.lastTrained else { return 3 }
                if thisWeek?.contains(date) == true || date >= (thisWeek?.end ?? .distantFuture) { return 0 }
                if lastWeek?.contains(date) == true { return 1 }
                return 2
            }
            let recentFirst: (ExerciseCatalogItem, ExerciseCatalogItem) -> Bool = {
                let a = $0.lastTrained ?? .distantPast, b = $1.lastTrained ?? .distantPast
                return a == b ? byName($0, $1) : a > b
            }
            return ["This week", "Last week", "Earlier", "Not trained yet"].enumerated().compactMap { index, title in
                let members = items.filter { bucket($0) == index }
                    .sorted(by: index == 3 ? byName : recentFirst)
                return members.isEmpty ? nil : ExerciseCatalogSection(
                    id: "recent-\(index)", title: title, family: nil, showsMark: false, items: members)
            }
        case .alphabetical:
            let grouped = Dictionary(grouping: items) { String($0.name.prefix(1)).uppercased() }
            return grouped.keys.sorted().map { letter in
                ExerciseCatalogSection(
                    id: "letter-\(letter)", title: letter, family: nil, showsMark: false,
                    items: (grouped[letter] ?? []).sorted(by: byName))
            }
        }
    }
}

// MARK: - Names

enum ExerciseNames {
    /// Trimmed, inner runs of whitespace collapsed, compared case- and diacritic-insensitively.
    static func comparable(_ name: String) -> String {
        name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    /// Whether `name` is already one of `existing` (New Exercise refuses it — user decision 4,
    /// ticket 08). A blank name is never "taken"; it is simply not addable.
    static func isTaken(_ name: String, among existing: [String]) -> Bool {
        let key = comparable(name)
        guard !key.isEmpty else { return false }
        return existing.contains { comparable($0) == key }
    }
}

// MARK: - Dates

enum ExerciseDates {
    /// "Today", "Yesterday", the weekday within the last six days ("Mon"), otherwise "Sep 19".
    static func relative(_ date: Date, now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ...0: return "Today"
        case 1: return "Yesterday"
        case 2...6: return formatted(date, "EEE", calendar: calendar, locale: locale)
        default: return formatted(date, "MMMd", calendar: calendar, locale: locale)
        }
    }

    /// "Thu"
    static func weekdayShort(_ date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        formatted(date, "EEE", calendar: calendar, locale: locale)
    }

    private static func formatted(_ date: Date, _ template: String, calendar: Calendar, locale: Locale) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.setLocalizedDateFormatFromTemplate(template)
        return f.string(from: date)
    }
}

// MARK: - Values by load type

/// One formatter for every best, record and history value in the Exercises area. It follows the
/// load type — a plain "70 × 8" on an assisted exercise would read as 70 lifted — and shows the
/// unit only when it differs from the user's unit (D52: the numbers as entered, never converted).
/// Weighted "105 × 8" · BW + added "+15 × 8", or "BW × 12" for a plain set · Assisted "−70 × 8"
/// (less is better; 0 = unassisted, "BW × 8") · Bodyweight "BW × 12".
enum ExerciseValueText {
    static func label(_ value: SetValue, loadType: LoadType, userUnit: WeightUnit?, alwaysUnit: Bool = false) -> String {
        let weight = value.weight ?? 0
        let unit = (alwaysUnit || value.unit != userUnit) ? " \(value.unit.rawValue)" : ""
        let number = WeightMath.displayNumber(weight)
        switch loadType {
        case .weighted:
            guard value.weight != nil else { return "\(value.reps) rep\(value.reps == 1 ? "" : "s")" }
            return "\(number)\(unit) × \(value.reps)"
        case .bodyweight:
            return "BW × \(value.reps)"
        case .bodyweightPlus:
            return weight > 0 ? "+\(number)\(unit) × \(value.reps)" : "BW × \(value.reps)"
        case .assisted:
            return weight > 0 ? "−\(number)\(unit) × \(value.reps)" : "BW × \(value.reps)"
        }
    }

    /// The load alone, for a record tile's figure: "105", "+15", "−70", "BW".
    static func figure(_ value: SetValue, loadType: LoadType) -> String {
        let weight = value.weight ?? 0
        let number = WeightMath.displayNumber(weight)
        switch loadType {
        case .weighted: return number
        case .bodyweight: return "BW"
        case .bodyweightPlus: return weight > 0 ? "+\(number)" : "BW"
        case .assisted: return weight > 0 ? "−\(number)" : "BW"
        }
    }

    /// Whether the figure carries a unit (a "BW" figure does not).
    static func figureHasUnit(_ value: SetValue, loadType: LoadType) -> Bool {
        switch loadType {
        case .weighted: value.weight != nil
        case .bodyweight: false
        case .bodyweightPlus, .assisted: (value.weight ?? 0) > 0
        }
    }

    /// VoiceOver: "105 pounds, 8 reps", "15 pounds added, 8 reps", "70 pounds assistance, 8 reps",
    /// "Bodyweight, 12 reps".
    static func spoken(_ value: SetValue, loadType: LoadType) -> String {
        let reps = "\(value.reps) rep\(value.reps == 1 ? "" : "s")"
        let weight = value.weight ?? 0
        let amount = "\(WeightMath.displayNumber(weight)) \(value.unit == .lb ? "pounds" : "kilograms")"
        switch loadType {
        case .weighted: return value.weight == nil ? reps : "\(amount), \(reps)"
        case .bodyweight: return "Bodyweight, \(reps)"
        case .bodyweightPlus: return weight > 0 ? "\(amount) added, \(reps)" : "Bodyweight, \(reps)"
        case .assisted: return weight > 0 ? "\(amount) assistance, \(reps)" : "Bodyweight, \(reps)"
        }
    }
}

extension LoadType {
    /// Which way records rank (assisted is the one that points down).
    var rankSymbol: String { self == .assisted ? "arrow.down" : "arrow.up" }

    /// The selected type's one consequence line (user decision 3, ticket 08: the prototype's
    /// shortened copy).
    var consequence: String {
        switch self {
        case .weighted: "More weight is harder. Records rank the heaviest set."
        case .bodyweight: "Your body is the load. Log reps alone."
        case .bodyweightPlus: "Your body plus any weight you add."
        case .assisted: "Less assistance is harder. Records rank the least."
        }
    }

    /// The rep-record table's title and, for assisted, its direction caption.
    var recordsTitle: (title: String, caption: String?) {
        switch self {
        case .weighted: ("Weight records", nil)
        case .assisted: ("Least-assistance records", "lower is better")
        case .bodyweightPlus: ("Added-weight records", nil)
        case .bodyweight: ("Bodyweight record", nil)
        }
    }
}

// MARK: - SwiftData bridge

extension ExerciseOverview {
    /// Every completed set of every finished workout, keyed by the snapshot exercise (D23).
    /// One fetch for the whole catalog.
    static func loggedSets(in context: ModelContext) throws -> [UUID: [ExerciseLoggedSet]] {
        let workouts = try context.fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.finishedAt != nil }))
        var result: [UUID: [ExerciseLoggedSet]] = [:]
        for workout in workouts where !workout.isDeleted {
            for entry in workout.entries ?? [] where !entry.isDeleted {
                for set in entry.sets ?? [] where !set.isDeleted && set.completedAt != nil {
                    result[entry.snapshotExerciseID, default: []].append(ExerciseLoggedSet(
                        setID: set.id, workoutID: workout.id, workoutStartedAt: workout.startedAt,
                        input: input(set, entry: entry)))
                }
            }
        }
        return result
    }

    static func input(_ set: SetRecord, entry: ExerciseEntry) -> RecordSetInput {
        RecordSetInput(
            loadType: entry.snapshotLoadType, exerciseID: entry.snapshotExerciseID, gymID: entry.snapshotGymID,
            machineID: entry.snapshotMachineID, modelID: entry.snapshotModelID,
            freeWeightTag: entry.snapshotFreeWeightTag, presetID: entry.snapshotPresetID,
            setType: set.type, reps: set.reps, weightValue: set.weightValue, weightUnit: set.weightUnit,
            normalizedKg: set.normalizedKg, completedAt: set.completedAt, barWeightValue: set.barWeightValue)
    }

    /// Sets already logged for an exercise, counted by the load type each was logged UNDER (the
    /// entry's snapshot, D23) — not the exercise's current type, which a correction may have changed
    /// since (the Load Type sheet's ledger). Every set of every captured entry; types in
    /// `LoadType.allCases` order, only those with sets.
    static func loggedSetCounts(of exercise: Exercise) -> [(loadType: LoadType, sets: Int)] {
        guard !exercise.isDeleted else { return [] }
        var counts: [LoadType: Int] = [:]
        for entry in exercise.entries ?? [] where !entry.isDeleted && entry.snapshotCapturedAt != nil {
            counts[entry.snapshotLoadType, default: 0] += (entry.sets ?? []).filter { !$0.isDeleted }.count
        }
        return LoadType.allCases.compactMap { type in
            counts[type].flatMap { $0 > 0 ? (type, $0) : nil }
        }
    }

    /// One past workout's sets of an exercise (the detail's History rows).
    struct Session: Identifiable {
        var id: UUID { workout.id }
        var workout: Workout
        /// The workout's entries of the exercise in logging order, each with ITS OWN snapshot
        /// context (D23/D36): a switch of grip or equipment mid-workout, or an entry re-typed in
        /// History, keeps its own words and its own load type. Adjacent entries with the same context
        /// share one group.
        var groups: [SessionGroup]
        var newBestSetIDs: Set<UUID>
    }

    struct SessionGroup: Identifiable {
        var id: UUID
        /// "Chest Press 2 · Narrow grip": the snapshot equipment, then the preset.
        var equipment: String
        var loadType: LoadType
        var sets: [SetRecord]
    }

    /// The newest `limit` finished workouts that trained the exercise, the sets in logging order,
    /// grouped by entry context; each set marked when it set a new best in its scope
    /// (`SetBadgeMath`, the same mark the live workout and the receipt show).
    static func recentSessions(
        exerciseID: UUID, finishedEntries: [ExerciseEntry], limit: Int = 3
    ) -> [Session] {
        let mine = finishedEntries.filter { $0.snapshotExerciseID == exerciseID && !$0.isDeleted }
        let byWorkout = Dictionary(grouping: mine.filter { $0.workout != nil }) { $0.workout!.id }
        return byWorkout.values
            .compactMap { entries -> Session? in
                let ordered = entries.sorted { $0.order < $1.order }
                guard let workout = ordered.first?.workout else { return nil }
                var groups: [SessionGroup] = []
                var newBests = Set<UUID>()
                for entry in ordered {
                    let sets = (entry.sets ?? []).filter { !$0.isDeleted && $0.completedAt != nil }
                        .sorted { $0.order < $1.order }
                    guard !sets.isEmpty else { continue }
                    let marks = SetBadgeMath.receiptMarks(for: entry, finishedEntries: finishedEntries).outcomes
                    newBests.formUnion(marks.filter { $0.value.badge == .newBest }.keys)
                    let equipment = [entry.snapshotMachineLabel ?? entry.snapshotFreeWeightTag?.label,
                                     entry.snapshotPresetName].compactMap { $0 }.joined(separator: " · ")
                    if let last = groups.last, last.equipment == equipment, last.loadType == entry.snapshotLoadType {
                        groups[groups.count - 1].sets += sets
                    } else {
                        groups.append(SessionGroup(id: entry.id, equipment: equipment,
                                                   loadType: entry.snapshotLoadType, sets: sets))
                    }
                }
                guard !groups.isEmpty else { return nil }
                return Session(workout: workout, groups: groups, newBestSetIDs: newBests)
            }
            .sorted { $0.workout.startedAt > $1.workout.startedAt }
            .prefix(limit)
            .map { $0 }
    }

    /// The snapshot words for a progress variation — as logged, not as today's rows say (D23).
    /// Naming policy lives in `ProgressSeriesMath.labels`.
    static func variationWords(for key: ProgressVariationKey, entries: [ExerciseEntry]) -> ProgressVariationWords {
        var equipmentName: String?
        var gymName: String?
        switch key.equipment {
        case .freeWeight(let tag):
            equipmentName = tag.label
        case .machine(let machineID):
            let entry = entries.first { $0.snapshotMachineID == machineID }
            equipmentName = entry?.snapshotMachineLabel ?? "Machine"
            gymName = entry?.snapshotGymName
        case .unrecorded:
            break
        }
        let presetName = key.presetID.map { id in
            entries.first { $0.snapshotPresetID == id }?.snapshotPresetName ?? "Variation"
        }
        return ProgressVariationWords(
            loadType: key.loadType, equipment: key.equipment,
            equipmentName: equipmentName, gymName: gymName, presetName: presetName)
    }
}
