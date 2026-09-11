# 09 — Empty states, app icon, Live Activity tint, docs

Status: resolved — Codex clear after 3 rounds (codex-review-09, 09b, 09c); unit 707/707; full UI suite 61/61 on `dcb8c8b`; merged to main 2026-09-11

Spec: `.scratch/ui-redesign/spec.md` ticket 09, on the chosen Ink / Amber system. The last
redesign ticket.

## What changed

- **Empty states**: the three remaining plain texts → `EmptyState`, byte-identical strings:
  "No machines yet" in `AddByMachineSheet` and `MachinePickerSheet` (dumbbell), "Nothing
  deleted" in `DeletedMachinesView` (trash). `MachineDeletionUITests` reads both as staticTexts
  — `EmptyState` renders its title as `Text`. Also "No presets yet. Without any, this exercise
  is logged as one thing." in `ExercisePresetsSheet` (same string, `noPresets` kept). No
  `ContentUnavailableView` remains in the app (History, Gyms and the chart went in 06/07).
  **Exception, recorded here**: `PreviousPerformanceSheet`'s five per-layer messages ("No
  completed sets on this machine yet." …) stay plain text — they repeat once per layer inside a
  native sheet, and five illustrations stacked would drown the one snapshot the sheet is for.
  The empty Gyms tab has never had a string; giving it one would be new copy, so it keeps its
  single "Add Gym…" hero.
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

## Codex review 09 — response (2026-09-11)

`codex-review-09.md`: standards clear; two P2s, three P3s.

- **P2, the Live Activity's text followed the host appearance on a fixed ink background.**
  The Lock Screen content now runs `.environment(\.colorScheme, .dark)` (`onInk()`), so
  `.primary` / `.secondary` resolve light whatever the Lock Screen appearance.
- **P2, the sweep missed "No presets yet…"** — now an `EmptyState` (same string, `noPresets`
  kept; `ExercisePresetUITests` reads it). The Previous Performance layer messages are the
  documented exception above.
- **P3, the icon's shaft stopped short of the outer plates** — it runs under every plate now;
  regenerated.
- **P3, SPEC overclaims** — narrowed: the native Forms keep the system look, symbols appear
  "wherever exercises are listed", the AccessibilityL captures are named screen by screen.
- **P3, D54 / STATE** — D54 now says who reviewed what (01/02 Codex-built, Claude-reviewed;
  03–09 the reverse); STATE says 09 is in review, and is finalised only after the gates.
- Gates after the fixes: `MachineDeletionUITests` 2/2, `ExercisePresetUITests` 3/3 (reads
  `noPresets`) — 5/5.

## Codex review 09b — response (2026-09-11)

`codex-review-09b.md`: four of five closed; the P3 on D54 remained — it still said 01–09
"each cross-reviewed to clear" while 09 was in review. D54 now records 01–08 as cleared and 09
as in review on its branch; the row is finalised (one sentence) when 09 merges.

## Codex review 09c — response (2026-09-11)

`codex-review-09c.md`: **clear**. D54 finalised in the merge commit.
