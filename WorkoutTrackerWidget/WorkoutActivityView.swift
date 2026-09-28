import ActivityKit
import SwiftUI
import WidgetKit

// Milestone 8, ticket 05 — how the workout renders on the lock screen and in
// the Dynamic Island.
//
// Presentation only. Every value comes from `ContentState`, pushed by the app;
// this extension never reads the store, because a widget extension is a
// separate process with no access to the app's SwiftData container.
//
// Floodlight redesign ticket 11: the views live in `Shared/WorkoutActivityViews.swift` (the app
// draws the same views in its activity gallery); this file only places them in the system's
// Lock Screen and Dynamic Island slots.

/// The Lock Screen card in the system's appearance (user decision 3).
private struct LockScreenActivity: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = ActivityPalette.lockScreen(scheme)
        WorkoutActivityCard(state: context.state, attributes: context.attributes, isStale: context.isStale, palette: palette)
            .activityBackgroundTint(palette.ground)
            .activitySystemActionForegroundColor(palette.live)
    }
}

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LockScreenActivity(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ActivityIslandExpandedLeading(state: context.state, isStale: context.isStale)
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ActivityIslandExpandedTrailing(state: context.state, isStale: context.isStale)
                        .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ActivityIslandExpandedBottom(state: context.state, attributes: context.attributes, isStale: context.isStale)
                        .padding(.horizontal, 6)
                }
            } compactLeading: {
                ActivityIslandGlyph(state: context.state, isStale: context.isStale, size: 25)
            } compactTrailing: {
                ActivityIslandCompactTrailing(state: context.state, isStale: context.isStale)
            } minimal: {
                ActivityIslandGlyph(state: context.state, isStale: context.isStale, size: 25)
            }
            .keylineTint(ActivityPalette.island.live.opacity(0.6))
        }
    }
}

@main
struct WorkoutTrackerWidgetBundle: WidgetBundle {
    var body: some Widget {
        WorkoutLiveActivity()
    }
}
