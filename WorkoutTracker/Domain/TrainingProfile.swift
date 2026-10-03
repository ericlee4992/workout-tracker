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

    /// The server's checks (training.ts), which are Ask AI's bounds (AIRoutineFlowModel.next): a non-blank goal of at
    /// most 1,000 characters without control characters (tab and line breaks allowed), 50–250 cm, 20–400 kg.
    var isValid: Bool {
        let trimmed = goals.trimmingCharacters(in: .whitespacesAndNewlines)
        let control = trimmed.unicodeScalars.contains {
            ($0.value < 0x20 && ![0x09, 0x0A, 0x0D].contains($0.value)) || $0.value == 0x7F
        }
        return !trimmed.isEmpty && !control && trimmed.count <= Self.maxGoalLength
            && Self.experiences.contains(experience) && Self.dayRange.contains(days)
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

    /// As entered (codex-review-05 #2): "178 cm", "82.5 kg", "180 lb", "5 ft 10.5 in" — never rounded to a
    /// different value.
    var display: String {
        switch unit {
        case .cm: "\(Self.number(value)) cm"
        case .inches: "\(Int(value / 12)) ft \(Self.number(value - Double(Int(value / 12) * 12))) in"
        case .kg: "\(Self.number(value)) kg"
        case .lb: "\(Self.number(value)) lb"
        }
    }

    /// The value without a trailing ".0", up to two decimals (as typed), in the POSIX locale (the field's).
    static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never).locale(Locale(identifier: "en_US_POSIX")))
    }

    /// A typed number ("82.5", "82,5"): digits and one decimal separator, at most two decimals; nil when empty.
    static func parse(_ text: String) -> Double? {
        let cleaned = text.replacingOccurrences(of: ",", with: ".").filter { $0.isNumber || $0 == "." }
        let parts = cleaned.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard let whole = parts.first, !(whole.isEmpty && parts.count == 1) else { return nil }
        let fraction = parts.count > 1 ? String(parts[1].filter(\.isNumber).prefix(2)) : ""
        return Double("\(whole.isEmpty ? "0" : String(whole.prefix(4))).\(fraction.isEmpty ? "0" : fraction)")
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
