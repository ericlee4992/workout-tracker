# Claude independent review 03 — sensor sample rows, stray-finish fold, control pinning

Reviewer: Claude (T6; Codex implemented). Date: 2026-09-18.
Range: `d0bcb54..03ada3d` ("Persist sensor samples incrementally and keep cardio controls
reachable"), fetched from `origin/ericlee4992/cardio-implementation` and reviewed in the
isolated checkout. No product source altered; no build, test or simulator run by me.

Inputs read: the full source diff, `WorkoutSensorSample.swift` in full, the live capture path
it must agree with (`HeartRateMonitor.summarySamples`, `WorkoutSummaryBuilder.capture`), both
changed test files, the UI-test diff, ADR 0002, the ticket's new exception lines, and the
author's `unit-7` artifacts (read only).

## Verdict

| Gate | State |
|---|---|
| N1 (checkpoint write volume) | **Resolved** |
| N2 (stray finish keeps checkpoint, no summary) | **Resolved** |
| New regressions in this range | **None blocking**; three Low notes (R1–R3) |
| **Code review of `03ada3d`** | **CLEAR** — no open High or Medium code finding from reviews 01–03 |
| Debug build | `build-10-exit.txt` = `0` (author's log) |
| Unit suite | **Verified**: `unit-7.xcresult` Passed, 748/748, 0 failed, 0 skipped; exit `0` |
| Targeted unit-8 and full UI suite (79) | **RUNNING** under PID 59715 per author; not assessed |
| Visual review | **NOT CLEAR** until recaptures are graded (`claude-visual-01.md` items A1–A3, V1, V6) |
| Merge clearance | **NOT GIVEN** — needs the full UI suite result and the visual pass |
| Real-device acceptance | **OUTSTANDING** — AirPods treadmill distance and background GPS; Watch cardio not claimed |

Code clearance here means the source is acceptable to take through the remaining gates. It is
not merge clearance and says nothing about hardware behaviour.

## N1 — resolved

Heartbeats are now individual `WorkoutSensorSample` rows inserted once each
(`CardioRecorder.swift:159-167`); the growing blob, its codec and `sensorSamplesData` are gone.
Each save carries the new rows plus a handful of scalars, so cost is linear in samples. The
model is CloudKit-compatible (UUID id, defaults, optional inverse, cascade from `Workout`,
`Models.swift:362-365`) and registered in the schema. After relaunch the restored samples are
already rows and `checkpointSampleCount` starts at the restored count
(`CardioRecorder.swift:74`), so nothing is inserted twice.

The probe (`SensorCheckpointWriteTests`) runs against a disk store: 3600 rows, 3600 inserting
saves, about 1 MB retained, versus roughly 642 MB of repeated payload under the old shape.
The ticket correctly labels this a write-shape measurement, not a NAND or battery measurement.
One save per second remains; that is the pre-existing checkpoint cadence and is acceptable.

## N2 — resolved

`finishInPlace` now calls `captureSensorCheckpoint` on every saved finish
(`WorkoutSession.swift:180`), so strays finished without a coordinator get their summary and
lose their transient rows (`strayFinishFoldsSavedSamplesAndClearsCheckpointRows`).

I checked the consequence for the **normal** finish, where the coordinator has already captured
from the live monitor before `finish` runs: the domain path repeats the same algorithm on the
same data (bound to the workout, pick the dominant source, `WorkoutVitalsMath.summarySamples`,
same max-HR basis via the new `sensorMaxHeartRate*` scalars), and `cardio.stop()` flushes all
monitor samples to rows before either capture. The second capture is therefore idempotent. It
cannot blank a good summary: energy falls back to the existing value, and
`WorkoutSummaryBuilder.capture` leaves series and vitals untouched when samples are empty. The
post-stop finalisation task still writes the final energy afterwards. `discardedEmpty` and
cancel delete the workout and cascade the rows.

## Other changes in the range — checked

- Pause/End moved to a bottom safe-area inset (`CardioControls`), stacked at accessibility
  sizes; identifiers unchanged. Add buttons stack at accessibility sizes.
- Sensor pace line hidden while an entered distance is in force (`CardioViews.swift:115`).
- Location authorisation and failure callbacks now respect `collectsDeviceSensors` and the
  running-outdoor guard, so fixtures no longer show "Location unavailable".
- Idle configuration hides the lifting heart-rate bar (`ActiveWorkoutView.swift:118`), closing N4.
- Route stroke uses the `AccentColor` asset by name; the colour set exists in the catalog.
- `onPhaseFinished` retention is now documented in `stop()` (N6). ADR 0002 records that schema
  10 has never been installed or exported (N5). Ticket records N3, V3 and V4 as Low exceptions.

## Low notes (not blocking)

- **R1** — `ActiveWorkoutView.swift:186-188`: in Cardio focus the inset shows the cardio
  controls *instead of* the rest bar. A rest started from Lifting focus while a segment is
  unfinished keeps running and still alarms, but is invisible until the user switches back.
  Acceptable for now; record it or show a compact rest indicator.
- **R2** — a finished one-hour workout deletes about 3600 rows in the finish save. Fine in the
  probe's scale; note it if finish latency is ever reported on the phone.
- **R3** — F6 (whole-route JSON re-encode per fix) and F8 (seconds-long lifting phases saved to
  Health when explicitly started) remain open by the author's own note; both are Low and
  belong in the ticket's known-limits list through merge.

## Limitations

Static review only. The full UI suite and targeted unit-8 were still running and are not
covered. No captures from `03ada3d` exist yet. Nothing here is evidence of AirPods indoor
distance delivery, HealthKit statistics timing on iPhone, or background GPS continuation.

## Remaining before merge clearance

1. Full local UI suite result on frozen `03ada3d`, with actual exit code and counts.
2. New default and AccessibilityL captures, graded against `claude-visual-01.md`.
3. Ticket and STATE updated with those results; device acceptance stays listed as outstanding.
