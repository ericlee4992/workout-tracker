import Foundation
import Testing
@testable import WorkoutTracker

// Ticket 12 — records computation core (D17/D20/D21/D23). Pure math over
// plain snapshot values: load-type-specific eligibility, rep-count bests
// (12-rep cap on weight-keyed tables), Brzycki e1RM (weighted only),
// volume, snapshot grouping keys, earliest-set tie resolution.
// Expected values are independent literals, not recomputed via the formula.

struct RecordsMathTests {

    // Fixed ids and instants so tests are deterministic.
    private static let exerciseID = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")!
    private static let machineID = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000002")!
    private static let modelID = UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000003")!

    private static func at(_ seconds: TimeInterval) -> Date {
        Date(timeIntervalSinceReferenceDate: seconds)
    }

    /// Builds an input the way the app snapshots completed sets: normalizedKg
    /// derived atomically from (value, unit) per D25.
    private static func set(
        _ loadType: LoadType = .weighted,
        type: SetType = .working,
        reps: Int? = 5,
        value: Double? = 100,
        unit: WeightUnit = .kg,
        completedAt: Date? = at(0),
        exercise: UUID = exerciseID,
        machine: UUID? = nil,
        model: UUID? = nil,
        tag: EquipmentTag? = nil
    ) -> RecordSetInput {
        RecordSetInput(
            loadType: loadType,
            exerciseID: exercise,
            machineID: machine,
            modelID: model,
            freeWeightTag: tag,
            setType: type,
            reps: reps,
            weightValue: value,
            weightUnit: unit,
            normalizedKg: value.map { WeightMath.normalizedKg(value: $0, unit: unit) },
            completedAt: completedAt
        )
    }

    // MARK: - Brzycki e1RM (D17/D20)

    @Test func brzycki_atOneRep_equalsTheWeightItself() throws {
        // weight / (1.0278 − 0.0278 × 1) = weight / 1.0
        let e1RM = try #require(RecordsMath.brzyckiE1RMKg(weightKg: 100, reps: 1))
        #expect(abs(e1RM - 100) < 1e-9)
    }

    @Test func brzycki_atTwelveReps_matchesIndependentLiteral() throws {
        // 100 / (1.0278 − 0.0278 × 12) = 100 / 0.6942 = 144.05070585…
        let e1RM = try #require(RecordsMath.brzyckiE1RMKg(weightKg: 100, reps: 12))
        #expect(abs(e1RM - 144.05070585) < 1e-6)
    }

    @Test func brzycki_atThirteenRepsOrInvalidInput_isNil() {
        #expect(RecordsMath.brzyckiE1RMKg(weightKg: 100, reps: 13) == nil)
        #expect(RecordsMath.brzyckiE1RMKg(weightKg: 100, reps: 0) == nil)
        #expect(RecordsMath.brzyckiE1RMKg(weightKg: 0, reps: 5) == nil)
        #expect(RecordsMath.brzyckiE1RMKg(weightKg: .infinity, reps: 5) == nil)
    }

    @Test func bestE1RM_ignoresSetsPastTwelveReps_evenWhenHeavier() throws {
        let sets = [
            Self.set(reps: 13, value: 120, completedAt: Self.at(0)),
            Self.set(reps: 5, value: 90, completedAt: Self.at(10)),
        ]
        let best = try #require(RecordsMath.bestE1RM(among: sets))
        // 90 / (1.0278 − 0.0278 × 5) = 90 / 0.8888 = 101.26012601…
        #expect(abs(best.e1RMKg - 101.26012601) < 1e-6)
        #expect(best.reps == 5)
        #expect(best.weightValue == 90)
    }

    @Test func bestE1RM_isWeightedOnly() {
        let sets = [
            Self.set(.assisted, reps: 5, value: 20),
            Self.set(.bodyweightPlus, reps: 5, value: 25),
            Self.set(.bodyweight, reps: 10, value: nil),
        ]
        #expect(RecordsMath.bestE1RM(among: sets) == nil)
    }

    // MARK: - Assisted ranking (D20: lower assistance is better)

    @Test func assisted_equalAssistance_moreRepsNeverRanksWorse() {
        let five = Self.set(.assisted, reps: 5, value: 20, completedAt: Self.at(0))
        let eight = Self.set(.assisted, reps: 8, value: 20, completedAt: Self.at(10))
        #expect(RecordsMath.outranks(eight, five))
        #expect(!RecordsMath.outranks(five, eight))
    }

    @Test func assisted_lowerAssistanceBeatsHigher_atSameReps() throws {
        let heavyAssist = Self.set(.assisted, reps: 5, value: 20, completedAt: Self.at(0))
        let lightAssist = Self.set(.assisted, reps: 5, value: 15, completedAt: Self.at(10))
        #expect(RecordsMath.outranks(lightAssist, heavyAssist))

        let bests = RecordsMath.repCountBests(among: [heavyAssist, lightAssist], loadType: .assisted)
        let record = try #require(bests[5])
        #expect(record.weightValue == 15)
    }

    @Test func assisted_zeroAssistance_isEligibleAndBeatsAnyAssistance() throws {
        let unassisted = Self.set(.assisted, reps: 5, value: 0, completedAt: Self.at(10))
        #expect(RecordsMath.isEligible(unassisted))

        let assisted = Self.set(.assisted, reps: 5, value: 10, completedAt: Self.at(0))
        let bests = RecordsMath.repCountBests(among: [assisted, unassisted], loadType: .assisted)
        #expect(try #require(bests[5]).weightValue == 0)
    }

    // MARK: - Mixed units & ties (comparisons via normalizedKg, D25)

    @Test func mixedUnits_rankedByNormalizedKg_displayedAsEntered() throws {
        // 100 lb = 45.359237 kg < 45.5 kg, so the kg set wins the 5-rep row.
        let pounds = Self.set(reps: 5, value: 100, unit: .lb, completedAt: Self.at(0))
        let kilos = Self.set(reps: 5, value: 45.5, unit: .kg, completedAt: Self.at(10))
        let record = try #require(RecordsMath.repCountBests(among: [pounds, kilos], loadType: .weighted)[5])
        #expect(record.weightValue == 45.5)
        #expect(record.weightUnit == .kg)
    }

    @Test func exactMixedUnitTie_earliestSetWins_carriesItsOwnUnit() throws {
        // 100 lb and 45.359237 kg normalize identically; the earlier lb set wins.
        let pounds = Self.set(reps: 5, value: 100, unit: .lb, completedAt: Self.at(0))
        let kilos = Self.set(reps: 5, value: 45.359237, unit: .kg, completedAt: Self.at(10))
        let record = try #require(RecordsMath.repCountBests(among: [kilos, pounds], loadType: .weighted)[5])
        #expect(record.weightValue == 100)
        #expect(record.weightUnit == .lb)
        #expect(record.completedAt == Self.at(0))
    }

    // MARK: - Eligibility (load-type-specific)

    @Test func draftsIncompleteAndInvalidSets_areIneligible() {
        #expect(!RecordsMath.isEligible(Self.set(completedAt: nil)))          // draft
        #expect(!RecordsMath.isEligible(Self.set(reps: nil)))                 // no reps
        #expect(!RecordsMath.isEligible(Self.set(reps: 0)))                   // zero reps
        #expect(!RecordsMath.isEligible(Self.set(reps: -1)))                  // negative reps
        #expect(!RecordsMath.isEligible(Self.set(value: nil)))                // weighted, no load
        #expect(!RecordsMath.isEligible(Self.set(value: .nan)))               // non-finite
        #expect(!RecordsMath.isEligible(Self.set(value: .infinity)))
    }

    @Test func warmupsAreOut_failureSetsAreIn() throws {
        let warmup = Self.set(type: .warmup, reps: 5, value: 200, completedAt: Self.at(0))
        let failure = Self.set(type: .failure, reps: 5, value: 100, completedAt: Self.at(10))
        #expect(!RecordsMath.isEligible(warmup))
        #expect(RecordsMath.isEligible(failure))

        let bests = RecordsMath.repCountBests(among: [warmup, failure], loadType: .weighted)
        #expect(try #require(bests[5]).weightValue == 100)
    }

    @Test func weightedZeroOrNegativeLoad_isIneligible() {
        #expect(!RecordsMath.isEligible(Self.set(.weighted, value: 0)))
        #expect(!RecordsMath.isEligible(Self.set(.weighted, value: -10)))
    }

    @Test func assistedAndBodyweightPlus_negativeLoadIneligible_zeroEligible() {
        #expect(!RecordsMath.isEligible(Self.set(.assisted, value: -5)))
        #expect(!RecordsMath.isEligible(Self.set(.bodyweightPlus, value: -5)))
        #expect(RecordsMath.isEligible(Self.set(.assisted, value: 0)))
        #expect(RecordsMath.isEligible(Self.set(.bodyweightPlus, value: 0)))
    }

    @Test func bodyweight_loadIsIgnored_nilWeightEligible() {
        #expect(RecordsMath.isEligible(Self.set(.bodyweight, value: nil)))
        #expect(RecordsMath.isEligible(Self.set(.bodyweight, value: 0)))
    }

    @Test func bodyweightPlusZeroAdded_countsInRepTable() throws {
        let plain = Self.set(.bodyweightPlus, reps: 8, value: 0, completedAt: Self.at(0))
        let added = Self.set(.bodyweightPlus, reps: 8, value: 10, completedAt: Self.at(10))
        let bests = RecordsMath.repCountBests(among: [plain, added], loadType: .bodyweightPlus)
        // Most added weight wins (D20).
        #expect(try #require(bests[8]).weightValue == 10)
    }

    // MARK: - Rep-count tables: 12-rep cap only on weight-keyed tables

    @Test func weightedRepTable_ignoresRepsPastTwelve_keepsTwelve() {
        let twelve = Self.set(reps: 12, value: 80, completedAt: Self.at(0))
        let thirteen = Self.set(reps: 13, value: 120, completedAt: Self.at(10))
        let bests = RecordsMath.repCountBests(among: [twelve, thirteen], loadType: .weighted)
        #expect(bests[12]?.weightValue == 80)
        #expect(bests[13] == nil)
        #expect(bests.count == 1)
    }

    @Test func bodyweightMostReps_isUncapped_tieGoesToEarliest() throws {
        let thirty = Self.set(.bodyweight, reps: 30, value: nil, completedAt: Self.at(20))
        let thirtyEarlier = Self.set(.bodyweight, reps: 30, value: nil, completedAt: Self.at(5))
        let twenty = Self.set(.bodyweight, reps: 20, value: nil, completedAt: Self.at(0))
        let warmup = Self.set(.bodyweight, type: .warmup, reps: 50, value: nil, completedAt: Self.at(1))

        let record = try #require(RecordsMath.mostRepsRecord(among: [thirty, thirtyEarlier, twenty, warmup]))
        #expect(record.reps == 30)
        #expect(record.completedAt == Self.at(5))
        #expect(record.weightValue == nil)
    }

    // MARK: - Volume (D21: weighted working+failure only, Σ normalizedKg × reps)

    @Test func volume_sumsWeightedWorkingAndFailure_excludesEverythingElse() {
        let sets = [
            Self.set(reps: 5, value: 100, completedAt: Self.at(0)),                    // 500
            Self.set(type: .failure, reps: 8, value: 80, completedAt: Self.at(10)),    // 640
            Self.set(type: .warmup, reps: 10, value: 60, completedAt: Self.at(20)),    // warmup: out
            Self.set(reps: 5, value: 100, completedAt: nil),                           // draft: out
            Self.set(.assisted, reps: 10, value: 20, completedAt: Self.at(30)),        // assisted: out
            Self.set(.bodyweight, reps: 15, value: nil, completedAt: Self.at(40)),     // bodyweight: out
            Self.set(.bodyweightPlus, reps: 6, value: 10, completedAt: Self.at(50)),   // bw+: out
        ]
        #expect(abs(RecordsMath.totalVolumeKg(among: sets) - 1140) < 1e-9)
    }

    // MARK: - D26: drop sets are real work

    /// A drop set counts exactly like a working or failure set for
    /// eligibility, in every load type — only warmups are excluded.
    @Test func dropSetsAreEligibleInEveryLoadType_warmupStillIsNot() {
        for loadType in LoadType.allCases {
            let value: Double? = loadType == .bodyweight ? nil : 40
            #expect(
                RecordsMath.isEligible(
                    Self.set(loadType, type: .drop, reps: 8, value: value)),
                "A drop set must be eligible under \(loadType)")
            #expect(
                !RecordsMath.isEligible(
                    Self.set(loadType, type: .warmup, reps: 8, value: value)),
                "A warmup must stay ineligible under \(loadType)")
        }
    }

    /// …and it can therefore *hold* a record: the drop set here is the only
    /// set at 8 reps in each weight-keyed table, and the best in the
    /// bodyweight most-reps table.
    @Test func dropSetsCanHoldTheRecordInEveryLoadType() throws {
        // weighted: heaviest at 8 reps.
        let weighted = RecordsMath.repCountBests(
            among: [
                Self.set(.weighted, type: .drop, reps: 8, value: 90, completedAt: Self.at(0)),
                Self.set(.weighted, type: .warmup, reps: 8, value: 200, completedAt: Self.at(1)),
            ],
            loadType: .weighted)
        #expect(try #require(weighted[8]).weightValue == 90)

        // assisted: least assistance at 8 reps — the drop set beats the
        // working one because 10 kg of help is less than 30 kg.
        let assisted = RecordsMath.repCountBests(
            among: [
                Self.set(.assisted, type: .working, reps: 8, value: 30, completedAt: Self.at(0)),
                Self.set(.assisted, type: .drop, reps: 8, value: 10, completedAt: Self.at(1)),
            ],
            loadType: .assisted)
        #expect(try #require(assisted[8]).weightValue == 10)

        // bodyweightPlus: most added weight at 8 reps.
        let bodyweightPlus = RecordsMath.repCountBests(
            among: [
                Self.set(.bodyweightPlus, type: .working, reps: 8, value: 5, completedAt: Self.at(0)),
                Self.set(.bodyweightPlus, type: .drop, reps: 8, value: 15, completedAt: Self.at(1)),
            ],
            loadType: .bodyweightPlus)
        #expect(try #require(bodyweightPlus[8]).weightValue == 15)

        // bodyweight: most reps, uncapped.
        let bodyweight = try #require(RecordsMath.mostRepsRecord(among: [
            Self.set(.bodyweight, type: .working, reps: 20, value: nil, completedAt: Self.at(0)),
            Self.set(.bodyweight, type: .drop, reps: 25, value: nil, completedAt: Self.at(1)),
        ]))
        #expect(bodyweight.reps == 25)

        // e1RM (weighted only) sees drop sets too.
        let e1RM = try #require(RecordsMath.bestE1RM(among: [
            Self.set(.weighted, type: .drop, reps: 5, value: 100, completedAt: Self.at(0)),
        ]))
        #expect(e1RM.reps == 5)
    }

    /// Volume: the drop set's tonnage is in, the warmup's is not.
    @Test func volume_includesDropSets() {
        let sets = [
            Self.set(reps: 5, value: 100, completedAt: Self.at(0)),                  // 500
            Self.set(type: .drop, reps: 10, value: 50, completedAt: Self.at(10)),    // 500
            Self.set(type: .warmup, reps: 10, value: 60, completedAt: Self.at(20)),  // out
        ]
        #expect(abs(RecordsMath.totalVolumeKg(among: sets) - 1000) < 1e-9)
    }

    @Test func volume_dumbbellEntriesAreNotDoubled() {
        // Dumbbells log the per-hand label (D21); no equipment special-casing.
        let sets = [
            Self.set(reps: 10, value: 20, completedAt: Self.at(0), tag: .dumbbell),
            Self.set(reps: 10, value: 20, completedAt: Self.at(10), tag: .dumbbell),
        ]
        #expect(abs(RecordsMath.totalVolumeKg(among: sets) - 400) < 1e-9)
    }

    @Test func volume_usesNormalizedKgForPoundEntries() {
        let sets = [Self.set(reps: 10, value: 100, unit: .lb, completedAt: Self.at(0))]
        // 100 lb = 45.359237 kg → × 10 reps.
        #expect(abs(RecordsMath.totalVolumeKg(among: sets) - 453.59237) < 1e-9)
    }

    // MARK: - Grouping keys (D23: snapshot values, never live rows)

    @Test func machinelessEntries_groupByExerciseAndFreeWeightTag() {
        let barbell = Self.set(reps: 5, value: 100, tag: .barbell)
        let dumbbell = Self.set(reps: 5, value: 40, tag: .dumbbell)

        let barbellKeys = RecordsMath.groupKeys(for: barbell)
        let dumbbellKeys = RecordsMath.groupKeys(for: dumbbell)
        #expect(barbellKeys.contains(.freeWeight(exerciseID: Self.exerciseID, tag: .barbell)))
        #expect(dumbbellKeys.contains(.freeWeight(exerciseID: Self.exerciseID, tag: .dumbbell)))
        // Barbell and dumbbell records never merge…
        #expect(!barbellKeys.contains(.freeWeight(exerciseID: Self.exerciseID, tag: .dumbbell)))
        // …but both roll up into the exercise-wide group.
        #expect(barbellKeys.contains(.exercise(Self.exerciseID)))
        #expect(dumbbellKeys.contains(.exercise(Self.exerciseID)))

        let groups = RecordsMath.grouped([barbell, dumbbell])
        #expect(groups[.freeWeight(exerciseID: Self.exerciseID, tag: .barbell)]?.count == 1)
        #expect(groups[.freeWeight(exerciseID: Self.exerciseID, tag: .dumbbell)]?.count == 1)
        #expect(groups[.exercise(Self.exerciseID)]?.count == 2)
    }

    @Test func machineEntries_groupByMachineModelAndExercise_notByTag() {
        let set = Self.set(reps: 5, value: 50, machine: Self.machineID, model: Self.modelID)
        let keys = RecordsMath.groupKeys(for: set)
        #expect(keys.contains(.machine(Self.machineID)))
        #expect(keys.contains(.model(Self.modelID)))
        #expect(keys.contains(.exercise(Self.exerciseID)))
        #expect(keys.count == 3)
    }

    @Test func machinelessEntryWithoutModel_getsExerciseAndFreeWeightKeysOnly() {
        let set = Self.set(reps: 5, value: 100, tag: .barbell)
        let keys = RecordsMath.groupKeys(for: set)
        #expect(keys.count == 2)
        #expect(keys.contains(.exercise(Self.exerciseID)))
        #expect(keys.contains(.freeWeight(exerciseID: Self.exerciseID, tag: .barbell)))
    }

    // MARK: - Tie rule & per-row independence

    @Test func weightedTie_sameLoadSameReps_earliestWins() throws {
        let later = Self.set(reps: 5, value: 100, completedAt: Self.at(100))
        let earlier = Self.set(reps: 5, value: 100, completedAt: Self.at(1))
        let record = try #require(RecordsMath.repCountBests(among: [later, earlier], loadType: .weighted)[5])
        #expect(record.completedAt == Self.at(1))
    }

    @Test func repTable_keepsIndependentRowsPerRepCount() {
        let sets = [
            Self.set(reps: 3, value: 110, completedAt: Self.at(0)),
            Self.set(reps: 8, value: 90, completedAt: Self.at(10)),
        ]
        let bests = RecordsMath.repCountBests(among: sets, loadType: .weighted)
        #expect(bests[3]?.weightValue == 110)
        #expect(bests[8]?.weightValue == 90)
        #expect(bests.count == 2)
    }

    @Test func repTable_onlyCountsMatchingSnapshotLoadType() {
        // A group can mix snapshot load types across time (D23); tables never do.
        let sets = [
            Self.set(.weighted, reps: 5, value: 100, completedAt: Self.at(0)),
            Self.set(.assisted, reps: 5, value: 20, completedAt: Self.at(10)),
        ]
        let weighted = RecordsMath.repCountBests(among: sets, loadType: .weighted)
        let assisted = RecordsMath.repCountBests(among: sets, loadType: .assisted)
        #expect(weighted[5]?.weightValue == 100)
        #expect(assisted[5]?.weightValue == 20)
    }
}
