# 04 — Export, docs, verification

Status: resolved
Blocked by: 03

## Acceptance criteria

- [x] CSV gains `presetID` and `presetName`, **appended** so a reader of the first 27 columns is
      unaffected; JSON entries gain the same two fields and `schemaVersion` moves to **2**.
- [x] Draft entries export their live preset, frozen entries their snapshot — same rule as the
      rest of the entry context.
- [x] D36–D38 recorded; SPEC's taxonomy, history and export sections updated; STATE refreshed.
- [x] Full suite green, re-run independently.
- [x] Codex cross-review (T6) — the matcher is untouched, but records grouping is not, and that is
      the part that silently corrupts history when it is wrong.

## Codex cross-review (2026-08-12)

`codex-review.md` — "do not merge or install over the live store yet". One critical, two high, four
medium, one hard standards violation. All addressed:

- **JSON was not a complete backup of presets** (critical): preset definitions, their order and
  ownership, and every machine's usual preset were absent — only presets that happened to be logged
  against left the phone, as an id and a name. The export now carries an `ExercisePreset` collection
  and `Machine.defaultPresetID`, and an exercise that owns a preset counts as referenced under D28.
- **Two of three previous-performance layers mixed presets**: the record block under each layer was
  scoped correctly, the snapshot row above it was not, so a narrow-grip sheet could headline a
  wide-grip session. There were two similar functions and I fixed one.
- **Switching preset could keep the other preset's prefilled numbers.** Prefill writes into the
  draft row, so the values sat there one tap from being logged as the new variation. Rows now
  record whether their values were *inherited* (`SetRecord.prefilledAt`, cleared by any edit), and
  a context change clears inherited values while leaving typed ones alone.
- **The service accepted a preset from another exercise** — the UI happened never to pass one.
  `choosePreset` now validates ownership, and so does the carry across an equipment change.
- The previous-performance sheet now names the current preset in every layer header, so an empty
  record table says *which* table is empty.
- **Migration was untested against the only store that matters.** `WorkoutTrackerTests/Fixtures/
  LegacyStore.store` is now a store written by `5239ef2` — the build on the user's phone — and
  `LegacyStoreMigrationTests` opens it with the new schema: history intact, preset fields nil, old
  sets still holding their records in the "no preset" group, export still working.
- Standards: the movement-label fallback moved into `Domain/MachineLabelDefaults.swift` with tests;
  `chooseEquipment` and `choosePreset` now share one `split` primitive — the duplication is what
  let the inherited-values rule be written once and missed once.

## Resolution (2026-08-12)

Suite: **329 unit + 13 UI tests**. The UI test drives the whole loop — define two presets on a
seeded exercise, make one a machine's usual, log a set, switch grips mid-workout and get a second
entry rather than a relabelled one, then read the variation back out of history.
