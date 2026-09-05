# Milestone 9 — name it, find it, see it

Six asks from the user, 2026-09-03, after the milestone-8 install had been in gym use for a week.

## What was asked, verbatim

1. "Be able to change workout name after starting workout"
2. "For exercises nothing shows under 'previous' next to set number even though it has history"
3. "In history, after clicking a session, add a button that when you click it shows chart for that
   exercise"
4. "For exercises that can alternate between barbell and dumbbell, they should save as separate
   exercises (e.g. bench press, incline bench press, and anything else you can think of)"
5. "Add calendar button in history section that when you click you can see when you completed
   workouts." (screenshot: a month grid in a sheet, green check on workout days)
6. "At the end of workout show things like graph (like apple fitness)." (screenshot: Apple
   Fitness workout detail — time, active/total calories, avg HR, effort, HR-over-time bar chart)

## What investigation found before any ticket was written

**Ask 2 was withdrawn by the user** ("it actually works") after the mechanism was explained: the
PREVIOUS column fills only from the strictest match — same exercise, same machine or free-weight
tag, same preset, same set type, same ordinal. Looser matches live in the Previous Performance
sheet. No ticket.

**Ask 1 is "add a name", not "change one".** `Workout` has no name field. The title is derived by
`HistoryRendering.title`: the snapshot template name if any, else "Bench Press +2" from the
snapshot exercises. A user-typed name is a new optional field — a schema change against the
user's real store — and the user wants it editable in History too, which puts it under D47's
"edited" marker.

**Ask 4 is three things, one of them a bug that exists whatever is decided.**
- Records and prefill ALREADY split barbell from dumbbell: `RecordGroupKey.freeWeight` keys a
  machineless set on `(exercise, freeWeightTag)` (D7, D23), and `layerOneMatch` compares the tag.
- The CHART does not. `ProgressVariationKey` is `(loadType, presetID)` and ignores the tag, so a
  dumbbell bench and a barbell bench draw as ONE line — the same pooling class as the D36 defect
  fixed in `3ad382d`, one axis over.
- The catalog barely knows dumbbells exist: 76 exercises, 8 tagged barbell, ONE tagged dumbbell
  (Dumbbell Curl), none tagged both. So today a dumbbell bench is "Bench Press" with Dumbbell chosen
  in the equipment sheet — which the user HAS done, so real history sits under barbell-named
  exercises with a dumbbell tag.
The user chose separate exercises ("go with your way"): seed dumbbell movements as their own
catalog rows, fix the chart so the tag counts regardless, and MOVE the existing dumbbell-tagged
history to the new exercises — deliberately, as a migration, because D23 forbids reinterpreting a
snapshot in place.

**Ask 6 has a data problem before it has a UI problem.** `Workout` persists only aggregates —
`averageHeartRate`, `maxHeartRate`, `activeEnergyKilocalories`, `zoneSeconds`. There is no
per-sample heart-rate series, so an Apple-Fitness-style HR-over-time graph cannot be drawn from the
store, for the workout just finished or for any past one. The monitor holds the samples in memory
during a session (zone time is computed from them); the change is to persist a downsampled copy
per workout. The finish sheet already shows time, volume, calories, avg/max HR and time in zones.
The user wants: the graph at finish AND in History detail; total calories (active + resting); NO
effort rating.

**Ask 5 is self-contained.** Tap a marked day → jump to that session.

## Order, and why

1. **01 — chart per equipment, and a chart button in History.** A real bug in the same class as
   the fix shipped this morning, and the smallest item. The History button is in the same file.
2. **02 — workout name.** Small, but a schema change: the `LegacyStore` gate must open.
3. **03 — History calendar.** Self-contained.
4. **04 — dumbbell exercises.** Catalog additions plus a one-time history move. Touches the
   user's only copy of their training history — export first.
5. **05 — finish summary with heart-rate graph.** Largest; a second schema change and monitor
   plumbing.

02, 04 and 05 all change what is on the user's phone's store. Batch installs; take an export before
the first.

## Process, as the user set it

Each ticket is built on this branch, then **Codex cross-reviews it (T6) before the next ticket
starts**. Reviews go in `codex-review-NN.md` beside this file; every critical is fixed and
regression-tested before moving on.

## Shipped

Merged to `main` 2026-09-04 (`97b656b`, fast-forward) and installed the same day. Six tickets, all
Codex-clear (01: 4 rounds, 02: 4, 03: 3, 04: 4, 05: 6, 06: 4). The reclassification moved **18 sets**
on the real store; the export taken just before it is in iCloud Drive.
