import Foundation

// Display formatting. Plain numbers (D52): no ≈, no "estimated". Weights show as
// entered, trimmed ("102.5", "110"); derived kg figures (volume, 1RM) convert
// plainly to the display unit. Dates are en_US so captures are deterministic.

enum Format {
    static let locale = Locale(identifier: "en_US")

    // MARK: Numbers

    private static func formatter(maxFraction: Int, grouping: Bool) -> NumberFormatter {
        let f = NumberFormatter()
        f.locale = locale
        f.numberStyle = .decimal
        f.usesGroupingSeparator = grouping
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = maxFraction
        f.roundingMode = .halfUp
        return f
    }
    private static let plain2 = formatter(maxFraction: 2, grouping: false)
    private static let plain1 = formatter(maxFraction: 1, grouping: false)
    private static let grouped0 = formatter(maxFraction: 0, grouping: true)

    /// "60", "62.5", "61.23" (≤ 2 decimals, trailing zeros trimmed).
    static func number(_ value: Double) -> String {
        plain2.string(from: value as NSNumber) ?? "\(value)"
    }
    /// "18,450"
    static func grouped(_ value: Double) -> String {
        grouped0.string(from: value.rounded() as NSNumber) ?? "\(Int(value))"
    }
    static func grouped(_ value: Int) -> String { grouped(Double(value)) }

    // MARK: Weights and sets

    /// "102.5"
    static func weight(_ value: Double) -> String { number(value) }
    /// "102.5 lb"
    static func weight(_ value: Double, _ unit: WeightUnit) -> String { "\(number(value)) \(unit.label)" }
    /// A derived kg figure (1RM, per-set best) in the display unit, plain: "231.5 lb".
    static func weight(kilograms: Double, in unit: WeightUnit) -> String {
        weight(unit.fromKg(kilograms), unit)
    }
    /// Volume number only: "18,450".
    static func volumeNumber(kilograms: Double, in unit: WeightUnit) -> String {
        grouped(unit.fromKg(kilograms))
    }
    /// "18,450 lb"
    static func volume(kilograms: Double, in unit: WeightUnit) -> String {
        "\(volumeNumber(kilograms: kilograms, in: unit)) \(unit.label)"
    }

    /// "110 lb × 8", "12 reps" (bodyweight, or no weight).
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

    /// History bar breakdown: "45 + 45 × 2 = 135 lb" or "45 lb bar = 45 lb".
    static func barBreakdown(_ value: SetValue) -> String? {
        guard let bar = value.bar, let total = value.weight, let perSide = value.perSide else { return nil }
        if perSide <= 0 { return "\(weight(bar, value.unit)) bar = \(weight(total, value.unit))" }
        return "\(weight(bar)) + \(weight(perSide)) × 2 = \(weight(total, value.unit))"
    }
    /// Live bar-mode caption: "= 135 lb".
    static func barTotal(_ total: Double, _ unit: WeightUnit) -> String { "= \(weight(total, unit))" }
    /// "Target: 4 sets · 12, 10, 8, 8 reps" body without the prefix: "4 sets · 12, 10, 8, 8 reps".
    static func targets(_ reps: [Int]) -> String {
        guard !reps.isEmpty else { return "No sets" }
        let sets = "\(reps.count) set\(reps.count == 1 ? "" : "s")"
        let values = reps.map(String.init).joined(separator: ", ")
        return "\(sets) · \(values) reps"
    }

    // MARK: Time

    /// "m:ss" — rest durations and timers: "2:00", "1:24".
    static func duration(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
    /// Rest default rows: "2:00".
    static func rest(_ seconds: Int) -> String { duration(seconds) }
    /// A running clock with seconds: "18:42", "1:02:03".
    static func elapsed(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return s < 3600
            ? String(format: "%d:%02d", s / 60, s % 60)
            : String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
    /// "12 minutes 34 seconds" (VoiceOver).
    static func spokenElapsed(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h) hour\(h == 1 ? "" : "s")") }
        if h > 0 || m > 0 { parts.append("\(m) minute\(m == 1 ? "" : "s")") }
        parts.append("\(sec) second\(sec == 1 ? "" : "s")")
        return parts.joined(separator: " ")
    }
    /// History duration: "52 min", "45s" under a minute.
    static func minutes(_ seconds: Int) -> String {
        seconds < 60 ? "\(max(0, seconds))s" : "\(seconds / 60) min"
    }
    /// "7.4 h"
    static func hours(_ hours: Double) -> String { "\(plain1.string(from: hours as NSNumber) ?? "0") h" }

    // MARK: Dates

    private static func dateFormatter(_ template: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.calendar = Calendar.app
        f.timeZone = Calendar.app.timeZone
        f.setLocalizedDateFormatFromTemplate(template)
        return f
    }
    private static let dayF = dateFormatter("EEEMMMd")
    private static let shortF = dateFormatter("MMMd")
    private static let mediumF: DateFormatter = {
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = Calendar.app.timeZone
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
    private static let monthF = dateFormatter("MMMyyyy")
    private static let monthNameF = dateFormatter("MMMM")
    private static let timeF = dateFormatter("jmm")
    private static let weekdayF = dateFormatter("EEEE")

    /// "Thu, Sep 24"
    static func day(_ date: Date) -> String { dayF.string(from: date) }
    /// "Sep 24"
    static func shortDate(_ date: Date) -> String { shortF.string(from: date) }
    /// "Sep 24, 2026" (Save as Template default: "Workout Sep 24, 2026").
    static func mediumDate(_ date: Date) -> String { mediumF.string(from: date) }
    /// "Sep 2026"
    static func month(_ date: Date) -> String { monthF.string(from: date) }
    /// "September"
    static func monthName(_ date: Date) -> String { monthNameF.string(from: date) }
    /// "6:30 PM"
    static func time(_ date: Date) -> String { timeF.string(from: date) }
    /// "Thursday"
    static func weekday(_ date: Date) -> String { weekdayF.string(from: date) }
    /// "M", "T", "W"…
    static func weekdayLetter(_ date: Date) -> String {
        let symbols = Calendar.app.veryShortWeekdaySymbols
        return symbols[Calendar.app.component(.weekday, from: date) - 1]
    }
    /// "Today", "Yesterday", "3 days ago", then "Sep 12".
    static func relativeDay(_ date: Date, now: Date) -> String {
        let cal = Calendar.app
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: now)).day ?? 0
        switch days {
        case 0: return "Today"
        case 1: return "Yesterday"
        case 2...6: return "\(days) days ago"
        default: return shortDate(date)
        }
    }

    // MARK: Cardio

    /// Pace "8:43" (seconds per unit), or "—".
    static func pace(_ secondsPerUnit: Double?) -> String {
        guard let s = secondsPerUnit, s.isFinite, s > 0 else { return "—" }
        return duration(Int(s.rounded()))
    }
    /// "8:43 /mi"
    static func paceLabel(_ secondsPerUnit: Double?, _ unit: DistanceUnit) -> String {
        "\(pace(secondsPerUnit)) /\(unit.label)"
    }
    /// Pace from a speed in m/s.
    static func pace(speed metersPerSecond: Double?, unit: DistanceUnit) -> String {
        guard let v = metersPerSecond, v > 0 else { return "—" }
        return pace(unit.metersPerUnit / v)
    }
    /// "3.1" (≤ 2 decimals, trimmed)
    static func distance(meters: Double, _ unit: DistanceUnit) -> String {
        number((meters / unit.metersPerUnit * 100).rounded() / 100)
    }
    /// "3.1 mi"
    static func distanceLabel(meters: Double, _ unit: DistanceUnit) -> String {
        "\(distance(meters: meters, unit)) \(unit.label)"
    }
    /// "18.4" units per hour.
    static func speed(metersPerSecond: Double, _ unit: DistanceUnit) -> String {
        plain1.string(from: (metersPerSecond * 3600 / unit.metersPerUnit) as NSNumber) ?? "—"
    }
    /// "18.4 mi/h"
    static func speedLabel(metersPerSecond: Double, _ unit: DistanceUnit) -> String {
        "\(speed(metersPerSecond: metersPerSecond, unit)) \(unit.label)/h"
    }

    // MARK: Vitals

    /// "128 bpm"
    static func bpm(_ value: Int) -> String { "\(value) bpm" }
    /// "96 cal"
    static func calories(_ value: Int) -> String { "\(value) cal" }
    /// "+6%", "−3%", "0%"
    static func percent(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        if rounded > 0 { return "+\(rounded)%" }
        if rounded < 0 { return "−\(-rounded)%" }
        return "0%"
    }

    /// "5 exercises", "1 set"
    static func count(_ n: Int, _ singular: String, _ plural: String? = nil) -> String {
        "\(grouped(n)) \(n == 1 ? singular : (plural ?? singular + "s"))"
    }
}
