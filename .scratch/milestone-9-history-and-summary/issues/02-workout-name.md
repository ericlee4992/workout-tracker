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


## Codex review 02 — response (2026-09-03)

`codex-review-02.md`: 3 high, 2 medium, 2 low. All acted on; two of the highs were real defects.

- **History rename never saved (high).** True — every neighbouring edit calls the view's `save()`
  and this one relied on autosave. Fixed; `aHistoryRenameIsOnDiskAfterSave` reopens the store from
  disk in a fresh container and finds both the name and the mark.
- **CSV column 4 silently changed meaning and dropped provenance (high).** True, and my source
  comment claiming the meaning was "unchanged" was false. Column 4 is `sourceTemplateName` again;
  the typed name is the appended column 36 `workoutTypedName`. Header test, spec table (which had
  also been missing column 35) and the v6 note corrected.
- **D47 drifted from rather than reopened (high).** Correct. **D50** now records the reopening and
  the reasoning — a name is authored, not captured; nothing downstream reads it — and D47 carries
  a pointer.
- **Lifecycle not enforced (medium ×2).** `WorkoutSession.rename` refuses a finished workout;
  `HistoryEditing.rename` refuses a running one. Both refusals tested.
- **Duplicated normalization (low).** `Workout.normalizedName` is the one definition.
- **JSON only partially proved (low).** A named workout round-trips; a v5-shaped payload with no
  `name` key decodes with nil.
