import AppIntents
import Foundation

// Floodlight redesign ticket 11 (user decision 1): +15s / Skip while resting and Pause / Resume
// during cardio, pressed on the Lock Screen card or the expanded Dynamic Island.
//
// Compiled into BOTH targets: the widget draws `Button(intent:)` with it, and a
// `LiveActivityIntent` always PERFORMS in the app's process (the system wakes or launches the
// app for it). The widget extension therefore never runs `perform`; the app installs the
// handler at launch (`WorkoutActivityCommands`), before any intent can arrive.

enum WorkoutActivityCommand: String, AppEnum {
    case addFifteen, skipRest, pauseCardio, resumeCardio

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Workout command"
    static let caseDisplayRepresentations: [WorkoutActivityCommand: DisplayRepresentation] = [
        .addFifteen: "Add 15 seconds",
        .skipRest: "Skip rest",
        .pauseCardio: "Pause",
        .resumeCardio: "Resume",
    ]
}

struct WorkoutActivityIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Workout command"
    /// A button on the workout's own card, not a shortcut anyone composes.
    static let isDiscoverable = false

    @Parameter(title: "Workout") var workoutID: String
    @Parameter(title: "Command") var command: WorkoutActivityCommand

    init() {}

    init(workoutID: UUID, command: WorkoutActivityCommand) {
        self.workoutID = workoutID.uuidString
        self.command = command
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: workoutID) {
            await WorkoutActivityCommandBridge.handler?(command, id)
        }
        return .result()
    }
}

/// Where a performed command goes. Set by the app at launch; nil in the widget extension.
@MainActor
enum WorkoutActivityCommandBridge {
    /// Returns once the workout and its card have both changed: the intent's return is when the
    /// system may suspend the app again.
    static var handler: ((WorkoutActivityCommand, UUID) async -> Void)?
}
