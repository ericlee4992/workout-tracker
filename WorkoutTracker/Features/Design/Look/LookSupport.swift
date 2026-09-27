import SwiftUI

// Plain display values the design components take. Screens build them from the SwiftData
// models; the components never read the store.

/// A live set row's state: an empty draft, a draft carried forward (untouched), a draft the
/// user typed, or a completed (logged) set.
enum LiveSetState: Hashable {
    case empty, prefilled, typed, completed
}

/// One heart-rate bar as the charts draw it (finish-graph ticket 01's display slot).
typealias HRSlot = HeartRateSeriesMath.DisplaySlot

/// The finish / history stat tiles, in the user's pair order (D54, ticket 17).
enum FinishTileKind: String, CaseIterable, Identifiable, Hashable {
    case workoutTime, totalVolume, activeCalories, totalCalories, averageHeartRate, maxHeartRate

    var id: String { rawValue }
    var label: String {
        switch self {
        case .workoutTime: "Workout time"
        case .totalVolume: "Total volume"
        case .activeCalories: "Active calories"
        case .totalCalories: "Total calories"
        case .averageHeartRate: "Avg. heart rate"
        case .maxHeartRate: "Max heart rate"
        }
    }
    var symbol: String {
        switch self {
        case .workoutTime: "timer"
        case .totalVolume: "scalemass"
        case .activeCalories: "flame.fill"
        case .totalCalories: "flame"
        case .averageHeartRate: "heart.fill"
        case .maxHeartRate: "arrow.up.heart.fill"
        }
    }
}

struct FinishTile: Identifiable, Hashable {
    var id: FinishTileKind { kind }
    var kind: FinishTileKind
    var value: String
    var unit: String
    var label: String { kind.label }
}

// MARK: - Display formatting for the components

/// Formatting the components use. Plain numbers (D52): no ≈, no "estimated". Weights show as
/// entered with at most 2 decimals, trimmed (`WeightMath.displayNumber`, D25).
enum LookFormat {
    private static func formatter(maxFraction: Int, grouping: Bool) -> NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.usesGroupingSeparator = grouping
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = maxFraction
        f.roundingMode = .halfUp
        return f
    }
    private static let grouped0 = formatter(maxFraction: 0, grouping: true)

    /// "60", "62.5", "61.23" (≤ 2 decimals, trailing zeros trimmed).
    static func number(_ value: Double) -> String { WeightMath.displayNumber(value) }
    /// "18,450"
    static func grouped(_ value: Double) -> String {
        grouped0.string(from: value.rounded() as NSNumber) ?? "\(Int(value))"
    }
    static func grouped(_ value: Int) -> String { grouped(Double(value)) }

    /// "102.5"
    static func weight(_ value: Double) -> String { number(value) }
    /// "102.5 lb"
    static func weight(_ value: Double, _ unit: WeightUnit) -> String { "\(number(value)) \(unit.rawValue)" }

    /// "110 lb × 8", "12 reps" (no weight: bodyweight).
    static func set(_ value: SetValue, loadType: LoadType = .weighted) -> String {
        guard loadType.takesWeight, let w = value.weight else { return reps(value.reps) }
        return "\(weight(w, value.unit)) × \(value.reps)"
    }
    /// "110 × 8" (the live PREVIOUS column / last-time comparisons).
    static func setShort(_ value: SetValue, loadType: LoadType = .weighted) -> String {
        guard loadType.takesWeight, let w = value.weight else { return reps(value.reps) }
        return "\(weight(w)) × \(value.reps)"
    }
    static func reps(_ n: Int) -> String { "\(n) rep\(n == 1 ? "" : "s")" }

    /// "m:ss" — rest durations and timers: "2:00", "1:24".
    static func duration(_ seconds: Int) -> String { Format.duration(seconds: max(0, seconds)) }
    /// A running clock with seconds: "18:42", "1:02:03".
    static func elapsed(_ seconds: Int) -> String { Format.elapsed(seconds: seconds) }
    /// "12 minutes 34 seconds" (VoiceOver).
    static func spokenElapsed(_ seconds: Int) -> String { Format.spokenElapsed(seconds: seconds) }

    private static func dateFormatter(_ template: String) -> DateFormatter {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate(template)
        return f
    }
    private static let shortF = dateFormatter("MMMd")
    private static let weekdayF = dateFormatter("EEEE")

    /// "Sep 24"
    static func shortDate(_ date: Date) -> String { shortF.string(from: date) }
    /// "Thursday"
    static func weekday(_ date: Date) -> String { weekdayF.string(from: date) }

    /// "+6%", "−3%", "0%"
    static func percent(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        if rounded > 0 { return "+\(rounded)%" }
        if rounded < 0 { return "−\(-rounded)%" }
        return "0%"
    }
}

extension LoadType {
    /// Whether a set of this load type carries a weight figure (plain bodyweight counts reps).
    var takesWeight: Bool { self != .bodyweight }
}

extension MuscleFamily: Identifiable {
    var id: String { rawValue }
    /// "Chest", "Back", … (the family's stored name).
    var label: String { rawValue }
    /// Template images in Assets.xcassets/MuscleMaps: the neutral body and the family's muscle.
    var bodyAsset: String { "MuscleMaps/\(rawValue.lowercased())-body" }
    var muscleAsset: String { "MuscleMaps/\(rawValue.lowercased())-muscle" }

    /// Families present, each once, in head-to-toe order.
    static func ordered(_ families: some Sequence<MuscleFamily>) -> [MuscleFamily] {
        let present = Set(families)
        return allCases.filter { present.contains($0) }
    }
}

extension WeightUnit {
    /// "kg" / "lb".
    var label: String { rawValue }
}
