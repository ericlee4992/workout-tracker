import Foundation
import Testing
@testable import WorkoutTracker

// Floodlight redesign — "New best" / "First time" on live sets. Warmups never count, assisted is
// lower-is-better, a tie is not a best, and the first workout in a scope shows "First time" once
// and never "New best".

struct SetBadgeTests {
    private let exercise = UUID()
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func set(_ kg: Double?, _ reps: Int, _ minute: Int, type: SetType = .working,
                     load: LoadType = .weighted, completed: Bool = true) -> RecordSetInput {
        RecordSetInput(loadType: load, exerciseID: exercise, gymID: nil, machineID: nil, modelID: nil,
                       freeWeightTag: nil, presetID: nil, setType: type, reps: reps,
                       weightValue: kg, weightUnit: .kg, normalizedKg: kg,
                       completedAt: completed ? t0.addingTimeInterval(Double(minute) * 60) : nil)
    }

    private func ids(_ n: Int) -> [UUID] { (0..<n).map { _ in UUID() } }

    @Test func beatingHistoryIsANewBestAndATieIsNot() {
        let history = [set(100, 8, -1000), set(105, 6, -900)]
        let id = ids(4)
        let badges = SetBadgeMath.badges(current: [
            (id[0], set(100, 10, 1)),   // lighter than 105: not a best
            (id[1], set(105, 6, 2)),    // ties the record: not a best
            (id[2], set(105, 8, 3)),    // same load, more reps: best
            (id[3], set(110, 8, 4)),    // heavier: best
        ], history: history)
        #expect(badges == [id[2]: .newBest, id[3]: .newBest])
    }

    @Test func earlierSetsInThisWorkoutRaiseTheBar() {
        let id = ids(2)
        let badges = SetBadgeMath.badges(current: [(id[0], set(120, 5, 1)), (id[1], set(115, 5, 2))],
                                         history: [set(110, 5, -500)])
        #expect(badges == [id[0]: .newBest])
    }

    @Test func warmupsAndIncompleteSetsNeverCount() {
        let id = ids(3)
        let badges = SetBadgeMath.badges(current: [
            (id[0], set(200, 5, 1, type: .warmup)),
            (id[1], set(200, 5, 2, completed: false)),
            (id[2], set(101, 5, 3, type: .drop)),
        ], history: [set(100, 5, -500), set(300, 5, -400, type: .warmup)])
        #expect(badges == [id[2]: .newBest])
    }

    @Test func assistedIsLowerIsBetter() {
        let id = ids(2)
        let badges = SetBadgeMath.badges(current: [
            (id[0], set(30, 8, 1, load: .assisted)),
            (id[1], set(20, 8, 2, load: .assisted)),
        ], history: [set(25, 8, -500, load: .assisted)])
        #expect(badges == [id[1]: .newBest])
    }

    @Test func firstWorkoutMarksOnlyItsFirstSetAsFirstTime() {
        let id = ids(3)
        let badges = SetBadgeMath.badges(current: [
            (id[0], set(50, 10, 1, type: .warmup)),
            (id[1], set(60, 10, 2)),
            (id[2], set(70, 10, 3)),
        ], history: [])
        #expect(badges == [id[1]: .firstTime])
    }

    @Test func bodyweightRanksByReps() {
        let id = ids(2)
        let badges = SetBadgeMath.badges(current: [
            (id[0], set(nil, 12, 1, load: .bodyweight)),
            (id[1], set(nil, 15, 2, load: .bodyweight)),
        ], history: [set(nil, 12, -500, load: .bodyweight)])
        #expect(badges == [id[1]: .newBest])
    }
}
