import Foundation
import Testing
import UserNotifications
@testable import WorkoutTracker

/// The production rest-notification adapter against a stand-in center (testing-workflow ticket 01, codex-review-01 #1):
/// the calls leave the caller's thread, stay in call order, and a slow removal does not move the notification later
/// than the rest's end.
@Suite struct RestNotificationSchedulerTests {
    /// Records each call; `removalDelay` stands in for a slow notification daemon.
    final class SlowCenter: RestNotificationCenter, @unchecked Sendable {
        private let lock = NSLock()
        private var log: [String] = []
        private var added: [(at: Date, interval: TimeInterval)] = []
        let removalDelay: TimeInterval
        init(removalDelay: TimeInterval = 0) { self.removalDelay = removalDelay }

        func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
            if removalDelay > 0 { Thread.sleep(forTimeInterval: removalDelay) }
            lock.withLock { log.append("remove \(identifiers.joined())") }
        }
        func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: (@Sendable (Error?) -> Void)?) {
            let interval = (request.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval ?? -1
            lock.withLock {
                log.append("add \(request.identifier)")
                added.append((Date(), interval))
            }
        }
        var calls: [String] { lock.withLock { log } }
        var additions: [(at: Date, interval: TimeInterval)] { lock.withLock { added } }
    }

    @Test func aSlowRemovalDoesNotDelayTheNotificationPastTheRestsEnd() throws {
        let center = SlowCenter(removalDelay: 0.6)
        let scheduler = UserNotificationScheduler(center: center)
        let end = Date().addingTimeInterval(60)
        scheduler.schedule(at: end)
        scheduler.waitUntilQueuedCallsFinish()
        let added = try #require(center.additions.first)
        // Due when the rest ends: the interval is measured from when the request is added, after the 0.6 s removal.
        #expect(abs(added.at.addingTimeInterval(added.interval).timeIntervalSince(end)) < 0.1)
        #expect(added.interval < 59.5)
    }

    @Test func callsReachTheCenterInCallOrder() {
        let center = SlowCenter(removalDelay: 0.05)
        let scheduler = UserNotificationScheduler(center: center)
        scheduler.schedule(at: Date().addingTimeInterval(90))
        scheduler.cancel()
        scheduler.waitUntilQueuedCallsFinish()
        // Schedule then cancel: the cancel's removal comes last, so nothing stays pending.
        #expect(center.calls == ["remove workout-rest-timer", "add workout-rest-timer", "remove workout-rest-timer"])

        let second = SlowCenter(removalDelay: 0.05)
        let again = UserNotificationScheduler(center: second)
        again.cancel()
        again.schedule(at: Date().addingTimeInterval(90))
        again.waitUntilQueuedCallsFinish()
        #expect(second.calls == ["remove workout-rest-timer", "remove workout-rest-timer", "add workout-rest-timer"])
    }

    @Test func aDeadlineAlreadyPassedStillNotifiesASecondLater() {
        let center = SlowCenter()
        let scheduler = UserNotificationScheduler(center: center)
        scheduler.schedule(at: Date().addingTimeInterval(-5))
        scheduler.waitUntilQueuedCallsFinish()
        #expect(center.additions.map(\.interval) == [1])
    }

    @Test func theCallerIsNotKeptWaitingForTheCenter() {
        let center = SlowCenter(removalDelay: 0.5)
        let scheduler = UserNotificationScheduler(center: center)
        let start = Date()
        scheduler.schedule(at: start.addingTimeInterval(60))
        scheduler.cancel()
        #expect(Date().timeIntervalSince(start) < 0.2, "schedule and cancel return before the slow removals run")
        scheduler.waitUntilQueuedCallsFinish()
        #expect(center.calls.count == 3)
    }
}
