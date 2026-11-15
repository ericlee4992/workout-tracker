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

/// Live-workout 04: Done on the card — log the set it showed, with the value it showed. The app logs it only while that
/// set is still the workout's next set with exactly that value (`WorkoutActivityCommands.logSet`); a card that has
/// fallen behind the workout never logs anything.
struct WorkoutActivityLogSetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Log set"
    /// A button on the workout's own card, not a shortcut anyone composes.
    static let isDiscoverable = false

    @Parameter(title: "Workout") var workoutID: String
    @Parameter(title: "Set") var setID: String
    @Parameter(title: "Weight") var weight: String?
    @Parameter(title: "Unit") var unit: String?
    @Parameter(title: "Reps") var reps: Int?

    init() {}

    init(workoutID: UUID, next: WorkoutActivityAttributes.NextSet) {
        self.workoutID = workoutID.uuidString
        self.setID = next.setID?.uuidString ?? ""
        self.weight = next.weight
        self.unit = next.unit
        self.reps = next.reps
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let workout = UUID(uuidString: workoutID), let set = UUID(uuidString: setID) {
            await WorkoutActivityCommandBridge.logSetHandler?(
                WorkoutActivityShownSet(workoutID: workout, setID: set, weight: weight, unit: unit, reps: reps))
        }
        return .result()
    }
}

/// What the card showed when Done was pressed.
struct WorkoutActivityShownSet: Hashable, Sendable {
    var workoutID: UUID
    var setID: UUID
    var weight: String?
    var unit: String?
    var reps: Int?
}

/// Where a performed command goes. Set by the app at launch; nil in the widget extension.
@MainActor
enum WorkoutActivityCommandBridge {
    /// Returns once the workout and its card have both changed: the intent's return is when the
    /// system may suspend the app again.
    static var handler: ((WorkoutActivityCommand, UUID) async -> Void)?
    /// Live-workout 04: Done.
    static var logSetHandler: ((WorkoutActivityShownSet) async -> Void)?
}
