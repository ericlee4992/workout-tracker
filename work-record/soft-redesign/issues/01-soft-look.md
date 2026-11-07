# S1 — Soft look app-wide

Type: change
Status: **proposed** (2026-11-07) — awaiting the user's approval
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
- **App icon:** unchanged (the dumbbell, D59) unless the user asks.
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

Not started.

## Comments
