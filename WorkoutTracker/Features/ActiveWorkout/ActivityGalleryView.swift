import SwiftUI

// Floodlight redesign ticket 11 — TEST-ONLY. `-uiTestActivityGallery <state>` replaces the app's
// root with the Live Activity's own views (`WorkoutTrackerWidget/Shared/WorkoutActivityViews.swift`,
// compiled into both targets) for one sample state: the Lock Screen card on a wallpaper, then the
// Dynamic Island compact, minimal and expanded. XCUITest cannot reach the Lock Screen at
// AccessibilityL in both appearances, so the capture tests photograph this; a real Live
// Activity in the Simulator is checked separately (FloodlightSystemUITests).
//
// The wallpaper, the card's rounded plate and the island's black shapes stand in for system
// chrome; only the content comes from the widget's views.

enum ActivityGallery {
    static var requestedState: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-uiTestActivityGallery"), args.indices.contains(index + 1) else { return nil }
        return args[index + 1]
    }

    static let attributes = WorkoutActivityAttributes(
        workoutID: UUID(uuidString: "00000000-0000-0000-0000-00000000A11E")!,
        startedAt: .now.addingTimeInterval(-(18 * 60 + 42)), gymName: "Iron Temple")

    /// The sample states, matching the prototype's Z01 / Z03 variants.
    static func state(_ name: String, now: Date = .now) -> (state: WorkoutActivityAttributes.ContentState, isStale: Bool) {
        let chestNext = WorkoutActivityAttributes.NextSet(
            marker: "3", supersetLetter: nil, exerciseName: "Seated Chest Press", line: "Next · Set 3 · 110 lb × 8",
            weight: "110", unit: "lb", reps: 8, previous: "105 lb × 8")
        var s = WorkoutActivityAttributes.ContentState(
            heartRateBpm: 128, zoneLabel: "Zone 2", restEndsAt: now.addingTimeInterval(84), completedSets: 7,
            currentExercise: "Seated Chest Press", zoneLevel: 2, totalSets: 18, restStartedAt: now.addingTimeInterval(-36),
            rest: .timer, restFollowsNewBest: false, next: chestNext, workoutTitle: "Push Day")
        var stale = false
        func ended(_ kind: WorkoutActivityAttributes.RestKind, length: TimeInterval) {
            s.rest = kind
            s.restEndsAt = now.addingTimeInterval(-2)
            s.restStartedAt = now.addingTimeInterval(-2 - length)
            stale = true
        }
        switch name {
        case "best":
            s.restFollowsNewBest = true
        case "ready":
            s.restEndsAt = nil; s.restStartedAt = nil; s.rest = nil
        case "superset":
            s.restEndsAt = nil; s.restStartedAt = nil; s.rest = nil
            s.completedSets = 5; s.totalSets = 21; s.heartRateBpm = 131
            s.currentExercise = "Bench Press"
            s.next = .init(marker: "3", supersetLetter: "A", exerciseName: "Bench Press", line: "Next · Bench Press",
                           weight: "135", unit: "lb", reps: 8, previous: "135 lb × 8")
        case "warmup":
            s.restEndsAt = nil; s.restStartedAt = nil; s.rest = nil
            s.completedSets = 8
            s.currentExercise = "Incline Chest Press"
            s.next = .init(marker: "W", supersetLetter: nil, exerciseName: "Incline Chest Press",
                           line: "Next · Warmup · 45 lb × 12", weight: "45", unit: "lb", reps: 12, previous: "90 lb × 10")
        case "nohr":
            s.heartRateBpm = nil; s.zoneLabel = nil; s.zoneLevel = nil
        case "nextExercise":
            s.next = .init(marker: "1", supersetLetter: nil, exerciseName: "Incline Chest Press",
                           line: "Next · Incline Chest Press", weight: "90", unit: "lb", reps: 10, previous: "90 lb × 10")
        case "timer":
            ended(.timer, length: 120)
        case "recovered":
            s.restEndsAt = nil; s.restStartedAt = nil; s.rest = nil
            s.heartRateBpm = 108; s.zoneLevel = 1; s.zoneLabel = "Zone 1"
            s.restResult = .recovered(bpm: 108, targetBpm: 110)
        case "cap":
            ended(.heartRate(targetBpm: 110), length: 240)
        case "noreading":
            s.heartRateBpm = nil; s.zoneLabel = nil; s.zoneLevel = nil
            ended(.fallback, length: 120)
        case "done":
            s.restEndsAt = nil; s.restStartedAt = nil; s.rest = nil
            s.completedSets = 18; s.next = nil
        case "cardio", "cardioTarget", "cardioPaused":
            s.restEndsAt = nil; s.restStartedAt = nil; s.rest = nil
            s.heartRateBpm = 146; s.zoneLevel = 3; s.zoneLabel = "Zone 3"
            s.currentExercise = "Indoor Run"
            // cardioTarget: 12:48 of a 20-minute target; cardioPaused: paused past it (the check).
            let elapsed = name == "cardioPaused" ? 1205 : 768
            s.cardio = .init(activity: "Indoor Run", symbol: "figure.run", isPaused: name == "cardioPaused",
                             clockStart: name == "cardioPaused" ? nil : now.addingTimeInterval(-Double(elapsed)),
                             elapsedSeconds: elapsed, distance: name == "cardio" ? "1.47" : "2.31", distanceUnit: "mi",
                             rate: "8:43", rateUnit: "/mi", targetMinutes: name == "cardio" ? nil : 20)
        default:
            break
        }
        return (s, stale)
    }
}

struct ActivityGalleryView: View {
    var name: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let sample = ActivityGallery.state(name)
        let palette = ActivityPalette.lockScreen(scheme)
        ScrollView {
            VStack(spacing: 18) {
                Text("Z01 · \(name)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("activityGallery")
                // The Lock Screen card (the system clips it at 160 pt; the plate shows that budget).
                WorkoutActivityCard(state: sample.state, attributes: ActivityGallery.attributes,
                                    isStale: sample.isStale, palette: palette)
                    .background(palette.ground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(palette.edge, lineWidth: 1) }
                    .padding(.horizontal, 12)
                    .accessibilityIdentifier("galleryLockScreen")

                // Compact: the glyph and the figure either side of the camera.
                HStack(spacing: 0) {
                    ActivityIslandGlyph(state: sample.state, isStale: sample.isStale, size: 25)
                    Spacer(minLength: 122)
                    ActivityIslandCompactTrailing(state: sample.state, isStale: sample.isStale)
                        .fixedSize()
                }
                .padding(.leading, 7).padding(.trailing, 13)
                .frame(height: 37)
                .background(Capsule().fill(.black))
                .fixedSize()
                .environment(\.colorScheme, .dark)
                .accessibilityIdentifier("galleryCompact")

                // Minimal: ours shrinks to a circle beside another activity's pill.
                HStack(spacing: 7) {
                    Capsule().fill(.black).frame(width: 126, height: 37)
                    ActivityIslandGlyph(state: sample.state, isStale: sample.isStale, size: 25)
                        .frame(width: 37, height: 37)
                        .background(Circle().fill(.black))
                }
                .environment(\.colorScheme, .dark)

                // Expanded: leading and trailing flank the camera; the bottom carries the rest.
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 0) {
                        ActivityIslandExpandedLeading(state: sample.state, isStale: sample.isStale)
                        Spacer(minLength: 134)
                        ActivityIslandExpandedTrailing(state: sample.state, isStale: sample.isStale)
                    }
                    .frame(minHeight: 50)
                    ActivityIslandExpandedBottom(state: sample.state, attributes: ActivityGallery.attributes,
                                                 isStale: sample.isStale)
                }
                .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 18)
                .background(RoundedRectangle(cornerRadius: 46, style: .continuous).fill(.black))
                .padding(.horizontal, 10)
                .environment(\.colorScheme, .dark)
                .accessibilityIdentifier("galleryExpanded")
            }
            .padding(.vertical, 24)
        }
        .background { wallpaper.ignoresSafeArea() }
        .environment(\.activityDrawsRingsStatically, true)
    }

    /// A neutral dusk wallpaper (the prototype's), low in saturation so the card is the loudest thing.
    private var wallpaper: some View {
        LinearGradient(colors: scheme == .light
                       ? [Color(red: 0.86, green: 0.89, blue: 0.93), Color(red: 0.95, green: 0.93, blue: 0.91)]
                       : [Color(red: 0.13, green: 0.16, blue: 0.23), Color(red: 0.04, green: 0.05, blue: 0.07)],
                       startPoint: .top, endPoint: .bottom)
    }
}
