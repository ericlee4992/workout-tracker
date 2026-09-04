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
            variation: ProgressVariationKey(loadType: .assisted, equipment: .unrecorded, presetID: nil))

        #expect(!series.higherIsBetter)
        let change = try? #require(ProgressSeriesMath.change(series))
        #expect((change ?? 0) > 0, "40kg → 20kg of assistance is a 50% IMPROVEMENT, got \(change ?? 0)")
        #expect(series.loadAxisLabel.contains("less is better"))
    }

    @Test func weightedProgressCountsUpwardAsImprovement() {
        let series = ProgressSeriesMath.series(
            for: [set(60, day: 1), set(70, day: 8)], variation: ProgressVariationKey(loadType: .weighted, equipment: .unrecorded, presetID: nil))
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
            variation: ProgressVariationKey(loadType: .assisted, equipment: .unrecorded, presetID: nil))
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
            variation: ProgressVariationKey(loadType: .weighted, equipment: .unrecorded, presetID: nil))
        #expect(series.points.first?.bestKg == 60, "a warmup must not become the day's best set")
        #expect(series.points.first?.volumeKg == 480, "warmup volume must not be counted")
    }

    /// `RecordsMath.totalVolumeKg` is weighted-only. A chart that summed
    /// assistance as "volume lifted" would disagree with every other volume
    /// figure in the app.
    @Test func volumeIsWeightedOnly() {
        let series = ProgressSeriesMath.series(
            for: [set(30, day: 1, loadType: .assisted)], variation: ProgressVariationKey(loadType: .assisted, equipment: .unrecorded, presetID: nil))
        #expect(series.points.first?.volumeKg == 0)
    }

    // MARK: - Grouping and ordering

    @Test func setsAreGroupedByDayAndOrderedOldestFirst() {
        let series = ProgressSeriesMath.series(
            for: [set(70, day: 8), set(60, day: 1), set(65, day: 1)],
            variation: ProgressVariationKey(loadType: .weighted, equipment: .unrecorded, presetID: nil))
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
        let series = ProgressSeriesMath.series(for: [lb], variation: ProgressVariationKey(loadType: .weighted, equipment: .unrecorded, presetID: nil))
        #expect(series.points.first?.bestValue == 135)
        #expect(series.points.first?.bestUnit == .lb)
    }

    // MARK: - Not claiming more than the data supports

    @Test func noSessionsIsEmptyRatherThanAZeroLine() {
        let series = ProgressSeriesMath.series(for: [], variation: ProgressVariationKey(loadType: .weighted, equipment: .unrecorded, presetID: nil))
        #expect(series.confidence == .empty)
        #expect(series.points.isEmpty)
        #expect(ProgressSeriesMath.change(series) == nil)
    }

    /// One point is not a trend, and two dots joined by a line invite the eye
    /// to read a slope that is not evidence.
    @Test func oneSessionIsMarkedAsASinglePointWithNoTrend() {
        let series = ProgressSeriesMath.series(for: [set(60, day: 1)], variation: ProgressVariationKey(loadType: .weighted, equipment: .unrecorded, presetID: nil))
        #expect(series.confidence == .single)
        #expect(ProgressSeriesMath.change(series) == nil, "one point has no direction")
    }

    @Test func aZeroBaselineYieldsNoPercentageRatherThanInfinity() {
        let series = ProgressSeriesMath.series(
            for: [
                set(0, day: 1, loadType: .bodyweightPlus),
                set(10, day: 8, loadType: .bodyweightPlus),
            ],
            variation: ProgressVariationKey(loadType: .bodyweightPlus, equipment: .unrecorded, presetID: nil))
        #expect(
            ProgressSeriesMath.change(series) == nil,
            "a percentage over a zero baseline is a division the app would be inventing")
    }

    @Test func e1rmIsWeightedOnly() {
        let weighted = ProgressSeriesMath.series(
            for: [set(100, reps: 5, day: 1)], variation: ProgressVariationKey(loadType: .weighted, equipment: .unrecorded, presetID: nil))
        #expect(weighted.points.first?.e1rmKg != nil)

        let assisted = ProgressSeriesMath.series(
            for: [set(30, reps: 5, day: 1, loadType: .assisted)], variation: ProgressVariationKey(loadType: .assisted, equipment: .unrecorded, presetID: nil))
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
            for: mixed, variation: ProgressVariationKey(loadType: .weighted, equipment: .unrecorded, presetID: narrow))
        #expect(series.points.count == 2, "narrow grip has two days, got \(series.points.count)")
        #expect(series.points.allSatisfy { ($0.bestKg ?? 0) >= 100 },
                "a wide-grip set leaked into the narrow-grip chart")
    }

    /// nil is a REAL group — sets logged with no variation — not a wildcard.
    /// Reading it as a wildcard is exactly how the pooling happened.
    @Test func nilPresetMeansNoVariationRatherThanEveryVariation() {
        let series = ProgressSeriesMath.series(
            for: mixed, variation: ProgressVariationKey(loadType: .weighted, equipment: .unrecorded, presetID: nil))
        #expect(series.points.count == 1, "only the one no-preset day, got \(series.points.count)")
        #expect(series.points.first?.bestKg == 80)
    }

    @Test func eachVariationKeepsItsOwnBest() {
        let narrowSeries = ProgressSeriesMath.series(
            for: mixed, variation: ProgressVariationKey(loadType: .weighted, equipment: .unrecorded, presetID: narrow))
        let wideSeries = ProgressSeriesMath.series(
            for: mixed, variation: ProgressVariationKey(loadType: .weighted, equipment: .unrecorded, presetID: wide))
        #expect(narrowSeries.points.last?.bestKg == 105)
        #expect(
            wideSeries.points.last?.bestKg == 65,
            "wide grip's best must not be narrow grip's 105")
    }

    // MARK: - Equipment as an axis (milestone 9, ticket 01)

    private let machineA = UUID()
    private let machineB = UUID()

    private func tagged(
        _ kg: Double, day: Int, tag: EquipmentTag?, preset: UUID? = nil
    ) -> RecordSetInput {
        var s = set(kg, day: day, preset: preset)
        s.freeWeightTag = tag
        return s
    }

    private func machined(_ kg: Double, day: Int, machine: UUID) -> RecordSetInput {
        var s = set(kg, day: day, preset: nil)
        s.machineID = machine
        return s
    }

    private var barbellAndDumbbell: [RecordSetInput] {
        [
            tagged(100, day: 1, tag: .barbell), tagged(105, day: 8, tag: .barbell),
            tagged(40, day: 2, tag: .dumbbell), tagged(42.5, day: 9, tag: .dumbbell),
            machined(90, day: 3, machine: machineA),
            tagged(70, day: 4, tag: nil),  // no machine, no tag: added from History
        ]
    }

    /// Records already split barbell from dumbbell (`RecordGroupKey.freeWeight`);
    /// the chart drew them as ONE line, so a 40 kg dumbbell day sat on the same
    /// slope as a 100 kg barbell day.
    @Test func aDumbbellSetNeverAppearsInTheBarbellLine() {
        let barbell = ProgressSeriesMath.series(
            for: barbellAndDumbbell,
            variation: ProgressVariationKey(loadType: .weighted, equipment: .freeWeight(.barbell), presetID: nil))
        #expect(barbell.points.count == 2, "barbell has two days, got \(barbell.points.count)")
        #expect(barbell.points.allSatisfy { ($0.bestKg ?? 0) >= 100 },
                "a dumbbell set leaked into the barbell chart")
    }

    /// codex-review 01 (high): the first cut keyed on the tag alone, so a
    /// machined set and a set with NO equipment recorded — genuinely different
    /// provenance under D23 — were one group. They are two.
    @Test func aMachinedSetAndAnUnrecordedSetAreDifferentGroups() {
        let machine = ProgressSeriesMath.series(
            for: barbellAndDumbbell,
            variation: ProgressVariationKey(loadType: .weighted, equipment: .machine(machineA), presetID: nil))
        let unrecorded = ProgressSeriesMath.series(
            for: barbellAndDumbbell,
            variation: ProgressVariationKey(loadType: .weighted, equipment: .unrecorded, presetID: nil))
        #expect(machine.points.map(\.bestKg) == [90])
        #expect(unrecorded.points.map(\.bestKg) == [70])
    }

    /// D1/D8: a weight on one machine is not a weight on another. The chart
    /// keys on the exact machine, as layer one of prefill and `.machine`
    /// records do — not on "some machine".
    @Test func twoMachinesAreTwoVariations() {
        let sets = [machined(100, day: 1, machine: machineA), machined(110, day: 2, machine: machineB)]
        let counts = ProgressSeriesMath.variations(in: sets)
        #expect(counts.count == 2)
        #expect(counts[ProgressVariationKey(loadType: .weighted, equipment: .machine(machineA), presetID: nil)] == 1)
        #expect(counts[ProgressVariationKey(loadType: .weighted, equipment: .machine(machineB), presetID: nil)] == 1)
    }

    @Test func sameGripUnderTwoTagsIsTwoVariations() {
        let sets = [
            tagged(100, day: 1, tag: .barbell, preset: wide),
            tagged(40, day: 2, tag: .dumbbell, preset: wide),
        ]
        let counts = ProgressSeriesMath.variations(in: sets)
        #expect(counts.count == 2, "one preset under two tags must be two lines, got \(counts.count)")
        #expect(counts[ProgressVariationKey(loadType: .weighted, equipment: .freeWeight(.barbell), presetID: wide)] == 1)
        #expect(counts[ProgressVariationKey(loadType: .weighted, equipment: .freeWeight(.dumbbell), presetID: wide)] == 1)
    }

    /// The ranking is one function, in the Domain, and it is total: days
    /// first, then plain before preset, then equipment by name, so the picker
    /// and the default agree and neither reshuffles between launches.
    @Test func rankedVariationsIsTotalAndStable() {
        let sets = [
            tagged(100, day: 1, tag: .dumbbell),
            tagged(100, day: 2, tag: .barbell),
            machined(90, day: 3, machine: machineA), machined(95, day: 10, machine: machineA),
            tagged(80, day: 4, tag: .barbell, preset: wide),
        ]
        let ranked = ProgressSeriesMath.rankedVariations(in: sets)
        #expect(ranked.map(\.days) == [2, 1, 1, 1])
        #expect(ranked.first?.key.equipment == .machine(machineA), "most days opens first")
        // Among the one-day ties: plain before preset, then barbell before dumbbell.
        #expect(ranked[1].key == ProgressVariationKey(loadType: .weighted, equipment: .freeWeight(.barbell), presetID: nil))
        #expect(ranked[2].key == ProgressVariationKey(loadType: .weighted, equipment: .freeWeight(.dumbbell), presetID: nil))
        #expect(ranked[3].key.presetID == wide)
        #expect(ProgressSeriesMath.defaultVariation(in: sets) == ranked.first?.key)
    }

    /// codex-review 01b: the rank left load type out, so after a D47
    /// correction two distinct keys could compare equal and fall back to
    /// dictionary order. Every field of the key now takes part.
    @Test func rankedVariationsSeparatesLoadTypesDeterministically() {
        var assisted = tagged(30, day: 1, tag: .barbell)
        assisted.loadType = .assisted
        let sets = [tagged(100, day: 2, tag: .barbell), assisted]
        let ranked = ProgressSeriesMath.rankedVariations(in: sets)
        #expect(ranked.count == 2)
        #expect(Set(ranked.map(\.key.loadType)) == [.weighted, .assisted])
        // Same days, same equipment, same (nil) preset: the order is by load
        // type's raw value, and identical on every call.
        let again = ProgressSeriesMath.rankedVariations(in: sets.reversed())
        #expect(ranked.map(\.key) == again.map(\.key))
        #expect(ranked.first?.key.loadType.rawValue ?? "" < ranked.last?.key.loadType.rawValue ?? "")
    }

    // MARK: - Picker labels never collide (codex-review 01b)

    private func words(
        _ key: ProgressVariationKey, equipment: String? = nil, gym: String? = nil, preset: String? = nil
    ) -> (key: ProgressVariationKey, words: ProgressVariationWords) {
        (key, ProgressVariationWords(
            loadType: key.loadType, equipment: key.equipment,
            equipmentName: equipment, gymName: gym, presetName: preset))
    }

    @Test func aPresetNamedLikeATagDoesNotCollideWithThatTag() {
        let unrecordedPreset = ProgressVariationKey(loadType: .weighted, equipment: .unrecorded, presetID: wide)
        let dumbbell = ProgressVariationKey(loadType: .weighted, equipment: .freeWeight(.dumbbell), presetID: nil)
        let labels = ProgressSeriesMath.labels(for: [
            words(unrecordedPreset, preset: "Dumbbell"),
            words(dumbbell, equipment: "Dumbbell"),
        ])
        #expect(labels[unrecordedPreset] != labels[dumbbell])
        #expect(labels[unrecordedPreset] == "No equipment recorded · Dumbbell")
        #expect(labels[dumbbell] == "Dumbbell")
    }

    @Test func twoMachinesWithTheSameLabelAreToldApartByGym() {
        let a = ProgressVariationKey(loadType: .weighted, equipment: .machine(machineA), presetID: nil)
        let b = ProgressVariationKey(loadType: .weighted, equipment: .machine(machineB), presetID: nil)
        let labels = ProgressSeriesMath.labels(for: [
            words(a, equipment: "Chest Press", gym: "Gold's"),
            words(b, equipment: "Chest Press", gym: "Anytime"),
        ])
        #expect(labels[a] != labels[b])
        #expect(labels[a]?.contains("Gold's") == true)
        #expect(labels[b]?.contains("Anytime") == true)
    }

    @Test func sameVariationUnderTwoLoadTypesShowsTheLoadType() {
        let w = ProgressVariationKey(loadType: .weighted, equipment: .freeWeight(.barbell), presetID: nil)
        let a = ProgressVariationKey(loadType: .assisted, equipment: .freeWeight(.barbell), presetID: nil)
        let labels = ProgressSeriesMath.labels(for: [words(w, equipment: "Barbell"), words(a, equipment: "Barbell")])
        #expect(labels[w] != labels[a])
        #expect(labels[a]?.contains(LoadType.assisted.badge) == true)
    }

    /// Nothing left to add and still identical: number them rather than
    /// ship two rows the user cannot tell apart.
    @Test func hopelessCollisionsAreNumbered() {
        let a = ProgressVariationKey(loadType: .weighted, equipment: .machine(machineA), presetID: nil)
        let b = ProgressVariationKey(loadType: .weighted, equipment: .machine(machineB), presetID: nil)
        let labels = ProgressSeriesMath.labels(for: [
            words(a, equipment: "Chest Press", gym: "Gold's"),
            words(b, equipment: "Chest Press", gym: "Gold's"),
        ])
        #expect(labels[a] != labels[b])
        #expect(labels[b]?.hasSuffix("(2)") == true)
    }

    /// The common case stays terse: no collisions, no discriminators.
    @Test func labelsStayTerseWhenNothingCollides() {
        let plain = ProgressVariationKey(loadType: .weighted, equipment: .unrecorded, presetID: nil)
        let grip = ProgressVariationKey(loadType: .weighted, equipment: .unrecorded, presetID: wide)
        let db = ProgressVariationKey(loadType: .weighted, equipment: .freeWeight(.dumbbell), presetID: nil)
        let labels = ProgressSeriesMath.labels(for: [
            words(plain), words(grip, preset: "Wide grip"), words(db, equipment: "Dumbbell"),
        ])
        #expect(labels[plain] == "No equipment recorded")
        #expect(labels[grip] == "Wide grip")
        #expect(labels[db] == "Dumbbell")
    }

    // MARK: - Choosing which variation to open on

    @Test func variationsAreCountedInDaysNotSets() {
        let sets = [
            set(100, day: 1, preset: narrow),
            set(102, day: 1, preset: narrow),   // same day
            set(60, day: 2, preset: wide),
        ]
        let counts = ProgressSeriesMath.variations(in: sets)
        #expect(counts[ProgressVariationKey(loadType: .weighted, equipment: .unrecorded, presetID: narrow)] == 1)
        #expect(counts[ProgressVariationKey(loadType: .weighted, equipment: .unrecorded, presetID: wide)] == 1)
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
            for: sets, variation: ProgressVariationKey(loadType: .weighted, equipment: .unrecorded, presetID: nil))
        #expect(weighted.points.count == 1)
        #expect(weighted.points.first?.bestKg == 100)
    }
}
