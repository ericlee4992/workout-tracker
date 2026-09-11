# 09 — Empty states, app icon, Live Activity tint, docs

Status: in review — gates green; Codex round 1 and the full suite pending

Spec: `.scratch/ui-redesign/spec.md` ticket 09, on the chosen Ink / Amber system. The last
redesign ticket.

## What changed

- **Empty states**: the three remaining plain texts → `EmptyState`, byte-identical strings:
  "No machines yet" in `AddByMachineSheet` and `MachinePickerSheet` (dumbbell), "Nothing
  deleted" in `DeletedMachinesView` (trash). `MachineDeletionUITests` reads both as staticTexts
  — `EmptyState` renders its title as `Text`. No `ContentUnavailableView` remains in the app
  (History, Gyms and the chart went in 06/07). The empty Gyms tab has never had a string; giving
  it one would be new copy, so it keeps its single "Add Gym…" hero.
- **App icon**: `scripts/render-app-icon.py` (PIL) draws a 1024² ink `#0A0A0C` tile with an
  amber dumbbell (a bar in the deeper amber, two plates a side) → committed as
  `Assets.xcassets/AppIcon.appiconset/AppIcon.png` with `"filename"` in `Contents.json`; run the
  script to regenerate. **Deviation from the plan**: amber, not the plan's coral — D54 is
  amber (the user chose Ink / Amber). iOS masks the corners; the tile is opaque.
- **Live Activity** (`WorkoutTrackerWidget/WorkoutActivityView.swift`): the widget target has
  no asset catalog, so `ActivityTheme` carries two literals — background `#0B0D10`
  (`SurfaceBackground`) for `activityBackgroundTint`, accent `#FFB45E` for the gym label, the
  system-action colour and the compact/minimal figure. The heart stays red (it is the heart-rate
  colour everywhere). **Deviation**: the plan's `#1A1A1E` / `#FF7A3D` were the coral system's.
- **Docs**: SPEC.md gets a "Visual design" paragraph; D54 is marked final; STATE.

## Acceptance criteria

- Screenshots `08-empty-history`, `08-empty-gyms`, `01-root` (test08) reviewed by the user; the
  icon PNG reviewed by the user (the simulator's home screen is not captured by XCUITest).
- Gates green: `MachineDeletionUITests` (both empty texts), `CoreLoopUITests`; unit suite; full
  UI suite before merge; Codex clear.

## Verification (2026-09-11)

Gates on `ui-redesign-09`: `MachineDeletionUITests` 2/2 (both empty texts read),
`CoreLoopUITests` 9/9, `test08_emptyStates` — 12/12. Screenshots `screenshots/09/`; the icon
PNG sent to the user. Full suite: see STATE.
