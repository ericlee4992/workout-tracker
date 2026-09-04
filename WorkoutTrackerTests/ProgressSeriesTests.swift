import Foundation
import Testing

@testable import WorkoutTracker

/// Milestone 8, ticket 01 — the numbers behind the progress charts.
///
/// A chart is a confident picture. These pin the cases where a naive chart
/// would be confidently wrong: assisted progress drawn as decline, warmups
/// inflating volume, and a slope drawn between two dots.
struct ProgressSeriesTests {

    private let exerciseID = UUID()

    private func set(
        _ kg: Double, reps: Int = 8, day: Int,
        type: SetType = .working, loadType: LoadType = .weighted
    ) -> RecordSetInput {
        RecordSetInput(
            loadType: loadType, exerciseID: exerciseID, setType: type,
            reps: reps, weightValue: kg, weightUnit: .kg, normalizedKg: kg,
            completedAt: Date(timeIntervalSince1970: Double(day) * 86_400 + 43_200))
    }

    // MARK: - Direction, which is the thing a chart can get catastrophically wrong

    /// The user's own complaint, one domain over: assisted means LESS is
    /// better. A chart that plots falling assistance as a downward "decline"
    /// tells someone who is getting stronger that they are getting weaker.
    @Test func assistedProgressCountsDownwardAsImprovement() {
        let series = ProgressSeriesMath.series(
            for: [
                set(40, day: 1, loadType: .assisted),
                set(30, day: 8, loadType: .assisted),
                set(20, day: 15, loadType: .assisted),
            ],
            loadType: .assisted, presetID: nil)

        #expect(!series.higherIsBetter)
        let change = try? #require(ProgressSeriesMath.change(series))
        #expect((change ?? 0) > 0, "40kg → 20kg of assistance is a 50% IMPROVEMENT, got \(change ?? 0)")
        #expect(series.loadAxisLabel.contains("less is better"))
    }

    @Test func weightedProgressCountsUpwardAsImprovement() {
        let series = ProgressSeriesMath.series(
            for: [set(60, day: 1), set(70, day: 8)], loadType: .weighted, presetID: nil)
        #expect(series.higherIsBetter)
        let change = try? #require(ProgressSeriesMath.change(series))
        #expect((change ?? 0) > 0)
    }

    /// The best set of a day must use the same ranking the records screen uses,
    /// not a local "max" that ignores load type.
    @Test func theBestSetOfADayRespectsLoadTypeDirection() {
        let series = ProgressSeriesMath.series(
            for: [
                set(40, day: 1, loadType: .assisted),
                set(25, day: 1, loadType: .assisted),
                set(35, day: 1, loadType: .assisted),
            ],
            loadType: .assisted, presetID: nil)
        #expect(series.points.count == 1)
        #expect(series.points.first?.bestKg == 25, "least assistance is the day's best set")
    }

    // MARK: - Eligibility

    @Test func warmupsAreExcludedFromTheSeries() {
        let series = ProgressSeriesMath.series(
            for: [
                set(100, day: 1, type: .warmup),
                set(60, day: 1, type: .working),
            ],
            loadType: .weighted, presetID: nil)
        #expect(series.points.first?.bestKg == 60, "a warmup must not become the day's best set")
        #expect(series.points.first?.volumeKg == 480, "warmup volume must not be counted")
    }

    /// `RecordsMath.totalVolumeKg` is weighted-only. A chart that summed
    /// assistance as "volume lifted" would disagree with every other volume
    /// figure in the app.
    @Test func volumeIsWeightedOnly() {
        let series = ProgressSeriesMath.series(
            for: [set(30, day: 1, loadType: .assisted)], loadType: .assisted, presetID: nil)
        #expect(series.points.first?.volumeKg == 0)
    }

    // MARK: - Grouping and ordering

    @Test func setsAreGroupedByDayAndOrderedOldestFirst() {
        let series = ProgressSeriesMath.series(
            for: [set(70, day: 8), set(60, day: 1), set(65, day: 1)],
            loadType: .weighted, presetID: nil)
        #expect(series.points.count == 2)
        #expect(series.points[0].bestKg == 65, "same-day sets collapse to their best")
        #expect(series.points[0].date < series.points[1].date, "a chart reads left to right")
    }

    /// D9/D25: the tooltip shows what the user typed, not a converted value.
    @Test func aPointCarriesTheValueAsEntered() {
        let lb = RecordSetInput(
            loadType: .weighted, exerciseID: exerciseID, setType: .working,
            reps: 5, weightValue: 135, weightUnit: .lb, normalizedKg: 61.23,
            completedAt: Date(timeIntervalSince1970: 86_400))
        let series = ProgressSeriesMath.series(for: [lb], loadType: .weighted, presetID: nil)
        #expect(series.points.first?.bestValue == 135)
        #expect(series.points.first?.bestUnit == .lb)
    }

    // MARK: - Not claiming more than the data supports

    @Test func noSessionsIsEmptyRatherThanAZeroLine() {
        let series = ProgressSeriesMath.series(for: [], loadType: .weighted, presetID: nil)
        #expect(series.confidence == .empty)
        #expect(series.points.isEmpty)
        #expect(ProgressSeriesMath.change(series) == nil)
    }

    /// One point is not a trend, and two dots joined by a line invite the eye
    /// to read a slope that is not evidence.
    @Test func oneSessionIsMarkedAsASinglePointWithNoTrend() {
        let series = ProgressSeriesMath.series(for: [set(60, day: 1)], loadType: .weighted, presetID: nil)
        #expect(series.confidence == .single)
        #expect(ProgressSeriesMath.change(series) == nil, "one point has no direction")
    }

    @Test func aZeroBaselineYieldsNoPercentageRatherThanInfinity() {
        let series = ProgressSeriesMath.series(
            for: [
                set(0, day: 1, loadType: .bodyweightPlus),
                set(10, day: 8, loadType: .bodyweightPlus),
            ],
            loadType: .bodyweightPlus, presetID: nil)
        #expect(
            ProgressSeriesMath.change(series) == nil,
            "a percentage over a zero baseline is a division the app would be inventing")
    }

    @Test func e1rmIsWeightedOnly() {
        let weighted = ProgressSeriesMath.series(
            for: [set(100, reps: 5, day: 1)], loadType: .weighted, presetID: nil)
        #expect(weighted.points.first?.e1rmKg != nil)

        let assisted = ProgressSeriesMath.series(
            for: [set(30, reps: 5, day: 1, loadType: .assisted)], loadType: .assisted, presetID: nil)
        #expect(assisted.points.first?.e1rmKg == nil, "D20: no e1RM outside weighted")
    }
}

/// D36 in the charts, which had NO preset coverage at all until this defect.
///
/// The bug: `ProgressSeriesMath.series` read a nil `presetID` as "accept every
/// preset" while its caller documented nil as "only sets with no preset", and
/// `ExercisesView` passed nothing. So narrow- and wide-grip histories were
/// drawn as one line — the pooling D36 exists to forbid, because one variation
/// can then appear to set a record the other could never beat.
struct ChartPresetScopingTests {

    private let exerciseID = UUID()
    private let narrow = UUID()
    private let wide = UUID()

    private func set(
        _ kg: Double, day: Int, preset: UUID?, loadType: LoadType = .weighted
    ) -> RecordSetInput {
        RecordSetInput(
            loadType: loadType, exerciseID: exerciseID, presetID: preset,
            setType: .working, reps: 8, weightValue: kg, weightUnit: .kg,
            normalizedKg: kg, completedAt: Date(timeIntervalSince1970: Double(day) * 86_400))
    }

    private var mixed: [RecordSetInput] {
        [
            set(100, day: 1, preset: narrow),
            set(105, day: 8, preset: narrow),
            set(60, day: 2, preset: wide),
            set(65, day: 9, preset: wide),
            set(80, day: 3, preset: nil),
        ]
    }

    /// THE DEFECT. A chart of one variation must contain only that variation.
    @Test func aVariationsChartExcludesEveryOtherVariation() {
        let series = ProgressSeriesMath.series(
            for: mixed, loadType: .weighted, presetID: narrow)
        #expect(series.points.count == 2, "narrow grip has two days, got \(series.points.count)")
        #expect(series.points.allSatisfy { ($0.bestKg ?? 0) >= 100 },
                "a wide-grip set leaked into the narrow-grip chart")
    }

    /// nil is a REAL group — sets logged with no variation — not a wildcard.
    /// Reading it as a wildcard is exactly how the pooling happened.
    @Test func nilPresetMeansNoVariationRatherThanEveryVariation() {
        let series = ProgressSeriesMath.series(
            for: mixed, loadType: .weighted, presetID: nil)
        #expect(series.points.count == 1, "only the one no-preset day, got \(series.points.count)")
        #expect(series.points.first?.bestKg == 80)
    }

    @Test func eachVariationKeepsItsOwnBest() {
        let narrowSeries = ProgressSeriesMath.series(
            for: mixed, loadType: .weighted, presetID: narrow)
        let wideSeries = ProgressSeriesMath.series(
            for: mixed, loadType: .weighted, presetID: wide)
        #expect(narrowSeries.points.last?.bestKg == 105)
        #expect(
            wideSeries.points.last?.bestKg == 65,
            "wide grip's best must not be narrow grip's 105")
    }

    // MARK: - Choosing which variation to open on

    @Test func variationsAreCountedInDaysNotSets() {
        let sets = [
            set(100, day: 1, preset: narrow),
            set(102, day: 1, preset: narrow),   // same day
            set(60, day: 2, preset: wide),
        ]
        let counts = ProgressSeriesMath.variations(in: sets)
        #expect(counts[ProgressVariationKey(loadType: .weighted, presetID: narrow)] == 1)
        #expect(counts[ProgressVariationKey(loadType: .weighted, presetID: wide)] == 1)
    }

    /// The chart opens on what the user has actually trained, rather than
    /// whichever variation the live exercise happens to name today.
    @Test func theDefaultVariationIsTheOneWithTheMostHistory() {
        let key = ProgressSeriesMath.defaultVariation(in: mixed)
        #expect(key?.presetID == narrow || key?.presetID == wide)
        let counts = ProgressSeriesMath.variations(in: mixed)
        let chosen = counts[key!] ?? 0
        #expect(chosen == counts.values.max(), "opened on a variation with less history")
    }

    /// A tie goes to the plain exercise, so it is not shadowed by a variation
    /// with equal history.
    @Test func aTiePrefersTheNoVariationGroup() {
        let sets = [
            set(100, day: 1, preset: narrow),
            set(80, day: 2, preset: nil),
        ]
        #expect(ProgressSeriesMath.defaultVariation(in: sets)?.presetID == nil)
    }

    @Test func noHistoryHasNoDefaultVariation() {
        #expect(ProgressSeriesMath.defaultVariation(in: []) == nil)
    }

    /// D47 lets an exercise hold history under two load types. They rank in
    /// OPPOSITE directions, so they are different variations, not one series.
    @Test func loadTypeIsPartOfTheVariationKey() {
        let sets = [
            set(100, day: 1, preset: nil, loadType: .weighted),
            set(30, day: 2, preset: nil, loadType: .assisted),
        ]
        let counts = ProgressSeriesMath.variations(in: sets)
        #expect(counts.count == 2, "a weighted and an assisted history are not one line")

        let weighted = ProgressSeriesMath.series(
            for: sets, loadType: .weighted, presetID: nil)
        #expect(weighted.points.count == 1)
        #expect(weighted.points.first?.bestKg == 100)
    }
}
