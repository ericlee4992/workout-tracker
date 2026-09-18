# Claude independent review — cardio implementation (code pass)

Reviewer: Claude (T6; Codex implemented). Date: 2026-09-18.
Range: `14982e7..b359d7c` ("Implement cardio segments and activity-focused workout recording"),
reviewed in the isolated checkout `review-cardio-implementation` at `b359d7c`. No product
source altered, no build, test, simulator or install run by me. Author artifacts in the
implementation worktree were read only.

Inputs read: AGENTS.md, STATE.md, `work-record/cardio/spec.md`, `issues/01-implementation.md`,
`research/01-indoor-distance-and-pace.md`, `CONTEXT.md`, ADR 0001, the SPEC/DECISIONS (D15,
D41, D52) hunks, `ios-design/REVIEW.md`, the full diff, every reachable caller of the new
types (`rg` over `WorkoutTracker/`), the new and changed tests, the built simulator
`Info.plist` under `/tmp/wt-cardio-derived`, and the SDK `HKWorkoutSession.h`.

User authorization in scope: direction B; optional devices with manual fallback; indoor
distance and pace on supported connected devices (AirPods Pro 3 named); outdoor runs/rides
with GPS; one mixed History workout; either activity may start or be added mid-workout.

## Verdict

| Gate | State |
|---|---|
| Code / contract review of `b359d7c` | **NOT CLEAR** — one High (F1), three Medium (F2–F4) |
| Unit suite | **Verified**: `unit-3.xcresult` reads Passed, 734/734, 0 failed, 0 skipped (`xcresulttool`, read-only) |
| Debug build | `build-3-exit.txt` = `0` (author's log; not rebuilt by me) |
| Focused UI run (`CardioUITests`, 4 tests) | **FAILED** at `b359d7c`: `focused-ui-1.log` ends `Executed 4 tests, with 4 failures`, `** TEST FAILED **`, exit file `65`, finished 01:03 EDT. PID 31080 has exited. The ticket's "running" sentence is stale |
| Author's follow-up | Uncommitted working-tree changes in the implementation checkout (`ActiveWorkoutView.swift`, `CardioViews.swift`, `CardioUITests.swift`); `distance-repro`/`distance-fix` runs still red at 01:06/01:09. Not part of this review's range |
| Visual review (default + AccessibilityL) | **PENDING** — no captures exist yet |
| Full local UI suite | **NOT RUN** |
| Merge clearance | **NOT GIVEN** |

The author's mid-review note (HealthKit cumulative totals span pauses while the pedometer
restarts each resume, so late HealthKit arrival overlaps prior phone-motion spans) matches F1
below. No author clearance is claimed or accepted; the re-review must cover the fix.

## Findings

Severity: High = wrong or lost user data / broken recording; Medium = spec contract violated
or a credible data-integrity risk that needs a fix or a device verification before merge;
Low = should be fixed or recorded, not blocking.

### F1 (High) — HealthKit distance can double-count a prior phone-motion span after a pause

- `WorkoutTracker/Domain/Cardio.swift:155-166` — `acceptDistance` stores one reading per source
  per *span* (a span starts at each `activeStartedAt`) and sums the per-span selected values.
- `WorkoutTracker/Domain/CardioRecorder.swift:101` — on resume `healthKitBaseline` is the HealthKit
  reading *reported so far*, not the distance HealthKit *covers* up to the pause.
- `WorkoutTracker/Domain/CardioRecorder.swift:116-119` — every later HealthKit reading is accepted
  as `reading − baseline` into the current span.

Scenario: indoor run, span 1 collects 500 m from the pedometer while HealthKit is silent. Pause,
resume (baseline = 0 because `cardioReading` is nil). HealthKit then delivers a cumulative
800 m covering both spans. Span 2 becomes HealthKit 800 m, span 1 stays phone-motion 500 m,
`automaticDistanceMeters` = 1300 m and the source label reads "Mixed distance sources". The
inflated figure is displayed, used for average pace, persisted and exported. This violates the
spec's "overlapping estimates are never added".

Same mechanism in the other direction: if HealthKit had reported 300 m at resume (baseline 300)
but the pedometer had 500 m in span 1, span 1 keeps 300 m (HealthKit > 0 wins), which is
consistent, but the true total then depends on delivery timing rather than measurement.

Expected fix shape (author's plan is compatible): key alternatives by sensor-session epoch
rather than by resume span, keep each source's own timestamps, choose one source per epoch
without adding, and let a late HealthKit total replace phone-motion totals it covers instead of
sitting beside them. Add a unit test for "phone-motion span, pause, resume, late HealthKit
cumulative" asserting the total is max-of-alternatives, not a sum.

### F2 (Medium) — cumulative HealthKit distance is discarded when its statistics are older than 15 s

- `WorkoutTracker/Domain/CardioRecorder.swift:117` — `now.timeIntervalSince(reading.date) <= 15`
  gates acceptance of the *cumulative* distance.
- `WorkoutTracker/Domain/HealthKitHeartRateProvider.swift:196-200` — `reading.date` is
  `statistics.endDate`, i.e. the end of the last collected sample, not the delivery time.

A cumulative total is not perishable: if the AirPods/phone distance stream is delivered in
batches, or the builder's `endDate` trails wall-clock, the app shows "—" for distance while
HealthKit holds a valid total, and the real-device treadmill acceptance would fail for a code
reason rather than a hardware one. The research note's rule is "a stale/missing stream should
show unavailable pace while retaining distance". Accept any reading with `date >= span start`
(monotonic within the source) and apply the 15 s freshness window only to `updateSpeed`, which
already resets on gaps (`:136-139`). Note this must be fixed together with F1 because both
touch the same acceptance path.

### F3 (Medium) — live sensor state hangs off weak `Workout` references; a re-attach in the same span silently drops GPS distance

- `WorkoutTracker/Domain/CardioRecorder.swift:16` — `private weak var workout`.
- `WorkoutTracker/Domain/WorkoutHeartRateCoordinator.swift:30` — `private weak var currentWorkout`.
- `WorkoutTracker/App/RootView.swift:65` — `onMinimize: { activeWorkout = nil }` drops the
  root's only strong reference when the user minimises the workout.
- `WorkoutTracker/Domain/CardioRecorder.swift:44-49, 97-104` — when `attach` sees a nil or
  different `workout`, it stops sensors and re-observes the segment with `gpsMeters = 0`.
- `WorkoutTracker/Domain/Cardio.swift:160` — `readings[source] = max(existing, meters)`.

Consequences if the model instance is released while minimised (I could not establish from the
code whether SwiftData's context or `StartWorkoutView`'s `@Query` keeps it alive on every tab):
`refresh()` returns early (no checkpoints, no segment HR/energy), `accept()` drops every GPS
fix, and on the next re-attach the local `gpsMeters` restarts at 0 inside the same span, so the
`max()` keeps the old value and *every subsequent metre is discarded* until the new counter
exceeds it. Recovery on relaunch is not affected (new span). Required before merge: either a
device/simulator check (start outdoor run → minimise → switch to History → lock → return) with
the route still growing, or a fix: hold the segment's `PersistentIdentifier` and re-fetch, keep
a strong reference only while a segment is unfinished, and seed `gpsMeters` from the stored gps
reading when re-observing an unchanged span.

### F4 (Medium) — distance sheet turns a measurement into an "Entered distance" on an unedited Save, and rewrites the typed value when the unit changes

- `WorkoutTracker/Features/Cardio/CardioViews.swift:249-252` — `onAppear` prefills the field
  with the *measured* distance; `:241-246` Save calls `enterDistance`, which stores it as manual.
- `WorkoutTracker/Domain/Cardio.swift:145-150` — a manual value replaces the displayed automatic
  distance and relabels the source "Entered distance".
- `WorkoutTracker/Features/Cardio/CardioViews.swift:225-230` — the unit picker converts the text
  the user typed (`5` km → `3.1068559611866697` mi).

Opening the sheet to look and tapping Save freezes a live, still-growing GPS/HealthKit distance
at that instant and relabels it as entered; the automatic evidence is retained (spec-correct)
but the display and export provenance now say the user typed it. The conversion violates the
spec's "Manual distance retains entered value/unit" and the D52 spirit of never silently
rewriting an entered value. Suggest: empty field with the measured value as placeholder/context,
Save disabled until edited, and no numeric rewrite on unit change. The UI test at
`CardioUITests.swift:37-40` exists only to delete the prefilled text, which is a tell.

### F5 (Low) — segment calories miss the final end-of-collection statistic

`CardioRecorder.refresh():114-115` copies `phaseActiveEnergy` before the provider stops;
`HealthKitHeartRateProvider.stop():139-141` publishes the final energy after `endCollection`.
The whole-workout total is corrected by the post-stop task
(`WorkoutHeartRateCoordinator.swift:139-148`); the segment's `activeEnergyKilocalories` is not.
Small under-report on End Cardio/Finish; record or fix.

### F6 (Low) — persistence churn and O(n²) route handling

`refresh()` writes `lastCheckpointAt` and saves on every HR sample (~1/s, coordinator `:92`)
and every 2 s (`CardioRecorder.swift:55`). `segment.route.append` (`:217`) decodes and re-encodes
the whole route JSON per accepted fix, and `CardioLiveView` decodes it again per render
(`CardioViews.swift:122`). No correctness defect found; battery/IO cost over an hour-long
outdoor run is unmeasured. Consider checkpointing every 5–10 s and appending to an in-memory
route buffer flushed periodically.

### F7 (Low) — `WorkoutHeartRateCoordinator.endAny()` does not stop the cardio recorder

`WorkoutHeartRateCoordinator.swift:228-236`. No caller in `WorkoutTracker/` today (the
`endAny` at `ActiveWorkoutView.swift:444` is the Live Activity controller), so latent only.

### F8 (Low) — every lifting phase, however short, is saved to Health as a strength workout

Consecutive sessions mean Start Lifting → Add Cardio within seconds, or End Cardio → Finish,
each write a seconds-long `traditionalStrengthTraining` `HKWorkout`
(`HealthKitHeartRateProvider.stop():131-142`). Pre-existing behaviour extended by the new
phase model; note it in the ticket as a capability-honesty consequence for the Health app.

### F9 (Low) — resumed mixed workout reopens on Cardio focus

`ActiveWorkoutView.swift:341` sets `cardioFocus = !workout.orderedCardio.isEmpty`, so a
workout whose cardio already ended reopens on the Cardio segment view. The author's
uncommitted diff adds a lifting-side banner; judge on captures.

### F10 (Low) — pedometer failures are silent

`CardioRecorder.swift:155` ignores `error` from `startUpdates`; a motion-denied user sees
"No distance source" with no reason, unlike the location messages at `:171-183`.

### F11 (Low) — test gaps

No unit test covers `CardioSegment.record` (dedupe, staleness, pause exclusion), the stray
auto-finish path (`WorkoutSession.startWorkout` ending another workout's running segment), CSV
`activeSeconds` for an unfinished segment, or `historyStatsLine`. `CardioRecorder` and the
HealthKit provider are untested by design (sensor code); that is a hardware-acceptance gap, not
a unit-test one, and must stay labelled as such.

### F12 (Low, UI pass) — two `Text` views in one alert message

`HistoryView.swift:147-150` and `WorkoutDetailView.swift:356` add a second `Text` to the delete
alert message. Confirm on a capture that both lines render; otherwise merge into one string.

## Verified correct against the spec

- Schema additive and CloudKit-compatible: `CardioSegment` has UUID id, defaults on every stored
  property, optional `workout`; `Workout.cardioSegments` optional with cascade
  (`Models.swift:362-363`). Current pre-cardio fixture and legacy fixture both migrate
  (`CardioTests.swift:144-162`, existing `LegacyStoreMigrationTests`, all green in `unit-3`).
- Finish keeps a cardio-only workout, ends and deletes unrecorded segments, never invents sets
  or volume; cancel cascades (`WorkoutSession.swift:169-178`, tests `:14-27`, `:96-105`).
- Sequential activity-specific HealthKit sessions: `WorkoutActivityProvider` serialises
  transitions through a chained task, banks energy once per finished phase, never overlaps
  providers (tests assert peak live = 1), and forwards one HR stream across phases so
  whole-workout HR history survives focus switches. Watch provider is excluded from cardio
  phases (`HeartRateMonitor.swift:272-281`), matching the strength-only companion protocol.
- Pause/resume: intervals recorded, spans rebased per resume, paused time excluded from
  active time and pace (`CardioTests.swift:29-43`). HealthKit session pause/resume reconciled on
  state change; `pause`/`resume` are iOS 17+ in the installed SDK header.
- Relaunch recovery pauses a running segment at its last checkpoint on container creation
  (`Models.swift:854-857`, `CardioTests.swift:120-142`); checkpoints are written every sample/2 s
  while alive, so at most ~2 s of dead time is ever claimed.
- Rest timer and queued alarm cleared when cardio starts (`Cardio.swift:234`,
  `ActiveWorkoutView.swift:288-289`).
- GPS: When-In-Use requested on use; denied/reduced accuracy messaged; fixes filtered to
  ≤50 m accuracy and ≤15 s age; a >20 s gap starts a new route portion and adds no distance;
  implausible speeds rejected (`CardioRecorder.swift:197-223`, `Cardio.swift:94-99`). The built
  simulator `Info.plist` contains `UIBackgroundModes` = audio, workout-processing, location and
  both new usage strings.
- Capability honesty: distance is accepted only from actual builder statistics, pedometer
  data or GPS fixes; nothing is derived from HR; missing metrics render "—" or are omitted;
  sources are labelled (`Cardio.swift:33-43`, `CardioViews.swift:102-113`).
- Export: schema 10; CSV keeps the 37 original columns and appends 14, strength rows tagged
  `strength`, cardio rows carry automatic metres, source, entered value/unit and active seconds;
  JSON carries intervals, spans with per-source readings and route points and round-trips
  (`CardioExportTests.swift`). History delete cascades segments and names the loss.
- Cardio-only workouts cannot be saved as templates (`WorkoutTemplates.swift:175-178`, test).

## Limitations of this review

- Static review only; I did not build, run tests or the simulator (author was using them).
  Unit and build results were verified from the author's `unit-3.xcresult` and exit files.
- No screenshots exist; items 1–12 of the design checklist are not yet graded.
- Real-device behaviour is unverified and cannot be verified from this checkout: AirPods Pro 3
  indoor distance delivery and cadence, `statistics.endDate` semantics on iPhone, background
  GPS continuation with the screen locked, and the F3 object-lifetime question.
- The author's working-tree fixes were not reviewed; re-review the committed follow-up.

## Required before re-review

1. Fix F1 and F2 together with a unit test for late cumulative arrival across a pause.
2. Resolve F3 by fix or by a recorded device/simulator check.
3. Fix F4 (or record a user decision accepting the prefill behaviour).
4. Commit the focused-UI fixes, rerun the four `CardioUITests`, attach default and
   AccessibilityL captures, then the full local UI suite; record counts and exit codes.
