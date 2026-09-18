# Claude independent review 02 — cardio review fixes and sensor checkpoints

Reviewer: Claude (T6; Codex implemented). Date: 2026-09-18.
Range: `b359d7c..d0bcb54` ("Fix cardio source handoffs, recovery, and editing semantics"),
fetched and reviewed in the isolated checkout `review-cardio-implementation`. No product source
altered, no build, test, simulator or install run by me. Author artifacts under
`cardio-implementation/work-record/ui-redesign/results/cardio/` were read only.

Inputs read: the full diff, `Cardio.swift` and `CardioRecorder.swift` in full at `d0bcb54`,
`SensorCheckpointCodec.swift`, `CardioRouteFixture.swift`, the provider/coordinator/monitor/
HealthKit diffs, every view diff, the export diffs, all new and changed tests, the spec/ticket/
STATE diffs, `frozen-d0bcb54.sh`, and review 01 for the finding numbering.

## Verdict

| Gate | State |
|---|---|
| F1–F4 from review 01 | **Resolved in code** with regression tests (details below) |
| New checkpoint / lifecycle paths | **One Medium (N1) and one Medium (N2)**; rest Low |
| Code clearance for merge | **NOT YET** — N1 needs a fix or a measured decision; N2 needs a fix or an explicit deferral recorded in the ticket |
| Debug build | `build-6-exit.txt` = `0` in `/tmp/wt-cardio-final-derived` (author's log; not rebuilt by me) |
| Unit suite on frozen source | **Verified**: `unit-6.xcresult` Passed, 747/747, 0 failed, 0 skipped; exit file `0` |
| Focused UI (`CardioUITests`, 7 methods) | **RUNNING** (`focused-ui-5`, xcodebuild PID 47769): 5 passed so far; the two outdoor route captures had not finished when this file was written |
| Visual review (default + AccessibilityL) | **PENDING** — no captures graded |
| Full local UI suite | **NOT RUN** |
| Real-device acceptance | **OUTSTANDING** — AirPods treadmill distance, background GPS; Watch cardio not claimed |

No author clearance is claimed or accepted.

## Review-01 findings, verified against `d0bcb54`

**F1 (High) — resolved.** Spans are now keyed by a sensor-collection *epoch* that survives
pauses (`Cardio.swift:45-67`, `CardioRecorder.swift:27, 147, 237`). Phone motion is rebased
on every resume (`phoneBaseline`, `:150, :261`) so it is cumulative over the same epoch as
HealthKit; `acceptDistance` keeps one reading per source per epoch, `selectSource` picks one,
and `recomputeDistance` sums only epochs (`:166-195`). A late HealthKit total therefore
replaces, never adds to, the phone total (`CardioRecorderTests.swift:30-57`). Relaunch starts a
new epoch because the HealthKit session is new; old epochs keep their logged source
(`refreshDistanceSelection` touches only the current epoch, `:179-188`). Correct.

**F2 (Medium) — resolved.** Cumulative readings are accepted at any age ≥ epoch; the 15 s
window now applies only to speed (`CardioRecorder.swift:192-194`) and to source *preference*
(`selectSource`), and a quiet stream keeps its total (`Cardio.swift:61-65`;
`CardioRecorderTests.swift:59-74`). The live view leads with average pace and shows current
pace only when fresh (`CardioViews.swift:104-121`); spec updated accordingly.

**F3 (Medium) — resolved.** The recorder holds the workout strongly until `stop()`
(`CardioRecorder.swift:19, 339`); a same-workout re-attach no longer resets counters
(`:69-77`), covered by `gpsKeepsGrowingAcrossReattachAndDoesNotJoinPauseOrOutageGaps`.

**F4 (Medium) — resolved.** Editor opens blank unless a manual value exists, Save is disabled
until text or unit changes, the unit picker no longer rewrites the number, and the measured
value is shown as context (`CardioViews.swift:238-275`); `enterDistance` marks history
edited only on a real change (`Cardio.swift:308-311`). UI test added.

**F5 resolved** (`onPhaseFinished` banks final segment energy on top of a per-segment baseline,
`CardioRecorder.swift:84-92`, test `endingPhaseBanksFinalSegmentEnergy`). **F7 resolved**
(`endAny` pauses and ends through the normal path). **F9 resolved** (`ActiveWorkoutView:346`).
**F10 resolved** (motion error message, `CardioRecorder.swift:249`). **F12 resolved** (single
alert string). **F6 and F8 remain open by author's note**; see N1 for why F6 got larger.
**F11** partly closed: HR dedupe/pause/stale/future test and stray auto-finish test added.

## New findings on the checkpoint and lifecycle paths

### N1 (Medium) — every workout now rewrites a growing heart-rate blob on every sample tick

- `CardioRecorder.swift:157-177` — `refresh()` appends new samples to an in-memory JSON-lines
  buffer and assigns the **whole buffer** to `workout.sensorSamplesData`, then `persist()`
  saves. It runs on every HR sample (coordinator `:92`), every 2 s timer tick (`:94`) and every
  HealthKit statistics callback (`:80`).
- `WorkoutHeartRateCoordinator.swift:102` — `cardio.attach` is called for **every** workout,
  so this applies to lifting-only sessions, not just cardio.

The append is cheap in memory, but SwiftData rewrites the entire blob column each save. At one
sample per second the blob is ~110 bytes per sample; over a one-hour session that is ~400 KB
rewritten ~3600 times (~0.7 GB of cumulative writes), and a two-hour session roughly four times
that. That is new battery and storage-wear cost on the user's actual training sessions, with no
correctness benefit beyond a few seconds of relaunch fidelity. Required before install: either
throttle the blob write (e.g. flush when ≥15–30 s or ≥N samples have accumulated, plus on
pause/end/stop, which already call `refresh()`), or store samples as append-only rows, and
record a measurement (energy log or write counters) in the ticket. Segment aggregates and
`lastCheckpointAt` can keep the 2 s cadence; they are small scalars.

### N2 (Medium) — a workout finished as a "stray" keeps its checkpoint forever and never gets a summary from it

- `WorkoutSession.swift:71-74, 88-98` — `startWorkout` and `resumableWorkout` finish strays
  through `finishInPlace` with no coordinator involvement.
- `WorkoutHeartRateCoordinator.swift:113-114` — `end()` returns early unless the coordinator is
  already tracking that workout; after a relaunch it tracks nothing until the user resumes.
- `WorkoutHeartRateCoordinator.swift:156-165` — checkpoints are cleared only on that path.

Scenario: app killed mid-workout, relaunch, user taps Start Lifting/Start Cardio and chooses
"Finish it and start new". The old workout's `sensorSamplesData` and energy checkpoints survive
on the finished record (and are exported as `sensorCheckpoint`) but no HR summary/series is
built from them, so History shows no heart rate for a session whose samples are sitting in the
store. Before this commit those samples were simply lost, so this is not a regression, but the
feature's stated purpose is "resume without replacing earlier data". Recommended: in
`finishInPlace` (domain, no sensors needed) fold a present checkpoint into the summary via
`WorkoutSummaryBuilder.capture` when no summary exists, then clear the three checkpoint fields;
add a unit test for the stray path. If deferred, record it in the ticket and STATE as a known
gap and keep the export of `sensorCheckpoint` so the data is not lost.

### N3 (Low) — a phase that starts while the request changes never reports `onPhaseFinished`

`WorkoutActivityProvider.swift:113-119` stops a just-started provider without setting
`applied`; the queued transition then finds `applied == nil` and skips `onPhaseFinished`
(`:96-98`). Its energy is banked into the workout total but not the segment. Only reachable
when the user switches activity within HealthKit start latency. Note in the ticket.

### N4 (Low) — `.idle` shows "waiting for sensor" with nothing collecting

`WorkoutActivityProvider.swift:105-109` reports `.waitingForSensor` for the idle configuration
that deliberately starts no session (cardio-only workout after End Cardio). The lifting-side HR
card will say it is waiting while no sensor is running until an exercise is added and
`entries.count` triggers `sync()` (`ActiveWorkoutView:363`). Consider a distinct feed state or
hide the card while idle. Judge on captures.

### N5 (Low) — export shape changed inside schema 10 without a bump

`ExportSnapshot.swift` adds `updatedAt`/`selectedSource` to distance spans and a
`sensorCheckpoint` block while `currentSchemaVersion` stays 10. Acceptable only because v10 has
never been installed or exported by a real build; say so in the export spec/ticket so nobody
later treats two v10 shapes as one.

### N6 (Low) — `onPhaseFinished` is not cleared in `stop()`

`CardioRecorder.swift:337-338` clears `onCardioMetrics` and `onPhaseStarted` but leaves
`onPhaseFinished` on the provider. Intended so the final energy lands after finish; the closure
holds the workout weakly and guards `isDeleted`, so it is safe. Document the intent in a comment
or clear it explicitly after the final phase to keep the pattern symmetric.

### N7 (Low) — route fixture seeds a *running* segment after recovery has run

`CardioRouteFixture.seed` inserts a segment whose `activeStartedAt` is five minutes in the
past, after `WorkoutTrackerStore` recovery already ran, so the captured screen shows five
minutes of "active" time nobody observed. Fixture-only (`-uiTestCardioRoute` requires
`-uiTestReset`) and it exists for captures, so no product effect; the ticket must keep stating
these captures are synthetic, as the file comment does.

## Lifecycle paths I traced and found correct

- **Pause → resume on the same segment** keeps one HealthKit provider (fast path), fires
  `onPhaseStarted` on unpause so the pedometer restarts from the resume time within the same
  epoch (`WorkoutActivityProvider.swift:89-93`, `CardioRecorder.swift:232-254`).
- **Relaunch with a running segment**: container recovery pauses it at the last checkpoint;
  `sensorConfiguration` yields `paused: true`; the provider starts **no** HealthKit session for
  a paused or idle configuration (`:105-109`, test `pausedRecoveryAndIdleDoNotStartPhantomWorkouts`);
  on resume a new session, epoch and energy phase begin, with the segment's stored energy as
  the baseline and the workout's banked energy restored from the checkpoint
  (`SensorCheckpointTests.swift:20-55`).
- **Latest-request generation** (`CardioRecorder.swift:131-138`) plus the provider's chained
  transition means a queued pause cannot override a later resume (test at
  `CardioRecorderTests.swift:43-46`).
- **Cross-workout teardown barrier**: the new monitor's `start()` awaits the previous
  finalisation task (`WorkoutHeartRateCoordinator.swift:105-111, 147-149`), so two HealthKit
  sessions cannot overlap across "Finish it and start new"; `configure` calls issued before
  `start()` only update `desired`, which `start()` then applies.
- **Finish/cancel**: `cardio.stop()` checkpoints first; the finalisation task clears the
  checkpoint fields once `finishedAt` is set and keeps them for an unfinished replacement;
  `.discardedEmpty` and cancel are guarded by `isDeleted`.
- **HR scoping**: `currentHeartRate` and `segment.record` only accept samples inside the
  current active interval, non-stale, not in the future, deduplicated (tests in
  `CardioTests.swift:163-178`, `CardioRecorderTests.swift:148-162`).
- **Codec**: JSON lines append without re-encoding, decode tolerates the earlier array format,
  round-trip test present. `HeartRateSample` is now `Codable` with four fields; no schema
  concern.
- **Schema**: three optional scalars added to `Workout`; additive and CloudKit-safe; the
  pre-cardio and legacy migration tests are in the green 747.
- **GPS**: pause and >20 s outages break portions and add no straight-line distance; a
  reattach keeps growing (test).
- **Watch**: still excluded from cardio phases; nothing in this diff claims Watch cardio.

## Limitations

- Static review; unit results verified from `unit-6.xcresult`, build from the exit file.
- `focused-ui-5` was still running (5/7 passed) when this was written; its final result and
  the outdoor captures are not assessed here.
- Nothing here establishes real AirPods indoor distance delivery, HealthKit statistics timing on
  iPhone, or background GPS continuation; those remain the device acceptance gates the ticket
  already names.
- N1's write volume is an estimate from the code path and the fixture's 1 Hz cadence; real
  AirPods cadence may be lower. Measure rather than argue.

## Required before code clearance

1. N1: throttle or restructure the sample-blob checkpoint, or record a measured decision.
2. N2: fold stray-finish checkpoints into the summary, or record the deferral explicitly.
3. Attach the finished `focused-ui-5` result and captures for the visual pass; then the full
   local UI suite.
