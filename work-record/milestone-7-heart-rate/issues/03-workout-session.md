# 03 — The iPhone workout session and the live heart-rate source

Status: resolved (device verification still owed — see below)
Blocked by: 01, 02

Where HealthKit actually enters the app — behind a protocol, so nothing above it knows.

## What to build

- `HeartRateSourcing` protocol: `start()`, `stop()`, an `AsyncStream<HeartRateSample>`, and a
  current-source property. Three implementations:
  - `HealthKitHeartRateSource` — `HKWorkoutSession` + `HKLiveWorkoutBuilder` +
    `HKLiveWorkoutDataSource` (all `ios(26.0)`), `.traditionalStrengthTraining`, indoor.
  - `FixtureHeartRateSource` — replays a scripted bpm series under `-uiTestHeartRate`, so the
    simulator (which has no heartbeat, no AirPods and no Watch) can drive the whole feature.
  - `PreviewHeartRateSource` — a gentle sine wave for SwiftUI previews.
- Authorization: request read for heart rate + active energy, share for workouts. Requested **on
  first use of the feature**, not at launch — the same rule the notification permission follows.
- Active energy comes from the builder's own accumulation (a "generated type", per WWDC25 322).
  **We never compute calories ourselves**; an invented number is exactly what this app refuses.
- Session lifecycle is tied to the app's own workout: starting a workout starts the session,
  Finish/Cancel ends it. A session that outlives its workout keeps the sensor on and drains the
  battery for nothing.

## Acceptance criteria

- [ ] With authorization denied, the app runs normally and the HR bar says it has no permission —
      no crash, no silent dead UI.
- [ ] Ending the workout ends the session, proven by a test double (the same class of bug the rest
      timer had: correct only because every call site happened to tear down first).
- [ ] The fixture source drives zones, vitals and the rest rule end to end with no HealthKit.
- [ ] Nothing in `Domain/` imports HealthKit; the protocol lives in Domain, the implementation
      does not.
- [x] Active energy shown on screen equals the builder's value, never a locally derived one.

## Resolution (2026-08-22)

`Domain/HeartRateMonitor.swift` (the `HeartRateProviding` protocol, the `@Observable`
`HeartRateMonitor`, and `FixtureHeartRateProvider`) plus `Domain/HealthKitHeartRateProvider.swift`
— the single file in the app that imports HealthKit. Tests:
`WorkoutTrackerTests/HeartRateMonitorTests.swift` (13). Suite: **399 unit tests green**.

Deviation from the ticket, deliberately: the HealthKit implementation lives in `Domain/`, not
outside it. The ticket said otherwise, but `RestTimer.swift` already sets the house pattern — a
system framework (`UserNotifications`) behind an injectable protocol, in `Domain/` — and CLAUDE.md
defines `Domain/` as free of **UI** imports, not of all frameworks. Following the existing shape
beat following my own ticket.

Three decisions worth the next reader's time:

- **Read permission is never probed.** HealthKit deliberately refuses to disclose read denial, so
  `authorizationStatus(for:)` reports "not determined" for a user who granted everything. Treating
  that as denial would blank the feed for a working setup. The only honest signal that reads work
  is a sample arriving — hence `.waitingForSensor` until one does.
- **Sample dates come from the statistic, not from `.now`.** Staleness must be measured against
  when the heart beat, not when the app noticed; using arrival time would make a laggy delivery
  look fresh.
- **A failed session closes the stream.** Otherwise the UI freezes on the last number forever,
  which is the exact failure `refreshLiveness` exists to prevent one layer up.

**Still owed, and not provable here:** every line of `HealthKitHeartRateProvider` is unexercised
by tests — the simulator has no sensor, no AirPods and no Watch. What is proven is that everything
*above* the protocol behaves correctly, including denial, staleness, and a sensor going quiet. The
real check is ticket 05 on the phone with AirPods in, and it belongs on the gym-feedback list
beside the scanner's.
