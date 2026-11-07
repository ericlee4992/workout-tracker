import SwiftUI

// PROTOTYPE — Ask AI area helpers the Store / Look layers lack. Area-prefixed so the
// integrator can promote them. Every readout derives from `store.ai` and the catalog;
// nothing here keeps state of its own.

// MARK: - Store readouts

extension Store {
    /// Working sets per family in one generated session (families with no sets omitted),
    /// head to toe. Core / full-body exercises have no family and are not counted.
    func aiFamilyCounts(of day: AIRoutineDay) -> [FamilyCount] {
        var sets: [MuscleFamily: Int] = [:]
        for item in day.items {
            if let family = exercise(item.exerciseID)?.family { sets[family, default: 0] += item.sets }
        }
        return MuscleFamily.allCases.compactMap { family in
            sets[family].map { FamilyCount(family: family, sets: $0) }
        }
    }

    /// All five families (zeros kept) summed across the generated week.
    var aiWeekFamilyCounts: [FamilyCount] {
        var sets: [MuscleFamily: Int] = [:]
        for day in ai.days {
            for count in aiFamilyCounts(of: day) { sets[count.family, default: 0] += count.sets }
        }
        return MuscleFamily.allCases.map { FamilyCount(family: $0, sets: sets[$0] ?? 0) }
    }

    /// The families of one session, head to toe.
    func aiFamilies(of day: AIRoutineDay) -> [MuscleFamily] {
        families(exerciseIDs: day.items.map(\.exerciseID))
    }

    /// Families that at least one exercise the AI may use trains.
    var aiEligibleFamilies: Set<MuscleFamily> {
        Set(aiEligibleExerciseIDs.compactMap { exercise($0)?.family })
    }

    /// Where an exercise would be done: the machine at the chosen gym, else its free-weight tag.
    func aiEquipment(exerciseID: UUID) -> (label: String, symbol: String)? {
        if let machine = machines(for: exerciseID, gymID: ai.request.gymID).first {
            return (machine.label, LookIcon.machine)
        }
        guard let ex = exercise(exerciseID) else { return nil }
        let available = Set(ai.request.equipment.flatMap(\.tags))
        let tag = ex.tags.first { $0 != .machine && available.contains($0) } ?? ex.tags.first { $0 != .machine }
        guard let tag else { return nil }
        return (tag.label, tag.symbol)
    }

    /// The day editor's exercise list: eligible exercises not already in the session,
    /// grouped by muscle group head to toe (then Uncategorized), token search.
    func aiPickerSections(dayID: UUID, query: String) -> [(title: String, exercises: [Exercise])] {
        let used = Set(ai.days.first { $0.id == dayID }?.items.map(\.exerciseID) ?? [])
        let eligible = aiEligibleExerciseIDs
        return exerciseSections(query: query).compactMap { section in
            let items = section.exercises.filter { eligible.contains($0.id) && !used.contains($0.id) }
            return items.isEmpty ? nil : (section.group?.label ?? "Uncategorized", items)
        }
    }

    /// Cardio the day editor offers: the activities sent with the request (real behaviour).
    var aiCardioOptions: [CardioActivity] {
        CardioActivity.allCases.filter { ai.request.cardio.contains($0) }
    }

    /// One session's families ordered by their share of its sets (most first, then head to toe),
    /// so the dominant family leads its card and two same-named days read differently.
    func aiFamilyShares(of day: AIRoutineDay) -> [FamilyCount] {
        let counts = aiFamilyCounts(of: day)
        return counts.enumerated().sorted { a, b in
            a.element.sets != b.element.sets ? a.element.sets > b.element.sets : a.offset < b.offset
        }.map(\.element)
    }

    /// Sessions × minutes the generated week adds up to.
    var aiWeekMinutes: Int { ai.days.reduce(0) { $0 + $1.estimatedMinutes } }
    var aiWeekSets: Int { ai.days.reduce(0) { $0 + $1.setCount } }
}

// MARK: - Presentation helpers

extension CardioActivity {
    /// Indoor and outdoor walks / runs get distinct glyphs (the treadmill figures indoors), so
    /// the cardio tiles differ by more than a word.
    var aiSymbol: String {
        switch self {
        case .indoorWalk: "figure.walk.treadmill"
        case .indoorRun: "figure.run.treadmill"
        default: symbol
        }
    }
}

extension String {
    /// "Day 1 — Fitness" may wrap only before the dash ("Day 1" / "— Fitness"), never leaving
    /// the dash stranded at a line end or splitting "Day 1".
    var aiWrapFriendly: String {
        replacingOccurrences(of: " — ", with: " —\u{00A0}")
            .replacingOccurrences(of: "Day ", with: "Day\u{00A0}")
    }
}

/// Re-applies the prototype's Dynamic Type override inside a sheet (a `.sheet` does not
/// inherit it), so the AccessibilityL captures really are AccessibilityL.
struct AITypeOverride: ViewModifier {
    @Environment(Router.self) private var router
    func body(content: Content) -> some View {
        if let size = router.dynamicTypeOverride { content.dynamicTypeSize(size) } else { content }
    }
}

extension EnvironmentValues {
    /// Capture variant "still": the generating step drawn as it is under Reduce Motion.
    @Entry var aiStill: Bool = false
}

/// Tracks whether the generated week was edited by hand (Cancel then asks before discarding).
enum AIWeekEdits {
    static var edited = false
}

// MARK: - Selection (one treatment per look)

/// How a chosen tile, chip or cell is drawn — the same everywhere in the flow:
/// A lit like a scoreboard bulb (flood fill, ink content); B the pearl 12 % lozenge with a pearl
/// edge (the selected-tab vocabulary; the pearl FILL stays the one command); C inked (text-colour
/// fill, sheet-colour content) — cobalt fill stays the one primary.
struct AISelectionPaint {
    var look: Look
    var isSelected: Bool

    var fill: Color {
        switch look.id {
        case .floodlight: isSelected ? look.done : look.surface
        case .anatomy: look.surface
        case .paper, .carbon: isSelected ? look.done : look.surface
        }
    }
    /// B's lozenge over the fill.
    var wash: Color? { look.id == .anatomy && isSelected ? look.segmentFill : nil }
    var foreground: Color {
        switch look.id {
        case .floodlight: isSelected ? look.onDone : look.textSecondary
        case .anatomy: isSelected ? look.textPrimary : look.textSecondary
        case .paper, .carbon: isSelected ? look.onDone : look.textPrimary
        }
    }
    var edge: Color {
        switch look.id {
        case .floodlight: isSelected ? .clear : look.hairline
        // B: the chosen item is ringed in pearl; the others sit flat with no edge, so the
        // difference reads at a glance without spending the pearl FILL (the one command).
        case .anatomy: isSelected ? look.textPrimary : .clear
        case .paper, .carbon: look.outline
        }
    }
    var edgeWidth: CGFloat {
        switch look.id {
        case .floodlight: 1
        case .anatomy: isSelected ? 2 : 0
        case .paper, .carbon: look.stroke.pressable
        }
    }
}

// MARK: - Switch

/// The routine-consent switch. It is a state, not a command, so it never takes the action colour:
/// A and B light the track (flood / pearl = "on") and keep a white knob with a defined edge,
/// with a small ink check on the lit track; C keeps the look's switch.
struct AISwitchStyle: ToggleStyle {
    @Environment(\.look) private var look
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        if look.id.isPaperClub {
            Toggle(configuration).toggleStyle(.look)
        } else {
            let on = configuration.isOn
            Button {
                if reduceMotion { configuration.isOn.toggle() } else {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) { configuration.isOn.toggle() }
                }
            } label: {
                HStack(spacing: 0) {
                    configuration.label
                    Spacer(minLength: 12)
                    Capsule()
                        .fill(on ? look.done : look.ringTrack)
                        .frame(width: 51, height: 31)
                        .overlay(alignment: .leading) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(look.onDone)
                                .padding(.leading, 9)
                                .opacity(on ? 1 : 0)
                        }
                        .overlay(alignment: on ? .trailing : .leading) {
                            Circle()
                                .fill(on ? Color.white : look.textSecondary)
                                .overlay { Circle().strokeBorder(Color.black.opacity(on ? 0.22 : 0), lineWidth: 1) }
                                .frame(width: 27, height: 27)
                                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                                .padding(2)
                        }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityRepresentation { Toggle(isOn: configuration.$isOn) { configuration.label } }
        }
    }
}

// MARK: - Goal phrases (PROPOSED quick chips that write into the goal text)

/// Tapping a chip adds its phrase to the free-text goal, or takes it out again. The chip's
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

// MARK: - Profile units (plain conversions; the store keeps cm / kg)

enum AIProfileUnits {
    static func feetInches(cm: Double) -> (feet: Int, inches: Int) {
        let total = Int((cm / 2.54).rounded())
        return (total / 12, total % 12)
    }
    static func centimetres(feet: Int, inches: Int) -> Double {
        Double(feet * 12 + inches) * 2.54
    }
    /// Whole numbers only (the fields use the number pad).
    static func text(_ value: Double?) -> String {
        guard let value else { return "" }
        return String(Int(value.rounded()))
    }
    static func parse(_ text: String) -> Int? {
        Int(text.filter(\.isNumber).prefix(4))
    }
}

// MARK: - Ordering

extension AIStep {
    /// Position in the flow (drives the step indicator and push direction).
    var aiOrder: Int {
        switch self {
        case .goals: 0
        case .equipment: 1
        case .generating, .error: 2
        case .preview: 3
        case .saved: 4
        }
    }
}
