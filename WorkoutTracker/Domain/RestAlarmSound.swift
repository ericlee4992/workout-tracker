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
    /// Called when a workout starts. Opens and HOLDS the audio session.
    ///
    /// Why hold it rather than activate per beep: activating an audio session
    /// from a backgrounded app is unreliable, and backgrounded is exactly when
    /// the alarm matters. Activating while the user is still looking at the
    /// screen, then keeping it for the workout, is not.
    func beginSession()
    /// Called when the workout ends. Holding the session open for a workout
    /// nobody is doing is the audio equivalent of leaving the sensor powered.
    func endSession()
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
    private var isSessionOpen = false
    /// Loops inaudible audio for the whole workout. THIS is what keeps the app
    /// alive in the background — see `beginSession`.
    private var keepAlive: AVAudioPlayer?
    private var observers: [NSObjectProtocol] = []
    private var unduckTask: Task<Void, Never>?

    func beginSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // `.playback` is the category that routes to A2DP headphones —
            // AirPods — which `.ambient` and the notification route do not.
            // `.mixWithOthers` so holding it open does not stop the user's
            // music; ducking is applied around the beep only, in `sound`.
            try session.setCategory(
                .playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            isSessionOpen = true
            startKeepAlive()
            observeInterruptions()
        } catch {
            // Non-fatal by design. A workout that cannot beep is still a
            // workout, and the local notification remains as the visual
            // channel. NOT `assertionFailure`: this app installs as Debug, so
            // trapping here would turn a missing beep into a crashed workout.
            print("[RestAlarm] could not open audio session: \(error)")
            isSessionOpen = false
        }
    }

    /// Plays inaudible audio on a loop for the length of the workout.
    ///
    /// WHY, because it looks like a hack and is load-bearing: an audio session
    /// that is merely ACTIVE does not keep an app running — iOS suspends it,
    /// the workout session stops delivering samples, every timer stops, and the
    /// rest alarm never fires. Audio that is actually PLAYING keeps the process
    /// alive, which is exactly how a music app keeps playing with the screen
    /// off. Two builds shipped before this and beeped only while the app was on
    /// screen; `workout-processing` alone did not fix it.
    ///
    /// The cost is honest: this holds an audio route open for the whole
    /// workout, which uses battery. It is released in `endSession`, on every
    /// path that ends a workout.
    private func startKeepAlive() {
        do {
            let player = try AVAudioPlayer(data: RestAlarmTone.keepAliveWav())
            player.numberOfLoops = -1
            player.volume = 0.01
            player.prepareToPlay()
            player.play()
            keepAlive = player
        } catch {
            print("[RestAlarm] keep-alive failed, background alarm will not fire: \(error)")
        }
    }

    /// A phone call or a Siri request deactivates our session and stops the
    /// keep-alive. Without restarting it the app is suspended for the rest of
    /// the workout and every later rest is silent.
    private func observeInterruptions() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(), queue: .main
        ) { note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard let raw, AVAudioSession.InterruptionType(rawValue: raw) == .ended else { return }
            Task { @MainActor [weak self] in self?.resumeAfterInterruption() }
        })
        // Pulling out an AirPod, or the case reconnecting, can also stop
        // playback without an interruption notification.
        observers.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(), queue: .main
        ) { _ in
            Task { @MainActor [weak self] in self?.resumeAfterInterruption() }
        })
    }

    private func resumeAfterInterruption() {
        guard isSessionOpen else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        if keepAlive?.isPlaying != true {
            keepAlive?.play()
            if keepAlive == nil { startKeepAlive() }
        }
    }

    func endSession() {
        unduckTask?.cancel()
        unduckTask = nil
        player?.stop()
        player = nil
        keepAlive?.stop()
        keepAlive = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        guard isSessionOpen else { return }
        isSessionOpen = false
        try? AVAudioSession.sharedInstance()
            .setActive(false, options: .notifyOthersOnDeactivation)
    }

    func sound(_ pattern: RestAlarmPattern) {
        let data = cache[pattern] ?? RestAlarmTone.wav(for: pattern)
        cache[pattern] = data
        // If the session never opened — or was torn down by an interruption
        // such as a phone call — try once more rather than failing silently.
        if !isSessionOpen { beginSession() }
        // Duck for the beep, then restore. Applied HERE rather than on the
        // held session because the session stays active for the whole workout,
        // and a permanently ducking session would keep the user's music quiet
        // for the entire hour (reported 2026-08-25 — they want the dip back,
        // not the whole workout dimmed).
        setDucking(true)
        do {
            let player = try AVAudioPlayer(data: data)
            player.volume = 1
            player.prepareToPlay()
            player.play()
            self.player = player
            unduckTask?.cancel()
            let seconds = player.duration + 0.3
            unduckTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(seconds))
                guard !Task.isCancelled else { return }
                self?.setDucking(false)
            }
        } catch {
            print("[RestAlarm] could not play \(pattern): \(error)")
            setDucking(false)
        }
    }

    /// Toggles `.duckOthers` without deactivating: deactivating would stop the
    /// keep-alive and let the app be suspended mid-rest.
    private func setDucking(_ ducking: Bool) {
        let options: AVAudioSession.CategoryOptions =
            ducking ? [.mixWithOthers, .duckOthers] : [.mixWithOthers]
        do {
            try AVAudioSession.sharedInstance()
                .setCategory(.playback, mode: .default, options: options)
        } catch {
            print("[RestAlarm] could not set ducking=\(ducking): \(error)")
        }
    }
}

/// Sounds nothing. Used by tests and by UI-test runs, which must not emit audio
/// on a CI machine.
@MainActor
final class SilentRestAlarm: RestAlarmSounding {
    private(set) var sounded: [RestAlarmPattern] = []
    private(set) var sessionOpens = 0
    private(set) var sessionCloses = 0
    func beginSession() { sessionOpens += 1 }
    func endSession() { sessionCloses += 1 }
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
