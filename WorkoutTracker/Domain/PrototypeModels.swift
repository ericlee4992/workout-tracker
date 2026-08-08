import Foundation

// MARK: - Shared domain enums

// Stored by the SwiftData models (Domain/Models.swift). String raw values are
// stable storage identifiers — never change one once data has shipped; display
// text lives in computed properties (`label`, `badge`, `marker`), not raw values.

enum WeightUnit: String, CaseIterable, Identifiable, Codable {
    case kg
    case lb

    var id: String { rawValue }
    var toggled: WeightUnit { self == .kg ? .lb : .kg }
}

enum SetType: String, CaseIterable, Codable {
    case warmup
    case working
    case failure

    var marker: String? {
        switch self {
        case .warmup: "W"
        case .working: nil
        case .failure: "F"
        }
    }
}

enum LoadType: String, CaseIterable, Codable {
    case weighted
    case bodyweight
    case bodyweightPlus
    case assisted

    var badge: String {
        switch self {
        case .weighted: "Weighted"
        case .bodyweight: "Bodyweight"
        case .bodyweightPlus: "BW + added"
        case .assisted: "Assisted"
        }
    }
}

enum EquipmentTag: String, CaseIterable, Identifiable, Codable {
    case machine
    case barbell
    case dumbbell
    case cable
    case smith
    case bodyweight

    var id: String { rawValue }

    var label: String {
        switch self {
        case .machine: "Machine"
        case .barbell: "Barbell"
        case .dumbbell: "Dumbbell"
        case .cable: "Cable"
        case .smith: "Smith machine"
        case .bodyweight: "Bodyweight"
        }
    }
}

enum Format {
    static func weight(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }
}

// MARK: - Milestone-1 prototype value types

// Throwaway in-memory stand-ins backing SampleStore and the prototype screens.
// `Sample`-prefixed to keep the canonical names free for the SwiftData models.
// Ticket 07 rewires the UI onto SwiftData and deletes everything below.

struct SampleExercise: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var loadType: LoadType = .weighted
    var tags: [EquipmentTag] = [.machine]
}

struct SampleEquipmentModel: Identifiable, Hashable {
    let id = UUID()
    var manufacturer: String
    var model: String

    var displayName: String { "\(manufacturer) \(model)" }
}

struct SampleGym: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var city: String
    var defaultUnit: WeightUnit
}

struct Machine: Identifiable, Hashable {
    let id = UUID()
    var gymID: UUID
    var label: String
    var model: SampleEquipmentModel?
    var defaultUnit: WeightUnit?
}

struct LoggedSet: Identifiable, Hashable {
    let id = UUID()
    var type: SetType = .working
    var weightText: String = ""
    var repsText: String = ""
    var unit: WeightUnit = .kg
    var completed: Bool = false
    var prevWeight: Double?
    var prevReps: Int?
    var prevUnit: WeightUnit = .kg

    var previousLabel: String? {
        guard let prevWeight, let prevReps else { return nil }
        return "\(Format.weight(prevWeight)) \(prevUnit.rawValue) × \(prevReps)"
    }
}

struct WorkoutEntry: Identifiable, Hashable {
    let id = UUID()
    var exercise: SampleExercise
    var machine: Machine?
    var freeWeightTag: EquipmentTag?
    var sets: [LoggedSet]
    var workingRest: Int = 120
    var warmupRest: Int = 60

    var equipmentLabel: String {
        if let machine { return machine.label }
        if let freeWeightTag { return freeWeightTag.label }
        return "Choose equipment"
    }
}

struct SampleWorkout: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var date: Date
    var gym: SampleGym?
    var entries: [WorkoutEntry]
    var durationMinutes: Int

    var totalSets: Int { entries.reduce(0) { $0 + $1.sets.count } }
}

struct SampleWorkoutTemplate: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var exerciseNames: [String]
}

struct PerformanceLayer: Identifiable {
    enum Kind {
        case thisMachine
        case sameModel(gymName: String)
        case anyEquipment
    }

    let id = UUID()
    var kind: Kind
    var lines: [String]
}
