import SwiftUI

// Soft redesign S2 (D68): the Train tab holds the three training libraries behind one switch —
// Templates | Gyms | Exercises — in place of the old Workout, Gyms and Exercises tabs. Each part
// keeps its own navigation stack (and so its own pushed pages); the switch sits in the root
// page's navigation bar, where the page's inline title used to fade in, so it leaves with a push.

enum TrainSection: String, CaseIterable, Identifiable, Hashable {
    case templates, gyms, exercises

    var id: String { rawValue }
    var title: String {
        switch self {
        case .templates: "Templates"
        case .gyms: "Gyms"
        case .exercises: "Exercises"
        }
    }
}

extension EnvironmentValues {
    /// Set by `TrainView` for its three root pages: they show the switch instead of their inline title.
    @Entry var trainSection: Binding<TrainSection>? = nil
}

struct TrainView: View {
    @Binding var section: TrainSection
    var onWorkoutStarted: (Workout) -> Void
    @Binding var startLiftingRequest: Bool

    var body: some View {
        // All three stay alive (as the old tabs did), so a switch keeps each part's place and its
        // start flow's state; only the shown part is hit-testable and visible to VoiceOver.
        ZStack {
            part(.templates) {
                StartWorkoutView(onWorkoutStarted: onWorkoutStarted, startLiftingRequest: $startLiftingRequest)
            }
            part(.gyms) { GymsView() }
            part(.exercises) { ExercisesView() }
        }
        .environment(\.trainSection, $section)
    }

    private func part<Content: View>(_ which: TrainSection, @ViewBuilder _ content: () -> Content) -> some View {
        let shown = section == which
        return content()
            .opacity(shown ? 1 : 0)
            .allowsHitTesting(shown)
            .accessibilityHidden(!shown)
    }
}

/// The switch between Train's parts: a segmented control, as in the approved prototype.
struct TrainSwitcher: View {
    @Binding var section: TrainSection
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Picker("Train", selection: $section) {
            ForEach(TrainSection.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 300)
        // The bar cannot grow: past xxxLarge the segments keep their size and long-press shows them large.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityIdentifier("trainSwitcher")
    }
}

/// A root page's principal bar item: the Train switch inside Train, otherwise the page's inline
/// title, shown once the large title has scrolled away.
struct InlineTitleOrTrainSwitcher: View {
    var title: String
    var visible: Bool
    @Environment(\.trainSection) private var trainSection
    @Environment(\.look) private var look

    var body: some View {
        if let trainSection {
            TrainSwitcher(section: trainSection)
        } else {
            Text(title)
                .font(look.font.navTitle)
                .foregroundStyle(look.textPrimary)
                .lineLimit(1)
                .opacity(visible ? 1 : 0)
                .accessibilityHidden(!visible)
        }
    }
}
