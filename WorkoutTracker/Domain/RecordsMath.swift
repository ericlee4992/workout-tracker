import Foundation

// Ticket 12 — records computation core (D17/D20/D21/D23). Pure logic: no UI,
// no SwiftData. Operates on plain values mirroring completed-set snapshots —
// callers map SetRecord/ExerciseEntry rows into `RecordSetInput`; this file
// never touches live catalog rows (D23).
//
// Per load type (D20):
// - weighted:       best weight per rep count (1–12) + Brzycki e1RM
// - assisted:       least assistance per rep count, no e1RM
// - bodyweightPlus: most added weight per rep count, no e1RM
// - bodyweight:     most reps, uncapped, no e1RM
// Comparisons use normalizedKg; results carry the as-entered (value, unit)
// for display. Ties resolve to the earliest achieving set.

// MARK: - Inputs

/// Plain-value mirror of one logged set plus its entry's context snapshot.
/// Grouping fields come from the entry's snapshot (D23), never live rows.
struct RecordSetInput: Equatable {
    var loadType: LoadType
    var exerciseID: UUID
    var machineID: UUID?
    var modelID: UUID?
    var freeWeightTag: EquipmentTag?
    var setType: SetType
    var reps: Int?
    /// As-entered load; for assisted this is the assistance weight, for
    /// bodyweightPlus the added weight. nil while drafting.
    var weightValue: Double?
    var weightUnit: WeightUnit
    /// Canonical kg derived atomically from (weightValue, weightUnit) (D25).
    var normalizedKg: Double?
    /// nil = not completed; only completed sets feed records/volume.
    var completedAt: Date?
}

// MARK: - Results

/// One record-table cell: the achieving set's reps, its as-entered load
/// (nil for plain bodyweight, where load is ignored), and when it happened.
struct RecordAchievement: Equatable {
    let reps: Int
    let weightValue: Double?
    let weightUnit: WeightUnit?
    let normalizedKg: Double?
    let completedAt: Date
}

/// Best Brzycki estimate plus the set that produced it (weighted only, D20).
struct E1RMRecord: Equatable {
    let e1RMKg: Double
    let reps: Int
    let weightValue: Double
    let weightUnit: WeightUnit
    let normalizedKg: Double
    let completedAt: Date
}

/// Snapshot-derived grouping keys (D23). A machineless entry is keyed by
/// (exercise, freeWeightTag) so barbell and dumbbell records never merge.
enum RecordGroupKey: Hashable {
    case machine(UUID)
    case model(UUID)
    case exercise(UUID)
    case freeWeight(exerciseID: UUID, tag: EquipmentTag?)
}

// MARK: - Records math

enum RecordsMath {

    /// D17: rep-count records and e1RM stop at 12 reps (weight-keyed tables
    /// only — bodyweight most-reps is uncapped).
    static let repRecordCap = 12

    // MARK: Eligibility

    /// Load-type-specific eligibility: completed, positive reps, warmups out,
    /// failure in; load finite and — weighted: > 0; assisted: ≥ 0 (0 =
    /// unassisted); bodyweightPlus: ≥ 0 (0 = plain); bodyweight: load ignored.
    static func isEligible(_ set: RecordSetInput) -> Bool {
        guard set.completedAt != nil,
              let reps = set.reps, reps > 0,
              set.setType != .warmup
        else { return false }

        switch set.loadType {
        case .bodyweight:
            return true
        case .weighted:
            guard let kg = eligibleLoadKg(of: set) else { return false }
            return kg > 0
        case .assisted, .bodyweightPlus:
            return eligibleLoadKg(of: set) != nil
        }
    }

    /// Finite, non-negative normalized load with its as-entered value present;
    /// nil when the set has no usable load.
    private static func eligibleLoadKg(of set: RecordSetInput) -> Double? {
        guard set.weightValue != nil,
              let kg = set.normalizedKg, kg.isFinite, kg >= 0
        else { return nil }
        return kg
    }

    // MARK: Ranking

    /// Whether `candidate` beats `incumbent` for record purposes. Both are
    /// assumed eligible and of the same (candidate's) load type. Load ranks
    /// first via normalizedKg — direction per load type (assisted: lower is
    /// better) — then more reps, then the earlier `completedAt` (tie rule).
    static func outranks(_ candidate: RecordSetInput, _ incumbent: RecordSetInput) -> Bool {
        guard let candidateReps = candidate.reps, let incumbentReps = incumbent.reps,
              let candidateDate = candidate.completedAt, let incumbentDate = incumbent.completedAt
        else { return false }

        switch candidate.loadType {
        case .bodyweight:
            break // Load ignored; reps decide.
        case .weighted, .bodyweightPlus, .assisted:
            guard let candidateKg = candidate.normalizedKg,
                  let incumbentKg = incumbent.normalizedKg
            else { return false }
            if candidateKg != incumbentKg {
                let lowerIsBetter = candidate.loadType == .assisted
                return lowerIsBetter ? candidateKg < incumbentKg : candidateKg > incumbentKg
            }
        }
        if candidateReps != incumbentReps { return candidateReps > incumbentReps }
        return candidateDate < incumbentDate
    }

    // MARK: Rep-count tables (weight-keyed load types)

    /// Best set per rep count (1–12) among sets whose snapshot load type is
    /// `loadType`: weighted → heaviest, assisted → least assistance,
    /// bodyweightPlus → most added. Empty for `bodyweight` — that load type
    /// has no weight-keyed table (use `mostRepsRecord`).
    static func repCountBests(
        among sets: [RecordSetInput], loadType: LoadType
    ) -> [Int: RecordAchievement] {
        guard loadType != .bodyweight else { return [:] }
        var bests: [Int: RecordSetInput] = [:]
        for set in sets where set.loadType == loadType && isEligible(set) {
            guard let reps = set.reps, reps <= repRecordCap else { continue }
            if let incumbent = bests[reps], !outranks(set, incumbent) { continue }
            bests[reps] = set
        }
        return bests.compactMapValues(achievement(from:))
    }

    /// Most-reps record among plain-bodyweight sets — uncapped (D20).
    static func mostRepsRecord(among sets: [RecordSetInput]) -> RecordAchievement? {
        var best: RecordSetInput?
        for set in sets where set.loadType == .bodyweight && isEligible(set) {
            if let incumbent = best, !outranks(set, incumbent) { continue }
            best = set
        }
        return best.flatMap(achievement(from:))
    }

    /// Result cell for an eligible set; nil only on malformed input.
    private static func achievement(from set: RecordSetInput) -> RecordAchievement? {
        guard let reps = set.reps, let completedAt = set.completedAt else { return nil }
        let carriesLoad = set.loadType != .bodyweight
        return RecordAchievement(
            reps: reps,
            weightValue: carriesLoad ? set.weightValue : nil,
            weightUnit: carriesLoad ? set.weightUnit : nil,
            normalizedKg: carriesLoad ? set.normalizedKg : nil,
            completedAt: completedAt
        )
    }

    // MARK: Brzycki e1RM (weighted only, D17/D20)

    /// Brzycki estimate `weight / (1.0278 − 0.0278 × reps)` in kg. nil outside
    /// 1...12 reps (estimates degrade past 12, D17) or for a non-positive load.
    static func brzyckiE1RMKg(weightKg: Double, reps: Int) -> Double? {
        guard (1...repRecordCap).contains(reps), weightKg.isFinite, weightKg > 0
        else { return nil }
        return weightKg / (1.0278 - 0.0278 * Double(reps))
    }

    /// Best Brzycki e1RM among eligible weighted sets of ≤ 12 reps; ties by
    /// estimate resolve to the earliest set. nil when nothing qualifies.
    static func bestE1RM(among sets: [RecordSetInput]) -> E1RMRecord? {
        var best: (set: RecordSetInput, e1RMKg: Double, completedAt: Date)?
        for set in sets where set.loadType == .weighted && isEligible(set) {
            guard let reps = set.reps, let kg = set.normalizedKg,
                  let completedAt = set.completedAt,
                  let e1RMKg = brzyckiE1RMKg(weightKg: kg, reps: reps)
            else { continue }
            if let incumbent = best,
               !(e1RMKg > incumbent.e1RMKg
                 || (e1RMKg == incumbent.e1RMKg && completedAt < incumbent.completedAt)) {
                continue
            }
            best = (set, e1RMKg, completedAt)
        }
        guard let best, let reps = best.set.reps,
              let weightValue = best.set.weightValue, let normalizedKg = best.set.normalizedKg
        else { return nil }
        return E1RMRecord(
            e1RMKg: best.e1RMKg,
            reps: reps,
            weightValue: weightValue,
            weightUnit: best.set.weightUnit,
            normalizedKg: normalizedKg,
            completedAt: best.completedAt
        )
    }

    // MARK: Volume (D21)

    /// Σ(normalizedKg × reps) over eligible working+failure sets of weighted
    /// exercises only. Dumbbell sets are logged per-hand and summed as
    /// labeled — no equipment special-casing, so nothing is doubled.
    /// Assisted/bodyweight/bodyweightPlus contribute nothing.
    static func totalVolumeKg(among sets: [RecordSetInput]) -> Double {
        sets.reduce(0) { total, set in
            guard set.loadType == .weighted, isEligible(set),
                  let reps = set.reps, let kg = set.normalizedKg
            else { return total }
            return total + kg * Double(reps)
        }
    }

    // MARK: Grouping (D23)

    /// Every record group this set belongs to, from snapshot values only:
    /// always the exercise; the machine and model when machined; and for
    /// machineless entries, (exercise, freeWeightTag).
    static func groupKeys(for set: RecordSetInput) -> Set<RecordGroupKey> {
        var keys: Set<RecordGroupKey> = [.exercise(set.exerciseID)]
        if let machineID = set.machineID {
            keys.insert(.machine(machineID))
        } else {
            keys.insert(.freeWeight(exerciseID: set.exerciseID, tag: set.freeWeightTag))
        }
        if let modelID = set.modelID {
            keys.insert(.model(modelID))
        }
        return keys
    }

    /// Sets bucketed under every group key each belongs to (a set appears in
    /// multiple buckets: its machine, model, exercise, and tag scopes).
    static func grouped(_ sets: [RecordSetInput]) -> [RecordGroupKey: [RecordSetInput]] {
        var groups: [RecordGroupKey: [RecordSetInput]] = [:]
        for set in sets {
            for key in groupKeys(for: set) {
                groups[key, default: []].append(set)
            }
        }
        return groups
    }
}
