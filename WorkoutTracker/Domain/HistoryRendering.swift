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
        let equipment: String
        if let machineLabel = snapshotMachineLabel {
            equipment = "\(machineLabel) · \(snapshotModelName ?? "unknown model")"
        } else {
            equipment = snapshotFreeWeightTag?.label ?? "No equipment"
        }
        // The variation is part of what was performed (D36), and it is
        // snapshotted like everything else here — renaming a preset later must
        // not retitle last month's sets.
        guard let preset = snapshotPresetName, !preset.isEmpty else { return equipment }
        return "\(equipment) · \(preset)"
    }
}

/// One exercise as history knows it: the snapshot ID that decides identity
/// and the snapshot name that gets displayed (D23). Two different exercises
/// that happen to share a display name are still two exercises.
struct HistoryExercise: Equatable {
    var id: UUID
    var name: String

    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
}

/// Ticket 17 E1–E3 — the words a history row is made of, kept here so they
/// can be tested without a view. Rows used to be headlined by the gym (every
/// workout at one gym indistinguishable), count "1 exercises", and flatten
/// every sub-minute workout to "0 min".
enum HistoryRendering {

    /// Headline for a workout with nothing to name it after.
    static let untitledWorkout = "Workout"

    /// E1: what a workout is called in History. The template it started from
    /// names it; otherwise the exercises performed do ("Chest Press +2"); a
    /// workout with neither gets the neutral fallback. The gym is the
    /// subtitle, never the title — it is what workouts have in common, not
    /// what tells them apart.
    ///
    /// `templateName` and `exercises` must both come from SNAPSHOTS (D23), so
    /// a later rename, deletion, or model correction cannot retitle a finished
    /// workout. Repeats are collapsed by snapshot exercise ID, never by
    /// display name — two distinct exercises may legitimately share one.
    ///
    /// `name` is what the user typed (milestone 9, ticket 02) and wins when it
    /// is non-blank; it is stored on the workout itself, so it is already frozen.
    static func title(
        name: String? = nil, templateName: String?, exercises: [HistoryExercise]
    ) -> String {
        if let name {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        if let templateName {
            let trimmed = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        var seen = Set<UUID>()
        let names = exercises
            .filter { seen.insert($0.id).inserted }
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let first = names.first else { return untitledWorkout }
        return names.count == 1 ? first : "\(first) +\(names.count - 1)"
    }

    /// E2: a count that agrees with its noun — never "1 exercises".
    static func pluralized(_ count: Int, _ singular: String, _ plural: String) -> String {
        "\(count) \(count == 1 ? singular : plural)"
    }

    /// E3: sub-minute workouts are not all "0 min" — a 14-second mistake and
    /// a 45-second finisher have to be tellable apart. Minutes above a minute.
    static func durationLabel(_ duration: TimeInterval) -> String {
        let seconds = max(0, Int(duration))
        return seconds < 60 ? "\(seconds)s" : "\(seconds / 60) min"
    }

    /// The stats line of a history row: exercises · sets · duration.
    static func statsLine(
        exerciseCount: Int,
        setCount: Int,
        duration: TimeInterval?
    ) -> String {
        var parts = [
            pluralized(exerciseCount, "exercise", "exercises"),
            pluralized(setCount, "set", "sets"),
        ]
        if let duration { parts.append(durationLabel(duration)) }
        return parts.joined(separator: " · ")
    }
}

extension Workout {
    /// Elapsed time from start to finish; nil while the workout is active.
    var duration: TimeInterval? {
        finishedAt.map { max(0, $0.timeIntervalSince(startedAt)) }
    }

    /// Rendered duration (E3); nil while the workout is active.
    var durationLabel: String? {
        duration.map(HistoryRendering.durationLabel)
    }

    /// Completed sets across all entries (entry order, then set order).
    var completedSets: [SetRecord] {
        WorkoutSession.orderedEntries(of: self)
            .flatMap { WorkoutSession.orderedSets(of: $0) }
            .filter { $0.completedAt != nil }
    }

    /// Snapshot exercises in entry order (D23) — the live `exercise`
    /// relationship is deliberately not consulted.
    var snapshotExercises: [HistoryExercise] {
        WorkoutSession.orderedEntries(of: self).map {
            HistoryExercise(id: $0.snapshotExerciseID, name: $0.snapshotExerciseName)
        }
    }

    /// E1: the row headline, sourced entirely from snapshots (D23) — the
    /// template name captured when the workout started, else the exercises
    /// performed. Renaming or deleting the template afterwards leaves this
    /// row alone; it is a record of what happened, not a live view of the
    /// library.
    var historyTitle: String {
        HistoryRendering.title(
            name: name, templateName: sourceTemplateName, exercises: snapshotExercises)
    }

    /// The title this workout would have with NO typed name — what the name
    /// field shows as its placeholder, so an empty field never reads as blank.
    var derivedTitle: String {
        HistoryRendering.title(
            name: nil, templateName: sourceTemplateName, exercises: snapshotExercises)
    }

    /// Gym label for history: the name captured at log time (D23) — the
    /// entry snapshots first, then the workout's own start-time snapshot. The
    /// live `gym` relationship is never consulted, so renaming a gym cannot
    /// rewrite the workouts already logged there.
    var historyGymName: String? {
        WorkoutSession.orderedEntries(of: self)
            .compactMap(\.snapshotGymName).first ?? snapshotGymName
    }
}
