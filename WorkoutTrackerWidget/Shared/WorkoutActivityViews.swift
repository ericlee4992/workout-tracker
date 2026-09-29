import AppIntents
import SwiftUI

// Floodlight redesign ticket 11 — the workout's Live Activity and Dynamic Island (Z01, Z03).
//
// Compiled into BOTH targets: the widget draws these for the system, and the app draws the same
// views in its test-only activity gallery (`-uiTestActivityGallery`) so every state can be
// captured at Default and AccessibilityL sizes in both appearances.
//
// The widget target has no asset catalog and cannot see the app's `Look`, so the Floodlight
// tokens it needs are literals here (`ActivityPalette`), copied from `Look.floodlight` /
// `Look.floodlightLight` with their measured contrast (FinalLook.swift's header).
//
// D46 still governs: every figure that moves on its own — the rest countdown, the workout and
// cardio clocks, the rest and target rings — is a system timer (`Text(timerInterval:)`,
// `Text(_:style: .timer)`, `ProgressView(timerInterval:)`). Nothing here is app-ticked, and
// nothing animates freely: a Live Activity cannot run animations.

// MARK: - Palette

struct ActivityPalette {
    var ground: Color
    var edge: Color
    var textPrimary: Color
    var textSecondary: Color
    /// Ultra: the live thing and its one command (rest ring, Skip, Pause, compact figure).
    var live: Color
    var onLive: Color
    var heartRate: Color
    /// The sets ring's done arc.
    var done: Color
    var ringTrack: Color
    var pillFill: Color
    var pillEdge: Color
    /// The new-best mark (Floodlight: an outlined plate in the text colour, never a fill).
    var positive: Color
    var zoneRamp: [Color]

    /// Floodlight dark (`Look.floodlight`).
    static let dark = ActivityPalette(
        ground: hex(0x060708), edge: .white.opacity(0.12), textPrimary: hex(0xF4F6F8),
        textSecondary: hex(0xA4A9B1), live: hex(0xB25CFF), onLive: hex(0x060708), heartRate: hex(0xFF4F86),
        done: hex(0xF4F6F8), ringTrack: .white.opacity(0.16), pillFill: hex(0x222427), pillEdge: .white.opacity(0.12),
        positive: hex(0xF4F6F8),
        zoneRamp: [0x7F858E, 0x9A5270, 0xC2577F, 0xE65C8E, 0xFF77A5, 0xFFB0CA].map(hex))

    /// Floodlight Light (`Look.floodlightLight`): violet #7A2EE0 6.37:1 under white, heart #C41D58.
    static let light = ActivityPalette(
        ground: hex(0xF2F3F5), edge: hex(0x0B0C0E).opacity(0.10), textPrimary: hex(0x0B0C0E),
        textSecondary: hex(0x555A63), live: hex(0x7A2EE0), onLive: .white, heartRate: hex(0xC41D58),
        done: hex(0x0B0C0E), ringTrack: hex(0xDCDFE4), pillFill: hex(0xE6E8EC), pillEdge: hex(0x0B0C0E).opacity(0.10),
        positive: hex(0x0B0C0E),
        zoneRamp: [0x62676F, 0x8E4E6C, 0xA63D69, 0xBF1F5C, 0xA0124B, 0x7A0A39].map(hex))

    /// The Lock Screen follows the system appearance (user decision 3); the island is always black.
    static func lockScreen(_ scheme: ColorScheme) -> ActivityPalette { scheme == .light ? light : dark }
    static let island = dark

    func zone(_ level: Int) -> Color { zoneRamp[max(0, min(zoneRamp.count - 1, level))] }

    private static func hex(_ value: UInt32) -> Color {
        Color(.sRGB, red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255,
              blue: Double(value & 255) / 255, opacity: 1)
    }
}

// MARK: - Type

enum ActivityType {
    /// Floodlight's numerals: SF Pro Expanded Heavy, monospaced digits so ticking figures never jitter.
    static func number(_ style: Font.TextStyle) -> Font {
        Font.system(style).weight(.heavy).width(.expanded).monospacedDigit()
    }
    /// Names (the header): SF Pro Expanded Heavy.
    static func name(_ style: Font.TextStyle) -> Font { Font.system(style).weight(.heavy).width(.expanded) }
    static let label = Font.system(.caption).weight(.semibold)
    static let columnHeader = Font.system(.caption2).weight(.semibold)
}

extension View {
    /// The Lock Screen card is at most 160 pt tall and the island's regions are fixed, and the
    /// system clips anything taller: their text stops growing at xLarge, where every state fits
    /// without truncation (the prototype's rule).
    func activityTypeCap() -> some View { dynamicTypeSize(...DynamicTypeSize.xLarge) }
}

// MARK: - Small pieces

/// The app icon's dumbbell (user decision 4) as the card's mark.
struct ActivityDumbbellMark: View {
    var tint: Color
    var size: CGFloat = 20

    var body: some View {
        ZStack {
            DumbbellBar().fill(tint.opacity(0.7))
            DumbbellPlates().fill(tint)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    // The icon's geometry (scripts/render-app-icon.py) in a unit square.
    private struct DumbbellBar: Shape {
        func path(in r: CGRect) -> Path {
            Path(roundedRect: CGRect(x: r.minX + 0.12 * r.width, y: r.midY - 0.0425 * r.height,
                                     width: 0.76 * r.width, height: 0.085 * r.height),
                 cornerRadius: 0.0425 * r.height)
        }
    }
    private struct DumbbellPlates: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            let plates: [(CGFloat, CGFloat)] = [(0.102, 0.32), (0.205, 0.44), (0.710, 0.44), (0.813, 0.32)]
            for (x, h) in plates {
                p.addRoundedRect(in: CGRect(x: r.minX + x * r.width, y: r.midY - h / 2 * r.height,
                                            width: 0.085 * r.width, height: h * r.height),
                                 cornerSize: CGSize(width: 0.025 * r.width, height: 0.025 * r.width))
            }
            return p
        }
    }
}

extension EnvironmentValues {
    /// true in the app's activity gallery: a timer `ProgressView` is a ring only inside a widget
    /// (in an app it is a spinner), so the gallery draws the ring's fraction at render time.
    @Entry var activityDrawsRingsStatically = false
}

/// A ring drawn by the system from a time span (the rest draining, a cardio target filling), or a
/// fixed fraction when nothing is running. The glyph sits inside.
struct ActivityTimerRing: View {
    enum Fill { case timer(ClosedRange<Date>, countsDown: Bool), fixed(Double) }
    var fill: Fill
    var symbol: String
    var tint: Color
    var track: Color
    var size: CGFloat
    @Environment(\.activityDrawsRingsStatically) private var drawsStatically

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: size * 0.09).padding(size * 0.045)
            if drawsStatically {
                Circle().trim(from: 0, to: staticFraction)
                    .stroke(tint, style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(size * 0.045)
            } else {
                systemRing
            }
            Image(systemName: symbol)
                .font(.system(size: size * 0.36).weight(.semibold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var staticFraction: Double {
        switch fill {
        case .fixed(let value): return max(0, min(1, value))
        case .timer(let span, let countsDown):
            let total = span.upperBound.timeIntervalSince(span.lowerBound)
            guard total > 0 else { return 0 }
            let elapsed = max(0, min(total, Date.now.timeIntervalSince(span.lowerBound)))
            return countsDown ? 1 - elapsed / total : elapsed / total
        }
    }

    private var systemRing: some View {
            Group {
                switch fill {
                case .timer(let span, let countsDown):
                    ProgressView(timerInterval: span, countsDown: countsDown) { EmptyView() } currentValueLabel: { EmptyView() }
                case .fixed(let value):
                    ProgressView(value: max(0, min(1, value)))
                }
            }
            .progressViewStyle(.circular)
            .labelsHidden()
            .tint(tint)
            .frame(width: size, height: size)
    }
}

/// The sets ring: one lit arc (the live header's segmented ring turns to dust this small).
struct ActivitySetsRing: View {
    var done: Int
    var total: Int
    var palette: ActivityPalette
    var size: CGFloat = 18

    var body: some View {
        let width = size * 0.16
        let fraction = total > 0 ? min(1, Double(done) / Double(total)) : 0
        ZStack {
            Circle().stroke(palette.ringTrack, lineWidth: width)
            Circle().trim(from: 0, to: fraction)
                .stroke(palette.done, style: StrokeStyle(lineWidth: width, lineCap: .butt))
                .rotationEffect(.degrees(-90))
        }
        .padding(width / 2)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The zone as five short bars, lit up to its level (the live strip's meter).
struct ActivityZoneMeter: View {
    var level: Int
    var palette: ActivityPalette

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(1...5, id: \.self) { step in
                Capsule().fill(step <= level ? palette.zone(step) : palette.ringTrack).frame(width: 8, height: 4)
            }
        }
        .accessibilityHidden(true)
    }
}

/// "♥ 128" with the zone meter; nothing at all without a reading (D44).
struct ActivityHeartReadout: View {
    var bpm: Int?
    var zoneLevel: Int?
    var zoneLabel: String?
    var palette: ActivityPalette
    var showsUnit = false
    var showsZone = true

    var body: some View {
        if let bpm {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(.caption).weight(.bold))
                    .foregroundStyle(palette.heartRate)
                Text("\(bpm)")
                    .font(ActivityType.number(.subheadline))
                    .foregroundStyle(palette.textPrimary)
                if showsUnit {
                    Text("bpm").font(ActivityType.label).foregroundStyle(palette.textSecondary)
                }
                if showsZone, let zoneLevel, zoneLevel > 0 {
                    ActivityZoneMeter(level: zoneLevel, palette: palette)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                }
            }
            .lineLimit(1)
            .fixedSize()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(bpm) beats per minute" + (zoneLabel.map { ", \($0)" } ?? ""))
        }
    }
}

/// The sets ring with "7/18".
struct ActivitySetsReadout: View {
    var done: Int
    var total: Int
    var palette: ActivityPalette
    var ringSize: CGFloat = 18
    var showsWord = false

    var body: some View {
        HStack(spacing: 5) {
            ActivitySetsRing(done: done, total: total, palette: palette, size: ringSize)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(done)/\(total)")
                    .font(ActivityType.number(.footnote))
                    .foregroundStyle(palette.textPrimary)
                if showsWord {
                    Text("sets").font(ActivityType.label).foregroundStyle(palette.textSecondary)
                }
            }
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(done) of \(total) sets")
    }
}

/// Floodlight's new-best mark: an outlined plate with a starburst.
struct ActivityNewBestMark: View {
    var palette: ActivityPalette

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "burst.fill").font(.system(.caption2).weight(.bold))
            Text("NEW BEST").font(.system(.caption2).weight(.bold)).tracking(0.5)
        }
        .foregroundStyle(palette.positive)
        .padding(.leading, 4).padding(.trailing, 6)
        .frame(minHeight: 18)
        .overlay { RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(palette.positive, lineWidth: 1.5) }
        .fixedSize()
        .accessibilityLabel("New best")
    }
}

/// The next set's marker (outlined in Ultra: it is next), with its superset letter.
struct ActivityNextMarker: View {
    var next: WorkoutActivityAttributes.NextSet
    var palette: ActivityPalette
    var side: CGFloat = 40
    /// Recovered (Z03): the marker fills — you are ready.
    var lit = false

    var body: some View {
        HStack(spacing: 6) {
            let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
            Text(next.marker)
                .font(Font.system(.subheadline).weight(.heavy).width(.expanded))
                .foregroundStyle(lit ? palette.onLive : palette.textPrimary)
                .frame(width: side, height: side)
                .background { if lit { shape.fill(palette.live) } }
                .overlay { if !lit { shape.strokeBorder(palette.live, lineWidth: 2) } }
            if let letter = next.supersetLetter {
                Text(letter)
                    .font(.system(.footnote).weight(.heavy))
                    .foregroundStyle(palette.textPrimary)
                    .frame(width: 24, height: 24)
                    .overlay { RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(palette.textPrimary, lineWidth: 1.5) }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.spoken(next))
    }

    /// "Set 3", "Warmup", "Drop set", "Failure set", with ", superset A" when paired.
    static func spoken(_ next: WorkoutActivityAttributes.NextSet) -> String {
        let kind = switch next.marker {
        case "W": "Warmup"
        case "D": "Drop set"
        case "F": "Failure set"
        default: "Set \(next.marker)"
        }
        return kind + (next.supersetLetter.map { ", superset \($0)" } ?? "")
    }
}

/// "110 lb × 8": big numbers, small unit and ×.
struct ActivitySetValue: View {
    var next: WorkoutActivityAttributes.NextSet
    var palette: ActivityPalette
    var style: Font.TextStyle = .title

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if let weight = next.weight {
                Text(weight).font(ActivityType.number(style)).foregroundStyle(palette.textPrimary)
                if let unit = next.unit {
                    Text(unit).font(.system(.footnote).weight(.semibold)).foregroundStyle(palette.textSecondary)
                }
                if next.reps != nil {
                    Text("×").font(.system(.title3).weight(.semibold)).foregroundStyle(palette.textSecondary)
                }
            }
            if let reps = next.reps {
                Text("\(reps)").font(ActivityType.number(style)).foregroundStyle(palette.textPrimary)
                if next.weight == nil {
                    Text("reps").font(.system(.footnote).weight(.semibold)).foregroundStyle(palette.textSecondary)
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    private var spoken: String {
        switch (next.weight, next.reps) {
        case let (weight?, reps?): "\(weight) \(next.unit ?? "") × \(reps)"
        case let (nil, reps?): "\(reps) reps"
        case let (weight?, nil): "\(weight) \(next.unit ?? "")"
        default: ""
        }
    }
}

/// A system-ticked countdown that holds its width: a timer `Text` in a widget claims all the
/// width it is offered, so it is laid over a hidden template of its widest reading.
struct ActivityCountdown: View {
    var end: Date
    var font: Font
    var color: Color
    var alignment: Alignment = .leading
    /// What VoiceOver says before the time ("Rest"); the time itself is the system's timer text.
    var spokenPrefix: String = "Rest"

    var body: some View {
        Text(end.timeIntervalSinceNow >= 600 ? "00:00" : "0:00")
            .font(font)
            .hidden()
            .overlay(alignment: alignment) {
                Text(timerInterval: Date.now...max(end, .now), countsDown: true)
                    .font(font)
                    .foregroundStyle(color)
                    .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
            }
            .lineLimit(1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(spokenPrefix), ") + Text(timerInterval: Date.now...max(end, .now), countsDown: true)
                                + Text(" left"))
    }
}

/// A system-ticked clock counting up from `start`, holding its width the same way.
struct ActivityClock: View {
    var start: Date
    var font: Font
    var color: Color
    var alignment: Alignment = .trailing
    /// What VoiceOver says before the time ("Workout time", "Indoor Run").
    var spokenPrefix: String = "Workout time"

    var body: some View {
        Text(Date.now.timeIntervalSince(start) >= 3000 ? "0:00:00" : "00:00")
            .font(font)
            .hidden()
            .overlay(alignment: alignment) {
                Text(start, style: .timer)
                    .font(font)
                    .foregroundStyle(color)
                    .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
            }
            .lineLimit(1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(spokenPrefix), ") + Text(start, style: .timer))
    }
}

/// A fixed "m:ss" / "h:mm:ss".
enum ActivityFormat {
    static func clock(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
            : String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// +15s / Skip / Pause pills. Styled labels on plain buttons: a Live Activity renders the label,
/// not a custom button style's pressed state.
struct ActivityPill: View {
    var title: String
    var symbol: String?
    var prominent: Bool
    var palette: ActivityPalette

    var body: some View {
        HStack(spacing: 5) {
            if let symbol { Image(systemName: symbol).font(.system(.footnote).weight(.bold)) }
            Text(title)
        }
        .font(.system(.callout).weight(prominent ? .bold : .semibold))
        .lineLimit(1)
        .fixedSize()
        .foregroundStyle(prominent ? palette.onLive : palette.textPrimary)
        .padding(.horizontal, prominent ? 18 : 14)
        .frame(minWidth: 56, minHeight: 44)
        .background(prominent ? palette.live : palette.pillFill, in: Capsule())
        .overlay { if !prominent { Capsule().strokeBorder(palette.pillEdge, lineWidth: 1) } }
        .contentShape(Capsule())
    }
}

struct ActivityCommands: View {
    enum Kind { case rest, cardio(paused: Bool) }
    var kind: Kind
    var workoutID: UUID
    var palette: ActivityPalette

    var body: some View {
        switch kind {
        case .rest:
            HStack(spacing: 8) {
                Button(intent: WorkoutActivityIntent(workoutID: workoutID, command: .addFifteen)) {
                    ActivityPill(title: "+15s", prominent: false, palette: palette)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add 15 seconds")
                .accessibilityIdentifier("activityAddFifteen")
                Button(intent: WorkoutActivityIntent(workoutID: workoutID, command: .skipRest)) {
                    ActivityPill(title: "Skip", prominent: true, palette: palette)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip rest")
                .accessibilityIdentifier("activitySkipRest")
            }
        case .cardio(let paused):
            Button(intent: WorkoutActivityIntent(workoutID: workoutID, command: paused ? .resumeCardio : .pauseCardio)) {
                ActivityPill(title: paused ? "Resume" : "Pause", symbol: paused ? "play.fill" : "pause.fill",
                             prominent: true, palette: palette)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("activityPauseResume")
        }
    }
}

// MARK: - Rest result (Z03)

/// How the rest ended, drawn: the drained ring and its length (timer), the reading under the
/// target mark (recovered), the capped clock and the reading over the mark (cap), the struck heart
/// with the timer that took over (no reading).
struct ActivityRestResultRow: View {
    var result: WorkoutActivityAttributes.RestResult
    var palette: ActivityPalette

    var body: some View {
        HStack(alignment: .center, spacing: 7) {
            switch result {
            case .timer(let seconds):
                drainedRing
                number(ActivityFormat.clock(seconds), color: palette.textPrimary)
            case .noReading(let seconds):
                Image(systemName: "heart.slash.fill").font(.system(.footnote).weight(.bold)).foregroundStyle(palette.textSecondary)
                drainedRing
                number(ActivityFormat.clock(seconds), color: palette.textPrimary)
            case .recovered(let bpm, let target):
                Image(systemName: "heart.fill").font(.system(.caption).weight(.bold)).foregroundStyle(palette.heartRate)
                number("\(bpm)", color: palette.textPrimary)
                ActivityTargetGauge(bpm: bpm, target: target, tint: palette.live, palette: palette)
            case .cap(let bpm, let target, let cap):
                Image(systemName: "clock.badge.exclamationmark").font(.system(.footnote).weight(.bold))
                    .foregroundStyle(palette.textSecondary)
                number(ActivityFormat.clock(cap), color: palette.textSecondary)
                if let bpm {
                    Image(systemName: "heart.fill").font(.system(.caption).weight(.bold)).foregroundStyle(palette.heartRate)
                        .padding(.leading, 4)
                    number("\(bpm)", color: palette.heartRate)
                    ActivityTargetGauge(bpm: bpm, target: target, tint: palette.heartRate, palette: palette)
                }
            }
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    private var drainedRing: some View {
        Circle().stroke(palette.ringTrack, lineWidth: 2.2)
            .overlay { Image(systemName: "hourglass").font(.system(size: 8).weight(.semibold)).foregroundStyle(palette.live) }
            .frame(width: 20, height: 20)
    }

    private func number(_ text: String, color: Color) -> some View {
        Text(text).font(ActivityType.number(.subheadline)).foregroundStyle(color)
    }

    private var spoken: String {
        switch result {
        case .timer(let s): "Rested \(ActivityFormat.clock(s))"
        case .noReading(let s): "No heart rate reading, rested \(ActivityFormat.clock(s))"
        case .recovered(let bpm, let target): "\(bpm) beats per minute, under \(target)"
        case .cap(let bpm, let target, let cap):
            "\(ActivityFormat.clock(cap)) cap reached" + (bpm.map { ", \($0) beats per minute, over \(target)" } ?? "")
        }
    }
}

/// A short bpm track with the target as a tick and its number.
struct ActivityTargetGauge: View {
    var bpm: Int
    var target: Int
    var tint: Color
    var palette: ActivityPalette
    private let width: CGFloat = 64

    var body: some View {
        let low = Double(target) - 30, high = Double(target) + 30
        let fraction = min(1, max(0.04, (Double(bpm) - low) / (high - low)))
        HStack(spacing: 5) {
            ZStack(alignment: .leading) {
                Capsule().fill(palette.textSecondary.opacity(0.25)).frame(width: width, height: 6)
                Capsule().fill(tint).frame(width: width * fraction, height: 6)
                RoundedRectangle(cornerRadius: 1).fill(palette.textPrimary)
                    .frame(width: 2.5, height: 14)
                    .offset(x: width / 2 - 1.25)
            }
            .frame(width: width, height: 14)
            Text("\(target)").font(.system(.caption).weight(.bold).monospacedDigit()).foregroundStyle(palette.textSecondary)
        }
    }
}

// MARK: - Lock Screen card

struct WorkoutActivityCard: View {
    var state: WorkoutActivityAttributes.ContentState
    var attributes: WorkoutActivityAttributes
    var isStale: Bool
    var palette: ActivityPalette

    var body: some View {
        let now = Date.now
        let phase = state.phase(at: now, isStale: isStale)
        VStack(alignment: .leading, spacing: 8) {
            header(phase: phase, now: now)
            switch phase {
            case .resting: restInstrument
            case .ready: readyInstrument(result: state.shownResult(at: now, isStale: isStale))
            case .cardio: cardioInstrument
            }
            footer(phase: phase, now: now)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        // The system clips the card at 160 pt: the header never wraps, and the type stops at
        // Large (codex-review-11 #5 measured 166 pt at xLarge with the footer stacked).
        .dynamicTypeSize(...DynamicTypeSize.large)
        .accessibilityElement(children: .contain)
    }

    // Header: mark · what you are on · the workout clock.
    private func header(phase: WorkoutActivityAttributes.ContentState.Phase, now: Date) -> some View {
        HStack(alignment: .center, spacing: 8) {
            ActivityDumbbellMark(tint: palette.live, size: 20)
            Text(state.headerTitle(at: now, isStale: isStale))
                .font(ActivityType.name(.subheadline))
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 8)
            ActivityClock(start: attributes.startedAt, font: ActivityType.number(.subheadline), color: palette.textSecondary)
        }
    }

    // Resting: ring · "Rest" over the countdown · +15s · Skip.
    @ViewBuilder private var restInstrument: some View {
        if let end = state.restEndsAt {
            let start = min(state.restStartedAt ?? .now, end)
            HStack(spacing: 12) {
                ActivityTimerRing(fill: .timer(start...end, countsDown: true), symbol: "hourglass",
                                  tint: palette.live, track: palette.ringTrack, size: 50)
                VStack(alignment: .leading, spacing: -2) {
                    HStack(spacing: 6) {
                        Text("Rest").font(ActivityType.label).foregroundStyle(palette.textSecondary)
                            .accessibilityHidden(true)
                        if state.restFollowsNewBest == true { ActivityNewBestMark(palette: palette) }
                    }
                    ActivityCountdown(end: end, font: ActivityType.number(.largeTitle), color: palette.textPrimary)
                }
                .fixedSize()
                .accessibilityElement(children: .combine)
                Spacer(minLength: 4)
                ActivityCommands(kind: .rest, workoutID: attributes.workoutID, palette: palette)
            }
        }
    }

    // Ready: the next set's marker · "Next" over its value · PREVIOUS.
    @ViewBuilder private func readyInstrument(result: WorkoutActivityAttributes.RestResult?) -> some View {
        if let next = state.next {
            HStack(spacing: 12) {
                ActivityNextMarker(next: next, palette: palette, side: 42, lit: isRecovered(result))
                VStack(alignment: .leading, spacing: 0) {
                    Text("Next").font(ActivityType.label).foregroundStyle(palette.textSecondary)
                    if next.weight != nil || next.reps != nil {
                        ActivitySetValue(next: next, palette: palette)
                    } else {
                        Text(next.exerciseName).font(ActivityType.name(.headline)).foregroundStyle(palette.textPrimary)
                            .lineLimit(1)
                    }
                }
                .layoutPriority(1)
                Spacer(minLength: 6)
                if let previous = next.previous {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("PREVIOUS").font(ActivityType.columnHeader).tracking(0.6).foregroundStyle(palette.textSecondary)
                        Text(previous).font(.system(.subheadline).weight(.semibold)).foregroundStyle(palette.textSecondary)
                    }
                    .lineLimit(1)
                    .fixedSize()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Last time \(previous)")
                }
            }
            .frame(minHeight: 50)
        } else {
            // Every set is done: the sets figure is the instrument (no new words).
            let total = state.totalSets ?? state.completedSets
            HStack(spacing: 12) {
                ActivitySetsRing(done: state.completedSets, total: total, palette: palette, size: 42)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(state.completedSets)/\(total)").font(ActivityType.number(.title)).foregroundStyle(palette.textPrimary)
                    Text("sets").font(.system(.footnote).weight(.semibold)).foregroundStyle(palette.textSecondary)
                }
            }
            .frame(minHeight: 50)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(state.completedSets) of \(total) sets")
        }
    }

    // Cardio: target ring · the activity over its clock · Pause / Resume.
    @ViewBuilder private var cardioInstrument: some View {
        if let cardio = state.cardio {
            HStack(spacing: 12) {
                ActivityCardioRing(cardio: cardio, palette: palette, size: 50)
                VStack(alignment: .leading, spacing: -2) {
                    Text(cardio.isPaused ? "Paused" : cardio.activity)
                        .font(ActivityType.label).foregroundStyle(palette.textSecondary)
                        .accessibilityHidden(!cardio.isPaused)
                    if let start = cardio.clockStart, !cardio.isPaused {
                        ActivityClock(start: start, font: ActivityType.number(.largeTitle), color: palette.textPrimary,
                                      alignment: .leading, spokenPrefix: cardio.activity)
                    } else {
                        Text(ActivityFormat.clock(cardio.elapsedSeconds))
                            .font(ActivityType.number(.largeTitle)).foregroundStyle(palette.textSecondary)
                    }
                }
                .fixedSize()
                .accessibilityElement(children: .combine)
                Spacer(minLength: 4)
                ActivityCommands(kind: .cardio(paused: cardio.isPaused), workoutID: attributes.workoutID, palette: palette)
            }
        }
    }

    // Footer.
    @ViewBuilder private func footer(phase: WorkoutActivityAttributes.ContentState.Phase, now: Date) -> some View {
        let heart = ActivityHeartReadout(bpm: state.heartRateBpm, zoneLevel: state.zoneLevel, zoneLabel: state.zoneLabel,
                                         palette: palette)
        let sets = ActivitySetsReadout(done: state.completedSets, total: state.totalSets ?? state.completedSets, palette: palette)
        switch phase {
        case .cardio:
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) { cardioFigures; Spacer(minLength: 4); heart }
                VStack(alignment: .leading, spacing: 6) { cardioFigures; heart }
            }
        case .resting, .ready:
            if let result = state.shownResult(at: now, isStale: isStale) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { ActivityRestResultRow(result: result, palette: palette); Spacer(minLength: 6); sets }
                    VStack(alignment: .leading, spacing: 6) { ActivityRestResultRow(result: result, palette: palette); sets }
                }
            } else {
                let trailing = HStack(spacing: 12) { heart; sets }.fixedSize()
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { footerLeading(phase); Spacer(minLength: 6); trailing }
                    VStack(alignment: .leading, spacing: 6) { footerLeading(phase); trailing }
                }
            }
        }
    }

    /// Resting: the next set. Ready: the gym (the next set is already in the instrument).
    @ViewBuilder private func footerLeading(_ phase: WorkoutActivityAttributes.ContentState.Phase) -> some View {
        if phase == .resting, let line = state.next?.line {
            Text(line).font(.footnote).foregroundStyle(palette.textSecondary).lineLimit(1)
        } else if let gym = attributes.gymName {
            HStack(spacing: 4) {
                Image(systemName: "mappin.and.ellipse").imageScale(.small)
                Text(gym)
            }
            .font(.footnote).foregroundStyle(palette.textSecondary).lineLimit(1)
        }
    }

    @ViewBuilder private var cardioFigures: some View {
        if let cardio = state.cardio {
            HStack(spacing: 14) {
                if let distance = cardio.distance { figure(distance, unit: cardio.distanceUnit ?? "") }
                if let rate = cardio.rate { figure(rate, unit: cardio.rateUnit ?? "") }
                if let minutes = cardio.targetMinutes {
                    figure("\(minutes)", unit: "min", symbol: "target").accessibilityLabel("Target \(minutes) minutes")
                }
            }
        }
    }

    private func figure(_ value: String, unit: String, symbol: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            if let symbol {
                Image(systemName: symbol).font(.system(.caption).weight(.bold)).foregroundStyle(palette.textSecondary)
            }
            Text(value).font(ActivityType.number(.subheadline)).foregroundStyle(palette.textPrimary)
            Text(unit).font(ActivityType.label).foregroundStyle(palette.textSecondary)
        }
        .lineLimit(1)
        .fixedSize()
    }

    private func isRecovered(_ result: WorkoutActivityAttributes.RestResult?) -> Bool {
        if case .recovered = result { return true }
        return false
    }
}

/// The cardio ring: fills toward the planned target (a check once reached), else a plain ring.
struct ActivityCardioRing: View {
    var cardio: WorkoutActivityAttributes.Cardio
    var palette: ActivityPalette
    var size: CGFloat

    var body: some View {
        let symbol = cardio.isPaused ? "pause.fill" : cardio.symbol
        if let minutes = cardio.targetMinutes, minutes > 0 {
            let total = Double(minutes * 60)
            if Double(cardio.activeSeconds(at: .now)) >= total {
                ActivityTimerRing(fill: .fixed(1), symbol: "checkmark", tint: palette.live, track: palette.ringTrack, size: size)
            } else if let start = cardio.clockStart, !cardio.isPaused {
                ActivityTimerRing(fill: .timer(start...start.addingTimeInterval(total), countsDown: false), symbol: symbol,
                                  tint: palette.live, track: palette.ringTrack, size: size)
            } else {
                ActivityTimerRing(fill: .fixed(Double(cardio.elapsedSeconds) / total), symbol: symbol,
                                  tint: palette.live, track: palette.ringTrack, size: size)
            }
        } else {
            ActivityTimerRing(fill: .fixed(0), symbol: symbol, tint: palette.live, track: palette.ringTrack, size: size)
        }
    }
}

// MARK: - Dynamic Island

/// The island's small live glyph: the rest ring, the cardio ring, or the sets ring.
struct ActivityIslandGlyph: View {
    var state: WorkoutActivityAttributes.ContentState
    var isStale: Bool
    var size: CGFloat
    private let palette = ActivityPalette.island

    var body: some View {
        switch state.phase(at: .now, isStale: isStale) {
        case .cardio:
            if let cardio = state.cardio { ActivityCardioRing(cardio: cardio, palette: palette, size: size) }
        case .resting:
            if let end = state.restEndsAt {
                ActivityTimerRing(fill: .timer(min(state.restStartedAt ?? .now, end)...end, countsDown: true),
                                  symbol: "hourglass", tint: palette.live, track: palette.ringTrack, size: size)
            }
        case .ready:
            ActivitySetsRing(done: state.completedSets, total: state.totalSets ?? state.completedSets,
                             palette: palette, size: size * 0.86)
                .frame(width: size, height: size)
        }
    }
}

/// Compact trailing: the countdown, the cardio clock, or "7/18".
struct ActivityIslandCompactTrailing: View {
    var state: WorkoutActivityAttributes.ContentState
    var isStale: Bool
    private let palette = ActivityPalette.island

    var body: some View {
        let font = ActivityType.number(.subheadline)
        Group {
            switch state.phase(at: .now, isStale: isStale) {
            case .resting:
                if let end = state.restEndsAt {
                    ActivityCountdown(end: end, font: font, color: palette.live, alignment: .trailing)
                }
            case .cardio:
                if let cardio = state.cardio {
                    if let start = cardio.clockStart, !cardio.isPaused {
                        ActivityClock(start: start, font: font, color: palette.live, spokenPrefix: "Time")
                    } else {
                        Text(ActivityFormat.clock(cardio.elapsedSeconds)).font(font).foregroundStyle(palette.textSecondary)
                    }
                }
            case .ready:
                Text("\(state.completedSets)/\(state.totalSets ?? state.completedSets)")
                    .font(font).foregroundStyle(palette.textPrimary)
                    .accessibilityLabel("\(state.completedSets) of \(state.totalSets ?? state.completedSets) sets")
            }
        }
        .activityTypeCap()
    }
}

/// Expanded, leading region: the live glyph, or the next set's marker once rest is over.
struct ActivityIslandExpandedLeading: View {
    var state: WorkoutActivityAttributes.ContentState
    var isStale: Bool

    var body: some View {
        Group {
            if state.phase(at: .now, isStale: isStale) == .ready, let next = state.next {
                ActivityNextMarker(next: next, palette: .island, side: 44,
                                   lit: { if case .recovered = state.shownResult(at: .now, isStale: isStale) { return true }; return false }())
            } else {
                ActivityIslandGlyph(state: state, isStale: isStale, size: 50)
            }
        }
        .activityTypeCap()
    }
}

/// Expanded, trailing region: the one big figure.
struct ActivityIslandExpandedTrailing: View {
    var state: WorkoutActivityAttributes.ContentState
    var isStale: Bool
    private let palette = ActivityPalette.island

    var body: some View {
        Group {
            switch state.phase(at: .now, isStale: isStale) {
            case .cardio:
                if let cardio = state.cardio {
                    VStack(alignment: .trailing, spacing: -2) {
                        Text(cardio.isPaused ? "Paused" : "Time").font(ActivityType.label).foregroundStyle(palette.textSecondary)
                            .accessibilityHidden(!cardio.isPaused)
                        if let start = cardio.clockStart, !cardio.isPaused {
                            ActivityClock(start: start, font: ActivityType.number(.largeTitle), color: palette.textPrimary,
                                          spokenPrefix: "Time")
                        } else {
                            Text(ActivityFormat.clock(cardio.elapsedSeconds))
                                .font(ActivityType.number(.largeTitle)).foregroundStyle(palette.textSecondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            case .resting:
                if let end = state.restEndsAt {
                    VStack(alignment: .trailing, spacing: -2) {
                        HStack(spacing: 6) {
                            if state.restFollowsNewBest == true { ActivityNewBestMark(palette: palette) }
                            Text("Rest").font(ActivityType.label).foregroundStyle(palette.textSecondary)
                                .accessibilityHidden(true)
                        }
                        ActivityCountdown(end: end, font: ActivityType.number(.largeTitle), color: palette.textPrimary,
                                          alignment: .trailing)
                    }
                    .accessibilityElement(children: .combine)
                }
            case .ready:
                if let next = state.next, next.weight != nil || next.reps != nil {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("Next").font(ActivityType.label).foregroundStyle(palette.textSecondary)
                        ActivitySetValue(next: next, palette: palette, style: .title2)
                    }
                    .fixedSize()
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .activityTypeCap()
    }
}

/// Expanded, bottom region: what it is about (name, the support line, heart) · the commands.
struct ActivityIslandExpandedBottom: View {
    var state: WorkoutActivityAttributes.ContentState
    var attributes: WorkoutActivityAttributes
    var isStale: Bool
    private let palette = ActivityPalette.island

    var body: some View {
        let phase = state.phase(at: .now, isStale: isStale)
        // The expanded island is at most 160 pt tall: the info sits beside the commands when both
        // fit on one line; else the commands take a row of their own and carry the heart reading.
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom, spacing: 10) {
                info(phase, showsHeart: true)
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 0)
                commands(phase)
            }
            VStack(alignment: .leading, spacing: 10) {
                info(phase, showsHeart: false)
                HStack(alignment: .center, spacing: 10) {
                    commands(phase)
                    Spacer(minLength: 0)
                    if state.shownResult(at: .now, isStale: isStale) == nil { heart }
                }
            }
        }
        .activityTypeCap()
    }

    private var heart: some View {
        ActivityHeartReadout(bpm: state.heartRateBpm, zoneLevel: state.zoneLevel, zoneLabel: state.zoneLabel,
                             palette: palette, showsUnit: true, showsZone: false)
    }

    private func info(_ phase: WorkoutActivityAttributes.ContentState.Phase, showsHeart: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(phase == .cardio ? (state.cardio?.activity ?? "Cardio") : state.headerTitle(at: .now, isStale: isStale))
                    .font(ActivityType.name(.subheadline))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
            }
            if let result = state.shownResult(at: .now, isStale: isStale) {
                ActivityRestResultRow(result: result, palette: palette)
            } else if let line = supportLine(phase) {
                Text(line).font(.system(.footnote).weight(.semibold)).foregroundStyle(palette.textSecondary).lineLimit(1)
            } else if phase == .ready, let previous = state.next?.previous {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("PREVIOUS").font(ActivityType.columnHeader).tracking(0.6)
                    Text(previous).font(.system(.footnote).weight(.semibold))
                }
                .foregroundStyle(palette.textSecondary)
                .lineLimit(1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Last time \(previous)")
            }
            // A drawn result already carries the reading.
            if showsHeart, state.shownResult(at: .now, isStale: isStale) == nil { heart }
        }
    }

    private func supportLine(_ phase: WorkoutActivityAttributes.ContentState.Phase) -> String? {
        switch phase {
        case .cardio:
            guard let cardio = state.cardio else { return nil }
            var parts: [String] = []
            if let distance = cardio.distance { parts.append("\(distance) \(cardio.distanceUnit ?? "")") }
            if let rate = cardio.rate { parts.append("\(rate) \(cardio.rateUnit ?? "")") }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        case .resting: return state.next?.line
        case .ready: return nil
        }
    }

    @ViewBuilder private func commands(_ phase: WorkoutActivityAttributes.ContentState.Phase) -> some View {
        switch phase {
        case .cardio:
            ActivityCommands(kind: .cardio(paused: state.cardio?.isPaused == true), workoutID: attributes.workoutID,
                             palette: palette)
        case .resting:
            ActivityCommands(kind: .rest, workoutID: attributes.workoutID, palette: palette)
        case .ready:
            ActivitySetsReadout(done: state.completedSets, total: state.totalSets ?? state.completedSets,
                                palette: palette, ringSize: 22, showsWord: true)
        }
    }
}
