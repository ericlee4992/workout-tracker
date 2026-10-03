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

    /// The value as entered, without a trailing ".0" — every stored decimal shown (up to six, beyond anything the
    /// editor accepts), in the POSIX locale (the field's).
    static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...6)).grouping(.never).locale(Locale(identifier: "en_US_POSIX")))
    }
}

/// A typed number, read strictly (codex-review-05b #2): what is accepted is exactly what is saved, never truncated or
/// clamped; anything else is `.invalid` and keeps Save off.
enum TypedNumber: Equatable {
    case empty
    case value(Double)
    case invalid

    /// Up to four digits, optionally a point or comma and one or two decimals ("82", "82.5", "82,25", "0.5").
    init(_ text: String, decimals: Bool = true) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { self = .empty; return }
        let pattern = decimals ? #"^\d{1,4}([.,]\d{1,2})?$"# : #"^\d{1,4}$"#
        guard trimmed.range(of: pattern, options: .regularExpression) != nil,
              let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")) else { self = .invalid; return }
        self = .value(value)
    }
}

/// The editor's staged text for one measurement (codex-review-05b #1): feet and inches kept together, the measurement
/// derived from both current strings. A field left as it was keeps the stored value exactly, whatever its precision.
struct MeasureDraft: Equatable {
    enum Kind { case height, weight }
    let kind: Kind
    /// Height in feet + inches, weight in pounds (else cm / kg).
    let imperial: Bool
    var first: String
    var second: String
    private let original: BodyMeasure?
    private let originalTexts: [String]

    init(_ measure: BodyMeasure?, kind: Kind, imperial: Bool) {
        self.kind = kind
        self.imperial = imperial
        original = measure
        switch (kind, imperial, measure) {
        case (.height, true, let m?):
            let feet = Int(m.value / 12)
            first = String(feet)
            second = BodyMeasure.number(m.value - Double(feet * 12))
        case (_, _, let m?):
            first = BodyMeasure.number(m.value)
            second = ""
        default:
            first = ""
            second = ""
        }
        originalTexts = [first, second]
    }

    /// The measurement to save: `.some(nil)` when cleared, nil (the outer optional) when the text is not a valid entry.
    var measure: BodyMeasure?? {
        if [first, second] == originalTexts { return .some(original) }
        let unit: BodyMeasure.Unit = switch (kind, imperial) {
        case (.height, true): .inches
        case (.height, false): .cm
        case (.weight, true): .lb
        case (.weight, false): .kg
        }
        if kind == .height && imperial {
            let feet = TypedNumber(first, decimals: false), inches = TypedNumber(second)
            switch (feet, inches) {
            case (.empty, .empty): return .some(nil)
            case (.invalid, _), (_, .invalid): return nil
            default:
                let f: Double = if case .value(let v) = feet { v } else { 0 }
                let i: Double = if case .value(let v) = inches { v } else { 0 }
                guard i < 12 else { return nil }   // 12 or more inches is not an entry; never carried silently
                return .some(BodyMeasure(value: f * 12 + i, unit: unit))
            }
        }
        switch TypedNumber(first) {
        case .empty: return .some(nil)
        case .invalid: return nil
        case .value(let v): return .some(BodyMeasure(value: v, unit: unit))
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
