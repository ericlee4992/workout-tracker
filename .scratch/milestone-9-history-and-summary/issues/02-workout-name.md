# 02 — Workout name, during and after

Status: ready-for-agent
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
