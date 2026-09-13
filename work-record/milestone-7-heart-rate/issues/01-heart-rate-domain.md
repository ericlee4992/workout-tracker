# 01 — Heart-rate domain core: zones, max HR, the rest rule, summary math

Status: resolved
Blocked by: —

Pure logic, `Foundation` only. No HealthKit, no UI, no SwiftData, no new targets — so this ticket
builds and proves itself today, on a Mac with no heartbeat anywhere near it. Every rule that can
be *wrong* in this milestone lives here.

## Files

- `WorkoutTracker/Domain/HeartRate.swift` — sample value type, source kind, staleness
- `WorkoutTracker/Domain/HeartRateZones.swift` — max-HR resolution + zone boundaries
- `WorkoutTracker/Domain/HeartRateRest.swift` — D43's rest rule as a pure state machine
- `WorkoutTracker/Domain/WorkoutVitals.swift` — running aggregate: avg, max, time-in-zone
- `WorkoutTrackerTests/HeartRateTests.swift`

## What to build

**`HeartRateSample`** — `bpm: Int`, `date: Date`, `source: HeartRateSource`
(`.airPods` / `.watch` / `.otherMonitor` / `.fixture`). A sample knows where it came from,
because the screen has to say.

**Staleness.** `isStale(asOf:tolerance:)` — a sample older than the tolerance (default 15s) is
not a current heart rate. A frozen 138 while the real rate is 90 is worse than showing nothing,
so the caller must be able to tell.

**`MaxHeartRate.resolve(measured:birthDate:asOf:)`** → `(bpm: Int, isEstimated: Bool)`.
A measured value wins. Otherwise `220 − age`, flagged `isEstimated: true` (D45). No birth date
and no measured value → nil, and zones are simply not shown; inventing an age is not an option.

**`HeartRateZones`** — 5 zones at 50/60/70/80/90/100% of max, `zone(for:max:)` → 1…5 (below 50%
is zone 0 = "warm"). Boundaries are inclusive-low, exclusive-high, so a bpm exactly on a boundary
lands in exactly one zone.

**`HeartRateRestRule`** (D43) — given a threshold bpm, a cap in seconds, a start date, and a
stream of samples, decide: `.resting`, `.finished(reason: .recovered)`, `.finished(reason: .cap)`,
or `.degraded` (no live source). Pure: it takes samples in and returns a state, so a test can
drive an entire rest from a literal array.

**`WorkoutVitals`** — folds samples into `averageBpm`, `maxBpm`, `secondsInZone: [Int: Int]`.
Time in a zone is the time *between* samples attributed to the zone of the earlier sample, so a
gap in the stream does not silently inflate a zone.

## Acceptance criteria

- [ ] A measured max wins over the formula; the formula's result is always `isEstimated == true`;
      neither present → nil rather than a guess.
- [ ] `220 − age` uses completed years at the workout's date, not at "now" — a workout exported
      later must not re-age the athlete.
- [ ] Zone boundaries: with max 180, 90 bpm is zone 1 and 89 is zone 0; 180 is zone 5, not zone 6;
      every bpm from 0…250 maps to exactly one zone.
- [ ] Rest rule: a stream that crosses the threshold finishes `.recovered`; a stream that never
      does finishes `.cap` at exactly the cap; a stream with no samples at all reports
      `.degraded`. **The cap and the threshold are distinguishable in the result** — "you
      recovered" and "time is up" are different facts and the notification says which.
- [ ] A sample arriving *after* the cap has passed does not retroactively report `.recovered`.
- [ ] Staleness: a 20-second-old sample is stale at the default tolerance, a 5-second-old one is
      not, and the boundary case is specified rather than accidental.
- [ ] Vitals: average is over samples' own values; time-in-zone across a 60-sample stream sums to
      the stream's own duration, and a 5-minute gap in samples does not add 5 minutes to any zone.
- [ ] Source precedence: given both a Watch and an AirPods sample for the same instant, the Watch
      one is selected, and the selection is a pure function a test can call directly.
- [x] Every file imports `Foundation` only.

## Resolution (2026-08-22)

`Domain/HeartRate.swift`, `HeartRateZones.swift`, `HeartRateRest.swift`, `WorkoutVitals.swift`
+ `WorkoutTrackerTests/HeartRateTests.swift` (24 tests). Full unit suite: **386 green**.

Four rules were sharper than the ticket anticipated, and each is stated where it can be broken:

- **Precedence applies within what is live, not globally.** A Watch that stopped reporting a
  minute ago must not outrank AirPods reporting now, or the screen freezes on a dead sensor while
  a working one sits ignored. `current(asOf:)` filters to fresh samples *first*, then ranks.
- **`degraded` outranks `cap`.** With nothing ever reporting, the truth is "no sensor", not "time
  is up" — and the two lead to different user actions.
- **A grace period before degrading** (20s, longer than the 15s staleness tolerance), so the
  ordinary pause before a sensor's first reading never reads as a dead sensor.
- **Zone ceiling ≠ observed maximum.** `WorkoutVitals` carries both; conflating them would put
  every set in zone 5.

Also settled deliberately rather than by accident: staleness begins *after* the tolerance, and
recovery is *strictly* below the threshold (110 does not end a "below 110" rest). Both are the
kind of boundary that otherwise gets read two ways by two call sites.

Not done here, and deliberately: the "no HealthKit import in Domain/" assertion. A test that
greps source files is a lint, not a test, and this repo has no lint step to hang it on — the
constraint is instead enforced by ticket 03 putting the implementation outside `Domain/`.
