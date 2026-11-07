import SwiftUI

// Soft redesign S2 (D68): the Train tab holds the three training libraries behind one switch —
// Templates | Gyms | Exercises — in place of the old Workout, Gyms and Exercises tabs. Each part
// has its own navigation stack; the switch sits in the ROOT page's navigation bar, where the
// page's inline title used to fade in, so it leaves with a push (pushed pages keep their titles).

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
        // Only the chosen part exists. Keeping all three alive behind opacity left the hidden parts' navigation
        // stacks in the accessibility tree (`accessibilityHidden` does not reach a stack's UIKit pages), so
        // VoiceOver and UI tests met two "Add Exercise" buttons. A switch therefore drops the other parts' pushed
        // pages; the gym choice is remembered (D1) and a start request is consumed when Templates appears.
        Group {
            switch section {
            case .templates:
                StartWorkoutView(onWorkoutStarted: onWorkoutStarted, startLiftingRequest: $startLiftingRequest)
            case .gyms:
                GymsView()
            case .exercises:
                ExercisesView()
            }
        }
        .environment(\.trainSection, $section)
    }
}

/// The switch between Train's parts: a segmented control, as in the approved prototype.
struct TrainSwitcher: View {
    @Binding var section: TrainSection

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

/// A page's principal bar item: the Train switch on one of Train's three ROOT pages (`trainRoot`), otherwise the
/// page's inline title, shown once the large title has scrolled away. Pages pushed inside Train (a gym, a machine,
/// an exercise) share these title helpers and inherit the environment, so they must not opt in (codex-review-s2 #1).
struct InlineTitleOrTrainSwitcher: View {
    var title: String
    var visible: Bool
    var trainRoot = false
    @Environment(\.trainSection) private var trainSection
    @Environment(\.look) private var look

    var body: some View {
        if trainRoot, let trainSection {
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
