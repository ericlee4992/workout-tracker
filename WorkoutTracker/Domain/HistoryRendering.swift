import Foundation

// Ticket 09 — history rendering domain logic. Pure derivations over the
// persisted models: no UI imports, unit-tested.

/// Unit badge for a workout summary, derived from the units of the actual
/// logged sets — never just the gym default (SPEC "Units").
enum WorkoutUnitBadge: Equatable {
    case single(WeightUnit)
    case mixed

    var label: String {
        switch self {
        case .single(let unit): unit.rawValue
        case .mixed: "Mixed"
        }
    }

    /// Badge over a list of set units: all one unit → that unit, otherwise
    /// Mixed. nil when there are no units to derive from.
    static func derive(fromUnits units: [WeightUnit]) -> WorkoutUnitBadge? {
        guard let first = units.first else { return nil }
        return units.allSatisfy { $0 == first } ? .single(first) : .mixed
    }

    /// Badge for a set list. Only completed sets count — drafts never reach
    /// history (Finish deletes them), and they carry no logged weight.
    static func derive(fromCompleted sets: [SetRecord]) -> WorkoutUnitBadge? {
        derive(fromUnits: sets.filter { $0.completedAt != nil }.map(\.weightUnit))
    }
}

extension ExerciseEntry {
    /// History equipment label rendered from snapshot display strings ONLY
    /// (D23) — never the live MachineInstance/EquipmentModel relationships,
    /// so later renames, model corrections, or archival never rewrite what a
    /// finished workout shows.
    var snapshotEquipmentLabel: String {
        if let machineLabel = snapshotMachineLabel {
            return "\(machineLabel) · \(snapshotModelName ?? "unknown model")"
        }
        return snapshotFreeWeightTag?.label ?? "No equipment"
    }
}

extension Workout {
    /// Whole minutes from start to finish; nil while the workout is active.
    var durationMinutes: Int? {
        finishedAt.map { max(0, Int($0.timeIntervalSince(startedAt)) / 60) }
    }

    /// Completed sets across all entries (entry order, then set order).
    var completedSets: [SetRecord] {
        WorkoutSession.orderedEntries(of: self)
            .flatMap { WorkoutSession.orderedSets(of: $0) }
            .filter { $0.completedAt != nil }
    }
}
