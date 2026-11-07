import SwiftUI

// PROTOTYPE — helpers for the System area (Z01–Z03: surfaces outside the app).
// Everything is prefixed `System`. The Look and Store extensions are candidates for promotion.
//
// The lock-screen wallpaper and the system chrome (clock, notification platter, Dynamic Island
// shape) are deliberately the SAME in every look: only what the app owns changes between looks
// (the Live Activity, the island's content, the app icon). That keeps the comparison fair.

// MARK: - Look faces

extension Look {
    /// The look's number face at a text style (A and C: SF Expanded Heavy; B: SF Rounded Heavy),
    /// with monospaced digits so ticking figures never jitter.
    func systemNumberFont(_ style: Font.TextStyle) -> Font {
        switch id {
        case .anatomy: Font.system(style, design: .rounded, weight: .heavy).monospacedDigit()
        case .floodlight, .paper, .carbon: Font.system(style, weight: .heavy).width(.expanded).monospacedDigit()
        }
    }

    /// The look's name face (A: SF Expanded Heavy; B: SF Rounded Bold; C: New York Heavy).
    func systemNameFont(_ style: Font.TextStyle) -> Font {
        switch id {
        case .floodlight: Font.system(style, weight: .heavy).width(.expanded)
        case .anatomy: Font.system(style, design: .rounded, weight: .bold)
        case .paper, .carbon: Font.system(style, design: .serif, weight: .heavy)
        }
    }

    /// Small labels ("Rest", "Time") in the look's label treatment.
    var systemLabelFont: Font {
        switch id {
        case .floodlight: .system(.caption, weight: .semibold)
        case .anatomy: .system(.caption, design: .rounded, weight: .bold)
        case .paper, .carbon: .system(.caption, weight: .semibold)
        }
    }
}

// MARK: - Capture variants

/// `-variant` tokens for the System sheet, e.g. "cardio", "p2", "cardio-p2", "tinted", "cap".
struct SystemVariant {
    let tokens: Set<String>

    init(_ raw: String?) {
        let parts = (raw ?? "").lowercased().split { ",+ _-".contains($0) }
        tokens = Set(parts.map(String.init))
    }

    func has(_ token: String) -> Bool { tokens.contains(token) }

    /// "p2" → 2, "p3" → 3 (scroll to that viewport on appear).
    var page: Int? {
        for token in tokens where token.hasPrefix("p") {
            if let n = Int(token.dropFirst()), n >= 2 { return n }
        }
        return nil
    }
}

// MARK: - Lock-screen formatting (system chrome)

enum SystemFormat {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Calendar.app.locale
        f.calendar = Calendar.app
        f.timeZone = Calendar.app.timeZone
        f.setLocalizedDateFormatFromTemplate("EEEEMMMMd")
        return f
    }()
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Calendar.app.locale
        f.calendar = Calendar.app
        f.timeZone = Calendar.app.timeZone
        f.dateFormat = "h:mm"
        return f
    }()

    /// "Thursday, September 24" (the lock screen's date line).
    static func lockDate(_ date: Date) -> String { dateFormatter.string(from: date) }
    /// "6:30" (the lock screen's clock has no AM/PM).
    static func lockTime(_ date: Date) -> String { timeFormatter.string(from: date) }
}

// MARK: - Live Activity data the snapshot does not carry

/// The next set's marker for the Live Activity's "ready" state (rest over).
struct SystemNextMarker: Equatable {
    var kind: SetType
    var number: Int
}

/// A planned cardio target: 20 min, 64 % done.
struct SystemCardioTarget: Equatable {
    var minutes: Int
    var progress: Double
    var isReached: Bool { progress >= 1 }
}

/// How the last rest ended, drawn in the activity (Z03). The banner copy is the real app's.
enum SystemRestResult: Hashable {
    /// The timer ran its full length.
    case timer(seconds: Int)
    /// Heart-rate rest: the reading dropped under the target.
    case recovered(bpm: Int, target: Int)
    /// Heart-rate rest: the cap ran out with the reading still above the target.
    case cap(bpm: Int, target: Int, capSeconds: Int)
    /// Heart-rate rest without a reading: it fell back to the timer.
    case noReading(seconds: Int)

    var notificationTitle: String { "Rest complete" }
    var notificationBody: String {
        switch self {
        case .timer: RestOutcome.timerDone.notificationBody ?? ""
        case .recovered(let bpm, _): RestOutcome.recovered(bpm: bpm).notificationBody ?? ""
        case .cap: RestOutcome.cap.notificationBody ?? ""
        case .noReading: "No heart rate reading — resting by the timer instead."
        }
    }
}

/// The moment a set beats the best (the store's 4-s celebration window): the set and how much it
/// beat the old best by ("110 lb × 8", "+5 lb").
struct SystemBestMoment: Equatable {
    var value: SetValue
    var loadType: LoadType
    var delta: String?
}

extension Store {
    /// Non-nil while the set that started this rest is a fresh new best.
    var systemBestMoment: SystemBestMoment? {
        guard let completion = freshNewBest, case .newBest(let previous) = completion.outcome else { return nil }
        return SystemBestMoment(value: completion.value, loadType: loadType(entryID: completion.entryID),
                                delta: previous.flatMap { Self.systemDelta(completion.value, over: $0) })
    }

    /// "+5 lb" (the weight moved) or "+2 reps" (same weight, more reps); signed, plain numbers.
    static func systemDelta(_ value: SetValue, over previous: SetValue) -> String? {
        if let weight = value.weight, let old = previous.weight, value.unit == previous.unit, weight != old {
            let d = weight - old
            return (d > 0 ? "+" : "−") + Format.weight(abs(d), value.unit)
        }
        if value.reps != previous.reps {
            let d = value.reps - previous.reps
            return (d > 0 ? "+" : "−") + "\(abs(d)) reps"
        }
        return nil
    }

    /// "Next · Set 3 · 110 lb × 8" / "Next · Incline Chest Press". On the Lock Screen there is no
    /// row or column to carry the unit, so every weight shows it, in every look.
    func systemNextLine() -> String? {
        guard let next = nextSet else { return nil }
        if next.isNewExercise { return "Next · \(next.exerciseName)" }
        guard let value = next.value else { return "Next · \(next.setLabel)" }
        return "Next · \(next.setLabel) · \(Format.set(value, loadType: next.loadType))"
    }

    /// Last time's value for the next set, with its unit ("105 lb × 8").
    func systemNextPrevious() -> String? {
        guard let next = nextSet, let previous = previousValue(entryID: next.entryID, setID: next.setID) else { return nil }
        return Format.set(previous, loadType: next.loadType)
    }

    /// The next set's marker ("3", "W", "D"…) for the ready state.
    var systemNextMarker: SystemNextMarker? {
        guard let next = nextSet, let entry = liveEntry(next.entryID),
              let set = entry.sets.first(where: { $0.id == next.setID }) else { return nil }
        return SystemNextMarker(kind: set.type, number: Int(setMarker(entryID: next.entryID, setID: next.setID)) ?? 0)
    }

    /// The next set's superset letter ("A" / "B"), when it belongs to one.
    var systemNextSupersetLetter: String? {
        nextSet.flatMap { supersetLabel(entryID: $0.entryID) }
    }

    /// The running rest was started by a set that was a new best (the activity marks it).
    var systemRestFollowsNewBest: Bool {
        guard let rest, let completion = lastCompletion else { return false }
        return completion.setID == rest.setID && completion.outcome.isNewBest
    }

    /// The running cardio segment's planned target, when it has one.
    var systemCardioTarget: SystemCardioTarget? {
        guard let s = session, let cardio = s.unfinishedCardio, let plannedID = cardio.plannedID,
              let plan = s.plannedCardio.first(where: { $0.id == plannedID }),
              let progress = plannedProgress(plannedID) else { return nil }
        return SystemCardioTarget(minutes: plan.minutes, progress: progress)
    }

    /// The current exercise's rest rule: the timer length, the heart-rate target and its cap.
    var systemRestRule: (timer: Int, target: Int, cap: Int) {
        let entry = currentEntryID.flatMap { liveEntry($0) }
        let settings = entry.map { restSettings(for: $0.exerciseID) } ?? RestSettings()
        let timer = entry.map { restSeconds(entryID: $0.id, type: .working) } ?? self.settings.workingRestSeconds
        return (timer, settings.thresholdBpm, settings.capSeconds)
    }
}

// MARK: - Wallpaper (the user's, not the app's: identical in every look)

/// A neutral dusk wallpaper, low in saturation so the app's colours are the loudest thing on it.
struct SystemWallpaper: View {
    /// iOS dims the wallpaper for the Dark / Tinted icon appearances.
    var dimmed = false
    /// The light version of the same wallpaper (Light mode on the Home Screen).
    var light = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            if light && !dimmed {
                ZStack {
                    LinearGradient(colors: [Color(hex: 0xDCE3EE), Color(hex: 0xECEFF3), Color(hex: 0xF3EEE7)],
                                   startPoint: .top, endPoint: .bottom)
                    Circle().fill(Color(hex: 0xA9BCDD))
                        .frame(width: w * 1.1, height: w * 1.1)
                        .position(x: w * 0.12, y: min(h * 0.16, 180))
                        .blur(radius: 80)
                        .opacity(0.7)
                    Circle().fill(Color(hex: 0xE9CDB2))
                        .frame(width: w * 0.9, height: w * 0.9)
                        .position(x: w * 0.98, y: h * 0.52)
                        .blur(radius: 90)
                        .opacity(0.6)
                    Circle().fill(Color(hex: 0xB5D3D0))
                        .frame(width: w, height: w)
                        .position(x: w * 0.25, y: h * 0.98)
                        .blur(radius: 100)
                        .opacity(0.6)
                }
            } else {
            ZStack {
                LinearGradient(colors: [Color(hex: 0x222A3A), Color(hex: 0x10131A), Color(hex: 0x0B0D11)],
                               startPoint: .top, endPoint: .bottom)
                Circle().fill(Color(hex: 0x41557A))
                    .frame(width: w * 1.1, height: w * 1.1)
                    .position(x: w * 0.12, y: min(h * 0.16, 180))
                    .blur(radius: 80)
                    .opacity(0.75)
                Circle().fill(Color(hex: 0x7A634E))
                    .frame(width: w * 0.9, height: w * 0.9)
                    .position(x: w * 0.98, y: h * 0.52)
                    .blur(radius: 90)
                    .opacity(0.42)
                Circle().fill(Color(hex: 0x2B5358))
                    .frame(width: w, height: w)
                    .position(x: w * 0.25, y: h * 0.98)
                    .blur(radius: 100)
                    .opacity(0.6)
                if dimmed { Color.black.opacity(0.38) }
            }
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

// MARK: - Fill a height inside a scroll view

/// Gives its one child at least `minHeight` (and more if it needs it) as a concrete proposal, so
/// Spacers inside it share the leftover height — a plain `.frame(minHeight:)` inside a ScrollView
/// proposes no height and the Spacers stay at their minimum.
struct SystemMinHeightLayout: Layout {
    var minHeight: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        let ideal = child.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        return CGSize(width: proposal.width ?? ideal.width, height: max(minHeight, ideal.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
    }
}

/// The scroll view's visible height under the header, and whether it has left the top.
struct SystemScrollMetrics: Equatable {
    var viewport: CGFloat
    var isScrolled: Bool
}

// MARK: - Sheet-level Dynamic Type

/// A presented sheet does not inherit the shell's `-axl` override, so the sheet applies it.
struct SystemTypeSizeOverride: ViewModifier {
    var size: DynamicTypeSize?
    func body(content: Content) -> some View {
        if let size { content.dynamicTypeSize(size) } else { content }
    }
}

/// Live Activities and the Dynamic Island live inside fixed system budgets (160 pt tall on the
/// Lock Screen; the island's regions are fixed), and the system clips anything taller. So their
/// text stops growing at xLarge, where every state still fits on one layout without truncation.
/// Everything else in the sheet (its chrome, the notification banners) scales fully.
extension View {
    func systemActivityTypeCap() -> some View { dynamicTypeSize(...DynamicTypeSize.xLarge) }
}
