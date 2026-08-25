import AVFoundation
import Foundation

// Gym feedback, 2026-08-24 — playing the rest alarm where the user can hear it.
//
// THE WHOLE POINT, stated where the decision is made: a `UNNotificationSound`
// does NOT reach connected AirPods. It plays on the phone's alert route. The
// user confirmed the rest notification arrives correctly, screen off included,
// and still heard nothing in their ears. So the fix is not "fix the
// notification" — the notification is fine — it is to play real audio through
// the shared `AVAudioSession`, which is the only route Bluetooth headphones are
// on.
//
// System framework behind a protocol, injectable, following the shape
// `RestTimer.swift` set for UserNotifications and `HeartRateMonitor.swift` set
// for HealthKit: the rules above it stay testable on a machine with no speaker.

@MainActor
protocol RestAlarmSounding: AnyObject {
    func sound(_ pattern: RestAlarmPattern)
}

/// Plays the alarm through the shared audio session, so it lands in whatever
/// the user is actually listening on.
@MainActor
final class SystemRestAlarm: RestAlarmSounding {

    static let shared = SystemRestAlarm()

    /// The player MUST be held. An `AVAudioPlayer` that goes out of scope is
    /// deallocated mid-buffer and the user hears nothing at all — a silent
    /// failure that looks exactly like the bug this file exists to fix.
    private var player: AVAudioPlayer?
    private var cache: [RestAlarmPattern: Data] = [:]

    func sound(_ pattern: RestAlarmPattern) {
        let data = cache[pattern] ?? RestAlarmTone.wav(for: pattern)
        cache[pattern] = data
        do {
            let session = AVAudioSession.sharedInstance()
            // `.playback` is what routes to A2DP headphones; `.duckOthers` dips
            // the user's music for the beep instead of stopping it, and
            // `.mixWithOthers` keeps us from seizing the session outright.
            // Together they are the difference between "a beep over your music"
            // and "your music stops".
            try session.setCategory(
                .playback, mode: .default, options: [.duckOthers, .mixWithOthers])
            try session.setActive(true)
            let player = try AVAudioPlayer(data: data)
            player.volume = 1
            player.prepareToPlay()
            player.play()
            self.player = player
            // Hand the session back once the tone has finished, so ducked music
            // returns to full volume rather than staying quiet for the rest of
            // the workout.
            let seconds = player.duration + 0.25
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(seconds))
                try? AVAudioSession.sharedInstance()
                    .setActive(false, options: .notifyOthersOnDeactivation)
                self?.player = nil
            }
        } catch {
            // Never fatal. A workout that cannot beep is still a workout, and
            // the local notification remains as the visual channel.
            assertionFailure("Rest alarm could not play: \(error)")
        }
    }
}

/// Sounds nothing. Used by tests and by UI-test runs, which must not emit audio
/// on a CI machine.
@MainActor
final class SilentRestAlarm: RestAlarmSounding {
    private(set) var sounded: [RestAlarmPattern] = []
    func sound(_ pattern: RestAlarmPattern) { sounded.append(pattern) }
}

enum RestAlarms {
    @MainActor
    static func make() -> any RestAlarmSounding {
        WorkoutTrackerStore.isUITestReset ? SilentRestAlarm() : SystemRestAlarm.shared
    }
}

/// Decides whether the rest-end alarm is due, and guarantees it sounds once.
///
/// Pure so the once-only rule is testable. It is load-bearing: the cap alarm is
/// evaluated on every heart-rate sample (roughly once a second) because that is
/// the only tick that keeps running with the screen off — a SwiftUI `Timer`
/// does not (codex-review 2.2). Without this gate the user would get a beep
/// every second until they picked the phone up.
enum RestAlarmDecision {
    static func shouldSound(restEndsAt: Date?, lastSounded: Date?, now: Date) -> Bool {
        guard let restEndsAt else { return false }
        guard now >= restEndsAt else { return false }
        return lastSounded != restEndsAt
    }
}
