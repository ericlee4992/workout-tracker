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

/// Editing-field formatting (weight text fields): integer weights drop the
/// decimal, fractional ones keep a single place. Display-only formatting for
/// history lives in `WeightMath` (D25).
enum Format {
    static func weight(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }
}
