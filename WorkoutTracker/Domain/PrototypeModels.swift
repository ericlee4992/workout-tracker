import Foundation

// Milestone-1 prototype domain: plain value types standing in for the future
// SwiftData schema (docs/SPEC.md, "Data model sketch"). Replaced at milestone 2.

enum WeightUnit: String, CaseIterable, Identifiable, Codable {
    case kg
    case lb

    var id: String { rawValue }
    var toggled: WeightUnit { self == .kg ? .lb : .kg }
}

enum SetType: CaseIterable, Hashable {
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

enum LoadType: Hashable {
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

enum EquipmentTag: String, CaseIterable, Identifiable, Hashable {
    case machine = "Machine"
    case barbell = "Barbell"
    case dumbbell = "Dumbbell"
    case cable = "Cable"
    case smith = "Smith machine"
    case bodyweight = "Bodyweight"

    var id: String { rawValue }
}

struct Exercise: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var loadType: LoadType = .weighted
    var tags: [EquipmentTag] = [.machine]
}

struct EquipmentModel: Identifiable, Hashable {
    let id = UUID()
    var manufacturer: String
    var model: String

    var displayName: String { "\(manufacturer) \(model)" }
}

struct Gym: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var city: String
    var defaultUnit: WeightUnit
}

struct Machine: Identifiable, Hashable {
    let id = UUID()
    var gymID: UUID
    var label: String
    var model: EquipmentModel?
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
    var exercise: Exercise
    var machine: Machine?
    var freeWeightTag: EquipmentTag?
    var sets: [LoggedSet]
    var workingRest: Int = 120
    var warmupRest: Int = 60

    var equipmentLabel: String {
        if let machine { return machine.label }
        if let freeWeightTag { return freeWeightTag.rawValue }
        return "Choose equipment"
    }
}

struct Workout: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var date: Date
    var gym: Gym?
    var entries: [WorkoutEntry]
    var durationMinutes: Int

    var totalSets: Int { entries.reduce(0) { $0 + $1.sets.count } }
}

struct WorkoutTemplate: Identifiable, Hashable {
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

enum Format {
    static func weight(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }
}
