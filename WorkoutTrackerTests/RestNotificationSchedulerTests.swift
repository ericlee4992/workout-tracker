import Foundation
import Testing
import UserNotifications
@testable import WorkoutTracker

/// The production rest-notification adapter against a stand-in center (testing-workflow ticket 01, codex-review-01 #1):
/// the calls leave the caller's thread, stay in call order, and a slow removal does not move the notification later
/// than the rest's end. No wall-clock limits (codex-review-01b): time comes from a controlled clock, and "the caller
/// is not kept waiting" is shown with a removal held closed until the test opens it.
@Suite struct RestNotificationSchedulerTests {
    /// A clock the test (and the stand-in center) moves by hand.
    final class ManualClock: @unchecked Sendable {
        private let lock = NSLock()
        private var value: Date
        init(_ start: Date) { value = start }
        var now: Date { lock.withLock { value } }
        func advance(_ seconds: TimeInterval) { lock.withLock { value += seconds } }
    }

    /// Records each call. `onRemove` stands in for the daemon's work during a removal (advance the clock, or wait).
    final class StandInCenter: RestNotificationCenter, @unchecked Sendable {
        private let lock = NSLock()
        private var log: [String] = []
        private var intervals: [TimeInterval] = []
        var onRemove: () -> Void = {}

        func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
            onRemove()
            lock.withLock { log.append("remove \(identifiers.joined())") }
        }
        func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: (@Sendable (Error?) -> Void)?) {
            let interval = (request.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval ?? -1
            lock.withLock {
                log.append("add \(request.identifier)")
                intervals.append(interval)
            }
        }
        var calls: [String] { lock.withLock { log } }
        var addedIntervals: [TimeInterval] { lock.withLock { intervals } }
    }

    @Test func aSlowRemovalDoesNotDelayTheNotificationPastTheRestsEnd() {
        let clock = ManualClock(Date(timeIntervalSinceReferenceDate: 1_000_000))
        let center = StandInCenter()
        center.onRemove = { clock.advance(20) }   // the daemon takes 20 s to remove the old request
        let scheduler = UserNotificationScheduler(center: center, now: { clock.now })
        scheduler.schedule(at: clock.now.addingTimeInterval(60))
        scheduler.waitUntilQueuedCallsFinish()
        // Due when the rest ends: 60 s from the start is 40 s after the 20 s removal (before the fix: 60 s, 20 s late).
        #expect(center.addedIntervals == [40])
    }

    @Test func callsReachTheCenterInCallOrder() {
        let center = StandInCenter()
        let scheduler = UserNotificationScheduler(center: center)
        scheduler.schedule(at: Date().addingTimeInterval(90))
        scheduler.cancel()
        scheduler.waitUntilQueuedCallsFinish()
        // Schedule then cancel: the cancel's removal comes last, so nothing stays pending.
        #expect(center.calls == ["remove workout-rest-timer", "add workout-rest-timer", "remove workout-rest-timer"])

        let second = StandInCenter()
        let again = UserNotificationScheduler(center: second)
        again.cancel()
        again.schedule(at: Date().addingTimeInterval(90))
        again.waitUntilQueuedCallsFinish()
        #expect(second.calls == ["remove workout-rest-timer", "remove workout-rest-timer", "add workout-rest-timer"])
    }

    @Test func aDeadlineAlreadyPassedStillNotifiesASecondLater() {
        let clock = ManualClock(Date(timeIntervalSinceReferenceDate: 1_000_000))
        let center = StandInCenter()
        let scheduler = UserNotificationScheduler(center: center, now: { clock.now })
        scheduler.schedule(at: clock.now.addingTimeInterval(-5))
        scheduler.waitUntilQueuedCallsFinish()
        #expect(center.addedIntervals == [1])
    }

    @Test func theCallerIsNotKeptWaitingForTheCenter() {
        let gate = DispatchSemaphore(value: 0)
        let counter = NSLock()
        var removalsOpenedByTest = 0
        let center = StandInCenter()
        center.onRemove = {
            // Held closed until the test opens it. The 30 s timeout only keeps a regression from hanging the run: a
            // scheduler that blocked its caller would sit here, time out, and fail the expectations below.
            if gate.wait(timeout: .now() + 30) == .success { counter.withLock { removalsOpenedByTest += 1 } }
        }
        let scheduler = UserNotificationScheduler(center: center)
        scheduler.schedule(at: Date().addingTimeInterval(60))
        scheduler.cancel()
        // Both calls returned while the first removal is still held: nothing has reached the center yet.
        #expect(center.calls.isEmpty)
        gate.signal(); gate.signal()
        scheduler.waitUntilQueuedCallsFinish()
        #expect(center.calls.count == 3)
        #expect(counter.withLock { removalsOpenedByTest } == 2)
    }
}
