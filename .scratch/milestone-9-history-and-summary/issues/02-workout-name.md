# 02 — Workout name, during and after

Status: resolved — awaiting Codex review
Blocked by: 01
Covers user ask **1**.

## What to build

- `Workout.name: String?` — optional, so every existing store migrates lightweightly. nil means
  "no name typed"; the derived title (`HistoryRendering.title`) stays the fallback everywhere.
- **During a workout:** the screen title is tappable and edits the name in place. Placeholder is the
  derived title so an unnamed workout never reads as blank.
- **In History:** the same edit from the session detail. Because it changes a logged workout it
  sets `historyEditedAt` (D47) like any other history edit — a renamed workout shows the "edited"
  marker.
- Export carries the name (a column in CSV, a field in JSON; D28–D32 shape).
- Starting from a template: the field starts EMPTY with the template's name as placeholder. The
  snapshot `sourceTemplateName` is unchanged — it records provenance, the name records intent.

## Acceptance criteria

- `HistoryRendering.title` prefers a non-empty trimmed `name`, then template, then exercises;
  unit-tested including whitespace-only names.
- `LegacyStoreMigrationTests` opens the fixture with the new field.
- Renaming in History sets `historyEditedAt`; renaming during the workout does not.
- Export tests cover the new field.
- UI tests: rename mid-workout and see it in the History list; rename from History detail and see
  the edited marker.


## Resolution (2026-09-03)

- `Workout.name: String?` — optional, nil = "no name typed". `HistoryRendering.title` takes
  `name:` first (non-blank wins), then template, then exercises; `Workout.derivedTitle` is the
  name-less form, used as the field's placeholder so an empty field never reads as blank.
- **Two rename paths, deliberately different.** `WorkoutSession.rename` (running workout: just
  typing, no mark) and `HistoryEditing.rename` (logged workout: marked `historyEditedAt` per D47,
  and a no-op that changes nothing marks nothing). Both trim; blank clears to nil.
- **Workout screen:** the nav title is now the name (or derived title) and is a principal-item
  button with a pencil (`workoutTitle`); tapping opens a "Workout Name" alert.
- **History detail:** a "Name" row at the top (`historyWorkoutName`) with the same alert; the
  message says renaming marks the workout as edited.
- **Export:** schema v6. JSON gains `workouts[].name` beside `sourceTemplateName` (intent vs
  provenance). CSV gains no column — `workoutName` (column 4) now carries the typed name when
  present, else the template name as before. `.scratch/milestone-3-export/spec.md` updated.
- Template-started workouts: the name starts empty with the template name as placeholder;
  `sourceTemplateName` untouched.

**Tests.** `WorkoutNameTests` (7): precedence, blank fall-through, logged rename marks / same-name
does not / clearing restores derived and still marks, live naming does not mark, export carries the
name and CSV prefers it. `LegacyStoreMigrationTests` gains `workoutNameArrivesNilAndTheTitleStillDerives`
— the fixture opens. Schema-version assertions moved to 6. `WorkoutNameUITests` (2): name mid-workout →
History lists it, unmarked; rename from History → edited mark. **590 unit green; UI: name (2),
core loop (9), history editing (2), export (1) green.** Screenshots `workout-named-live`,
`workout-renamed-history`.

**Not done:** the finish sheet and Live Activity do not show the name — neither showed the
template name before, so nothing regressed; noted so it is a choice, not an oversight.
