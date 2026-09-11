import Foundation

/// The five muscle families a template tile shows an icon for (UI redesign
/// ticket 11): the user asked for icons "only for muscle group (either
/// chest, back, arm, shoulder or leg), based on the exercises in the
/// template" — not one per exercise, not the 14 seeded `muscleGroup` values.
///
/// Pure: the mapping from the seeded vocabulary (`BodyArea.order`) to a
/// family, and the ordered, deduplicated families of a set of groups.
/// Core, Neck and Full Body map to no family — the user named five.
enum MuscleFamily: String, CaseIterable, Hashable, Sendable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case arms = "Arms"
    case legs = "Legs"

    /// The seeded `muscleGroup` vocabulary, each to its family.
    static let byGroup: [String: MuscleFamily] = [
        "Chest": .chest,
        "Back": .back,
        "Shoulders": .shoulders,
        "Biceps": .arms, "Triceps": .arms, "Forearms": .arms,
        "Quads": .legs, "Hamstrings": .legs, "Glutes": .legs, "Hips": .legs, "Calves": .legs,
    ]

    init?(muscleGroup: String?) {
        guard let muscleGroup, let family = MuscleFamily.byGroup[muscleGroup] else { return nil }
        self = family
    }

    /// The families present in `groups`, each once, in `allCases` order
    /// (head to toe) — never in the order the exercises happen to sit.
    static func families(of groups: [String?]) -> [MuscleFamily] {
        let present = Set(groups.compactMap { MuscleFamily(muscleGroup: $0) })
        return allCases.filter { present.contains($0) }
    }
}
