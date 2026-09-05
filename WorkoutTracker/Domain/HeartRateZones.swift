import Foundation

// Milestone 7, ticket 01 — maximum heart rate and the five zones (D45).
//
// THE RULE THIS FILE OWNS: with no basis at all no zone is shown, and a zone
// computed from a 220−age maximum CARRIES that fact (`isEstimated`,
// `zonesFromEstimatedMax`) wherever the data goes — store, summary, export.
//
// Until D52 (2026-09-04) every screen also SAID it ("(estimated)"); the user
// chose plain numbers, so screens no longer do. The flag stays because 220−age
// carries a standard deviation of about ±10–12 bpm, and a future screen that
// wants the mark back must be able to show it without guessing.

/// A maximum heart rate and whether it was measured or guessed at.
struct MaxHeartRate: Equatable, Sendable {
    let bpm: Int
    /// True when this came from the age formula rather than from the user.
    /// Carried through to the summary and the export; not shown (D52).
    let isEstimated: Bool
}

enum MaxHeartRateResolver {

    /// The classic Fox formula. Population-level, not personal — hence
    /// `isEstimated`.
    static func formulaBpm(age: Int) -> Int {
        220 - age
    }

    /// Completed years between `birthDate` and `date`.
    ///
    /// Computed at the **workout's** date, never at "now": a summary re-rendered
    /// or re-exported next year must not re-age the athlete and silently
    /// restate what zone last year's sets were in (D23's rule, applied to a
    /// derived number).
    static func age(
        birthDate: Date, at date: Date, calendar: Calendar = .current
    ) -> Int? {
        let years = calendar.dateComponents([.year], from: birthDate, to: date).year
        guard let years, years >= 0 else { return nil }
        return years
    }

    /// Resolves the maximum to use.
    ///
    /// A measured value always wins. Otherwise the formula, flagged. With
    /// neither, **nil** — the caller shows no zones rather than inventing an
    /// age, because a fabricated basis is worse than an absent feature.
    static func resolve(
        measured: Int?,
        birthDate: Date?,
        at date: Date,
        calendar: Calendar = .current
    ) -> MaxHeartRate? {
        if let measured, measured > 0 {
            return MaxHeartRate(bpm: measured, isEstimated: false)
        }
        guard let birthDate,
              let age = age(birthDate: birthDate, at: date, calendar: calendar)
        else { return nil }
        let bpm = formulaBpm(age: age)
        guard bpm > 0 else { return nil }
        return MaxHeartRate(bpm: bpm, isEstimated: true)
    }
}

/// The five training zones, as percentages of maximum heart rate.
///
/// Zone 0 ("warm") is not padding: below the zone-1 floor is not training, and
/// labelling it "Zone 1" would inflate every easy minute into work.
///
/// **These boundaries are 5 points ABOVE the textbook 50/60/70/80/90 (D45,
/// revised 2026-08-24 at the user's request after gym use).** The textbook
/// figures read one zone high for this user against a 220−age maximum. What
/// that means, and it matters: this app's "Zone 3" is NOT Polar's or Apple's
/// Zone 3 — do not compare a zone here against a zone there. The cleaner fix is
/// a measured maximum, which would let these go back to standard; see D45.
enum HeartRateZone: Int, CaseIterable, Sendable, Codable {
    case warm = 0
    case one = 1
    case two = 2
    case three = 3
    case four = 4
    case five = 5

    /// Lower bound as a fraction of max, inclusive. Textbook values +5 points
    /// — see the type's note before changing these back.
    var lowerFraction: Double {
        switch self {
        case .warm: 0
        case .one: 0.55
        case .two: 0.65
        case .three: 0.75
        case .four: 0.85
        case .five: 0.95
        }
    }

    var label: String {
        switch self {
        case .warm: "Warm-up"
        case .one: "Zone 1"
        case .two: "Zone 2"
        case .three: "Zone 3"
        case .four: "Zone 4"
        case .five: "Zone 5"
        }
    }

    /// What the zone means in training terms, for the one place the UI has room
    /// to say it.
    var descriptionText: String {
        switch self {
        case .warm: "Below training intensity"
        case .one: "Very light"
        case .two: "Light — endurance"
        case .three: "Moderate — aerobic"
        case .four: "Hard — threshold"
        case .five: "Maximum"
        }
    }
}

enum HeartRateZones {

    /// The zone a reading falls in, given a maximum.
    ///
    /// Bounds are inclusive-low and exclusive-high, so every bpm lands in
    /// exactly one zone — except at the top, where anything at or above the
    /// zone-5 floor is zone 5. A heart rate *above* the recorded maximum is not zone 6; it
    /// means the maximum is wrong, and the honest render is still "Zone 5".
    static func zone(for bpm: Int, max maxBpm: Int) -> HeartRateZone? {
        guard maxBpm > 0, bpm >= 0 else { return nil }
        let fraction = Double(bpm) / Double(maxBpm)
        // Walk down so the highest matching lower bound wins.
        for zone in HeartRateZone.allCases.reversed()
        where fraction >= zone.lowerFraction {
            return zone
        }
        return .warm
    }

    /// The bpm at which `zone` begins, for rendering boundaries and pickers.
    static func lowerBound(of zone: HeartRateZone, max maxBpm: Int) -> Int {
        Int((Double(maxBpm) * zone.lowerFraction).rounded())
    }
}
