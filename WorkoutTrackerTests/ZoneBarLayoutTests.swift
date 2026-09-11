import CoreGraphics
import Testing
@testable import WorkoutTracker

/// UI redesign ticket 03 — the zone bar never spills past its card.
struct ZoneBarLayoutTests {
    private func sum(_ widths: [CGFloat]) -> CGFloat { widths.reduce(0, +) }

    @Test func oneZoneTakesTheWholeWidth() {
        #expect(ZoneBarLayout.widths(values: [600], width: 300) == [300])
    }

    @Test func sharesAreProportionalAndSumToWidthMinusGaps() {
        let widths = ZoneBarLayout.widths(values: [300, 100], width: 302)
        #expect(widths == [225, 75])
        #expect(sum(widths) == 300)
    }

    @Test func aOneSecondZoneBesideAnHourIsAVisibleSliverAndNothingSpills() {
        let widths = ZoneBarLayout.widths(values: [3599, 1], width: 300)
        #expect(widths[1] == 4)
        #expect(abs(sum(widths) - 298) < 0.001, "width minus one gap")
    }

    @Test func manySliversArePaidForByTheLargestSegment() {
        let widths = ZoneBarLayout.widths(values: [3595, 1, 1, 1, 1, 1], width: 300)
        #expect(widths.dropFirst().allSatisfy { $0 == 4 })
        #expect(abs(sum(widths) - (300 - 5 * 2)) < 0.001)
    }

    @Test func anUnaffordableMinimumCollapsesToAnEvenSplit() {
        let widths = ZoneBarLayout.widths(values: [1, 1, 1, 1], width: 10)
        #expect(widths.allSatisfy { abs($0 - 1) < 0.001 }, "10 − 3 gaps = 7 shared four ways, floor 1.75 → even")
        #expect(abs(sum(widths) - 4) < 0.001)
    }

    @Test func emptyAndDegenerateInputs() {
        #expect(ZoneBarLayout.widths(values: [], width: 300).isEmpty)
        #expect(ZoneBarLayout.widths(values: [10], width: 0).isEmpty)
        #expect(ZoneBarLayout.widths(values: [0, 0], width: 100) == [49, 49], "all-zero splits evenly")
    }
}
