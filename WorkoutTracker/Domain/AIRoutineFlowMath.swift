import Foundation

// Floodlight ticket 10 — the Ask AI flow's pure pieces: goal phrases, profile units, the
// generating stages, and the week's readouts. Everything derives from the request and the
// generated routine; nothing here is stored.

// MARK: - Goal phrases

/// Quick chips that add their phrase to the free-text goal, or take it out again. A chip's
/// selected state is read from the text, so the text stays the single source of truth.
enum AIGoalPhrase: String, CaseIterable, Identifiable {
    case strength = "Build strength"
    case muscle = "Build muscle"
    case endurance = "Improve endurance"
    case fatLoss = "Lose fat"

    var id: String { rawValue }

    func isIn(_ text: String) -> Bool { text.range(of: rawValue, options: .caseInsensitive) != nil }

    func toggled(in text: String) -> String {
        if isIn(text) {
            var result = text
            for variant in [rawValue + ".", rawValue + ",", rawValue] {
                while let range = result.range(of: variant, options: .caseInsensitive) { result.removeSubrange(range) }
            }
            while result.contains("  ") { result = result.replacingOccurrences(of: "  ", with: " ") }
            result = result.trimmingCharacters(in: .whitespaces)
            while let first = result.first, ".,".contains(first) {
                result.removeFirst()
                result = result.trimmingCharacters(in: .whitespaces)
            }
            return result
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return rawValue + "." }
        if let last = trimmed.last, ".!?".contains(last) { return trimmed + " " + rawValue + "." }
        return trimmed + ". " + rawValue + "."
    }
}

// MARK: - Profile units

/// The optional profile in the user's units (ticket 10, decision 4). The request always carries
/// cm and kg; the fields take whole numbers (number pad).
enum AIProfileUnits {
    static func feetInches(cm: Double) -> (feet: Int, inches: Int) {
        let total = Int((cm / 2.54).rounded())
        return (total / 12, total % 12)
    }

    static func centimetres(feet: Int, inches: Int) -> Double {
        Double(feet * 12 + inches) * 2.54
    }

    static func pounds(kg: Double) -> Double { kg / WeightMath.kilogramsPerPound }
    static func kilograms(pounds: Double) -> Double { pounds * WeightMath.kilogramsPerPound }

    /// A stored value as a whole-number field ("" when empty).
    static func text(_ value: Double?) -> String {
        guard let value else { return "" }
        return String(Int(value.rounded()))
    }

    /// The digits typed (at most four), nil when there are none.
    static func parse(_ text: String) -> Int? {
        Int(text.filter(\.isNumber).prefix(4))
    }
}

// MARK: - Generating stages

/// What the wait shows while OpenAI builds the week (ticket 10, decision 1): a timed illustration,
/// not measured progress — the API reports none. It holds at the last stage until the reply.
enum AIRoutineStages {
    struct Stage: Equatable {
        var at: TimeInterval
        var progress: Double
        var text: String
    }

    static func stages(gymName: String?) -> [Stage] {
        [Stage(at: 0, progress: 0.08, text: "Building your week…"),
         Stage(at: 0.8, progress: 0.35, text: gymName.map { "Checking equipment at \($0)…" } ?? "Checking your equipment…"),
         Stage(at: 1.7, progress: 0.65, text: "Balancing muscle families…"),
         Stage(at: 2.5, progress: 0.9, text: "Fitting sessions to your time…")]
    }

    /// The stage shown `elapsed` seconds into the request.
    static func stage(at elapsed: TimeInterval, gymName: String?) -> Stage {
        let all = stages(gymName: gymName)
        return all.last { $0.at <= elapsed } ?? all[0]
    }
}

// MARK: - Readouts

enum AIRoutineReadouts {
    /// A session's length by the validator's own estimate (`AIRoutine.validated`): 45 s per set,
    /// rest between sets, 60 s per exercise, plus cardio minutes. Rounded to whole minutes.
    static func minutes(of day: AIRoutineDay) -> Int {
        let seconds = day.strength.reduce(0) { $0 + $1.sets * 45 + max(0, $1.sets - 1) * $1.restSeconds + 60 }
            + day.cardio.reduce(0) { $0 + $1.minutes * 60 }
        return Int((Double(seconds) / 60).rounded())
    }

    static func sets(of day: AIRoutineDay) -> Int { day.strength.reduce(0) { $0 + $1.sets } }

    /// Sets per family in one session, head to toe; families with no sets omitted. Exercises whose
    /// muscle group has no family (Core, Neck, Full Body) are not counted.
    static func familyCounts(of day: AIRoutineDay, groups: [UUID: String]) -> [FamilyCount] {
        var sets: [MuscleFamily: Int] = [:]
        for item in day.strength {
            if let family = MuscleFamily(muscleGroup: groups[item.exerciseID]) { sets[family, default: 0] += item.sets }
        }
        return MuscleFamily.allCases.compactMap { family in sets[family].map { FamilyCount(family: family, sets: $0) } }
    }

    /// One session's families by their share of its sets (most first, then head to toe).
    static func familyShares(of day: AIRoutineDay, groups: [UUID: String]) -> [FamilyCount] {
        familyCounts(of: day, groups: groups).enumerated().sorted { a, b in
            a.element.sets != b.element.sets ? a.element.sets > b.element.sets : a.offset < b.offset
        }.map(\.element)
    }

    /// All five families (zeros kept) summed across the week.
    static func weekFamilyCounts(_ days: [AIRoutineDay], groups: [UUID: String]) -> [FamilyCount] {
        var sets: [MuscleFamily: Int] = [:]
        for day in days {
            for count in familyCounts(of: day, groups: groups) { sets[count.family, default: 0] += count.sets }
        }
        return MuscleFamily.allCases.map { FamilyCount(family: $0, sets: sets[$0] ?? 0) }
    }

    /// The families at least one exercise the AI may use trains.
    static func eligibleFamilies(_ options: [RoutineExerciseOption]) -> Set<MuscleFamily> {
        Set(options.compactMap { MuscleFamily(muscleGroup: $0.muscleGroup) })
    }

    /// "Iron Temple · 3 days · 45 min", leaving out the gym when `line` already names it.
    static func requestLine(gymName: String?, days: Int, minutes: Int, omittingGymIn line: String = "") -> String {
        var parts: [String] = []
        if let gymName, !line.contains(gymName) { parts.append(gymName) }
        parts.append("\(days) \(days == 1 ? "day" : "days")")
        parts.append("\(minutes) min")
        return parts.joined(separator: " · ")
    }
}

// MARK: - Error text

enum AIRoutineErrorText {
    /// "Could not reach OpenAI. Check your connection or continue manually." → ("Could not reach
    /// OpenAI.", "Check your connection."): what happened, what to do. The error step offers no
    /// manual path, so "or continue manually" is dropped from what it shows.
    static func split(_ message: String) -> (what: String, next: String?) {
        let shown = message.replacingOccurrences(of: " or continue manually.", with: ".")
        guard let range = shown.range(of: ". ") else { return (shown, nil) }
        return (String(shown[..<range.lowerBound]) + ".", String(shown[range.upperBound...]))
    }
}
