# 01 — Design system + root: dark, one warm accent, cards

Status: built 2026-09-10 with ticket 02 on `ui-redesign-01` (1db593c) — screenshots captured; gates running; Codex review pending

Spec: `work-record/ui-redesign/spec.md` (the approved plan). This ticket adds the tokens and
components every later screen ticket uses, forces dark at the window, swaps the teal accent for
coral, and captures the "before" screenshots. No screen changes layout yet.

## Outcome (2026-09-10) — Codex's design chosen

Two designs were built to this ticket's spec, by Claude ("Coral", branch `ui-redesign-01`) and by
Codex ("Ink / Amber", branch `ericlee4992/ui-redesign-codex`), and put side by side on the board
https://claude.ai/code/artifact/8d3aa889-2a2b-44ae-8d37-7620377bd3f9. **The user chose Codex's.**
Branch `ui-redesign` continues from Codex's commit `b008e5c` with: the docs from Claude's branch
(D54 rewritten for amber, STATE, CLAUDE.md iOS 26), the fifteen-screen review surface
`RedesignScreenshotUITests`, the board's config/scripts/screenshots, and two fixes from Claude's
review of Codex's code (below). Claude's branch is retired.

### The implementation (Codex's report: `work-record/ui-redesign/codex-design-report.md`)

`Features/Design/`: `Theme.swift` (amber `#FFB45E` accent via `AccentColor`, `OnAccent`,
four blue-graphite surfaces, text trio, danger/warmup/drop, unit tints; radii 24/16/10; spacing
4/8/12/16/24; `hero` largeTitle rounded black, `stat` title2 rounded bold, `cardTitle`, `label`),
`MuscleGroupStyle` (14 groups + fallback, `MuscleIcon` 40 pt), `CardStyle` (`.card()` /
`.card(.elevated)`), `Chip` + `UnitChip` (the unit badge's only child is `Text(unit.rawValue)`),
`StatTile`, `ProgressRing` (reduced-motion aware), `ButtonStyles` (`.primary` / `.secondary`),
`EmptyState`, `Haptics`. Dark forced at the window root; 15 colour sets. `ThemeTests` proves every
catalog group has a style whose symbol resolves.

### Claude's cross-review of Codex's code (T6: the non-author reviews)

- **Fixed — the header ring's count chip overlapped the tick** (`.overlay(.bottom).offset(y: 14)`
  over a 68 pt ring; visible on the board). Now a `VStack`: 56 pt ring, chip beneath.
- **Fixed — the swipe-delete button used raw `Color.red`** → `Theme.danger`.
- Noted, not changed: Triceps and Biceps share `dumbbell.fill` (colour tells them apart); the bpm
  number is rendered in `Danger` red (a choice, consistent with the heart glyph); `import UIKit`
  in `ActiveWorkoutView` for the keyboard notifications is fine in `Features/`.
- Verified by reading: swipe mechanics (88 pt, threshold 14, opaque row, `setRow.previous` a
  single `Text`), `List` + `.onMove` + clear row backgrounds, every identifier and string, the
  bar-mode `= 135 lb` caption inside the unified input, presets under the sets, D26/D13 rest
  rules untouched (`RestTimerBar` keeps its API; the expiry haptic fires from the screen via a
  counter so a dismissed dock cannot lose it), no new `Text("…")` copy beyond numbers.

## Acceptance criteria (as met)

- Every screen dark with the amber accent; the workout screen and Start restyled (02, 04-lite).
- `screenshots/before`, `claude`, `codex` committed; the user compared and chose.
- Codex's run: 699 unit + the 21 gate UI tests + its 3 screenshot tests green. On `ui-redesign`
  after the two fixes: build green; full UI suite run before merge (result in STATE).
