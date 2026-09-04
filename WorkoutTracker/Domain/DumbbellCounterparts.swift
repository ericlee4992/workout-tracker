import Foundation

// Milestone 9, ticket 04 — which catalog exercise a dumbbell-tagged set of a
// barbell/machine movement actually was.
//
// Until catalog version 5 the catalog had ONE dumbbell exercise, so a dumbbell
// bench press was logged as "Bench Press" with the Dumbbell equipment tag. The
// user asked for separate exercises. This table is the bridge: it drives the
// one-time history move (`DumbbellHistoryMove`) and the equipment sheet's
// "Log as Dumbbell Bench Press instead" row, so the split cannot re-grow.
//
// Keyed by catalog UUID, never by name: names are allowlisted-mutable seeded
// fields (D24); the ids are fixed forever.

enum DumbbellCounterparts {

    struct Pair: Equatable {
        /// The exercise a dumbbell-tagged set used to be logged under.
        let source: UUID
        /// The dumbbell exercise it belongs to since catalog version 5.
        let target: UUID
        /// The target's catalog name, for a sheet that must name the
        /// counterpart even when the row is momentarily missing from the
        /// store. The store's row is authoritative when present.
        let targetName: String
    }

    private static func id(_ index: Int) -> UUID {
        UUID(uuidString: String(format: "5EED0001-0000-4000-8000-%012d", index))!
    }

    /// One target per source, one source per target. A movement with no
    /// honest dumbbell counterpart (Deadlift, Squat, Preacher Curl) is
    /// deliberately absent: a dumbbell-tagged Deadlift is not necessarily a
    /// Romanian deadlift, and guessing would be the fabricated context D23
    /// exists to prevent. Those sets stay where they are, tagged Dumbbell.
    static let pairs: [Pair] = [
        Pair(source: id(6), target: id(77), targetName: "Dumbbell Bench Press"),      // from Bench Press
        Pair(source: id(17), target: id(78), targetName: "Dumbbell Incline Press"),    // from Incline Bench Press
        Pair(source: id(18), target: id(79), targetName: "Dumbbell Decline Press"),    // from Decline Bench Press
        Pair(source: id(15), target: id(80), targetName: "Dumbbell Fly"),              // from Chest Fly (Pec Deck)
        Pair(source: id(34), target: id(82), targetName: "Dumbbell Shoulder Press"),   // from Overhead Press
        Pair(source: id(32), target: id(83), targetName: "Dumbbell Lateral Raise"),    // from Lateral Raise
        Pair(source: id(26), target: id(84), targetName: "Dumbbell Row"),              // from Bent-Over Row
        Pair(source: id(27), target: id(85), targetName: "Dumbbell Shrug"),            // from Shrug
        Pair(source: id(56), target: id(87), targetName: "Dumbbell Lunge"),            // from Lunge
        Pair(source: id(59), target: id(90), targetName: "Dumbbell Hip Thrust"),       // from Hip Thrust
    ]

    private static let pairBySource = Dictionary(
        uniqueKeysWithValues: pairs.map { ($0.source, $0) })

    /// Every source id — the cheap pre-check the launch-time move uses.
    static var sourceIDs: Set<UUID> { Set(pairs.map(\.source)) }

    /// The dumbbell exercise a dumbbell-tagged set of `exerciseID` belongs
    /// to, or nil when the movement has no counterpart.
    static func counterpart(of exerciseID: UUID) -> UUID? {
        pairBySource[exerciseID]?.target
    }

    static func pair(forSource exerciseID: UUID) -> Pair? {
        pairBySource[exerciseID]
    }
}
