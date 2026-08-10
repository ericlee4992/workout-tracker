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

/// D12, amended by D26. Raw values are persisted — `drop` is appended, never
/// inserted, so stores written before it existed keep decoding.
enum SetType: String, CaseIterable, Codable {
    case warmup
    case working
    case failure
    case drop

    var marker: String? {
        switch self {
        case .warmup: "W"
        case .working: nil
        case .failure: "F"
        case .drop: "D"
        }
    }

    /// Named option in the row's set-type menu (E5).
    var displayName: String {
        switch self {
        case .warmup: "Warmup"
        case .working: "Working"
        case .failure: "Failure"
        case .drop: "Drop"
        }
    }

    /// D26: a drop set is *by definition* performed without resting, so
    /// completing one starts no rest timer. Every other type rests, on the
    /// durations D13/D22 lay down (warmup duration for warmups, working
    /// duration for working and failure).
    var startsRestTimer: Bool {
        switch self {
        case .warmup, .working, .failure: true
        case .drop: false
        }
    }

    /// D12/D26: only warmups are excluded from records and volume — working,
    /// failure and drop sets are all real work. `RecordsMath` is the one
    /// place that decides eligibility; this states the rule it applies.
    var countsTowardRecords: Bool { self != .warmup }
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

    /// `m:ss` for every rest duration the app shows — the running timer, the
    /// global defaults, and the per-exercise overrides read the same way.
    static func duration(seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
