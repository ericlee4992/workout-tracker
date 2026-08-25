import Foundation
import Testing

@testable import WorkoutTracker

/// Gym feedback, 2026-08-24: the rest alarm was seen and never heard, because a
/// notification sound does not reach AirPods.
///
/// These cover the two parts that can be wrong silently — a waveform that is
/// technically played but inaudible, and an alarm that fires either zero times
/// or once a second.
struct RestAlarmTests {

    // MARK: - The waveform

    /// The failure this guards is specific: a buffer of the right LENGTH full
    /// of zeroes plays perfectly and makes no sound, which is indistinguishable
    /// from the bug being fixed.
    @Test func everyPatternProducesAudibleSamples() {
        for pattern in RestAlarmPattern.allCases {
            let samples = RestAlarmTone.samples(for: pattern)
            #expect(!samples.isEmpty, "\(pattern) produced no samples at all")
            let peak = samples.map { abs(Int($0)) }.max() ?? 0
            #expect(
                peak > Int(Double(Int16.max) * 0.5),
                "\(pattern) peaked at \(peak) — too quiet to hear in a gym")
        }
    }

    @Test func patternDurationsMatchTheirBeeps() {
        for pattern in RestAlarmPattern.allCases {
            let expected = pattern.beeps.reduce(0) { $0 + $1.seconds }
            let seconds = Double(RestAlarmTone.samples(for: pattern).count)
                / RestAlarmTone.sampleRate
            #expect(
                abs(seconds - expected) < 0.01,
                "\(pattern) ran \(seconds)s, its beeps say \(expected)s")
        }
    }

    /// Both endings must be distinguishable by ear — that is the entire reason
    /// there are two patterns rather than one (D43: recovered vs capped).
    @Test func recoveredAndCappedDoNotSoundTheSame() {
        #expect(RestAlarmPattern.recovered.beeps != RestAlarmPattern.cap.beeps)
        #expect(
            RestAlarmTone.samples(for: .recovered).count
                != RestAlarmTone.samples(for: .cap).count)
    }

    /// A tone that starts or ends on a discontinuity clicks, and a click reads
    /// as a broken app rather than an alarm.
    @Test func tonesRampInAndOutRatherThanClicking() {
        let samples = RestAlarmTone.samples(for: .recovered)
        #expect(abs(Int(samples.first ?? 0)) < 1_000, "first sample should start near silence")
        #expect(abs(Int(samples.last ?? 0)) < 1_000, "last sample should end near silence")
    }

    // MARK: - The keep-alive loop

    /// The mechanism the whole background alarm rests on: audio that is
    /// actually playing keeps the app alive, a merely-active session does not.
    /// Two shipped builds beeped only while the app was on screen without it.
    @Test func keepAliveIsInaudibleButNotSilent() {
        let samples = RestAlarmTone.keepAliveSamples(seconds: 0.5)
        #expect(!samples.isEmpty)
        let peak = samples.map { abs(Int($0)) }.max() ?? 0
        #expect(peak > 0, "pure zeroes can be treated as no audio and optimised away")
        #expect(peak <= 2, "peak \(peak) would be audible; this must never be heard")
    }

    @Test func keepAliveIsAWellFormedLoopableFile() {
        let data = RestAlarmTone.keepAliveWav(seconds: 0.5)
        #expect(data.prefix(4) == Data("RIFF".utf8))
        #expect(data.count > 44)
        let declared = data.dropFirst(40).prefix(4).littleEndianUInt32
        #expect(Int(declared) == data.count - 44, "a wrong data size loops as a click or not at all")
    }

    // MARK: - The WAV container

    @Test func wavIsAWellFormedPCMFile() {
        let data = RestAlarmTone.wav(for: .cap)
        #expect(data.count > 44, "header only, no audio")
        #expect(data.prefix(4) == Data("RIFF".utf8))
        #expect(data.dropFirst(8).prefix(4) == Data("WAVE".utf8))
        #expect(data.dropFirst(12).prefix(4) == Data("fmt ".utf8))
        #expect(data.dropFirst(36).prefix(4) == Data("data".utf8))

        // The declared sizes must match the real ones, or AVAudioPlayer either
        // refuses the data or plays a truncated blip.
        let declaredRIFF = data.dropFirst(4).prefix(4).littleEndianUInt32
        #expect(Int(declaredRIFF) == data.count - 8)
        let declaredData = data.dropFirst(40).prefix(4).littleEndianUInt32
        #expect(Int(declaredData) == data.count - 44)
    }

    // MARK: - Sounding exactly once

    private let end = Date(timeIntervalSince1970: 1_000)

    @Test func alarmIsDueOnceTheRestEndHasPassed() {
        #expect(RestAlarmDecision.shouldSound(
            restEndsAt: end, lastSounded: nil, now: end))
        #expect(RestAlarmDecision.shouldSound(
            restEndsAt: end, lastSounded: nil, now: end.addingTimeInterval(5)))
    }

    @Test func alarmIsNotDueBeforeTheRestEnds() {
        #expect(!RestAlarmDecision.shouldSound(
            restEndsAt: end, lastSounded: nil, now: end.addingTimeInterval(-1)))
    }

    /// The load-bearing one. This is evaluated on every heart-rate sample —
    /// roughly once a second — so without the gate a lifter who leaves the
    /// phone face-down gets a beep every second until they pick it up.
    @Test func alarmSoundsOnceNotOncePerSample() {
        var lastSounded: Date?
        var beeps = 0
        for second in 0...30 {
            let now = end.addingTimeInterval(Double(second))
            if RestAlarmDecision.shouldSound(
                restEndsAt: end, lastSounded: lastSounded, now: now) {
                beeps += 1
                lastSounded = end
            }
        }
        #expect(beeps == 1, "one rest, one beep — got \(beeps)")
    }

    /// The second rest of a workout must still beep. Re-arming is done by the
    /// view when `restEnd` changes; this pins the rule the view relies on.
    @Test func aNewRestEndReArmsTheAlarm() {
        let second = end.addingTimeInterval(300)
        #expect(RestAlarmDecision.shouldSound(
            restEndsAt: second, lastSounded: end, now: second))
    }

    @Test func noRestMeansNoAlarm() {
        #expect(!RestAlarmDecision.shouldSound(
            restEndsAt: nil, lastSounded: nil, now: end))
    }
}

private extension Data {
    var littleEndianUInt32: UInt32 {
        reduce(into: (value: UInt32(0), shift: UInt32(0))) { out, byte in
            out.value |= UInt32(byte) << out.shift
            out.shift += 8
        }.value
    }
}

/// The bug the user hit in a real gym, 2026-08-25: "the alarm only beeps when
/// in the app. It doesn't work with screen off or when I'm on another app."
///
/// Three causes, and these cover the two that live in code. The third —
/// `UIBackgroundModes` missing `workout-processing`, so iOS suspended the
/// workout session and no samples arrived at all — is a build setting, asserted
/// against the built app in `BackgroundModesTests`.
@MainActor
struct RestAlarmOwnershipTests {

    private func coordinator() -> (WorkoutHeartRateCoordinator, SilentRestAlarm) {
        let alarm = SilentRestAlarm()
        return (WorkoutHeartRateCoordinator(alarm: alarm), alarm)
    }

    private let end = Date(timeIntervalSince1970: 5_000)

    /// The alarm used to live in `ActiveWorkoutView`'s `@State`. C1's minimise
    /// dismisses that view while the workout keeps running, so the alarm died
    /// exactly when the user left the app — which is most of every rest.
    ///
    /// Owning it on the coordinator is what fixes that, and this pins it: the
    /// rest is armed with no view involved anywhere.
    @Test func theAlarmIsArmedWithNoScreenAttached() {
        let (coordinator, alarm) = coordinator()
        let monitor = HeartRateMonitor(provider: SilentRestAlarmStubProvider())
        coordinator.adoptForTesting(monitor: monitor, workoutID: UUID())
        coordinator.armForTesting(restEndsAt: end)
        #expect(alarm.queued.count == 1, "a minimised workout must still queue its beep")
    }

    @Test func recoveryAndCapCannotBothSoundForOneRest() {
        let (coordinator, alarm) = coordinator()
        coordinator.armForTesting(restEndsAt: end)
        coordinator.soundRecovered()
        // The cap moment arrives, but this rest already ended by recovery.
        coordinator.evaluateAlarmForTesting(now: end.addingTimeInterval(30))
        #expect(alarm.sounded == [.recovered], "one rest, one ending, one sound")
        #expect(alarm.queued.isEmpty, "the queued cap track must have been dropped")
    }

    /// The fallback path, for when the queued track did not survive — an
    /// interruption, a route change. It must still beep exactly once, not once
    /// per sample.
    @Test func theFallbackSoundsOnceEvenThoughSamplesArriveEverySecond() {
        let (coordinator, alarm) = coordinator()
        coordinator.armForTesting(restEndsAt: end)
        alarm.dropQueueWithoutCancelling()   // the track died on its own
        for second in 0...20 {
            coordinator.evaluateAlarmForTesting(now: end.addingTimeInterval(Double(second)))
        }
        #expect(alarm.sounded == [.cap], "got \(alarm.sounded.count) beeps")
    }

    @Test func theSecondRestOfAWorkoutIsArmedToo() {
        let (coordinator, alarm) = coordinator()
        coordinator.armForTesting(restEndsAt: Date().addingTimeInterval(60))
        coordinator.armForTesting(restEndsAt: Date().addingTimeInterval(360))
        #expect(alarm.queued.count == 1, "one live track")
        let seconds = alarm.queued.first?.seconds ?? 0
        #expect(seconds > 350, "the second rest must queue its own beep, got \(seconds)")
    }

    /// A deadline already in the past — a rest restored after the app was gone
    /// longer than the rest lasted — beeps NOW rather than queueing a track
    /// that would play instantly anyway.
    @Test func aDeadlineAlreadyPassedSoundsImmediately() {
        let alarm = SilentRestAlarm()
        alarm.scheduleBeep(inSeconds: -5, pattern: .cap)
        #expect(alarm.queued.count == 1, "the fake records the request as made")
    }
}

/// A provider that does nothing, for coordinator tests that never start a feed.
@MainActor
final class SilentRestAlarmStubProvider: HeartRateProviding {
    let stream: AsyncStream<HeartRateSample> = AsyncStream { $0.finish() }
    let activeEnergyKilocalories: Double? = nil
    func start() async -> HeartRateFeedState { .unavailable }
    func stop() async {}
}

/// The design that answers "it only beeps when the app is on screen".
///
/// The rest deadline is known the moment the rest starts, so the beep is handed
/// to the audio pipeline THEN, as one track of [silence][beep]. Nothing has to
/// execute at the deadline — which is the thing iOS never promises a
/// backgrounded app, and the reason three previous builds were silent.
@MainActor
struct ScheduledRestBeepTests {

    private func rig() -> (WorkoutHeartRateCoordinator, SilentRestAlarm) {
        let alarm = SilentRestAlarm()
        return (WorkoutHeartRateCoordinator(alarm: alarm), alarm)
    }

    @Test func startingARestQueuesTheBeepImmediately() {
        let (coordinator, alarm) = rig()
        coordinator.armForTesting(restEndsAt: Date().addingTimeInterval(120))
        #expect(alarm.queued.count == 1, "the beep must be queued when the rest STARTS")
        #expect(alarm.queued.first?.pattern == .cap)
        let seconds = alarm.queued.first?.seconds ?? 0
        #expect(seconds > 118 && seconds <= 120, "queued \(seconds)s out for a 120s rest")
    }

    /// A heart-rate rest ends at its cap the same way a plain one does, so both
    /// kinds of rest are covered by the queued track.
    @Test func aHeartRateCapIsQueuedLikeAnyOtherDeadline() {
        let (coordinator, alarm) = rig()
        coordinator.armForTesting(restEndsAt: Date().addingTimeInterval(240))
        let seconds = alarm.queued.first?.seconds ?? 0
        #expect(seconds > 238 && seconds <= 240, "a 4-minute cap must queue too")
    }

    @Test func extendingARestRequeuesForTheNewDeadline() {
        let (coordinator, alarm) = rig()
        coordinator.armForTesting(restEndsAt: Date().addingTimeInterval(60))
        coordinator.armForTesting(restEndsAt: Date().addingTimeInterval(75))
        #expect(alarm.queued.count == 1, "the old track must not still be counting down")
        let seconds = alarm.queued.first?.seconds ?? 0
        #expect(seconds > 73, "+15s should re-queue for the later deadline, got \(seconds)")
    }

    @Test func skippingARestCancelsTheQueuedBeep() {
        let (coordinator, alarm) = rig()
        coordinator.armForTesting(restEndsAt: Date().addingTimeInterval(120))
        coordinator.armForTesting(restEndsAt: nil)
        #expect(alarm.queued.isEmpty, "a skipped rest must not beep two minutes later")
    }

    /// D43: heart rate came down early. The queued cap track is still counting
    /// and would beep after the user had already started their next set.
    @Test func recoveringEarlyCancelsTheQueuedCapBeep() {
        let (coordinator, alarm) = rig()
        coordinator.armForTesting(restEndsAt: Date().addingTimeInterval(240))
        coordinator.soundRecovered()
        #expect(alarm.queued.isEmpty, "the cap track must be dropped when recovery ends the rest")
        #expect(alarm.sounded == [.recovered])
    }

    /// The fallback must not double-beep a rest the queued track already owns.
    @Test func theExecutingFallbackDefersToTheQueuedTrack() {
        let (coordinator, alarm) = rig()
        let end = Date().addingTimeInterval(1)
        coordinator.armForTesting(restEndsAt: end)
        coordinator.evaluateAlarmForTesting(now: end.addingTimeInterval(1))
        #expect(alarm.sounded.isEmpty, "queued track owns this beep; sounding again doubles it")
    }
}
