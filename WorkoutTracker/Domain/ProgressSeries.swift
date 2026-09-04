import Foundation

// Milestone 8, ticket 01 — the numbers behind the progress charts.
//
// Pure logic, no SwiftUI, so the series can be proven without rendering
// anything. A chart that "looked right on my machine" is exactly what this
// project's process refuses; and a second, parallel implementation of best-set
// or volume that can drift from `RecordsMath` would eventually draw a picture
// disagreeing with the records screen. So every judgement here — eligibility,
// ranking direction, volume — delegates to `RecordsMath`.

/// One session's worth of a single exercise, reduced to what a chart plots.
struct ProgressPoint: Equatable, Identifiable {
    var id: Date { date }
    /// The session's date, normalized to its day so points land on an axis.
    let date: Date
    /// Best set that day, in canonical kg — direction already resolved for the
    /// load type (assisted: least assistance).
    let bestKg: Double?
    /// Reps of that best set, for the tooltip.
    let bestReps: Int?
    /// As entered, so the tooltip can show the number the user actually typed
    /// rather than a converted one (D9/D25).
    let bestValue: Double?
    let bestUnit: WeightUnit?
    /// Weighted-only, per `RecordsMath.totalVolumeKg`. Zero for load types
    /// where "volume lifted" is not a meaningful quantity.
    let volumeKg: Double
    /// Best Brzycki estimate that day, weighted only (D20). nil elsewhere.
    let e1rmKg: Double?
}

/// What a chart is allowed to claim about a series.
///
/// Two points are not a trend. Drawing a line between them and letting the eye
/// read a slope is the same false precision D9/D25 mark with `≈` — one domain
/// over, and easier to believe because it looks like maths.
enum ProgressConfidence: Equatable {
    case empty
    /// One session. Render the point, never a line.
    case single
    /// Enough to draw, with the count of DAYS so the UI can caveat a short series.
    case series(days: Int)
}

struct ProgressSeries: Equatable {
    let points: [ProgressPoint]
    let loadType: LoadType
    let confidence: ProgressConfidence

    /// True when a HIGHER value means a better set. False for assisted, where
    /// less assistance is the improvement — a chart that draws that as decline
    /// is worse than no chart at all.
    var higherIsBetter: Bool { loadType != .assisted }

    /// What the load axis is actually measuring, so the direction is
    /// unmistakable on screen.
    var loadAxisLabel: String {
        switch loadType {
        case .assisted: "Assistance (less is better)"
        case .bodyweight: "Reps"
        case .bodyweightPlus: "Added weight"
        case .weighted: "Weight"
        }
    }
}

/// Where a set was done, at the granularity the records use.
///
/// Mirrors `RecordGroupKey` (D23): an exact machine, a free-weight tag, or
/// nothing recorded. codex-review 01 (high): the first cut keyed only on the
/// tag, so a machined set (tag nil, machine set) and a History "Add Exercise"
/// row (tag nil, machine nil — equipment genuinely unknown) fell into ONE
/// group, and every machine pooled with every other. D1/D8 exist because a
/// weight on one machine is not a weight on another; the chart is not exempt.
enum ProgressEquipment: Hashable, Sendable {
    /// One specific machine — the same scope layer one of prefill matches.
    case machine(UUID)
    case freeWeight(EquipmentTag)
    /// No machine and no tag: added from History, or logged before tags
    /// existed. A real group, and an honest label for it, not a wildcard.
    case unrecorded

    init(machineID: UUID?, freeWeightTag: EquipmentTag?) {
        if let machineID { self = .machine(machineID) }
        else if let freeWeightTag { self = .freeWeight(freeWeightTag) }
        else { self = .unrecorded }
    }

    /// Stable order for ties: tags by name, then machines by id, then
    /// unrecorded — so the same history ranks the same way every launch.
    fileprivate var sortKey: String {
        switch self {
        case .freeWeight(let tag): "0-\(tag.rawValue)"
        case .machine(let id): "1-\(id.uuidString)"
        case .unrecorded: "2"
        }
    }
}

/// One chartable variation of an exercise: a snapshot load type, where it was
/// done, and a preset.
///
/// D36 keeps records per variation, so a chart must be per variation too —
/// pooling narrow- and wide-grip lets one set a record the other can never
/// beat, and draws a line describing neither. The load type is part of the key
/// for the same reason: after a D47 correction an exercise can hold history
/// under two different types, and they rank in opposite directions. The
/// equipment is here because records were ALREADY split by it and the chart
/// was not (milestone 9, ticket 01): a dumbbell bench and a barbell bench
/// never shared a PR, yet drew as one line.
///
/// Every field is required on purpose. A defaulted axis is how the D36
/// pooling happened: a caller silently receiving a group it did not ask for.
struct ProgressVariationKey: Hashable, Sendable {
    var loadType: LoadType
    var equipment: ProgressEquipment
    var presetID: UUID?
}

enum ProgressSeriesMath {

    /// The variations present in history, with how many DAYS each has.
    ///
    /// The count drives which one a chart opens on: the variation the user has
    /// actually trained, rather than whichever the live exercise happens to
    /// name today.
    static func variations(
        in sets: [RecordSetInput], calendar: Calendar = .current
    ) -> [ProgressVariationKey: Int] {
        var days: [ProgressVariationKey: Set<Date>] = [:]
        for set in sets where RecordsMath.isEligible(set) {
            guard let completedAt = set.completedAt else { continue }
            let key = ProgressVariationKey(
                loadType: set.loadType,
                equipment: ProgressEquipment(machineID: set.machineID, freeWeightTag: set.freeWeightTag),
                presetID: set.presetID)
            days[key, default: []].insert(calendar.startOfDay(for: completedAt))
        }
        return days.mapValues(\.count)
    }

    /// Every variation with history, most days first — the order a picker
    /// lists them in and the order `defaultVariation` chooses from.
    ///
    /// Ties: the plain (no-preset) variation first, then load type, then
    /// equipment by tag name / machine id / unrecorded, then preset id. Every
    /// field of the key takes part, so two DISTINCT keys never compare equal
    /// and the chart opens on the same variation every launch rather than
    /// dictionary order. (codex-review 01b: the first cut left load type out,
    /// and D47 is exactly how one exercise ends up with history under two.)
    /// Lives here, not in the view, because codex-review 01 found the view had
    /// grown its own copy of this comparator — fallback selection is Domain
    /// logic (CLAUDE.md) precisely so two copies cannot drift.
    static func rankedVariations(
        in sets: [RecordSetInput], calendar: Calendar = .current
    ) -> [(key: ProgressVariationKey, days: Int)] {
        variations(in: sets, calendar: calendar)
            .map { (key: $0.key, days: $0.value) }
            .sorted { precedes($0, $1) }
    }

    /// The one comparator behind `rankedVariations`, exposed so a test can
    /// prove it is total: for any two DISTINCT keys exactly one precedes the
    /// other. (codex-review 01c: a test on the sorted output could pass by
    /// dictionary luck with an axis removed; a test on the comparator cannot.)
    static func precedes(
        _ a: (key: ProgressVariationKey, days: Int),
        _ b: (key: ProgressVariationKey, days: Int)
    ) -> Bool {
        let aRank = (-a.days, a.key.presetID == nil ? 0 : 1, a.key.loadType.rawValue,
                     a.key.equipment.sortKey, a.key.presetID?.uuidString ?? "")
        let bRank = (-b.days, b.key.presetID == nil ? 0 : 1, b.key.loadType.rawValue,
                     b.key.equipment.sortKey, b.key.presetID?.uuidString ?? "")
        return aRank < bRank
    }

    /// The variation a chart should open on: the first of `rankedVariations`.
    static func defaultVariation(
        in sets: [RecordSetInput], calendar: Calendar = .current
    ) -> ProgressVariationKey? {
        rankedVariations(in: sets, calendar: calendar).first?.key
    }

    /// Builds a per-exercise series from logged sets.
    ///
    /// Warmups are excluded by `RecordsMath.isEligible`, the same rule the
    /// records screen uses — not a second filter that could drift from it.
    static func series(
        for sets: [RecordSetInput],
        /// The variation to chart, every axis stated. A nil preset, or
        /// `.unrecorded` equipment, charts sets logged with none — a real
        /// group, not "all of them" (D36).
        variation: ProgressVariationKey,
        calendar: Calendar = .current
    ) -> ProgressSeries {
        let loadType = variation.loadType
        // FILTER TO ONE CLASSIFICATION, then judge within it.
        //
        // codex-review 2 (critical): this used to accept whatever it was
        // handed, so a chart mixed every snapshot load type and every preset
        // for an exercise, and `outranks` then compared them using each
        // CANDIDATE's own direction. After a load-type correction, old weighted
        // sets were ranked as assistance; narrow- and wide-grip bests were
        // pooled, which D36 exists to prevent because one variation could then
        // set a record the other can never beat.
        //
        // The series is now scoped the way a record group is: one load type,
        // one piece of equipment, one preset.
        // `presetID` nil means "sets logged with NO preset" — its own group,
        // exactly as `RecordsMath.groupKeys` treats it. It is NOT a wildcard.
        //
        // It was written as one (`presetID == nil || …`), so a chart opened
        // without a preset pooled narrow- and wide-grip history into a single
        // line — the pooling D36 exists to forbid, and the opposite of what
        // this function's own caller documented. Contract and caller
        // disagreed; the caller won, silently.
        let eligible = sets
            .filter { $0.loadType == loadType }
            .filter {
                ProgressEquipment(machineID: $0.machineID, freeWeightTag: $0.freeWeightTag)
                    == variation.equipment
            }
            .filter { $0.presetID == variation.presetID }
            .filter { RecordsMath.isEligible($0) }
        // Grouped by calendar DAY, which is not identical to "session": two
        // workouts in one day collapse to a point, and one workout spanning
        // midnight becomes two (codex-review 2). Day is still the right x-axis
        // for a progression chart — the naming is what was wrong, and
        // `ProgressConfidence` now says "days" rather than claiming sessions.
        let byDay = Dictionary(grouping: eligible) { set -> Date in
            calendar.startOfDay(for: set.completedAt ?? .distantPast)
        }

        let points = byDay.keys.sorted().compactMap { day -> ProgressPoint? in
            guard let daySets = byDay[day], !daySets.isEmpty else { return nil }
            // `outranks` owns the direction, so assisted ranks least-assistance
            // best without this file knowing why.
            let best: RecordSetInput
            if loadType == .bodyweight {
                // Most reps wins, matching `RecordsMath.mostRepsRecord`.
                best = daySets.dropFirst().reduce(daySets[0]) { incumbent, candidate in
                    (candidate.reps ?? 0) > (incumbent.reps ?? 0) ? candidate : incumbent
                }
            } else {
                best = daySets.dropFirst().reduce(daySets[0]) { incumbent, candidate in
                    RecordsMath.outranks(candidate, incumbent) ? candidate : incumbent
                }
            }
            // D20: plain bodyweight has no load, so its progression is MOST
            // REPS. Plotting `normalizedKg` — nil for bodyweight — drew an
            // empty chart under an axis labelled "Reps (kg)"
            // (codex-review 2, high).
            let plotted: Double? = loadType == .bodyweight
                ? best.reps.map(Double.init)
                : best.normalizedKg
            return ProgressPoint(
                date: day,
                bestKg: plotted,
                bestReps: best.reps,
                bestValue: best.weightValue,
                bestUnit: best.weightUnit,
                volumeKg: RecordsMath.totalVolumeKg(among: daySets),
                e1rmKg: RecordsMath.bestE1RM(among: daySets)?.e1RMKg)
        }

        return ProgressSeries(
            points: points,
            loadType: loadType,
            confidence: confidence(days: points.count))
    }

    static func confidence(days sessions: Int) -> ProgressConfidence {
        switch sessions {
        case 0: .empty
        case 1: .single
        default: .series(days: sessions)
        }
    }

    /// Change between the first and last point of a series, as a fraction.
    ///
    /// Returns nil for a series too short to have a direction, and nil when the
    /// baseline is zero — a "percentage improvement" over nothing is a division
    /// the app would be inventing.
    static func change(_ series: ProgressSeries) -> Double? {
        guard case .series = series.confidence,
              let first = series.points.first?.bestKg,
              let last = series.points.last?.bestKg,
              first != 0
        else { return nil }
        let raw = (last - first) / abs(first)
        // Assisted improves DOWNWARD, so a drop in assistance is progress.
        return series.higherIsBetter ? raw : -raw
    }
}


/// The words a picker has for one variation, resolved from SNAPSHOTS by the
/// caller (D23). Pure data so the labelling rule can be tested without a view.
struct ProgressVariationWords: Equatable, Sendable {
    var loadType: LoadType
    var equipment: ProgressEquipment
    /// "Dumbbell", the frozen machine label, or nil for unrecorded equipment.
    var equipmentName: String?
    /// The frozen gym name of a machine, used only to tell two machines with
    /// the same label apart.
    var gymName: String?
    /// The frozen preset name, nil for the plain exercise.
    var presetName: String?
}

extension ProgressSeriesMath {

    /// How much of a variation's words a label spends. Terse by default; a
    /// colliding row escalates one stage at a time, in this order.
    enum LabelStage: Int, CaseIterable, Comparable {
        case terse, equipment, loadType, gym
        static func < (l: Self, r: Self) -> Bool { l.rawValue < r.rawValue }
        var next: LabelStage { LabelStage(rawValue: rawValue + 1) ?? .gym }
    }

    /// One label per variation, and NO two the same.
    ///
    /// codex-review 01b: hiding "No equipment recorded" behind a preset name
    /// let a preset the user had called "Dumbbell" render identically to the
    /// dumbbell tag, and two machines with the same frozen label collided too.
    /// So: start terse, and only where labels collide add discriminators —
    /// the equipment word, then the load type, then the machine's gym. When
    /// the stages are spent, ordinals — allocated against EVERY label in the
    /// list, including user-typed names that already look like "X (2)"
    /// (codex-review 01c), so the floor cannot itself create a duplicate.
    static func labels(
        for rows: [(key: ProgressVariationKey, words: ProgressVariationWords)]
    ) -> [ProgressVariationKey: String] {
        func render(_ w: ProgressVariationWords, at stage: LabelStage) -> String {
            var parts: [String] = []
            switch w.equipment {
            case .unrecorded:
                if w.presetName == nil || stage >= .equipment { parts.append("No equipment recorded") }
            default:
                parts.append(w.equipmentName ?? "Machine")
            }
            if let preset = w.presetName { parts.append(preset) }
            if stage >= .loadType { parts.append(w.loadType.badge) }
            if stage >= .gym, case .machine = w.equipment, let gym = w.gymName { parts.append(gym) }
            return parts.joined(separator: " · ")
        }
        func collisions(in labels: [ProgressVariationKey: String]) -> Set<ProgressVariationKey> {
            let counts = Dictionary(grouping: labels.values) { $0 }.mapValues(\.count)
            return Set(labels.filter { (counts[$0.value] ?? 0) > 1 }.keys)
        }

        var stage = [ProgressVariationKey: LabelStage](
            uniqueKeysWithValues: rows.map { ($0.key, .terse) })
        var out: [ProgressVariationKey: String] = [:]
        // Escalate colliding rows until nothing collides or every colliding
        // row is at the last stage. Raising some rows can collide with an
        // untouched one; the loop re-checks the whole set each pass.
        while true {
            out = Dictionary(uniqueKeysWithValues: rows.map {
                ($0.key, render($0.words, at: stage[$0.key] ?? .terse))
            })
            let colliding = collisions(in: out)
            let raisable = colliding.filter { (stage[$0] ?? .gym) < .gym }
            if raisable.isEmpty { break }
            for key in raisable { stage[key] = stage[key]?.next }
        }
        // Ordinal floor. Suffixes are chosen against the complete set of
        // labels as they stand, so "(2)" is skipped when a user already named
        // something exactly that. Each assignment joins the set before the
        // next is chosen, so three-way collisions get (2) and (3).
        var taken = Set(out.values)
        let stillColliding = collisions(in: out)
        var kept: Set<String> = []
        for row in rows where stillColliding.contains(row.key) {
            guard let label = out[row.key] else { continue }
            // The first row carrying a colliding label keeps it; the rest move.
            if kept.insert(label).inserted { continue }
            var n = 2
            while taken.contains("\(label) (\(n))") { n += 1 }
            let fresh = "\(label) (\(n))"
            out[row.key] = fresh
            taken.insert(fresh)
        }
        return out
    }
}
