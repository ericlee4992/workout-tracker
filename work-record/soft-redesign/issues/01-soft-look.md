# S1 — Soft look app-wide

Type: change
Status: **review clear** (Codex round 1, 2026-11-07) — merge waits for the deferred Phase 1 test run (the user, 2026-11-07)
Blocked by: —
Implementer: Claude; Reviewer: Codex (visible Orca terminal), to "clear".
Branch (when built): `ericlee4992/soft-01-look` off `main`.
Spec: [soft-redesign](../spec.md). Decisions: D67 (reopens D59's look).

## Goal

Every screen of the real app takes the approved Soft look — type, colour, cards, buttons, rings and charts — in light
and dark, without changing what any screen does or where anything is. Navigation is S2's job.

## Scope

- **Tokens and components** in `WorkoutTracker/Features/Design/Look/`: port the prototype's `SoftLook.swift` values
  (grounds, card surface and shadow, hairline in dark, text levels, Mono action, radii, type scale in SF Pro) and
  restyle the shared components (`Buttons`, `Surfaces`, `Lists`, `NativeLists`, `Stats`, `Rings`, `Charts`,
  `WeekWidget`, `HomePieces`, `LivePieces`, `Glyphs`). Remove Floodlight's SF Pro Expanded and violet once nothing
  uses them; keep the muscle-family palette and figures.
- **Screens restyled** (structure unchanged): Workout tab and template detail/editor, live lifting workout (set table
  skin only), cardio live and picker, finish sheet, History list/detail/calendar/edit sheets, Exercises, Gyms, Progress,
  Settings and its sheets, Account/Profile, sign-in, onboarding (welcome, tour), What's New, Scan Machine, Ask AI.
- **App icon:** the dumbbell in Mono (the user, 2026-11-07: "for icon make a mono version").
- The Live Activity / widget: colours follow the new tokens where they read from them; no layout change.

## Acceptance

1. Every screen listed above renders in the Soft look in light and dark; no Floodlight violet or Expanded type left
   (search the code for the old tokens).
2. The live set table's columns, controls and behaviour are unchanged (existing CoreLoop / Live UI tests pass).
3. Default and AccessibilityL captures, light and dark, of each restyled screen, shown to the user; contrast of text
   and the Mono action measured on both grounds (≥ 4.5:1 body text, ≥ 3:1 large text and controls).
4. Screenshot/capture UI suites (`Floodlight*UITests`, `RedesignScreenshotUITests`, `CodexScreenshotUITests`) updated
   or renamed so they capture the new look; no assertion silently deleted.
5. `xcodebuild build` succeeds; no stored-format change (`StoreFormatGuardTests` pass unchanged).
6. Codex clear.

## Verification scope

Broad visual change across shared components → build, unit tests that cover view formatting, the capture suites
above, and the core-flow UI classes (CoreLoop, Cardio, History edit, Templates, Settings). Not the full UI suite
(that runs once at the release, ticket R).

## Code map

- `WorkoutTracker/Features/Design/Look/*.swift` (tokens: `FinalLook.swift`, `Look.swift`, `LookSupport.swift`).
- Prototype: `design/soft-approved-2026-11-07:DesignPrototype/Sources/Look/SoftLook.swift` and `Look/Components/`.

## Open

- Whether the Workout tab's "This week" card is restyled here or replaced by S2's Today rings (proposal: restyle only;
  S2 moves it).

## Progress

- **2026-11-07 — implemented on `ericlee4992/soft-01-look`** (checkpoint `75460c2`): Soft tokens (`Look.softDark`
  in Look.swift, `Look.softLight` in FinalLook.swift, replacing `Look.floodlight` / `floodlightLight`), `LookFonts.soft`
  (SF Pro only; `LookFonts.floodlight` and the Expanded face removed), lifted cards and the warm ground wash
  (`liftedCards`, `groundWash` in Surfaces.swift), the live workout in Soft with a flat Mono action (`Look.live`; the
  ink rest slab's ring and Skip use `liveOnSlab`), 39 inline Expanded fonts → SF Pro semibold/bold, the Live
  Activity palette and fonts, AccentColor, and the Mono app icon. The structural id stays `.floodlight` (the layout
  family Soft keeps). Prototype greys failed contrast and were deepened (D67).
- **Verified so far:** `xcodebuild build` succeeded; unit tests `SoftLookContrastTests`, `MuscleMapAssetTests`,
  `StoreFormatGuardTests` **10/10 passed** (xcresult summary); `RedesignScreenshotUITests` test04_start,
  test02_activeWorkoutAndFinish, test05_history, test06_gymsAndExercises **4/4 passed**, captures checked (dark).
- **Deferred by the user (2026-11-07):** "Can we run the test after building more?" — the capture suites and the
  core-flow UI classes (Verification scope above) run once after more of Phase 1 is built, covering S1 and the
  following tickets together. S1 is not merged into `main` before that run and Codex's clear.
- **Codex round 1: clear** ([codex-review-s1.md](../codex-review-s1.md)): 0 findings; its own build (exit 0) and the
  three unit suites (10/10) on WT-iPhone27. Non-blocking, to do in the deferred run: check tertiary text over the
  warm wash in light captures (worst case ≈ 4.44:1 at the wash's peak); `SoftLookContrastTests` helper should
  composite alpha and assert colour resolution if it ever measures translucent pairs.
- Still open before merge: the deferred run (captures light/dark, default/AccessibilityL, incl. live rest/Skip and
  new-best states, native sheets/menus/toggles, the activity gallery; core-flow UI classes listed in the review).

## Comments
