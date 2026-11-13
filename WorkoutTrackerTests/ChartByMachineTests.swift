import Foundation
import SwiftData
import Testing
@testable import WorkoutTracker

/// Live-workout 03 (D87) — the chart opened from a live exercise, by machine: each machine the exercise was logged on
/// is its own series (D1/D8), "All machines" pools only the machines and only when asked, and the chart opens on the
/// machine in use.
struct ChartByMachineTests {
    private let exerciseID = UUID()
    private let machineA = UUID()
    private let machineB = UUID()
    private let narrow = UUID()

    private func set(
        _ kg: Double, reps: Int = 8, day: Int, machine: UUID?, tag: EquipmentTag? = nil,
        type: SetType = .working, loadType: LoadType = .weighted, preset: UUID? = nil
    ) -> RecordSetInput {
        RecordSetInput(
            loadType: loadType, exerciseID: exerciseID, machineID: machine, freeWeightTag: tag, presetID: preset,
            setType: type, reps: reps, weightValue: kg, weightUnit: .kg, normalizedKg: kg,
            completedAt: Date(timeIntervalSince1970: Double(day) * 86_400 + 43_200))
    }

    private func key(_ equipment: ProgressEquipment, loadType: LoadType = .weighted, preset: UUID? = nil)
        -> ProgressVariationKey {
        ProgressVariationKey(loadType: loadType, equipment: equipment, presetID: preset)
    }

    // MARK: - All machines is offered, never defaulted

    @Test func allMachinesIsOfferedOnlyForTwoOrMoreMachines() {
        let one = [set(50, day: 1, machine: machineA), set(55, day: 2, machine: machineA)]
        #expect(ProgressSeriesMath.pooledMachineVariations(in: one).isEmpty,
                "with one machine the pool is that machine: not offered twice")

        let two = one + [set(70, day: 3, machine: machineB)]
        let pooled = ProgressSeriesMath.pooledMachineVariations(in: two)
        #expect(pooled.map(\.key) == [key(.anyMachine)])
        #expect(pooled.first?.days == 3, "days are distinct days across the machines")
    }

    @Test func allMachinesCountsDaysOnceAndSkipsWarmups() {
        let sets = [
            set(50, day: 1, machine: machineA), set(70, day: 1, machine: machineB),   // one day, two machines
            set(30, day: 2, machine: machineA, type: .warmup),                        // warmup: not a day
            set(75, day: 4, machine: machineB),
        ]
        #expect(ProgressSeriesMath.pooledMachineVariations(in: sets).first?.days == 2)
    }

    /// A pool always has at least as many days as any one machine; ranked with the others it would become every
    /// chart's default — the pooling D1/D8 forbid unless the user picks it.
    @Test func allMachinesIsNeverTheDefaultOrARankedVariation() {
        let sets = [set(50, day: 1, machine: machineA), set(70, day: 2, machine: machineB),
                    set(72, day: 3, machine: machineB)]
        #expect(ProgressSeriesMath.rankedVariations(in: sets).allSatisfy { $0.key.equipment != .anyMachine })
        #expect(ProgressSeriesMath.defaultVariation(in: sets) == key(.machine(machineB)))
    }

    /// One pool per load type and preset (D36, D47): a narrow-grip machine set is not pooled with a plain one.
    @Test func allMachinesIsPerLoadTypeAndPreset() {
        let sets = [
            set(50, day: 1, machine: machineA), set(70, day: 2, machine: machineB),
            set(40, day: 3, machine: machineA, preset: narrow),                       // one machine under narrow
            set(20, day: 4, machine: machineA, loadType: .assisted),
            set(25, day: 5, machine: machineB, loadType: .assisted),
        ]
        let keys = Set(ProgressSeriesMath.pooledMachineVariations(in: sets).map(\.key))
        #expect(keys == [key(.anyMachine), key(.anyMachine, loadType: .assisted)])
    }

    // MARK: - The pooled series

    @Test func allMachinesChartsOnlyMachineSets() {
        let sets = [
            set(50, day: 1, machine: machineA),
            set(70, day: 2, machine: machineB),
            set(90, day: 3, machine: nil, tag: .dumbbell),                             // a free weight: not a machine
            set(95, day: 4, machine: nil),                                            // nothing recorded
            set(60, day: 5, machine: machineA, preset: narrow),                       // another variation
        ]
        let series = ProgressSeriesMath.series(for: sets, variation: key(.anyMachine))
        #expect(series.points.map(\.bestKg) == [50, 70])
        #expect(ProgressSeriesMath.scoped(sets, to: key(.anyMachine)).count == 2)
    }

    /// Each machine stays its own line: machine A's chart never shows B's heavier numbers (D1/D8).
    @Test func eachMachineChartsOnItsOwn() {
        let sets = [set(50, day: 1, machine: machineA), set(70, day: 2, machine: machineB),
                    set(55, day: 3, machine: machineA)]
        #expect(ProgressSeriesMath.series(for: sets, variation: key(.machine(machineA))).points.map(\.bestKg) == [50, 55])
        #expect(ProgressSeriesMath.series(for: sets, variation: key(.machine(machineB))).points.map(\.bestKg) == [70])
    }

    /// The day's best across machines still follows the load type: assisted, less assistance wins.
    @Test func allMachinesRespectsLoadTypeDirection() {
        let sets = [set(30, day: 1, machine: machineA, loadType: .assisted),
                    set(20, day: 1, machine: machineB, loadType: .assisted)]
        let series = ProgressSeriesMath.series(for: sets, variation: key(.anyMachine, loadType: .assisted))
        #expect(series.points.first?.bestKg == 20)
    }

    // MARK: - Labels: name · gym

    private func words(_ key: ProgressVariationKey, equipment: String? = nil, gym: String? = nil)
        -> (key: ProgressVariationKey, words: ProgressVariationWords) {
        (key, ProgressVariationWords(loadType: key.loadType, equipment: key.equipment,
                                     equipmentName: equipment, gymName: gym, presetName: nil))
    }

    @Test func machinesAreNamedWithTheirGymAndThePoolSaysAllMachines() {
        let a = key(.machine(machineA)), b = key(.machine(machineB)), all = key(.anyMachine)
        let labels = ProgressSeriesMath.labels(for: [
            words(all), words(a, equipment: "Chest Press 2", gym: "Iron Temple"),
            words(b, equipment: "Chest Press", gym: "Hotel Gym"),
        ])
        #expect(labels[all] == "All machines")
        #expect(labels[a] == "Chest Press 2 · Iron Temple")
        #expect(labels[b] == "Chest Press · Hotel Gym")
    }

    @Test func aMachineWithNoGymKeepsItsName() {
        let a = key(.machine(machineA))
        #expect(ProgressSeriesMath.labels(for: [words(a, equipment: "Leg Press")])[a] == "Leg Press")
    }

    // MARK: - Opening on the machine in use

    private func makeContext() throws -> ModelContext {
        let schema = WorkoutTrackerStore.schema
        let container = try ModelContainer(
            for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    /// A draft follows its live rows — the machine and preset it is set to now; a frozen entry its snapshot (D19,
    /// D23), even if a live row changed since.
    @Test func theChartOpensOnTheEntrysCurrentVariation() throws {
        let context = try makeContext()
        let exercise = Exercise(name: "Chest Press", loadType: .weighted, muscleGroup: "Chest")
        let gym = Gym(name: "Iron Temple")
        let machine = MachineInstance(label: "Chest Press 2", gym: gym, model: nil)
        let other = MachineInstance(label: "Chest Press", gym: gym, model: nil)
        for object in [exercise, gym, machine, other] as [any PersistentModel] { context.insert(object) }
        let workout = try WorkoutSession(context: context).startWorkout(at: gym)
        let entry = try WorkoutSession(context: context).addEntry(for: exercise, to: workout, machine: machine)

        #expect(ProgressVariationKey.current(for: entry)
            == ProgressVariationKey(loadType: .weighted, equipment: .machine(machine.id), presetID: nil))

        entry.machine = other
        #expect(ProgressVariationKey.current(for: entry).equipment == .machine(other.id), "a draft can still move")

        entry.snapshotCapturedAt = .now
        entry.snapshotMachineID = machine.id
        entry.snapshotLoadType = .assisted
        #expect(ProgressVariationKey.current(for: entry)
            == ProgressVariationKey(loadType: .assisted, equipment: .machine(machine.id), presetID: nil),
            "frozen: the snapshot, not the live rows")
    }
}
