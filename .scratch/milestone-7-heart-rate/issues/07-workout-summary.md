# 07 — The finish summary

Status: resolved
Blocked by: 01, 03

Replaces `WorkoutFinishedSheet` with the screen the user asked for: Apple's shape, plus what only
this app knows.

## What to build

Header (date, gym, duration) and a stat grid: workout time, active calories, total volume (D21),
average HR, max HR, time in zones. Then **Exercises** — every entry with its equipment, set count,
and best set, including the bar for a bar-mode set (D39).

- Everything HR-shaped is omitted, not zeroed, when no session ran. A workout logged without a
  sensor shows volume and exercises and says nothing about heart rate — `0 BPM` is a lie.
- A1/A2 unchanged: a workout with nothing logged is still discarded and still says so, instead of
  showing a summary of nothing.
- The summary's numbers are **persisted on `Workout`** at finish (avg/max HR, active energy, time
  in zones), so History renders from the app's own store rather than re-querying HealthKit for a
  six-month-old workout. Same reasoning as D23: what History shows must not change because a
  source later changed its mind.

## Acceptance criteria

- [ ] Exercises list matches what was logged, in workout order, with per-entry best sets.
- [ ] Volume agrees with `RecordsMath` to the last decimal — two numbers for one fact is how they
      drift.
- [ ] A no-sensor workout renders with no HR rows at all (not zeros), asserted.
- [ ] Schema change → `LegacyStoreMigrationTests` opens the current fixture and the new fields
      read nil. **Regenerate the fixture from the installed commit first** (STATE gotcha).
- [ ] Export (D28–D32): the new persisted fields either export with a schemaVersion bump, or the
      ticket states in writing why they do not. A backup that silently omits them is not a backup.
- [ ] XCUITest drives Finish under `-uiTestHeartRate` and asserts the summary; screenshot attached.


## Resolution (2026-08-22)

`Domain/WorkoutSummary.swift` (the value type + builder + `capture`), the stats and exercises
sections on `WorkoutFinishedSheet`, and four new persisted fields on `Workout`.
Tests: `WorkoutSummaryTests` (8), `heartRateFieldsArriveEmptyOnPreHeartRateData` in the migration
suite, and a UI test that drives Finish under the fixture. **418 unit tests green.**

Decisions worth carrying forward:

- **The export carries it, at schemaVersion 4.** D30 says nothing is silently dropped, so the JSON
  gains the whole summary and the CSV gains three workout-level columns (31 → 34), repeated per
  set row the way `workoutNotes` already is. `zoneSeconds` is JSON-only and the spec says why: it
  is an array, and a flat ledger of sets has nowhere honest to put one.
- **Absent, never zero.** Every heart-rate value is optional at every layer — model, summary,
  export — and a workout logged without a sensor renders no heart-rate rows at all. Two tests
  exist purely to keep `0 BPM` from ever appearing.
- **Volume comes from `RecordsMath`**, asserted equal to the last decimal. Two numbers for one
  fact is how they drift, and this screen's would be the one the user believes.
- **The best set excludes warmups** (D12/D26) and names its bar (D39), so the summary cannot
  disagree with the PR tables.

The UI test cost two rounds of the same lesson from ticket 05: an identifier on a SwiftUI
container is not queryable, *and* a `List` is lazy — the Exercises section genuinely does not
exist until scrolled into view, so the test swipes before asserting. The heart-rate rows are
above the fold and need no scroll.
