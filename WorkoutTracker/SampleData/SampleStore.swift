import Foundation
import SwiftUI

// In-memory data backing the milestone-1 UI prototype. Everything here is
// throwaway; SwiftData replaces it at milestone 2.
@MainActor
final class SampleStore: ObservableObject {

    // MARK: Catalog

    let gyms: [SampleGym]
    let machines: [Machine]
    let exercises: [SampleExercise]
    let templates: [SampleWorkoutTemplate]

    @Published var currentGym: SampleGym
    @Published var history: [SampleWorkout]
    @Published var activeWorkout: SampleWorkout

    var gymGangnam: SampleGym { gyms[0] }
    var gymSF: SampleGym { gyms[1] }

    init() {
        // Gyms — one kg country, one lb country, to exercise mixed-unit UI.
        let gangnam = SampleGym(name: "Gold's Gym Gangnam", city: "Seoul", defaultUnit: .kg)
        let sf = SampleGym(name: "Fitness SF Transbay", city: "San Francisco", defaultUnit: .lb)
        gyms = [gangnam, sf]
        currentGym = gangnam

        // Equipment models (stand-ins for the seeded catalog).
        let lfInsignia = SampleEquipmentModel(manufacturer: "Life Fitness", model: "Insignia Chest Press")
        let hsMTS = SampleEquipmentModel(manufacturer: "Hammer Strength", model: "MTS Iso-Lateral Chest Press")
        let tgLat = SampleEquipmentModel(manufacturer: "Technogym", model: "Selection 900 Lat Pulldown")
        let matrixAssist = SampleEquipmentModel(manufacturer: "Matrix", model: "Ultra Assisted Chin/Dip")
        let cybexLeg = SampleEquipmentModel(manufacturer: "Cybex", model: "Eagle NX Leg Press")
        let precorRow = SampleEquipmentModel(manufacturer: "Precor", model: "Vitality Seated Row")
        let lfShoulder = SampleEquipmentModel(manufacturer: "Life Fitness", model: "Signature Shoulder Press")

        machines = [
            Machine(gymID: gangnam.id, label: "Chest Press #1", model: lfInsignia, defaultUnit: nil),
            Machine(gymID: gangnam.id, label: "Chest Press #2", model: hsMTS, defaultUnit: nil),
            Machine(gymID: gangnam.id, label: "Lat Pulldown", model: tgLat, defaultUnit: nil),
            Machine(gymID: gangnam.id, label: "Assisted Pull-Up", model: matrixAssist, defaultUnit: nil),
            Machine(gymID: gangnam.id, label: "Leg Press", model: cybexLeg, defaultUnit: nil),
            // Same model as Chest Press #1 — the travel case.
            Machine(gymID: sf.id, label: "Chest Press A", model: lfInsignia, defaultUnit: nil),
            Machine(gymID: sf.id, label: "Seated Row", model: precorRow, defaultUnit: nil),
            Machine(gymID: sf.id, label: "Shoulder Press", model: lfShoulder, defaultUnit: .lb),
        ]

        let seatedChestPress = SampleExercise(name: "Seated Chest Press")
        let latPulldown = SampleExercise(name: "Lat Pulldown", tags: [.machine, .cable])
        let seatedRow = SampleExercise(name: "Seated Row", tags: [.machine, .cable])
        let legPress = SampleExercise(name: "Leg Press")
        let shoulderPress = SampleExercise(name: "Machine Shoulder Press")
        let benchPress = SampleExercise(name: "Bench Press", tags: [.barbell])
        let squat = SampleExercise(name: "Squat", tags: [.barbell])
        let pullUp = SampleExercise(name: "Pull-Up", loadType: .bodyweightPlus, tags: [.bodyweight])
        let assistedPullUp = SampleExercise(name: "Assisted Pull-Up", loadType: .assisted)
        let dbCurl = SampleExercise(name: "Dumbbell Curl", tags: [.dumbbell])
        let pushdown = SampleExercise(name: "Triceps Pushdown", tags: [.cable])
        let dip = SampleExercise(name: "Dip", loadType: .bodyweightPlus, tags: [.bodyweight])
        exercises = [
            seatedChestPress, latPulldown, seatedRow, legPress, shoulderPress,
            benchPress, squat, pullUp, assistedPullUp, dbCurl, pushdown, dip,
        ]

        templates = [
            SampleWorkoutTemplate(name: "Push Day", exerciseNames: ["Seated Chest Press", "Bench Press", "Machine Shoulder Press", "Triceps Pushdown"]),
            SampleWorkoutTemplate(name: "Pull Day", exerciseNames: ["Lat Pulldown", "Seated Row", "Assisted Pull-Up", "Dumbbell Curl"]),
            SampleWorkoutTemplate(name: "Leg Day", exerciseNames: ["Squat", "Leg Press"]),
        ]

        let chestPress1 = machines[0]
        let assistMachine = machines[3]
        let chestPressA = machines[5]
        let precorRowMachine = machines[6]
        let tgLatMachine = machines[2]

        // Active workout: Push Day at Gangnam, mid-session.
        activeWorkout = SampleWorkout(
            name: "Push Day",
            date: .now,
            gym: gangnam,
            entries: [
                WorkoutEntry(
                    exercise: seatedChestPress,
                    machine: chestPress1,
                    freeWeightTag: nil,
                    sets: [
                        LoggedSet(type: .warmup, weightText: "40", repsText: "12", unit: .kg, completed: true, prevWeight: 40, prevReps: 12, prevUnit: .kg),
                        LoggedSet(type: .working, weightText: "60", repsText: "10", unit: .kg, completed: true, prevWeight: 60, prevReps: 10, prevUnit: .kg),
                        LoggedSet(type: .working, weightText: "60", repsText: "", unit: .kg, completed: false, prevWeight: 60, prevReps: 9, prevUnit: .kg),
                    ]
                ),
                WorkoutEntry(
                    exercise: benchPress,
                    machine: nil,
                    freeWeightTag: .barbell,
                    sets: [
                        // User overrode the gym's kg default on this one.
                        LoggedSet(type: .working, weightText: "135", repsText: "8", unit: .lb, completed: true, prevWeight: 135, prevReps: 8, prevUnit: .lb),
                        LoggedSet(type: .working, weightText: "135", repsText: "", unit: .lb, completed: false, prevWeight: 135, prevReps: 6, prevUnit: .lb),
                    ]
                ),
                WorkoutEntry(
                    exercise: assistedPullUp,
                    machine: assistMachine,
                    freeWeightTag: nil,
                    sets: [
                        LoggedSet(type: .working, weightText: "25", repsText: "", unit: .kg, completed: false, prevWeight: 30, prevReps: 8, prevUnit: .kg),
                    ]
                ),
            ],
            durationMinutes: 24
        )

        // History across both gyms, mixed units.
        let cal = Calendar.current
        func daysAgo(_ d: Int) -> Date { cal.date(byAdding: .day, value: -d, to: .now) ?? .now }

        func doneSet(_ type: SetType = .working, _ w: Double, _ r: Int, _ u: WeightUnit) -> LoggedSet {
            LoggedSet(type: type, weightText: Format.weight(w), repsText: String(r), unit: u, completed: true)
        }

        history = [
            SampleWorkout(
                name: "Pull Day", date: daysAgo(1), gym: gangnam,
                entries: [
                    WorkoutEntry(exercise: latPulldown, machine: tgLatMachine, freeWeightTag: nil, sets: [
                        doneSet(.warmup, 35, 12, .kg), doneSet(.working, 55, 10, .kg), doneSet(.working, 55, 9, .kg), doneSet(.failure, 60, 6, .kg),
                    ]),
                    WorkoutEntry(exercise: assistedPullUp, machine: assistMachine, freeWeightTag: nil, sets: [
                        doneSet(.working, 30, 8, .kg), doneSet(.working, 30, 7, .kg),
                    ]),
                    WorkoutEntry(exercise: dbCurl, machine: nil, freeWeightTag: .dumbbell, sets: [
                        doneSet(.working, 14, 12, .kg), doneSet(.working, 14, 10, .kg),
                    ]),
                ],
                durationMinutes: 52
            ),
            SampleWorkout(
                name: "Push Day", date: daysAgo(4), gym: gangnam,
                entries: [
                    WorkoutEntry(exercise: seatedChestPress, machine: chestPress1, freeWeightTag: nil, sets: [
                        doneSet(.warmup, 40, 12, .kg), doneSet(.working, 60, 10, .kg), doneSet(.working, 60, 9, .kg),
                    ]),
                    WorkoutEntry(exercise: benchPress, machine: nil, freeWeightTag: .barbell, sets: [
                        doneSet(.working, 135, 8, .lb), doneSet(.working, 135, 6, .lb),
                    ]),
                ],
                durationMinutes: 61
            ),
            SampleWorkout(
                name: "Push Day (travel)", date: daysAgo(21), gym: sf,
                entries: [
                    WorkoutEntry(exercise: seatedChestPress, machine: chestPressA, freeWeightTag: nil, sets: [
                        doneSet(.warmup, 90, 12, .lb), doneSet(.working, 135, 10, .lb), doneSet(.working, 135, 8, .lb),
                    ]),
                    WorkoutEntry(exercise: shoulderPress, machine: machines[7], freeWeightTag: nil, sets: [
                        doneSet(.working, 80, 10, .lb), doneSet(.working, 80, 9, .lb),
                    ]),
                ],
                durationMinutes: 48
            ),
            SampleWorkout(
                name: "Pull Day (travel)", date: daysAgo(23), gym: sf,
                entries: [
                    WorkoutEntry(exercise: seatedRow, machine: precorRowMachine, freeWeightTag: nil, sets: [
                        doneSet(.working, 120, 10, .lb), doneSet(.working, 120, 10, .lb),
                    ]),
                    WorkoutEntry(exercise: pullUp, machine: nil, freeWeightTag: .bodyweight, sets: [
                        doneSet(.working, 0, 8, .lb), doneSet(.working, 0, 6, .lb),
                    ]),
                ],
                durationMinutes: 44
            ),
            SampleWorkout(
                name: "Leg Day", date: daysAgo(35), gym: gangnam,
                entries: [
                    WorkoutEntry(exercise: squat, machine: nil, freeWeightTag: .barbell, sets: [
                        doneSet(.warmup, 60, 8, .kg), doneSet(.working, 100, 5, .kg), doneSet(.working, 100, 5, .kg),
                    ]),
                    WorkoutEntry(exercise: legPress, machine: machines[4], freeWeightTag: nil, sets: [
                        doneSet(.working, 180, 10, .kg), doneSet(.working, 180, 10, .kg),
                    ]),
                ],
                durationMinutes: 58
            ),
        ]
    }

    // MARK: Queries

    func machines(at gym: SampleGym) -> [Machine] {
        machines.filter { $0.gymID == gym.id }
    }

    func gymName(for machine: Machine) -> String {
        gyms.first { $0.id == machine.gymID }?.name ?? "Unknown gym"
    }

    /// Static sample of the layered previous-performance panel
    /// (this machine → same model elsewhere → any equipment).
    func performanceLayers(for entry: WorkoutEntry) -> [PerformanceLayer] {
        if entry.exercise.loadType == .assisted {
            return [
                PerformanceLayer(kind: .thisMachine, lines: [
                    "Last: 30 kg assist × 8, 30 × 7 (yesterday)",
                    "Best (least assistance) at 8 reps: 25 kg",
                    "Trend: assistance down 10 kg over 6 weeks",
                ]),
                PerformanceLayer(kind: .anyEquipment, lines: [
                    "No other assisted machines logged",
                ]),
            ]
        }
        return [
            PerformanceLayer(kind: .thisMachine, lines: [
                "Last: 60 kg × 10, 60 × 9 (4 days ago)",
                "Best 10-rep: 60 kg · Best 8-rep: 65 kg",
                "Est. 1RM 80 kg (Brzycki)",
            ]),
            PerformanceLayer(kind: .sameModel(gymName: "Fitness SF Transbay"), lines: [
                "Chest Press A · same model (Life Fitness Insignia)",
                "Last: 135 lb × 10 (3 weeks ago)",
                "Best 10-rep: 135 lb",
            ]),
            PerformanceLayer(kind: .anyEquipment, lines: [
                "3 machines logged for this exercise",
                "Heaviest set anywhere: 70 kg × 8 (Chest Press #2)",
            ]),
        ]
    }
}
