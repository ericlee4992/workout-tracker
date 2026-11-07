import Foundation

// Pure helpers: everything the screens show that is computed from stored data
// (records, summaries, charts, zones). Simplified ports of the real Domain code
// (RecordsMath, PreviousPerformance, ProgressSeries, HeartRateSeries,
// WorkoutCalendar, TemplateDrift). No state; the Store wraps these.

// MARK: - Records

enum Records {
    /// Rep-count tables stop at 12 reps; 1RM (Brzycki) covers 1…12 reps only.
    static let repRecordCap = 12

    /// Completed, reps > 0, not a warmup; weighted needs weight > 0,
    /// assisted / BW+added accept 0 (unassisted / plain); bodyweight ignores load.
    static func isEligible(type: SetType, value: SetValue?, loadType: LoadType) -> Bool {
        guard type.countsTowardRecords, let value, value.reps > 0 else { return false }
        switch loadType {
        case .weighted: return (value.kg ?? 0) > 0
        case .assisted, .bodyweightPlus: return (value.kg ?? 0) >= 0
        case .bodyweight: return true
        }
    }

    /// `a` is strictly better than `b`: load first (assisted: LOWER is better),
    /// then reps. A tie is never better — the earlier set keeps the record.
    static func outranks(_ a: SetValue, _ b: SetValue, loadType: LoadType) -> Bool {
        if loadType == .bodyweight { return a.reps > b.reps }
        let ka = a.kg ?? 0, kb = b.kg ?? 0
        if abs(ka - kb) > 1e-6 { return loadType.higherIsBetter ? ka > kb : ka < kb }
        return a.reps > b.reps
    }

    /// Best of `values` (the earliest wins a tie).
    static func best(_ values: [SetValue], loadType: LoadType) -> SetValue? {
        values.reduce(nil) { current, next in
            guard let current else { return next }
            return outranks(next, current, loadType: loadType) ? next : current
        }
    }

    /// Brzycki: w / (1.0278 − 0.0278 × reps), 1…12 reps.
    static func brzyckiKg(kg: Double, reps: Int) -> Double? {
        guard kg > 0, (1...repRecordCap).contains(reps) else { return nil }
        return kg / (1.0278 - 0.0278 * Double(reps))
    }

    /// Best 1RM over eligible values — weighted only (D20).
    static func bestOneRepMaxKg(_ values: [SetValue], loadType: LoadType) -> Double? {
        guard loadType == .weighted else { return nil }
        return values.compactMap { v in v.kg.flatMap { brzyckiKg(kg: $0, reps: v.reps) } }.max()
    }

    /// Σ kg × reps over counted WEIGHTED sets (D21). Dumbbells are per hand, never doubled.
    static func volumeKg(_ sets: [LoggedSet], loadType: LoadType) -> Double {
        guard loadType == .weighted else { return 0 }
        return sets.reduce(0) { sum, s in
            guard s.type.countsTowardRecords, let kg = s.normalizedKg, let reps = s.reps, reps > 0 else { return sum }
            return sum + kg * Double(reps)
        }
    }

    /// Best set per rep count 1…12 (weighted heaviest, assisted least assistance, BW+ most added).
    static func repBests(_ dated: [(value: SetValue, date: Date)], loadType: LoadType) -> [RepBest] {
        guard loadType != .bodyweight else { return [] }
        var table: [Int: RepBest] = [:]
        for item in dated where (1...repRecordCap).contains(item.value.reps) {
            let reps = item.value.reps
            if let current = table[reps] {
                let a = item.value.kg ?? 0, b = current.value.kg ?? 0
                let better = loadType.higherIsBetter ? a > b + 1e-6 : a < b - 1e-6
                if better { table[reps] = RepBest(reps: reps, value: item.value, date: item.date) }
            } else {
                table[reps] = RepBest(reps: reps, value: item.value, date: item.date)
            }
        }
        return table.values.sorted { $0.reps < $1.reps }
    }
}

extension WorkoutEntry {
    var scope: RecordScope {
        RecordScope(exerciseID: exerciseID, machineID: machineID,
                    freeWeightTag: machineID == nil ? freeWeightTag : nil, presetID: presetID)
    }
    var bestCounted: SetValue? {
        Records.best(sets.filter { Records.isEligible(type: $0.type, value: $0.value, loadType: loadType) }
            .compactMap(\.value), loadType: loadType)
    }
}

extension LiveEntry {
    var scope: RecordScope {
        RecordScope(exerciseID: exerciseID, machineID: machineID,
                    freeWeightTag: machineID == nil ? freeWeightTag : nil, presetID: presetID)
    }
}

enum Derived {

    // MARK: - New bests over history

    /// For every eligible set in history, whether it was a new best when logged
    /// (scope = machine or free-weight tag + preset). Warmups excluded; assisted
    /// lower-is-better; ties are not PRs; the first workout in a scope is
    /// "First time" (its first eligible set), never a PR.
    static func bestOutcomes(_ workouts: [Workout]) -> [UUID: BestOutcome] {
        var best: [RecordScope: SetValue] = [:]
        var firstWorkout: [RecordScope: UUID] = [:]
        var result: [UUID: BestOutcome] = [:]
        for workout in workouts.sorted(by: { $0.startedAt < $1.startedAt }) {
            for entry in workout.entries {
                let scope = entry.scope
                for set in entry.sets.sorted(by: { $0.completedAt < $1.completedAt }) {
                    guard Records.isEligible(type: set.type, value: set.value, loadType: entry.loadType),
                          let value = set.value else { continue }
                    guard let current = best[scope] else {
                        best[scope] = value
                        firstWorkout[scope] = workout.id
                        result[set.id] = .firstTime
                        continue
                    }
                    if Records.outranks(value, current, loadType: entry.loadType) {
                        best[scope] = value
                        if firstWorkout[scope] != workout.id { result[set.id] = .newBest(previous: current) }
                    }
                }
            }
        }
        return result
    }

    /// The outcome of completing `value` live: compared with finished history in
    /// the scope plus this session's earlier completed sets in the scope.
    static func liveOutcome(value: SetValue, type: SetType, loadType: LoadType, scope: RecordScope,
                            history: [Workout], sessionEarlier: [SetValue]) -> BestOutcome {
        guard Records.isEligible(type: type, value: value, loadType: loadType) else { return .none }
        let past = history.flatMap(\.entries).filter { $0.scope == scope }.flatMap { entry in
            entry.sets.filter { Records.isEligible(type: $0.type, value: $0.value, loadType: loadType) }
                .compactMap(\.value)
        }
        if past.isEmpty {
            return sessionEarlier.isEmpty ? .firstTime : .none
        }
        guard let best = Records.best(past + sessionEarlier, loadType: loadType) else { return .firstTime }
        return Records.outranks(value, best, loadType: loadType) ? .newBest(previous: best) : .none
    }

    /// "Last time" for a live row: the same scope's latest finished workout,
    /// matched by set type and position among sets of that type (layer 1 only).
    static func previousValue(scope: RecordScope, type: SetType, ordinal: Int, history: [Workout]) -> SetValue? {
        for workout in history.sorted(by: { $0.startedAt > $1.startedAt }) {
            let entries = workout.entries.filter { $0.scope == scope && !$0.sets.isEmpty }
            guard !entries.isEmpty else { continue }
            let sameType = entries.flatMap(\.sets).filter { $0.type == type }
            return ordinal < sameType.count ? sameType[ordinal].value : nil
        }
        return nil
    }

    // MARK: - Previous performance (three layers)

    static func previousPerformance(exercise: Exercise, machine: Machine?, tag: EquipmentTag?, presetID: UUID?,
                                    gymID: UUID?, history: [Workout], machines: [UUID: Machine]) -> PreviousPerformance {
        let loadType = exercise.loadType
        let all = history.flatMap { w in w.entries.map { (w, $0) } }
            .filter { $0.1.exerciseID == exercise.id && $0.1.presetID == presetID }

        func layer(_ kind: PerformanceLayerKind, _ pairs: [(Workout, WorkoutEntry)], title: String, empty: String) -> PerformanceLayer {
            let byWorkout = Dictionary(grouping: pairs, by: { $0.0.id })
            let sessions = byWorkout.values.compactMap { group -> PerformanceSession? in
                guard let workout = group.first?.0 else { return nil }
                let sets = group.flatMap { $0.1.sets }
                return PerformanceSession(workoutID: workout.id, date: workout.startedAt, gymName: workout.gymName,
                                          equipmentLabel: group[0].1.equipmentLabel,
                                          sets: sets.compactMap(\.value), types: sets.map(\.type))
            }.sorted { $0.date > $1.date }
            let dated: [(value: SetValue, date: Date)] = pairs.flatMap { pair in
                pair.1.sets.filter { Records.isEligible(type: $0.type, value: $0.value, loadType: loadType) }
                    .compactMap { s in s.value.map { (value: $0, date: s.completedAt) } }
            }
            let values = dated.map(\.value)
            var message: String? = nil
            if sessions.isEmpty { message = empty } else if values.isEmpty { message = "No eligible records at this layer yet." }
            return PerformanceLayer(
                kind: kind, title: title, sessions: Array(sessions.prefix(5)),
                best: Records.best(values, loadType: loadType),
                repBests: Records.repBests(dated, loadType: loadType),
                oneRepMaxKg: Records.bestOneRepMaxKg(values, loadType: loadType),
                mostReps: loadType == .bodyweight ? values.map(\.reps).max() : nil,
                emptyMessage: message)
        }

        var layers: [PerformanceLayer] = []
        if let machine {
            layers.append(layer(.thisEquipment, all.filter { $0.1.machineID == machine.id },
                                title: "This machine", empty: "No completed sets on this machine yet."))
        } else {
            layers.append(layer(.thisEquipment, all.filter { $0.1.machineID == nil && $0.1.freeWeightTag == tag },
                                title: "This equipment", empty: "No completed sets with this equipment yet."))
        }
        if let modelID = machine?.modelID, let gymID {
            let elsewhere = all.filter { pair in
                guard let id = pair.1.machineID, let other = machines[id] else { return false }
                return other.modelID == modelID && other.gymID != gymID
            }
            layers.append(layer(.sameModelElsewhere, elsewhere, title: "Same model elsewhere",
                                empty: "No other gyms with this model logged yet."))
        }
        layers.append(layer(.anyEquipment, all, title: "Any equipment", empty: "No history for this exercise yet."))
        let presetName = exercise.presets.first { $0.id == presetID }?.name
        return PreviousPerformance(exerciseName: exercise.name, loadType: loadType, presetName: presetName, layers: layers)
    }

    // MARK: - Progress

    /// The progress variation a history entry belongs to (load type × equipment × preset) —
    /// the per-exercise chart button passes it to `progressSeries(exerciseID:variationID:)`.
    static func variationID(for e: WorkoutEntry) -> String {
        let equipment = e.machineID?.uuidString ?? e.freeWeightTag?.rawValue ?? "none"
        return "\(e.loadType.rawValue)|\(equipment)|\(e.presetID?.uuidString ?? "")"
    }

    /// Variations of an exercise (load type × equipment × preset), most training days first.
    /// Labels: "Chest Press 2", "Chest Press 2 · Narrow grip", and a machine at another gym than
    /// the exercise's usual one gets the gym: "Chest Press · Gangnam Fitness".
    static func progressVariations(exerciseID: UUID, history: [Workout]) -> [ProgressVariation] {
        let entries = history.flatMap { w in w.entries.map { (w, $0) } }.filter { $0.1.exerciseID == exerciseID }
        let grouped = Dictionary(grouping: entries, by: { variationID(for: $0.1) })
        // The gym with the most training days for this exercise.
        let daysByGym = Dictionary(grouping: entries.compactMap { pair in pair.0.gymName.map { ($0, pair.0.startedAt) } },
                                   by: \.0).mapValues { Set($0.map { Calendar.app.startOfDay(for: $0.1) }).count }
        let mainGym = daysByGym.max { ($0.value, $1.key) < ($1.value, $0.key) }?.key
        var variations = grouped.map { key, pairs -> ProgressVariation in
            let e = pairs[0].1
            var label = e.machineLabel ?? e.freeWeightTag?.label ?? "No equipment"
            if let preset = e.presetName { label += " · \(preset)" }
            if e.machineID != nil, let gym = pairs[0].0.gymName, gym != mainGym { label += " · \(gym)" }
            let days = Set(pairs.map { Calendar.app.startOfDay(for: $0.0.startedAt) }).count
            return ProgressVariation(id: key, label: label, machineID: e.machineID,
                                     freeWeightTag: e.machineID == nil ? e.freeWeightTag : nil,
                                     presetID: e.presetID, loadType: e.loadType, trainingDays: days)
        }
        // Still identical (e.g. two load types on one machine): add the load type.
        let counts = Dictionary(grouping: variations, by: \.label).mapValues(\.count)
        for i in variations.indices where (counts[variations[i].label] ?? 0) > 1 {
            variations[i].label += " · \(variations[i].loadType.badge)"
        }
        return variations.sorted { ($0.trainingDays, $1.label) > ($1.trainingDays, $0.label) }
    }

    /// One point per calendar day for one variation.
    static func progressSeries(exerciseID: UUID, variation: ProgressVariation, history: [Workout]) -> ProgressSeries {
        let loadType = variation.loadType
        let pairs = history.flatMap { w in w.entries.map { (w, $0) } }
            .filter { $0.1.exerciseID == exerciseID && variationID(for: $0.1) == variation.id }
        let byDay = Dictionary(grouping: pairs, by: { Calendar.app.startOfDay(for: $0.0.startedAt) })
        var points: [ProgressPoint] = []
        var bestSoFar: SetValue?
        for day in byDay.keys.sorted() {
            let dayPairs = byDay[day] ?? []
            let eligible = dayPairs.flatMap { $0.1.sets }
                .filter { Records.isEligible(type: $0.type, value: $0.value, loadType: loadType) }
                .compactMap(\.value)
            guard let best = Records.best(eligible, loadType: loadType) else { continue }
            let isRecord = bestSoFar.map { Records.outranks(best, $0, loadType: loadType) } ?? false
            if bestSoFar == nil || isRecord { bestSoFar = best }
            points.append(ProgressPoint(
                date: day, workoutID: dayPairs[0].0.id, best: best, bestKg: best.kg,
                volumeKg: dayPairs.reduce(0) { $0 + Records.volumeKg($1.1.sets, loadType: loadType) },
                oneRepMaxKg: Records.bestOneRepMaxKg(eligible, loadType: loadType), isRecord: isRecord))
        }
        return ProgressSeries(exerciseID: exerciseID, variation: variation, points: points)
    }

    /// First → last change in percent for a metric; flipped for assisted. nil under 2 points or a zero baseline.
    static func change(_ series: ProgressSeries, metric: ProgressMetric) -> Double? {
        guard series.points.count >= 2, let first = series.points.first, let last = series.points.last else { return nil }
        func metricValue(_ p: ProgressPoint) -> Double? {
            switch metric {
            case .bestSet: series.variation.loadType == .bodyweight ? Double(p.best.reps) : p.bestKg
            case .volume: p.volumeKg
            case .oneRepMax: p.oneRepMaxKg
            }
        }
        guard let a = metricValue(first), let b = metricValue(last), a > 0 else { return nil }
        let raw = (b - a) / a * 100
        return metric == .bestSet && !series.variation.loadType.higherIsBetter ? -raw : raw
    }

    // MARK: - Supersets

    /// Superset letters for an ordered list of groups (template items, history entries, live
    /// entries): each run of ≥ 2 adjacent equal non-nil groups is lettered "A", "B", "C"…;
    /// everything else is nil. An interrupted group renders as two runs (D48).
    static func supersetLabels(groups: [UUID?]) -> [String?] {
        var labels = [String?](repeating: nil, count: groups.count)
        var i = 0
        while i < groups.count {
            guard let group = groups[i] else { i += 1; continue }
            var j = i
            while j + 1 < groups.count, groups[j + 1] == group { j += 1 }
            if j > i {
                for k in i...j { labels[k] = String(UnicodeScalar(UInt8(65 + min(25, k - i)))) }
            }
            i = j + 1
        }
        return labels
    }

    // MARK: - Families

    /// Families of a set of exercises, each once, head to toe.
    static func families(exerciseIDs: [UUID], exercises: [UUID: Exercise]) -> [MuscleFamily] {
        MuscleFamily.ordered(exerciseIDs.compactMap { exercises[$0]?.family })
    }
    static func families(of template: Template, exercises: [UUID: Exercise]) -> [MuscleFamily] {
        families(exerciseIDs: template.items.map(\.exerciseID), exercises: exercises)
    }
    static func families(of workout: Workout, exercises: [UUID: Exercise]) -> [MuscleFamily] {
        families(exerciseIDs: workout.entries.map(\.exerciseID), exercises: exercises)
    }

    static func volumeKg(of workout: Workout) -> Double {
        workout.entries.reduce(0) { $0 + Records.volumeKg($1.sets, loadType: $1.loadType) }
    }
    static func countedSets(of workout: Workout) -> Int {
        workout.entries.reduce(0) { $0 + $1.countedSets.count }
    }

    // MARK: - Week, month, streak

    static func dayWorkout(_ w: Workout, exercises: [UUID: Exercise]) -> DayWorkout {
        let kind: DayWorkoutKind
        if w.hasLifting && w.hasCardio { kind = .mixed }
        else if let activity = w.cardio.first?.activity, !w.hasLifting { kind = .cardio(activity) }
        else { kind = .lifting }
        return DayWorkout(workoutID: w.id, title: w.title, kind: kind, families: families(of: w, exercises: exercises),
                          minutes: w.durationSeconds / 60, sets: w.setCount)
    }

    static func weekSummary(history: [Workout], exercises: [UUID: Exercise], now: Date) -> WeekSummary {
        let cal = Calendar.app
        let start = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? cal.startOfDay(for: now)
        let today = cal.startOfDay(for: now)
        var days: [WeekDaySummary] = []
        var counts: [MuscleFamily: Int] = [:]
        var minutes = 0, total = 0
        for offset in 0..<7 {
            let day = cal.date(byAdding: .day, value: offset, to: start)!
            let items = history.filter { cal.isDate($0.startedAt, inSameDayAs: day) }.sorted { $0.startedAt < $1.startedAt }
            for w in items {
                minutes += w.durationSeconds / 60
                for entry in w.entries {
                    if let family = exercises[entry.exerciseID]?.family { counts[family, default: 0] += entry.countedSets.count }
                }
            }
            total += items.count
            days.append(WeekDaySummary(date: day, letter: Format.weekdayLetter(day), isToday: day == today,
                                       isFuture: day > today, workouts: items.map { dayWorkout($0, exercises: exercises) }))
        }
        let lastWeekStart = cal.date(byAdding: .day, value: -7, to: start)!
        let lastWeek = history.filter { $0.startedAt >= lastWeekStart && $0.startedAt < start }.count
        return WeekSummary(days: days, workoutCount: total, trainingDayCount: days.filter { !$0.workouts.isEmpty }.count,
                           setsByFamily: MuscleFamily.allCases.map { FamilyCount(family: $0, sets: counts[$0] ?? 0) },
                           minutes: minutes, lastWeekWorkoutCount: lastWeek)
    }

    static func monthSummary(history: [Workout], month: Date) -> MonthSummary {
        let cal = Calendar.app
        let items = history.filter { cal.isDate($0.startedAt, equalTo: month, toGranularity: .month) }
        return MonthSummary(month: cal.dateInterval(of: .month, for: month)?.start ?? month,
                            workouts: items.count, sets: items.reduce(0) { $0 + $1.setCount },
                            hours: Double(items.reduce(0) { $0 + $1.durationSeconds }) / 3600)
    }

    /// PROPOSED feature (not in SPEC/DECISIONS): consecutive weeks with ≥ 1 workout.
    static func weekStreak(history: [Workout], now: Date) -> WeekStreak {
        let cal = Calendar.app
        func weekStart(_ d: Date) -> Date { cal.dateInterval(of: .weekOfYear, for: d)?.start ?? d }
        let active = Set(history.map { weekStart($0.startedAt) })
        let thisWeek = weekStart(now)
        var count = 0
        var cursor = cal.date(byAdding: .day, value: -7, to: thisWeek)!
        while active.contains(cursor) {
            count += 1
            cursor = cal.date(byAdding: .day, value: -7, to: cursor)!
        }
        return WeekStreak(completedWeeks: count, thisWeekActive: active.contains(thisWeek))
    }

    // MARK: - Template, gym, machine stats

    static func templateStats(templateID: UUID, history: [Workout]) -> TemplateStats {
        let runs = history.filter { $0.templateID == templateID }
        let avg = runs.isEmpty ? nil : runs.reduce(0) { $0 + $1.durationSeconds } / runs.count
        return TemplateStats(timesRun: runs.count, lastRun: runs.map(\.startedAt).max(), averageDurationSeconds: avg)
    }

    static func gymStats(gymID: UUID, history: [Workout], machines: [Machine]) -> GymStats {
        let visits = history.filter { $0.gymID == gymID }
        let here = machines.filter { $0.gymID == gymID }
        return GymStats(visits: visits.count, lastVisit: visits.map(\.startedAt).max(),
                        machineCount: here.filter { !$0.isDeleted }.count,
                        deletedMachineCount: here.filter(\.isDeleted).count)
    }

    /// Machine history. Bests are per record scope (exercise + preset on this machine), most used first.
    static func machineStats(machineID: UUID, history: [Workout]) -> MachineStats {
        let pairs = history.flatMap { w in w.entries.map { (w, $0) } }.filter { $0.1.machineID == machineID }
        struct Key: Hashable { var exerciseID: UUID; var presetID: UUID? }
        let byScope = Dictionary(grouping: pairs, by: { Key(exerciseID: $0.1.exerciseID, presetID: $0.1.presetID) })
        let bests = byScope.compactMap { key, group -> MachineBest? in
            let latest = group.max { $0.0.startedAt < $1.0.startedAt }!.1
            let loadType = latest.loadType
            let values = group.flatMap(\.1.sets)
                .filter { Records.isEligible(type: $0.type, value: $0.value, loadType: loadType) }.compactMap(\.value)
            guard let best = Records.best(values, loadType: loadType) else { return nil }
            return MachineBest(exerciseID: key.exerciseID, exerciseName: latest.exerciseName, presetID: key.presetID,
                               presetName: latest.presetName, loadType: loadType, value: best,
                               timesUsed: Set(group.map(\.0.id)).count)
        }.sorted { ($0.timesUsed, $1.label) > ($1.timesUsed, $0.label) }
        return MachineStats(timesUsed: Set(pairs.map(\.0.id)).count, lastUsed: pairs.map(\.0.startedAt).max(),
                            bests: bests, setCount: pairs.reduce(0) { $0 + $1.1.sets.count })
    }

    // MARK: - Calendar

    static func intensity(sets: Int, trained: Bool) -> Int {
        guard trained else { return 0 }
        switch sets {
        case ..<12: return 1
        case 12..<20: return 2
        case 20..<28: return 3
        default: return 4
        }
    }

    static func calendarMonth(containing date: Date, selected: Date?, history: [Workout],
                              exercises: [UUID: Exercise], now: Date) -> CalendarMonth {
        let cal = Calendar.app
        let monthStart = cal.dateInterval(of: .month, for: date)!.start
        let dayCount = cal.range(of: .day, in: .month, for: monthStart)!.count
        let leading = (cal.component(.weekday, from: monthStart) - cal.firstWeekday + 7) % 7
        let today = cal.startOfDay(for: now)
        let selectedDay = selected.map { cal.startOfDay(for: $0) }
        var cells: [CalendarDay?] = Array(repeating: nil, count: leading)
        for offset in 0..<dayCount {
            let day = cal.date(byAdding: .day, value: offset, to: monthStart)!
            let items = history.filter { cal.isDate($0.startedAt, inSameDayAs: day) }
            let sets = items.reduce(0) { $0 + countedSets(of: $1) }
            cells.append(CalendarDay(date: day, dayNumber: offset + 1, isToday: day == today, isFuture: day > today,
                                     sets: sets, intensity: intensity(sets: sets, trained: !items.isEmpty),
                                     workoutIDs: items.sorted { $0.startedAt < $1.startedAt }.map(\.id),
                                     isSelected: day == selectedDay))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        let weeks = stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
        let selectedWorkouts = selectedDay.map { day in
            history.filter { cal.isDate($0.startedAt, inSameDayAs: day) }.sorted { $0.startedAt < $1.startedAt }
                .map { dayWorkout($0, exercises: exercises) }
        } ?? []
        let firstMonth = history.map(\.startedAt).min().flatMap { cal.dateInterval(of: .month, for: $0)?.start }
        let symbols = (0..<7).map { cal.veryShortWeekdaySymbols[(cal.firstWeekday - 1 + $0) % 7] }
        return CalendarMonth(month: monthStart, title: Format.month(monthStart), weekdaySymbols: symbols, weeks: weeks,
                             selectedDate: selectedDay, selectedWorkouts: selectedWorkouts,
                             hasPrevious: firstMonth.map { $0 < monthStart } ?? false,
                             hasNext: monthStart < cal.dateInterval(of: .month, for: now)!.start)
    }

    // MARK: - Heart rate

    /// The zone of a reading (inclusive-low bounds; ≥ 95 % is Zone 5).
    static func zone(bpm: Int, max maxBpm: Int?) -> HeartRateZone? {
        guard let maxBpm, maxBpm > 0, bpm >= 0 else { return nil }
        let fraction = Double(bpm) / Double(maxBpm)
        return HeartRateZone.allCases.reversed().first { fraction >= $0.lowerFraction } ?? .warm
    }
    static func lowerBound(of zone: HeartRateZone, max maxBpm: Int) -> Int {
        Int((Double(maxBpm) * zone.lowerFraction).rounded())
    }
    /// Zone ladder for the max-HR sheet and legends.
    static func zoneRows(max maxBpm: Int) -> [ZoneRow] {
        HeartRateZone.allCases.map { zone in
            let next = HeartRateZone(rawValue: zone.rawValue + 1)
            return ZoneRow(zone: zone, lowerBound: lowerBound(of: zone, max: maxBpm),
                           upperBound: next.map { lowerBound(of: $0, max: maxBpm) })
        }
    }
    /// Zones with time, in order; zero rows omitted (F01 has no Zone 5 row).
    static func zoneTimes(_ zoneSeconds: [Int]) -> [ZoneTime] {
        zoneSeconds.enumerated().compactMap { i, seconds in
            guard seconds > 0, let zone = HeartRateZone(rawValue: i) else { return nil }
            return ZoneTime(zone: zone, seconds: seconds)
        }
    }
    /// Seconds per zone from 15 s buckets (gaps count toward no zone). Index-based [6]:
    /// zones without time are 0 — list them with `zoneTimes(_:)`, which omits zero rows.
    static func zoneSeconds(series: HeartRateSeries, max maxBpm: Int?) -> [Int] {
        guard maxBpm != nil else { return [] }
        var seconds = [Int](repeating: 0, count: 6)
        for bpm in series.mean where bpm > 0 {
            if let zone = zone(bpm: bpm, max: maxBpm) { seconds[zone.rawValue] += series.intervalSeconds }
        }
        return seconds
    }

    /// Merge 15 s buckets into at most `maxSlots` bars; gaps stay holes.
    static func hrSlots(series: HeartRateSeries, durationSeconds: Int, maxSlots: Int = 110) -> [HRSlot] {
        let mean = series.mean
        guard !mean.isEmpty, maxSlots > 0 else { return [] }
        let interval = max(1, series.intervalSeconds)
        let count = durationSeconds > 0
            ? min(mean.count, Int((Double(durationSeconds) / Double(interval)).rounded(.up))) : mean.count
        guard count > 0 else { return [] }
        let hasRange = series.low.count == mean.count && series.high.count == mean.count
        let perSlot = Int((Double(count) / Double(maxSlots)).rounded(.up))
        let slotCount = Int((Double(count) / Double(perSlot)).rounded(.up))
        var slots: [HRSlot] = []
        for slot in 0..<slotCount {
            let first = slot * perSlot, last = min(count, first + perSlot)
            var lowest = Int.max, highest = Int.min
            for i in first..<last where mean[i] > 0 {
                lowest = min(lowest, hasRange && series.low[i] > 0 ? series.low[i] : mean[i])
                highest = max(highest, hasRange && series.high[i] > 0 ? series.high[i] : mean[i])
            }
            guard lowest != Int.max else { continue }
            let end = durationSeconds > 0 ? min(last * interval, durationSeconds) : last * interval
            slots.append(HRSlot(index: slot, startSeconds: first * interval, endSeconds: end,
                                low: lowest, high: max(lowest, highest)))
        }
        return slots
    }
    /// The chart's own y-axis (not 0…220).
    static func hrRange(_ slots: [HRSlot]) -> ClosedRange<Int>? {
        guard let lo = slots.map(\.low).min(), let hi = slots.map(\.high).max() else { return nil }
        return lo...hi
    }

    // MARK: - Cardio

    static func meters(_ a: RoutePoint, _ b: RoutePoint) -> Double {
        let r = 6_371_000.0
        let dLat = (b.latitude - a.latitude) * .pi / 180, dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(a.latitude * .pi / 180) * cos(b.latitude * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * asin(min(1, sqrt(h)))
    }

    /// Per-unit splits from a route's timestamps, scaled to the segment's distance.
    static func splits(_ segment: CardioSegment) -> [CardioSplit] {
        guard segment.route.count > 1, let total = segment.distanceMeters, total > 0 else { return [] }
        var cumulative: [(meters: Double, offset: Double)] = [(0, segment.route[0].offset)]
        for i in 1..<segment.route.count {
            let step = segment.route[i].portion == segment.route[i - 1].portion ? meters(segment.route[i - 1], segment.route[i]) : 0
            cumulative.append((cumulative[i - 1].meters + step, segment.route[i].offset))
        }
        guard let routeMeters = cumulative.last?.meters, routeMeters > 0 else { return [] }
        let scale = total / routeMeters
        let unitMeters = segment.unit.metersPerUnit
        let endOffset = Double(segment.activeSeconds)
        func offset(atMeters m: Double) -> Double {
            for i in 1..<cumulative.count where cumulative[i].meters * scale >= m {
                let a = cumulative[i - 1], b = cumulative[i]
                let span = (b.meters - a.meters) * scale
                let t = span > 0 ? (m - a.meters * scale) / span : 0
                return a.offset + t * (b.offset - a.offset)
            }
            return endOffset
        }
        var result: [CardioSplit] = []
        var start = 0.0, index = 0, covered = 0.0
        while covered < total - 1 {
            let next = min(total, covered + unitMeters)
            let end = next >= total ? endOffset : offset(atMeters: next)
            result.append(CardioSplit(index: index, distance: (next - covered) / unitMeters, seconds: Int((end - start).rounded())))
            start = end; covered = next; index += 1
        }
        return result
    }

    // MARK: - Template drift

    /// Differences between a finished workout's completed structure and its template.
    static func drift(template: Template, workout: Workout, exercises: [UUID: Exercise]) -> TemplateDrift? {
        var changes: [DriftChange] = []
        let entriesByExercise = Dictionary(grouping: workout.entries, by: \.exerciseID)
        func name(_ id: UUID) -> String { exercises[id]?.name ?? "Exercise" }
        for item in template.items {
            guard let entries = entriesByExercise[item.exerciseID] else {
                changes.append(DriftChange(id: .stable("drift.\(item.id)"), exerciseID: item.exerciseID,
                                           exerciseName: name(item.exerciseID), kind: .removed, bestValue: nil))
                continue
            }
            let sets = entries.flatMap(\.sets)
            let reps = sets.compactMap(\.reps)
            let best = entries.compactMap(\.bestCounted).first
            if sets.count != item.setCount {
                changes.append(DriftChange(id: .stable("drift.\(item.id)"), exerciseID: item.exerciseID,
                                           exerciseName: name(item.exerciseID),
                                           kind: .setCount(from: item.setCount, to: sets.count), bestValue: best))
            } else if reps != item.targetReps {
                changes.append(DriftChange(id: .stable("drift.\(item.id)"), exerciseID: item.exerciseID,
                                           exerciseName: name(item.exerciseID),
                                           kind: .reps(from: item.targetReps, to: reps), bestValue: best))
            }
        }
        let planned = Set(template.items.map(\.exerciseID))
        for entry in workout.entries where !planned.contains(entry.exerciseID) {
            changes.append(DriftChange(id: .stable("drift.\(entry.id)"), exerciseID: entry.exerciseID,
                                       exerciseName: entry.exerciseName, kind: .added(sets: entry.sets.count),
                                       bestValue: entry.bestCounted))
        }
        guard !changes.isEmpty else { return nil }
        return TemplateDrift(templateID: template.id, templateName: template.name, workoutID: workout.id, changes: changes)
    }

    /// The template a resolution produces (keepOriginal returns it unchanged).
    static func resolve(_ resolution: DriftResolution, template: Template, workout: Workout) -> Template {
        var result = template
        let oldItems = Dictionary(template.items.map { ($0.exerciseID, $0) }, uniquingKeysWith: { a, _ in a })
        func completedReps(_ entry: WorkoutEntry) -> [Int] { entry.sets.map { $0.reps ?? 0 } }
        switch resolution {
        case .keepOriginal:
            break
        case .updateValuesOnly:
            let byExercise = Dictionary(grouping: workout.entries, by: \.exerciseID)
            for i in result.items.indices {
                guard let reps = byExercise[result.items[i].exerciseID].map({ $0.flatMap(completedReps) }) else { continue }
                for slot in 0..<min(reps.count, result.items[i].targetReps.count) {
                    result.items[i].targetReps[slot] = reps[slot]
                }
            }
        case .updateTemplate, .updateBoth:
            result.items = workout.entries.map { entry in
                let reps = completedReps(entry)
                var targets = reps
                if resolution == .updateTemplate, let old = oldItems[entry.exerciseID] {
                    for slot in 0..<min(old.targetReps.count, targets.count) { targets[slot] = old.targetReps[slot] }
                }
                return TemplateItem(id: oldItems[entry.exerciseID]?.id ?? .stable("item.\(entry.id)"),
                                    exerciseID: entry.exerciseID, targetReps: targets,
                                    restSeconds: oldItems[entry.exerciseID]?.restSeconds,
                                    supersetGroup: entry.supersetGroup, equipmentTag: entry.freeWeightTag)
            }
        }
        return result
    }

    /// Save as Template: completed structure becomes targets; supersets and free-weight
    /// tags are kept; recorded cardio becomes planned cardio (minutes, 1…180).
    static func template(from workout: Workout, name: String) -> Template {
        let id = UUID()
        return Template(
            id: id, name: name,
            items: workout.entries.map { entry in
                TemplateItem(id: UUID(), exerciseID: entry.exerciseID, targetReps: entry.sets.map { $0.reps ?? 0 },
                             restSeconds: nil, supersetGroup: entry.supersetGroup, equipmentTag: entry.freeWeightTag)
            },
            cardio: workout.cardio.map { segment in
                PlannedCardio(id: UUID(), activity: segment.activity,
                              minutes: min(180, max(1, Int((Double(segment.activeSeconds) / 60).rounded()))),
                              distance: nil, unit: segment.unit)
            })
    }

    // MARK: - Finish summary

    static func finishSummary(for workout: Workout, history: [Workout], exercises: [UUID: Exercise],
                              unit: WeightUnit, maxHeartRate: Int?) -> FinishSummary {
        let volume = volumeKg(of: workout)
        var tiles = [FinishTile(kind: .workoutTime, value: Format.elapsed(workout.durationSeconds), unit: "")]
        if workout.hasLifting && volume > 0 {
            tiles.append(FinishTile(kind: .totalVolume, value: Format.volumeNumber(kilograms: volume, in: unit), unit: unit.label))
        }
        if let active = workout.activeCalories { tiles.append(FinishTile(kind: .activeCalories, value: "\(active)", unit: "cal")) }
        if let total = workout.totalCalories { tiles.append(FinishTile(kind: .totalCalories, value: "\(total)", unit: "cal")) }
        if let hr = workout.heartRate {
            tiles.append(FinishTile(kind: .averageHeartRate, value: "\(hr.average)", unit: "bpm"))
            tiles.append(FinishTile(kind: .maxHeartRate, value: "\(hr.maximum)", unit: "bpm"))
        }
        let outcomes = bestOutcomes(history)
        var newBests: [NewBestLine] = []
        var entriesWithBest = Set<UUID>()
        for entry in workout.entries {
            for set in entry.sets {
                if case .newBest(let previous) = outcomes[set.id], let value = set.value {
                    newBests.append(NewBestLine(setID: set.id, exerciseID: entry.exerciseID, exerciseName: entry.exerciseName,
                                                value: value, previous: previous))
                    entriesWithBest.insert(entry.id)
                }
            }
        }
        // Keep one line per exercise: its final (highest) new best.
        var seen = Set<UUID>()
        newBests = newBests.reversed().filter { seen.insert($0.exerciseID).inserted }.reversed()

        var comparison: TemplateComparison?
        if let templateID = workout.templateID,
           let last = history.filter({ $0.templateID == templateID && $0.startedAt < workout.startedAt })
            .max(by: { $0.startedAt < $1.startedAt }) {
            let lastVolume = volumeKg(of: last)
            comparison = TemplateComparison(
                templateName: workout.templateName ?? workout.title, lastDate: last.startedAt, lastVolumeKg: lastVolume,
                volumeKg: volume, lastDurationSeconds: last.durationSeconds, durationSeconds: workout.durationSeconds,
                volumeChangePercent: lastVolume > 0 ? (volume - lastVolume) / lastVolume * 100 : nil)
        }
        let series = workout.heartRate?.series
        let zones = maxHeartRate != nil ? (workout.heartRate?.zoneSeconds ?? []) : []
        var parts: [String] = []
        if workout.setCount > 0 {
            parts.append(Format.count(workout.entries.count, "exercise"))
            parts.append(Format.count(workout.setCount, "set"))
        }
        if workout.hasCardio { parts.append(Format.count(workout.cardio.count, "cardio activity", "cardio activities")) }
        if let gym = workout.gymName { parts.append(gym) }
        return FinishSummary(
            id: .stable("finish.\(workout.id)"), saved: true, workoutID: workout.id, title: workout.title,
            date: workout.startedAt, gymName: workout.gymName, durationSeconds: workout.durationSeconds,
            volumeKg: volume, setCount: workout.setCount, exerciseCount: workout.entries.count, tiles: tiles,
            averageHeartRate: workout.heartRate?.average, maxHeartRate: workout.heartRate?.maximum,
            zoneSeconds: zones.contains(where: { $0 > 0 }) ? zones : [],
            hrSlots: series.map { hrSlots(series: $0, durationSeconds: workout.durationSeconds) } ?? [],
            newBests: newBests, comparison: comparison, families: families(of: workout, exercises: exercises),
            exercises: workout.entries.map { entry in
                FinishExerciseLine(entryID: entry.id, exerciseID: entry.exerciseID, name: entry.exerciseName,
                                   equipmentLabel: entry.equipmentLabel, family: exercises[entry.exerciseID]?.family,
                                   setCount: entry.sets.count, best: entry.bestCounted, loadType: entry.loadType,
                                   hasNewBest: entriesWithBest.contains(entry.id))
            },
            cardio: workout.cardio, summaryLine: parts.joined(separator: " · "))
    }

    /// Finishing with nothing logged: the workout is not saved.
    static func notSavedSummary(at date: Date) -> FinishSummary {
        FinishSummary(id: UUID(), saved: false, workoutID: nil, title: "Nothing logged", date: date, gymName: nil,
                      durationSeconds: 0, volumeKg: 0, setCount: 0, exerciseCount: 0, tiles: [],
                      averageHeartRate: nil, maxHeartRate: nil, zoneSeconds: [], hrSlots: [], newBests: [],
                      comparison: nil, families: [], exercises: [], cardio: [],
                      summaryLine: "No sets were completed, so this workout wasn't saved.")
    }
}
