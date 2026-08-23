import Foundation
import SwiftData
import UserNotifications

protocol RestClock {
    var now: Date { get }
}

struct SystemRestClock: RestClock {
    var now: Date { .now }
}

protocol RestNotificationScheduling: AnyObject {
    func requestAuthorization()
    func schedule(at date: Date)
    /// D43: "your heart rate came down" and "you have been sitting here four
    /// minutes" are different facts about the set you just did, so the alarm
    /// says which. Defaulted, so existing implementations (and test doubles)
    /// that only know the plain form keep working.
    func schedule(at date: Date, title: String, body: String)
    func cancel()
}

extension RestNotificationScheduling {
    func schedule(at date: Date, title: String, body: String) {
        schedule(at: date)
    }
}

/// Production adapter. One stable identifier guarantees that every start,
/// +time, or replacement leaves at most one pending rest notification.
final class UserNotificationScheduler: RestNotificationScheduling {
    static let shared = UserNotificationScheduler()
    private let center: UNUserNotificationCenter
    private let identifier = "workout-rest-timer"

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() {
        Task { _ = try? await center.requestAuthorization(options: [.alert, .sound]) }
    }

    func schedule(at date: Date) {
        schedule(at: date, title: "Rest complete", body: "Time for your next set.")
    }

    func schedule(at date: Date, title: String, body: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let interval = max(1, date.timeIntervalSinceNow)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: interval, repeats: false))
        Task { try? await center.add(request) }
    }

    func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

struct RestTimerState: Equatable {
    var end: Date
    var remaining: TimeInterval
    /// The full duration this rest was started with, including any +15s
    /// extensions. `remaining / total` is the progress-bar fraction; using
    /// `remaining` as the denominator would show a restored timer as full.
    var total: TimeInterval
}

/// Ticket 14 timer state machine. Absolute time lives on Workout, duration
/// selection is override → global (failure uses working), and all clock/
/// notification effects are injected for deterministic tests.
struct RestTimerService {
    let context: ModelContext
    let clock: any RestClock
    let notifications: any RestNotificationScheduling

    init(
        context: ModelContext,
        clock: any RestClock = SystemRestClock(),
        notifications: any RestNotificationScheduling = UserNotificationScheduler.shared
    ) {
        self.context = context
        self.clock = clock
        self.notifications = notifications
    }

    /// D22: warmups get the warmup duration, working and failure sets the
    /// working one. Drop sets never reach here — `handleCompletionChange`
    /// starts no timer for them (D26) — so they carry no duration of their own.
    func durationSeconds(for set: SetRecord) throws -> Int {
        let preferences = try AppPreferences.canonical(in: context)
        let isWarmup = set.type == .warmup
        guard let exerciseID = set.entry?.exercise?.id else {
            return isWarmup
                ? preferences.globalWarmupRestSeconds
                : preferences.globalWorkingRestSeconds
        }
        let overrides = try context.fetch(FetchDescriptor<ExerciseRestOverride>(
            predicate: #Predicate { $0.exerciseID == exerciseID }
        ))
        let canonical = overrides.canonical
        if isWarmup, let seconds = canonical?.warmupRestSeconds { return max(0, seconds) }
        if !isWarmup, let seconds = canonical?.workingRestSeconds { return max(0, seconds) }
        return max(0, isWarmup
            ? preferences.globalWarmupRestSeconds
            : preferences.globalWorkingRestSeconds)
    }

    /// Call after WorkoutSession toggles completion. A completion starts or
    /// replaces the timer. An un-completion only cancels when this exact set
    /// started the current timer; it never starts a new one.
    ///
    /// D26: completing a *drop* set starts nothing — a drop set is performed
    /// without rest, so a countdown here would only be something to dismiss.
    /// Any timer already running is left exactly as it is (the rest the user
    /// is actually taking is not this set's to cancel).
    @discardableResult
    func handleCompletionChange(
        of set: SetRecord,
        isCompleted: Bool
    ) throws -> RestTimerState? {
        guard let workout = set.entry?.workout else { return nil }
        if !isCompleted {
            if workout.restStartedBySetID == set.id {
                clear(workout)
                try context.save()
                notifications.cancel()
            }
            return try currentState(for: workout)
        }
        guard set.type.startsRestTimer else { return try currentState(for: workout) }

        let preferences = try AppPreferences.canonical(in: context)
        if !preferences.notificationPermissionRequested {
            preferences.notificationPermissionRequested = true
            preferences.updatedAt = clock.now
            notifications.requestAuthorization()
        }

        // D43: a heart-rate rest runs to its CAP as far as the clock and the
        // persisted timer are concerned. The threshold can only end it early,
        // and only while a live reading is arriving — so the cap is what
        // survives a relaunch, a backgrounded app, or a sensor that dies.
        let plan = try restPlan(for: set)
        let seconds = plan.seconds
        let end = clock.now.addingTimeInterval(TimeInterval(seconds))
        workout.restEndsAt = end
        workout.restStartedAt = clock.now
        workout.restStartedBySetID = set.id
        try context.save()
        switch plan.mode {
        case .standard:
            notifications.schedule(at: end)
        case .heartRate:
            notifications.schedule(
                at: end,
                title: "Rest complete",
                body: "Time is up — your heart rate didn't reach the target.")
        }
        return RestTimerState(
            end: end,
            remaining: TimeInterval(seconds),
            total: TimeInterval(seconds))
    }

    // MARK: - Heart-rate rest (D43)

    /// How a rest for this set should run: standard durations (D22), or a
    /// heart-rate threshold with its cap.
    struct RestPlan: Equatable {
        var mode: RestMode
        /// The countdown length. In heart-rate mode this is the CAP.
        var seconds: Int
        /// nil in standard mode.
        var rule: HeartRateRestRule?
    }

    func restPlan(for set: SetRecord) throws -> RestPlan {
        guard let exerciseID = set.entry?.exercise?.id
                ?? set.entry?.snapshotExerciseID else {
            return RestPlan(
                mode: .standard, seconds: try durationSeconds(for: set), rule: nil)
        }
        let rows = try context.fetch(FetchDescriptor<ExerciseRestOverride>(
            predicate: #Predicate { $0.exerciseID == exerciseID }))
        let override = rows.canonical
        guard override?.restMode == .heartRate else {
            return RestPlan(
                mode: .standard, seconds: try durationSeconds(for: set), rule: nil)
        }
        // A missing threshold or cap resolves to the defaults rather than
        // disabling the mode: the user asked for a heart-rate rest, and a
        // silently-standard timer would be the app quietly doing something else.
        let rule = HeartRateRestRule(
            thresholdBpm: override?.heartRateThresholdBpm
                ?? HeartRateRestRule.defaultThresholdBpm,
            cap: TimeInterval(
                override?.heartRateCapSeconds ?? Int(HeartRateRestRule.defaultCap)))
        return RestPlan(mode: .heartRate, seconds: Int(rule.cap), rule: rule)
    }

    /// codex-review 2.1 (critical) — falls a heart-rate rest back to the
    /// standard duration when nothing is reading the user.
    ///
    /// The original code left the cap running and called that "degrading to the
    /// standard timer". It is not: the cap is four minutes and the user's
    /// standard rest is one or two, so a dead sensor silently doubled every
    /// rest while the settings screen promised a fallback. D43 says the rest
    /// degrades AND says it degraded.
    ///
    /// Returns the new state when it moved the deadline, nil when there was
    /// nothing to do — so this is safe to call on every tick.
    @discardableResult
    func degradeToStandard(_ workout: Workout, set: SetRecord) throws -> RestTimerState? {
        guard let start = workout.restStartedAt, let end = workout.restEndsAt else {
            return nil
        }
        let seconds = try durationSeconds(for: set)
        let standardEnd = start.addingTimeInterval(TimeInterval(seconds))
        // Idempotent in BOTH directions. Round 1 only shortened, so a 5:00
        // standard rest against a 4:00 cap never degraded at all and kept the
        // false "didn't reach target" alarm (codex-review-2 #4). Degrading means
        // "rest the way this exercise normally rests", whether that is shorter
        // or longer; already being there is the no-op.
        guard standardEnd != end else { return nil }

        let body = "No heart rate reading — resting by the timer instead."
        guard standardEnd > clock.now else {
            // The standard rest already elapsed while we waited on a sensor that
            // never reported. End it now — and schedule ONCE, not twice as round
            // 1 did.
            clear(workout)
            try context.save()
            notifications.schedule(
                at: clock.now.addingTimeInterval(1),
                title: "Rest complete", body: body)
            return nil
        }

        workout.restEndsAt = standardEnd
        try context.save()
        notifications.schedule(at: standardEnd, title: "Rest complete", body: body)
        return RestTimerState(
            end: standardEnd,
            remaining: standardEnd.timeIntervalSince(clock.now),
            total: TimeInterval(seconds))
    }

    /// Ends a heart-rate rest early because the user's heart rate came down.
    ///
    /// Separate from `skip` so the notification can tell the truth: this fires
    /// an alarm saying the athlete recovered, where `skip` fires none at all.
    func finishRecovered(_ workout: Workout, bpm: Int) throws {
        guard workout.restEndsAt != nil else { return }
        clear(workout)
        try context.save()
        // +1s rather than `now`: a UNTimeIntervalNotificationTrigger of zero is
        // rejected, and the app may well be backgrounded — which is exactly the
        // case this alarm exists for.
        notifications.schedule(
            at: clock.now.addingTimeInterval(1),
            title: "Rest complete",
            body: "Heart rate down to \(bpm) bpm — ready for your next set.")
    }

    /// Reconstruct or expire a persisted timer. Expired timers are cleared so
    /// returning from suspension never shows stale UI.
    func currentState(for workout: Workout) throws -> RestTimerState? {
        guard let end = workout.restEndsAt else { return nil }
        let remaining = end.timeIntervalSince(clock.now)
        guard remaining > 0 else {
            clear(workout)
            try context.save()
            notifications.cancel()
            return nil
        }
        return RestTimerState(
            end: end, remaining: remaining, total: total(of: workout, end: end))
    }

    @discardableResult
    func add(seconds: Int, to workout: Workout) throws -> RestTimerState? {
        guard let state = try currentState(for: workout) else { return nil }
        let end = state.end.addingTimeInterval(TimeInterval(seconds))
        workout.restEndsAt = end
        try context.save()
        notifications.schedule(at: end)
        // `restStartedAt` is untouched, so the total grows with the extension
        // and the bar keeps shrinking from wherever it was.
        return RestTimerState(
            end: end,
            remaining: end.timeIntervalSince(clock.now),
            total: total(of: workout, end: end))
    }

    /// Total = end − start. Timers persisted before `restStartedAt` existed
    /// fall back to the remaining time (the old behaviour) rather than zero.
    private func total(of workout: Workout, end: Date) -> TimeInterval {
        guard let started = workout.restStartedAt else {
            return max(0, end.timeIntervalSince(clock.now))
        }
        return max(0, end.timeIntervalSince(started))
    }

    func skip(_ workout: Workout) throws {
        clear(workout)
        try context.save()
        notifications.cancel()
    }

    /// App-level upsert; duplicate overrides use the same latest-date/id
    /// canonical rule as preferences and gym memory.
    func setOverride(
        for exercise: Exercise,
        warmupSeconds: Int?,
        workingSeconds: Int?,
        restMode: RestMode? = nil,
        heartRateThresholdBpm: Int? = nil,
        heartRateCapSeconds: Int? = nil
    ) throws {
        let exerciseID = exercise.id
        let rows = try context.fetch(FetchDescriptor<ExerciseRestOverride>(
            predicate: #Predicate { $0.exerciseID == exerciseID }
        ))
        let row = rows.canonical ?? ExerciseRestOverride(exerciseID: exerciseID)
        if rows.isEmpty { context.insert(row) }
        row.warmupRestSeconds = warmupSeconds.map { max(0, $0) }
        row.workingRestSeconds = workingSeconds.map { max(0, $0) }
        row.restMode = restMode
        // Clamped, not trusted: a zero or negative cap would make every
        // heart-rate rest expire the instant it started, which reads as the
        // feature being broken rather than misconfigured.
        row.heartRateThresholdBpm = heartRateThresholdBpm.map { max(30, min(240, $0)) }
        row.heartRateCapSeconds = heartRateCapSeconds.map { max(15, $0) }
        row.updatedAt = clock.now
        try context.save()
    }

    private func clear(_ workout: Workout) {
        workout.restEndsAt = nil
        workout.restStartedAt = nil
        workout.restStartedBySetID = nil
    }
}
