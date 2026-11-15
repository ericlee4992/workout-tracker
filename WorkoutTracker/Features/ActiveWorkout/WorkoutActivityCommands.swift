import Foundation
import OSLog
import SwiftData

// Floodlight redesign ticket 11 (user decision 1) — +15s, Skip, Pause and Resume pressed on the
// Lock Screen card or the expanded Dynamic Island.
//
// The intent (`WorkoutActivityIntent`, shared with the widget) runs in this process and lands
// here. Each command does what the live screen's own button does, through the same services, so
// the store, the rest notification, the audible alarm and the Watch mirror all move together:
//   +15s / Skip → `RestTimerService.add` / `.skip` (store + notification), then
//                 `broadcastRest` (the alarm track and the Watch), as the screen's
//                 `onChange(of: restEnd)` does;
//   Pause / Resume → the cardio recorder when it is recording this workout (it also stops and
//                 restarts the sensors), else `CardioSession` directly;
//   Done (live-workout 04) → `WorkoutSession.toggleCompletion` then `RestTimerService.restAfterCompletionChange`
//                 — the set row's check and the live screen's rest rule (D48 supersets, D43 heart-rate rests) —
//                 then `broadcastRest`. Only the set the card showed, while it is still the next set with exactly
//                 the value shown; otherwise nothing is logged and the card is brought up to date.
// It works whether the live screen is up, minimised, or not yet built (a cold background launch):
// nothing here depends on a view. When the screen is up it re-reads its rest from the store on
// `didApply`, and the card is re-pushed from the store either way.
//
// A command for a workout that has finished, been deleted, or has no rest / cardio to act on
// does nothing: a stale card must never edit a workout that is no longer live.

@MainActor
final class WorkoutActivityCommands {
    static let shared = WorkoutActivityCommands()
    private static let log = Logger(subsystem: "WorkoutTracker", category: "LiveActivity")

    /// Posted after a command changed a workout; `object` is the workout's id.
    static let didApply = Notification.Name("WorkoutActivityCommands.didApply")

    private var container: ModelContainer?
    /// The workout's runtime — the heart-rate session, the rest alarm, the Watch mirror, the
    /// cardio recorder — and the card's controller. Owned HERE, created with the app, so a
    /// command that launches the app in the background has them before any view exists
    /// (codex-review-11 #1). `RootView` borrows the same two objects.
    let coordinator: WorkoutHeartRateCoordinator
    let activity: WorkoutActivityController
    /// Starts the workout's runtime the way the live screen does on appear (the heart-rate
    /// session, the audio session, the recorder attached). Injected by tests.
    var attachRuntime: (Workout, ModelContext) -> Void
    /// Injected by tests; the real scheduler otherwise.
    var notifications: any RestNotificationScheduling = UserNotificationScheduler.shared
    /// Done's saves (the set's check and its rest). Tests inject a failing one (codex-review-04 #1, #2).
    var save: (ModelContext) throws -> Void = { try $0.save() }

    init(coordinator: WorkoutHeartRateCoordinator? = nil, activity: WorkoutActivityController? = nil,
         attachRuntime: ((Workout, ModelContext) -> Void)? = nil) {
        let coordinator = coordinator ?? WorkoutHeartRateCoordinator()
        self.coordinator = coordinator
        self.activity = activity ?? WorkoutActivityController()
        self.attachRuntime = attachRuntime ?? { workout, context in
            guard coordinator.workoutID != workout.id else { return }
            coordinator.monitor(for: workout, maxHeartRate: MaxHeartRateResolver.current(in: context))
        }
    }

    /// Called from the app's `init`, before any intent can arrive.
    func install(container: ModelContainer) {
        use(container)
        WorkoutActivityCommandBridge.handler = { [weak self] command, id in
            await self?.handle(command, workoutID: id)
        }
        WorkoutActivityCommandBridge.logSetHandler = { [weak self] shown in
            await self?.logSet(shown)
        }
    }

    /// The store commands act on (tests use their own, without installing the intent handler).
    func use(_ container: ModelContainer) { self.container = container }

    /// Applies a pressed command and waits until the card shows it.
    func handle(_ command: WorkoutActivityCommand, workoutID: UUID) async {
        guard perform(command, workoutID: workoutID) else { return }
        await settle()
    }

    /// Live-workout 04: Done pressed on the card. Waits until the card shows the logged set (or, refused, the
    /// workout as it is now).
    func logSet(_ shown: WorkoutActivityShownSet) async {
        performLogSet(shown)
        await settle()
    }

    /// A runtime attached by a command starts asynchronously; the intent's return is when the system may suspend the
    /// app again. (Its providers replay the rest once running.)
    private func settle() async {
        await coordinator.ready()
        await activity.settle()
    }

    /// Applies one command. Returns whether it changed anything.
    @discardableResult
    func perform(_ command: WorkoutActivityCommand, workoutID: UUID) -> Bool {
        apply(command.rawValue, workoutID: workoutID) { workout, context, rest in
            let recorder = self.coordinator.cardio
            switch command {
            case .addFifteen:
                // `add` returns nil when no rest is running (or it already ran out).
                guard try rest.add(seconds: 15, to: workout) != nil else { return false }
                self.coordinator.broadcastRest(endsAt: workout.restEndsAt)
            case .skipRest:
                // A rest that already ran out keeps its result; there is nothing to skip.
                guard let end = workout.restEndsAt, end > .now else { return false }
                try rest.skip(workout)
                self.coordinator.lastRestResult = nil
                self.coordinator.broadcastRest(endsAt: nil)
            case .pauseCardio, .resumeCardio:
                guard let segment = workout.unfinishedCardio else { return false }
                let pausing = command == .pauseCardio
                guard segment.isRunning == pausing else { return false }
                if recorder.current?.id == segment.id {
                    if pausing { recorder.pause() } else { recorder.resume() }
                } else if pausing {
                    try CardioSession(context: context).pause(segment)
                } else {
                    try CardioSession(context: context).resume(segment)
                }
            }
            return true
        }
    }

    /// Live-workout 04: logs the set the card showed. Returns whether it logged it.
    ///
    /// The wrong record is the danger here (AGENTS): a card can lag the workout — the set already checked in the
    /// app, deleted, its value or type edited, another set now next. So the card's current set is rebuilt from the
    /// store and its fingerprint (`WorkoutActivityContent.logFingerprint`: the set, type, exact weight, unit, reps,
    /// bar, exercise, machine, preset, tag) must equal what was shown; anything else logs nothing and the card is
    /// re-pushed so it catches up.
    ///
    /// Saves (codex-review-04 #1, #2): edits already pending in the context are the user's, so they are saved first;
    /// then a failed completion save is rolled back whole (stamp, snapshot, memory) and a failed rest save rolls back
    /// only the rest — the set stays logged — and only the restored rest is published.
    @discardableResult
    func performLogSet(_ shown: WorkoutActivityShownSet) -> Bool {
        apply("logSet", workoutID: shown.workoutID, refreshesWhenUnchanged: true) { workout, context, rest in
            guard let current = WorkoutActivityContent.nextSet(in: workout, restEntryID: nil), current.isLoggable,
                  current.setID == shown.setID, current.fingerprint == shown.fingerprint,
                  let set = WorkoutSession.nextSet(in: workout), set.id == shown.setID, set.completedAt == nil
            else {
                Self.log.notice("logSet refused: the card no longer shows the workout's next set as it is")
                return false
            }
            if context.hasChanges { try self.save(context) }
            var session = WorkoutSession(context: context, notifications: self.notifications)
            session.persist = self.save
            do {
                // The set row's check: the stamp, the snapshot (D23), gym memory, the save. Throws on an unloggable
                // row (A1).
                try session.toggleCompletion(of: set)
            } catch {
                context.rollback()
                Self.log.error("logSet: the set was not saved: \(String(describing: error), privacy: .public)")
                return false
            }
            // From here the set IS logged.
            self.coordinator.lastRestResult = nil
            var restTimer = rest
            restTimer.persist = self.save
            do {
                try restTimer.restAfterCompletionChange(of: set, isCompleted: true)
            } catch {
                // Only the rest's own changes are pending (the set was saved): back to the rest as it was saved.
                context.rollback()
                Self.log.error("logSet: the rest was not saved: \(String(describing: error), privacy: .public)")
            }
            // The fallback belongs to its rest (the live screen's rule, codex-review-11b #2).
            if let degraded = self.coordinator.degradedRestSetID,
               workout.restEndsAt == nil || workout.restStartedBySetID != degraded {
                self.coordinator.degradedRestSetID = nil
            }
            self.coordinator.broadcastRest(endsAt: workout.restEndsAt)
            return true
        }
    }

    /// D43 for a runtime no screen has claimed (a Done after a cold launch started a heart-rate rest): the coordinator's
    /// check on each sample, then the Watch, the alarm, the screen and the card told — what the screen's redraw does.
    func evaluateRestWithoutScreen(workoutID: UUID) {
        guard coordinator.onSample == nil, let context = container?.mainContext,
              let workout = try? context.fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.id == workoutID })).first,
              !workout.isDeleted, workout.finishedAt == nil
        else { return }
        var rest = RestTimerService(context: context, notifications: notifications)
        rest.persist = save
        let outcome: WorkoutHeartRateCoordinator.HeartRateRestOutcome
        do {
            outcome = try coordinator.evaluateHeartRateRest(for: workout, restTimer: rest)
        } catch {
            Self.log.error("heart-rate rest check failed: \(String(describing: error), privacy: .public)")
            return
        }
        guard outcome != .unchanged else { return }
        coordinator.broadcastRest(endsAt: workout.restEndsAt)
        NotificationCenter.default.post(name: Self.didApply, object: workoutID)
        pushCard(workout, in: context)
    }

    private func pushCard(_ workout: Workout, in context: ModelContext) {
        let monitor = coordinator.workoutID == workout.id ? coordinator.monitor : nil
        let heart = monitor.map { WorkoutActivityContent.Heart(bpm: $0.isStale ? nil : $0.current?.bpm, zone: $0.currentZone) }
        activity.show(
            workoutID: workout.id, startedAt: workout.startedAt, gymName: workout.gym?.name,
            state: WorkoutActivityContent.make(for: workout, in: context, heart: heart,
                                               restResult: coordinator.lastRestResult,
                                               degradedRestSetID: coordinator.degradedRestSetID))
    }

    /// The steps every card command shares: the live workout, its runtime, how an expired rest ended; then the
    /// change; then the screen told and the card re-pushed. `change` returns whether it changed anything.
    /// `refreshesWhenUnchanged`: re-push the card even when nothing changed (a refused Done brings a lagging card
    /// up to date).
    private func apply(_ name: String, workoutID: UUID, refreshesWhenUnchanged: Bool = false,
                       change: (Workout, ModelContext, RestTimerService) throws -> Bool) -> Bool {
        Self.log.notice("command \(name, privacy: .public) for \(workoutID.uuidString, privacy: .public); store \(self.container == nil ? "missing" : "ready", privacy: .public)")
        guard let context = container?.mainContext,
              let workout = try? context.fetch(FetchDescriptor<Workout>(
                  predicate: #Predicate { $0.id == workoutID })).first,
              !workout.isDeleted, workout.finishedAt == nil
        else { return false }

        // A cold launch (or a runtime ended by a crash) has no session for this workout yet:
        // start it first, so the alarm, the Watch and the recorder move with the command.
        attachRuntime(workout, context)
        // D43 without a screen (live-workout 04): the runtime checks a heart-rate rest on each sample until a screen
        // claims `onSample`.
        coordinator.restEvaluator = { [weak self] in self?.evaluateRestWithoutScreen(workoutID: workoutID) }
        let monitor = coordinator.workoutID == workout.id ? coordinator.monitor : nil
        let heart = monitor.map { WorkoutActivityContent.Heart(bpm: $0.isStale ? nil : $0.current?.bpm, zone: $0.currentZone) }
        // `RestTimerService` clears a rest that has run out; say how it ended first, as the live
        // screen does (codex-review-11 #4).
        if let end = workout.restEndsAt, end <= .now {
            coordinator.lastRestResult = WorkoutActivityContent.make(
                for: workout, in: context, heart: heart, restResult: coordinator.lastRestResult,
                degradedRestSetID: coordinator.degradedRestSetID).shownResult(at: .now, isStale: true)
        }
        let rest = RestTimerService(context: context, notifications: notifications)
        let changed: Bool
        do {
            changed = try change(workout, context, rest)
        } catch {
            // Never fatal: a failed lock-screen command leaves the workout as it was.
            Self.log.error("command \(name, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            if refreshesWhenUnchanged { pushCard(workout, in: context) }
            return false
        }
        guard changed || refreshesWhenUnchanged else { return false }

        Self.log.notice("command \(name, privacy: .public) \(changed ? "applied" : "refused, card refreshed", privacy: .public); rest ends \(String(describing: workout.restEndsAt), privacy: .public)")
        if changed { NotificationCenter.default.post(name: Self.didApply, object: workoutID) }
        pushCard(workout, in: context)
        return changed
    }
}
