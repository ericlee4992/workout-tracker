# 07 — Gyms: gym cards, machine cards, deleted machines

Status: in review — gates green, screenshots sent; Codex round 1 and the full suite pending

Spec: `.scratch/ui-redesign/spec.md` ticket 07, on the chosen Ink / Amber system.

## What changed

- `GymsView.swift` (list): gym rows → cards — the pin tile the Start screen uses for the
  chosen gym, name (`cardTitle`), city, a machine-count `Chip` (dumbbell + count; accessibility
  label "N machines"), the unit badge or "app default". The row is a `Button` that appends to a
  `path` on the `NavigationStack` (same reason as History: a `List` draws a `NavigationLink`'s
  chevron outside the label); `gymRow.<name>` stays on the row; the `navigationDestination` is
  unchanged. "Add Gym…" is `.primary` when there are no gyms (the one thing to do), `.secondary`
  beside gyms. List on `Theme.background`.
- `GymDetailView`: the unit/city/Edit rows on `Theme.card`; machine rows → cards (an accent
  dumbbell tile, the label in `cardTitle`, the model as a `Chip` or the "No model" caption, the
  unit badge); swipe-delete and the context menu unchanged (`machineRow.<label>`,
  `deleteMachine.<label>`); section headers as `label` uppercase ("Machines" / A–Z / groups);
  "No machines yet" → `EmptyState`; "Add Machine…" `.primary`; "Deleted machines (N)" stays a
  `NavigationLink`, on `Theme.card`; the footer unchanged.
- `MachineDeletion.swift` (`DeletedMachinesView`): cards with a `.secondary` Restore
  (`restoreMachine.<label>`); "Nothing deleted" kept.
- `ModelPickerView`: "New Model…" `.secondary`. The gym/machine editors are stock Forms and the
  scan sheet is untouched: its black/white shutter controls sit on a camera preview, not on the
  theme, and every string and id it carries is read by the scan/Ask-AI tests.
- **Both cards are accessibility containers** (`.accessibilityElement(children: .contain)`
  before the id). Without it the id on a bare container propagates to the FIRST child — the
  40 pt tile — and `MachineDeletionUITests`' swipe on that tile was too short to reveal Delete
  (the first gate run failed exactly there). The children stay reachable, so
  `staticTexts["Life Fitness…"]` still resolves for the scan test.
- No new copy.

## Acceptance criteria

- Screenshots `06-gyms`, `06-gym-detail`, `08-empty-gyms`, `07-delete-machine-confirmation`
  reviewed by the user.
- Gates green: `MachineDeletionUITests`, `ScanMachineLabelUITests`, `AskAIUITests`,
  `DumbbellCounterpartUITests`; unit suite; full UI suite before merge; Codex clear.

## Verification (2026-09-11)

Gates on `ui-redesign-07`: `AskAIUITests` 7/7, `ScanMachineLabelUITests` 2/2,
`DumbbellCounterpartUITests` 1/1, `RedesignScreenshotUITests` test06 + test08 (first run, 13/14 —
the MachineDeletion swipe, see above); after the container fix `MachineDeletionUITests` 2/2,
`DumbbellCounterpartUITests` 1/1, test06 recaptured — 4/4. Screenshots `screenshots/07/` — sent
to the user. Full suite: see STATE.
