import Foundation
import Testing
@testable import WorkoutTracker

// Milestone 7, ticket 01 — the heart-rate rules, proven with no heartbeat
// anywhere near the machine. Every expected value is an independent literal
// from the ticket, not something recomputed from the code under test.

struct HeartRateTests {

    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    private func sample(
        _ bpm: Int, at offset: TimeInterval, from source: HeartRateSource = .fixture
    ) -> HeartRateSample {
        HeartRateSample(bpm: bpm, date: t0.addingTimeInterval(offset), source: source)
    }

    // MARK: - Staleness

    @Test func stalenessBeginsAfterTheTolerance_notAtIt() {
        let s = sample(120, at: 0)
        // Exactly at the tolerance is still fresh; staleness begins after.
        #expect(!s.isStale(asOf: t0.addingTimeInterval(15)))
        #expect(s.isStale(asOf: t0.addingTimeInterval(15.01)))
        #expect(!s.isStale(asOf: t0.addingTimeInterval(5)))
        #expect(s.isStale(asOf: t0.addingTimeInterval(20)))
    }

    // MARK: - Source precedence

    @Test func watchOutranksAirPodsForTheSameInstant() {
        let ears = sample(130, at: 0, from: .airPods)
        let wrist = sample(126, at: 0, from: .watch)
        let chosen = [ears, wrist].current(asOf: t0.addingTimeInterval(1))
        #expect(chosen?.source == .watch)
        #expect(chosen?.bpm == 126)
    }

    /// A dead sensor must not outrank a working one. The Watch stopped
    /// reporting a minute ago; the AirPods are reporting now, so the screen
    /// shows the ears rather than freezing on the wrist's last known number.
    @Test func aDeadHigherPrioritySourceLosesToALiveOne() {
        let staleWatch = sample(150, at: 0, from: .watch)
        let liveEars = sample(122, at: 58, from: .airPods)
        let chosen = [staleWatch, liveEars].current(asOf: t0.addingTimeInterval(60))
        #expect(chosen?.source == .airPods)
        #expect(chosen?.bpm == 122)
    }

    /// When everything is stale there is still a most-recent reading to show —
    /// the UI's job is then to mark it stale, not to blank the screen.
    @Test func allStaleStillReturnsTheBestCandidateToMarkAsStale() {
        let old = sample(150, at: 0, from: .watch)
        let chosen = [old].current(asOf: t0.addingTimeInterval(300))
        #expect(chosen == old)
        #expect(chosen?.isStale(asOf: t0.addingTimeInterval(300)) == true)
    }

    // MARK: - Max heart rate (D45)

    @Test func measuredMaxWinsAndIsNotFlaggedEstimated() throws {
        let birth = Date(timeIntervalSince1970: 0)
        let resolved = try #require(MaxHeartRateResolver.resolve(
            measured: 191, birthDate: birth, at: t0))
        #expect(resolved.bpm == 191)
        #expect(!resolved.isEstimated)
    }

    @Test func withoutAMeasuredMaxTheFormulaIsUsedAndFlagged() throws {
        // Born 1990-01-01, workout on 2026-08-22 → 36 completed years.
        var components = DateComponents()
        components.year = 1990; components.month = 1; components.day = 1
        let calendar = Calendar(identifier: .gregorian)
        let birth = try #require(calendar.date(from: components))
        var workoutDay = DateComponents()
        workoutDay.year = 2026; workoutDay.month = 8; workoutDay.day = 22
        let date = try #require(calendar.date(from: workoutDay))

        let resolved = try #require(MaxHeartRateResolver.resolve(
            measured: nil, birthDate: birth, at: date, calendar: calendar))
        #expect(resolved.bpm == 184, "220 − 36")
        #expect(resolved.isEstimated, "a population formula is not this athlete's maximum")
    }

    @Test func noBasisMeansNoMaximum_ratherThanAGuess() {
        #expect(MaxHeartRateResolver.resolve(measured: nil, birthDate: nil, at: t0) == nil)
        #expect(MaxHeartRateResolver.resolve(measured: 0, birthDate: nil, at: t0) == nil)
    }

    /// The age is taken at the workout's date, so re-rendering an old summary
    /// next year cannot restate which zone last year's sets were in.
    @Test func ageIsTakenAtTheWorkoutsDateNotToday() throws {
        let calendar = Calendar(identifier: .gregorian)
        var c = DateComponents(); c.year = 1990; c.month = 1; c.day = 1
        let birth = try #require(calendar.date(from: c))
        var then = DateComponents(); then.year = 2020; then.month = 6; then.day = 1
        var later = DateComponents(); later.year = 2030; later.month = 6; later.day = 1
        // Hoisted rather than nested: a `#require` inside a `#require` expands
        // recursively and does not compile.
        let thenDate = try #require(calendar.date(from: then))
        let laterDate = try #require(calendar.date(from: later))

        let old = try #require(MaxHeartRateResolver.resolve(
            measured: nil, birthDate: birth, at: thenDate, calendar: calendar))
        let new = try #require(MaxHeartRateResolver.resolve(
            measured: nil, birthDate: birth, at: laterDate, calendar: calendar))
        #expect(old.bpm == 190, "220 − 30")
        #expect(new.bpm == 180, "220 − 40")
    }

    // MARK: - Zones

    @Test func zoneBoundariesAreInclusiveLowAndExclusiveHigh() {
        // Max 180: zone 1 begins at 90 (50%).
        #expect(HeartRateZones.zone(for: 90, max: 180) == .one)
        #expect(HeartRateZones.zone(for: 89, max: 180) == .warm)
        #expect(HeartRateZones.zone(for: 108, max: 180) == .two)   // 60%
        #expect(HeartRateZones.zone(for: 126, max: 180) == .three) // 70%
        #expect(HeartRateZones.zone(for: 144, max: 180) == .four)  // 80%
        #expect(HeartRateZones.zone(for: 162, max: 180) == .five)  // 90%
        #expect(HeartRateZones.zone(for: 180, max: 180) == .five)
    }

    /// Above the recorded maximum means the maximum is wrong, not that a sixth
    /// zone exists.
    @Test func aboveMaximumIsStillZoneFive() {
        #expect(HeartRateZones.zone(for: 200, max: 180) == .five)
    }

    @Test func everyBpmMapsToExactlyOneZone() {
        for bpm in 0...250 {
            let zone = HeartRateZones.zone(for: bpm, max: 180)
            #expect(zone != nil, "bpm \(bpm) fell through every zone")
        }
        #expect(HeartRateZones.zone(for: 120, max: 0) == nil, "no max, no zone")
    }

    @Test func lowerBoundsRenderTheBoundariesTheZonesUse() {
        #expect(HeartRateZones.lowerBound(of: .one, max: 180) == 90)
        #expect(HeartRateZones.lowerBound(of: .five, max: 180) == 162)
    }

    // MARK: - The rest rule (D43)

    private var rule: HeartRateRestRule {
        HeartRateRestRule(thresholdBpm: 110, cap: 240)
    }

    @Test func restEndsOnRecovery_atTheCrossingSample() throws {
        let samples = [
            sample(150, at: 5), sample(132, at: 20),
            sample(118, at: 35), sample(107, at: 50), sample(101, at: 65),
        ]
        let state = rule.evaluate(
            samples: samples, start: t0, asOf: t0.addingTimeInterval(70))
        guard case .finished(let end) = state, case .recovered(let at, let bpm) = end else {
            Issue.record("expected recovery, got \(state)"); return
        }
        #expect(bpm == 107, "the first reading strictly below 110")
        #expect(at == t0.addingTimeInterval(50))
    }

    /// "Drops below 110" means 110 does not end it.
    @Test func thresholdIsStrictlyBelow() {
        let state = rule.evaluate(
            samples: [sample(110, at: 30)], start: t0, asOf: t0.addingTimeInterval(35))
        #expect(state == .resting(elapsed: 35))
    }

    @Test func restEndsAtTheCapWhenRecoveryNeverComes() throws {
        // A hard set: never gets below 110 inside the four minutes.
        let samples = (1...16).map { sample(140, at: Double($0) * 15) }
        let state = rule.evaluate(
            samples: samples, start: t0, asOf: t0.addingTimeInterval(240))
        guard case .finished(let end) = state, case .cap(let at) = end else {
            Issue.record("expected cap, got \(state)"); return
        }
        #expect(at == t0.addingTimeInterval(240))
        #expect(!end.isRecovered, "the alarm must not claim recovery it never saw")
    }

    /// A reading that arrives after the cap has passed cannot un-time-out a
    /// rest that already ended.
    @Test func aLateSampleDoesNotRetroactivelyRecover() throws {
        let samples = [sample(140, at: 100), sample(95, at: 300)]
        let state = rule.evaluate(
            samples: samples, start: t0, asOf: t0.addingTimeInterval(310))
        guard case .finished(let end) = state, case .cap = end else {
            Issue.record("expected cap, got \(state)"); return
        }
    }

    @Test func noSamplesAtAllReportsDegraded_notACap() {
        // Past the grace period with nothing reading the user.
        let state = rule.evaluate(samples: [], start: t0, asOf: t0.addingTimeInterval(25))
        #expect(state == .degraded)
        // …and inside the grace period it is simply still resting: a sensor
        // takes a moment to produce its first reading.
        let early = rule.evaluate(samples: [], start: t0, asOf: t0.addingTimeInterval(10))
        #expect(early == .resting(elapsed: 10))
    }

    /// A sensor that dies mid-rest degrades too — the rule cannot rest against
    /// a heart rate nobody is reporting.
    @Test func aSensorThatDiesMidRestDegrades() {
        let state = rule.evaluate(
            samples: [sample(150, at: 5)], start: t0, asOf: t0.addingTimeInterval(90))
        #expect(state == .degraded)
    }

    @Test func degradedOutranksTheCapWhenNothingEverReported() {
        let state = rule.evaluate(samples: [], start: t0, asOf: t0.addingTimeInterval(400))
        #expect(state == .degraded, "the truth is 'no sensor', not 'time is up'")
    }

    // MARK: - Vitals (D44)

    @Test func vitalsAverageAndMaximumComeFromTheSamples() throws {
        let samples = [sample(100, at: 0), sample(120, at: 10), sample(140, at: 20)]
        let vitals = WorkoutVitalsMath.vitals(from: samples, zoningAgainst: nil)
        #expect(vitals.averageBpm == 120)
        #expect(vitals.maxBpm == 140)
        #expect(vitals.sampleCount == 3)
        #expect(vitals.secondsInZone.isEmpty, "no ceiling, no zones (D45)")
    }

    @Test func noSamplesMeansNilRatherThanZero() {
        let vitals = WorkoutVitalsMath.vitals(from: [], zoningAgainst: nil)
        #expect(vitals.isEmpty)
        #expect(vitals.averageBpm == nil, "0 BPM would be a false value, not a missing one")
        #expect(vitals.maxBpm == nil)
    }

    @Test func timeInZoneIsMeasuredBetweenSamples() throws {
        let ceiling = MaxHeartRate(bpm: 180, isEstimated: false)
        // 10s at 150 (zone 4), then 10s at 95 (zone 1), then a final sample.
        let samples = [sample(150, at: 0), sample(95, at: 10), sample(95, at: 20)]
        let vitals = WorkoutVitalsMath.vitals(from: samples, zoningAgainst: ceiling)
        #expect(vitals.secondsInZone[HeartRateZone.four.rawValue] == 10)
        #expect(vitals.secondsInZone[HeartRateZone.one.rawValue] == 10)
        #expect(vitals.totalZonedSeconds == 20, "the stream's own duration, no more")
    }

    /// A five-minute dropout must not donate five minutes to whatever zone the
    /// sensor was in when it died.
    @Test func aLongGapIsAttributedToNoZone() {
        let ceiling = MaxHeartRate(bpm: 180, isEstimated: false)
        let samples = [sample(150, at: 0), sample(150, at: 300)]
        let vitals = WorkoutVitalsMath.vitals(from: samples, zoningAgainst: ceiling)
        #expect(vitals.totalZonedSeconds == 0)
        // The samples themselves still count toward average and max.
        #expect(vitals.averageBpm == 150)
    }

    @Test func duplicateTimestampsContributeNoTime() {
        let ceiling = MaxHeartRate(bpm: 180, isEstimated: false)
        let samples = [sample(150, at: 10), sample(151, at: 10)]
        let vitals = WorkoutVitalsMath.vitals(from: samples, zoningAgainst: ceiling)
        #expect(vitals.totalZonedSeconds == 0)
    }
}
