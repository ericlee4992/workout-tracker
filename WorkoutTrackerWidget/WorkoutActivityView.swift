import ActivityKit
import SwiftUI
import WidgetKit

// Milestone 8, ticket 05 — how the workout renders on the lock screen and in
// the Dynamic Island.
//
// Presentation only. Every value comes from `ContentState`, pushed by the app;
// this extension never reads the store, because a widget extension is a
// separate process with no access to the app's SwiftData container.

/// The app's tokens as literals (D54): the widget target has no asset
/// catalog of its own. Ink `#0B0D10` = `SurfaceBackground`, amber `#FFB45E`
/// = the accent (UI redesign ticket 09).
private enum ActivityTheme {
    static let background = Color(red: 0x0B / 255, green: 0x0D / 255, blue: 0x10 / 255)
    static let accent = Color(red: 0xFF / 255, green: 0xB4 / 255, blue: 0x5E / 255)
}

extension View {
    /// The Lock Screen content sits on a FIXED ink background, so its text
    /// must not follow the host's appearance — in a light Lock Screen
    /// appearance `.primary` would turn dark on near-black (codex-review-09).
    /// Forcing the dark scheme resolves `.primary` / `.secondary` to light.
    func onInk() -> some View { environment(\.colorScheme, .dark) }
}

struct WorkoutActivityView: View {
    let state: WorkoutActivityAttributes.ContentState
    let attributes: WorkoutActivityAttributes

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(attributes.gymName ?? "Workout", systemImage: "figure.strengthtraining.traditional")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ActivityTheme.accent)
                Spacer()
                // System-ticked, not app-ticked (D46).
                Text(attributes.startedAt, style: .timer)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if let exercise = state.currentExercise {
                Text(exercise)
                    .font(.headline)
                    .lineLimit(1)
            }

            HStack(spacing: 14) {
                if let bpm = state.heartRateBpm {
                    Label("\(bpm)", systemImage: "heart.fill")
                        .foregroundStyle(.red)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
                if let zone = state.zoneLabel {
                    Text(zone)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
                Spacer()
                Text("\(state.completedSets) set\(state.completedSets == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let end = state.restEndsAt, end > .now {
                HStack {
                    Label("Rest", systemImage: "hourglass")
                        .font(.caption)
                    Spacer()
                    // THE D46 POINT: `timerInterval` is counted down by the
                    // system. An app-ticked countdown would freeze the moment
                    // the app is suspended, which is most of every rest.
                    Text(timerInterval: .now...end, countsDown: true)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .frame(maxWidth: 60, alignment: .trailing)
                }
            }
        }
        .padding()
    }
}

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            WorkoutActivityView(state: context.state, attributes: context.attributes)
                .onInk()
                .activityBackgroundTint(ActivityTheme.background)
                .activitySystemActionForegroundColor(ActivityTheme.accent)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if let bpm = context.state.heartRateBpm {
                        Label("\(bpm)", systemImage: "heart.fill")
                            .foregroundStyle(.red)
                            .monospacedDigit()
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let end = context.state.restEndsAt, end > .now {
                        Text(timerInterval: .now...end, countsDown: true)
                            .monospacedDigit()
                            .frame(maxWidth: 60)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.currentExercise ?? "Workout")
                        .font(.caption)
                }
            } compactLeading: {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(ActivityTheme.accent)
            } compactTrailing: {
                if let bpm = context.state.heartRateBpm {
                    Text("\(bpm)").monospacedDigit()
                } else if let end = context.state.restEndsAt, end > .now {
                    Text(timerInterval: .now...end, countsDown: true)
                        .monospacedDigit()
                        .frame(maxWidth: 44)
                }
            } minimal: {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(ActivityTheme.accent)
            }
        }
    }
}

@main
struct WorkoutTrackerWidgetBundle: WidgetBundle {
    var body: some Widget {
        WorkoutLiveActivity()
    }
}
