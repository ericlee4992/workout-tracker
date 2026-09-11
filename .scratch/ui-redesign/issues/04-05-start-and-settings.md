# 04 + 05 — Start (gear button, resume banner) and the Settings screen

Status: in review — gates green, screenshots sent; Codex round 1 and the full suite pending

Spec: `.scratch/ui-redesign/spec.md` tickets 04 and 05, on the chosen Ink / Amber system.
Two tickets in one branch because the gear button (04) is meaningless without the screen it
opens (05), and the three tests that navigate to Settings must change in the same commit as the
move (spec, "Settings move").

## Where Start already was

Codex's Start-lite (merged with tickets 01 + 02, `84610c9`) already did most of ticket 04: the
gym card (`gymPicker` still on the `Menu`), the full-width `.primary` hero with
`.sensoryFeedback(.workoutStart)`, template cards with up to five `MuscleIcon`s, the
accent-bordered resume card. Left over from the spec: the gear button and the pulsing dot.

## What changed

- `StartWorkoutView.swift`: a `gearshape` toolbar button (`openSettings`, label "Settings")
  pushes `SettingsView` inside the Workout tab's `NavigationStack`. The resume banner's figure
  sits in the same 44 pt accent tile as the gym card's pin, with a pulsing accent dot at its
  corner (`symbolEffect(.pulse)`, accessibility-hidden — the label is unchanged).
- `Features/Settings/SettingsView.swift` (new): a `List` of the SAME two views that used to end
  the Gyms list — `AppSettingsSection`, `ExportSection` — on `Theme.background`, inline title
  "Settings". Every row, id and string is unchanged (`heartRateZonesSettings`, `askAISettings`,
  `dumbbellMoveNote`, `exportSummary`, `exportCSV`, `exportJSON`, …); only the way in moved.
- `GymsView.swift`: loses the two sections.
- Tests: `HeartRateUITests.testZonesAreReachableFromSettings`,
  `AskAIUITests.testAPreselectedPlateNeverOffersAskAI`, `ExportUITests` — Workout tab →
  `openSettings` instead of the Gyms tab. `RedesignScreenshotUITests.test05_settings` captures
  `redesign-05-settings`; `test04_start` (resume banner + gym) already existed.
- `AppSettingsSection` loses its "Settings" header: under a screen titled Settings it read twice.
  `ExportSection` keeps "Export". Stale doc comments in both files, and SPEC.md's "Settings (Gyms
  screen)", now say where Settings lives.
- No new copy beyond "Settings" (the toolbar label and title).

## Acceptance criteria

- Screenshots `04-start` (gym chosen, workout minimised — banner with the dot) and
  `05-settings` reviewed by the user.
- Gates green: `CoreLoopUITests` (setup), `HeartRateUITests`, `MachineDeletionUITests`,
  `AskAIUITests`, `ExportUITests`, `RedesignScreenshotUITests`; unit suite; full UI suite before
  merge; Codex clear.

## Verification (2026-09-10)

Gates on `ui-redesign-05`: `AskAIUITests` 7/7, `CoreLoopUITests` 9/9, `HeartRateUITests` 5/5,
`MachineDeletionUITests` 2/2, `ExportUITests` 1/1, `RedesignScreenshotUITests` test04 + test05 —
26/26; Export + test05 re-run after the header removal, 2/2. Screenshots `screenshots/05/` — sent
to the user. Full suite: see STATE.

## Codex review 0405 — response (2026-09-10)

`codex-review-0405.md`: two P3s, no P1/P2, no runtime regression found; Reduce Motion for the
pulse "unverified".

- **P3, the move and its test rewrites were split across commits** (spec: "same commit"). The
  branch is now ONE commit on top of `main` (`f80b00a`): the move, the three routes, the gear,
  the dot, the docs. The old seven-commit history was force-pushed over on the feature branch
  only; `main` never had it.
- **P3, stale comment** on `test06_gymsAndExercises` ("with Settings below") — fixed.
- **Reduce Motion**: no longer relies on the framework's default — the pulse is
  `symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)` with
  `@Environment(\.accessibilityReduceMotion)`, the same pattern `ProgressRing` and the button
  styles use.
- Full suite on the squashed commit: see the verification below / STATE.
