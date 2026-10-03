import Foundation

/// Public beta ticket 05: the saved training profile (spec → Profile page; amends D58). The inputs Ask AI for Templates
/// asks for, kept with the account on the server. Height and weight keep the value and unit entered (D52): never
/// silently converted; Ask AI converts only for its request.
struct TrainingProfile: Codable, Equatable {
    static let experiences = ["Beginner", "Intermediate", "Experienced"]
    static let dayRange = 1...7
    /// Ask AI's minutes control (AIMinutesControl).
    static let minuteRange = 15...120
    static let maxGoalLength = 1000

    var goals: String
    var experience: String
    var days: Int
    var minutes: Int
    var height: BodyMeasure?
    var weight: BodyMeasure?

    static let empty = TrainingProfile(goals: "", experience: "Beginner", days: 3, minutes: 45)

    /// Ask AI's bounds (AIRoutineFlowModel.next): a goal under 1,000 characters, 50–250 cm, 20–400 kg.
    var isValid: Bool {
        goals.count <= Self.maxGoalLength && Self.experiences.contains(experience) && Self.dayRange.contains(days)
            && Self.minuteRange.contains(minutes)
            && (height.map { (50...250).contains($0.centimetres) } ?? true)
            && (weight.map { (20...400).contains($0.kilograms) } ?? true)
    }
}

/// A body measurement as entered: centimetres or inches for height (feet and inches are stored as total inches),
/// kilograms or pounds for weight.
struct BodyMeasure: Codable, Equatable {
    enum Unit: String, Codable { case cm, inches = "in", kg, lb }
    var value: Double
    var unit: Unit

    var centimetres: Double {
        switch unit {
        case .cm: value
        case .inches: value * 2.54
        case .kg, .lb: .nan
        }
    }

    var kilograms: Double {
        switch unit {
        case .kg: value
        case .lb: AIProfileUnits.kilograms(pounds: value)
        case .cm, .inches: .nan
        }
    }

    /// As shown: "178 cm", "5 ft 10 in", "82 kg", "180 lb" (whole numbers, as Ask AI's fields take them).
    var display: String {
        switch unit {
        case .cm: "\(Int(value.rounded())) cm"
        case .inches: "\(Int(value.rounded()) / 12) ft \(Int(value.rounded()) % 12) in"
        case .kg: "\(Int(value.rounded())) kg"
        case .lb: "\(Int(value.rounded())) lb"
        }
    }
}

/// What the profile page shows (from `GET /v1/profile` and `GET /v1/ai/usage` once wired).
struct AccountProfile: Equatable {
    var displayName: String
    var email: String
    var provider: String
    var memberSince: Date
    var training: TrainingProfile?
    var aiUsage: [AIUsage]
    var aiResetsAt: Date
    var aiPaused: Bool

    struct AIUsage: Equatable, Identifiable {
        var id: String { flow }
        var flow: String
        var title: String
        var used: Int
        var limit: Int
    }
}
