import AVFoundation
import Foundation
import os

// Diagnostics go through `Logger`, not `print`.
//
// This bug has now survived three fix attempts, every one of them reasoned about
// from the outside because nothing on the device could be observed. `print`
// output does not reach the device console; `Logger` does, and can be read from
// the Mac while the phone is in a pocket with the screen off:
//
//   log stream --device-name "Eric's iPhone" \
//     --predicate 'subsystem == "com.ericlee4992.workouttracker"'
//
// The question every line here exists to answer is the same one: IS THIS APP
// STILL EXECUTING while backgrounded?
let restAlarmLog = Logger(
    subsystem: "com.ericlee4992.workouttracker", category: "RestAlarm")

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
    /// Queues the rest-end beep NOW, to play by itself in `seconds`.
    ///
    /// The whole point: nothing has to execute when the rest actually ends.
    /// Called on every change to the rest deadline — start, +15s, skip.
    func scheduleBeep(inSeconds seconds: TimeInterval, pattern: RestAlarmPattern)
    /// Drops a queued beep, for a rest that ended some other way.
    func cancelScheduledBeep()
    /// True while a queued track is still counting down to its beep, so a
    /// fallback path can avoid sounding the same rest twice.
    var hasQueuedBeep: Bool { get }
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
    /// The pre-rendered [silence][beep] track for the current rest.
    private var scheduled: AVAudioPlayer?
    /// When that track is due to beep. Kept so an interruption can rebuild it
    /// for the REMAINING time rather than losing the rest's alarm entirely.
    private var scheduledEndsAt: Date?
    private var scheduledPattern: RestAlarmPattern = .cap
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
            restAlarmLog.notice("session opened, category=\(session.category.rawValue, privacy: .public) options=\(session.categoryOptions.rawValue)")
        } catch {
            // Non-fatal by design. A workout that cannot beep is still a
            // workout, and the local notification remains as the visual
            // channel. NOT `assertionFailure`: this app installs as Debug, so
            // trapping here would turn a missing beep into a crashed workout.
            restAlarmLog.error("could not open audio session: \(error.localizedDescription, privacy: .public)")
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
            // volume 1.0, NOT a small number. `keepAliveSamples` dithers at
            // ±1 LSB precisely so the output is never digital silence; the
            // previous 0.01 scaled that to ~3e-7 and defeated its own
            // safeguard, which is a plausible reason iOS stopped treating this
            // as real playback. Inaudibility must come from the SAMPLES, never
            // from the volume.
            player.volume = 1.0
            player.prepareToPlay()
            player.play()
            keepAlive = player
            restAlarmLog.notice("keep-alive playing=\(player.isPlaying)")
        } catch {
            restAlarmLog.error("keep-alive failed, background alarm will not fire: \(error.localizedDescription, privacy: .public)")
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

        // The QUEUED TRACK FIRST — it carries the actual alarm.
        //
        // Codex cross-review, 2026-08-25: this used to restart only the
        // keep-alive, so a phone call or a Siri request part-way through a rest
        // silently threw away that rest's beep. Rebuilt from the wall clock
        // rather than resumed, because the track's own playhead has no idea how
        // long the interruption lasted.
        if let endsAt = scheduledEndsAt, scheduled?.isPlaying != true {
            let remaining = endsAt.timeIntervalSinceNow
            restAlarmLog.notice("interruption ended, rebuilding queued beep for \(remaining, format: .fixed(precision: 1))s")
            scheduleBeep(inSeconds: remaining, pattern: scheduledPattern)
            return
        }
        if keepAlive?.isPlaying != true {
            keepAlive?.play()
            if keepAlive == nil { startKeepAlive() }
        }
    }

    func endSession() {
        unduckTask?.cancel()
        unduckTask = nil
        scheduled?.stop()
        scheduled = nil
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

    func scheduleBeep(inSeconds seconds: TimeInterval, pattern: RestAlarmPattern) {
        cancelScheduledBeep()
        guard seconds > 0 else { sound(pattern); return }
        if !isSessionOpen { beginSession() }
        do {
            let track = RestAlarmTone.restTrackWav(
                silenceSeconds: seconds, pattern: pattern)
            let player = try AVAudioPlayer(data: track)
            player.volume = 1
            player.prepareToPlay()
            player.play()
            scheduled = player
            scheduledEndsAt = Date().addingTimeInterval(seconds)
            scheduledPattern = pattern
            // The keep-alive loop would fight this track for the route, and the
            // track is itself continuous audio — it IS the keep-alive now.
            keepAlive?.stop()
            restAlarmLog.notice("queued beep in \(seconds, format: .fixed(precision: 1))s, playing=\(player.isPlaying)")
        } catch {
            restAlarmLog.error("could not queue beep: \(error.localizedDescription, privacy: .public)")
            startKeepAlive()
        }
    }

    var hasQueuedBeep: Bool { scheduled?.isPlaying == true }

    func cancelScheduledBeep() {
        guard scheduled != nil else { return }
        scheduled?.stop()
        scheduled = nil
        scheduledEndsAt = nil
        restAlarmLog.notice("queued beep cancelled")
        // Something must keep holding the route, or the app is suspended and
        // the NEXT rest cannot queue anything either.
        if keepAlive?.isPlaying != true { startKeepAlive() }
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
            restAlarmLog.notice("SOUNDED \(String(describing: pattern), privacy: .public) playing=\(player.isPlaying) keepAlive=\(self.keepAlive?.isPlaying == true)")
            unduckTask?.cancel()
            let seconds = player.duration + 0.3
            unduckTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(seconds))
                guard !Task.isCancelled else { return }
                self?.setDucking(false)
            }
        } catch {
            restAlarmLog.error("could not play: \(error.localizedDescription, privacy: .public)")
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
            restAlarmLog.error("could not set ducking=\(ducking): \(error.localizedDescription, privacy: .public)")
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
    /// (seconds, pattern) for each queued beep, so tests can assert the
    /// deadline was queued rather than left to run at the moment it fires.
    private(set) var queued: [(seconds: TimeInterval, pattern: RestAlarmPattern)] = []
    private(set) var cancellations = 0
    func beginSession() { sessionOpens += 1 }
    func endSession() { sessionCloses += 1 }
    func scheduleBeep(inSeconds seconds: TimeInterval, pattern: RestAlarmPattern) {
        // Replaces, mirroring the real implementation, which cancels the old
        // track first. A fake that appends would let a +15s test pass while the
        // real app had two tracks counting down at once.
        queued = [(seconds, pattern)]
    }
    func cancelScheduledBeep() { cancellations += 1; queued.removeAll() }
    /// Test seam: the track stopped on its own — an interruption, a route
    /// change — without anyone cancelling it, which is when the executing
    /// fallback has to take over.
    func dropQueueWithoutCancelling() { queued.removeAll() }
    var hasQueuedBeep: Bool { !queued.isEmpty }
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
