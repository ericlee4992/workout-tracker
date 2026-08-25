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
    /// coordinator sounds a rest with no view involved anywhere.
    @Test func theAlarmSoundsWithNoScreenAttached() {
        let (coordinator, alarm) = coordinator()
        let monitor = HeartRateMonitor(provider: SilentRestAlarmStubProvider())
        coordinator.adoptForTesting(monitor: monitor, workoutID: UUID())
        coordinator.armForTesting(restEndsAt: end)

        coordinator.evaluateAlarmForTesting(now: end)
        #expect(alarm.sounded == [.cap], "a minimised workout must still beep")
    }

    @Test func recoveryAndCapCannotBothSoundForOneRest() {
        let (coordinator, alarm) = coordinator()
        coordinator.armForTesting(restEndsAt: end)
        coordinator.soundRecovered()
        // The cap moment arrives, but this rest already ended by recovery.
        coordinator.evaluateAlarmForTesting(now: end.addingTimeInterval(30))
        #expect(alarm.sounded == [.recovered], "one rest, one ending, one sound")
    }

    @Test func oneRestSoundsOnceEvenThoughSamplesArriveEverySecond() {
        let (coordinator, alarm) = coordinator()
        coordinator.armForTesting(restEndsAt: end)
        for second in 0...20 {
            coordinator.evaluateAlarmForTesting(now: end.addingTimeInterval(Double(second)))
        }
        #expect(alarm.sounded == [.cap], "got \(alarm.sounded.count) beeps")
    }

    @Test func theSecondRestOfAWorkoutStillSounds() {
        let (coordinator, alarm) = coordinator()
        coordinator.armForTesting(restEndsAt: end)
        coordinator.evaluateAlarmForTesting(now: end)
        let second = end.addingTimeInterval(300)
        coordinator.armForTesting(restEndsAt: second)
        coordinator.evaluateAlarmForTesting(now: second)
        #expect(alarm.sounded == [.cap, .cap])
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
