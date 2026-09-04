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
        Pair(source: id(6), target: id(77)),   // Bench Press → Dumbbell Bench Press
        Pair(source: id(17), target: id(78)),  // Incline Bench Press → Dumbbell Incline Press
        Pair(source: id(18), target: id(79)),  // Decline Bench Press → Dumbbell Decline Press
        Pair(source: id(15), target: id(80)),  // Chest Fly (Pec Deck) → Dumbbell Fly
        Pair(source: id(34), target: id(82)),  // Overhead Press → Dumbbell Shoulder Press
        Pair(source: id(32), target: id(83)),  // Lateral Raise → Dumbbell Lateral Raise
        Pair(source: id(26), target: id(84)),  // Bent-Over Row → Dumbbell Row
        Pair(source: id(27), target: id(85)),  // Shrug → Dumbbell Shrug
        Pair(source: id(56), target: id(87)),  // Lunge → Dumbbell Lunge
        Pair(source: id(59), target: id(90)),  // Hip Thrust → Dumbbell Hip Thrust
    ]

    private static let targetBySource = Dictionary(
        uniqueKeysWithValues: pairs.map { ($0.source, $0.target) })

    /// The dumbbell exercise a dumbbell-tagged set of `exerciseID` belongs
    /// to, or nil when the movement has no counterpart.
    static func counterpart(of exerciseID: UUID) -> UUID? {
        targetBySource[exerciseID]
    }
}
