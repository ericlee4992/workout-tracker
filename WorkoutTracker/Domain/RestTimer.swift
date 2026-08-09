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
    func cancel()
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
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.body = "Time for your next set."
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

        let preferences = try AppPreferences.canonical(in: context)
        if !preferences.notificationPermissionRequested {
            preferences.notificationPermissionRequested = true
            preferences.updatedAt = clock.now
            notifications.requestAuthorization()
        }

        let seconds = try durationSeconds(for: set)
        let end = clock.now.addingTimeInterval(TimeInterval(seconds))
        workout.restEndsAt = end
        workout.restStartedAt = clock.now
        workout.restStartedBySetID = set.id
        try context.save()
        notifications.schedule(at: end)
        return RestTimerState(
            end: end,
            remaining: TimeInterval(seconds),
            total: TimeInterval(seconds))
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
        workingSeconds: Int?
    ) throws {
        let exerciseID = exercise.id
        let rows = try context.fetch(FetchDescriptor<ExerciseRestOverride>(
            predicate: #Predicate { $0.exerciseID == exerciseID }
        ))
        let row = rows.canonical ?? ExerciseRestOverride(exerciseID: exerciseID)
        if rows.isEmpty { context.insert(row) }
        row.warmupRestSeconds = warmupSeconds.map { max(0, $0) }
        row.workingRestSeconds = workingSeconds.map { max(0, $0) }
        row.updatedAt = clock.now
        try context.save()
    }

    private func clear(_ workout: Workout) {
        workout.restEndsAt = nil
        workout.restStartedAt = nil
        workout.restStartedBySetID = nil
    }
}
