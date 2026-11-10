# N5 — Today's food parts

Type: feature
Status: **proposed** (2026-11-07) — awaiting the user's approval
Blocked by: N3, N4
Implementer: Claude; Reviewer: Codex (visible Orca terminal), to "clear".
Branch (when built): `ericlee4992/nutrition-05-today` off `main`.
Spec: [nutrition](../spec.md); design: [ui-evolution](../../ui-evolution/spec.md) rounds 2 and 5. Decisions: D71.

## Goal

Today shows the day's food beside the training (S2).

## Scope

- **Day rings:** each day's ring fills toward that day's calorie goal in protein · carbs · fat colours (real per-entry
  macros, not a fake split); dashed = nothing logged; faint = days ahead; the workout disc stays inside. Key under the
  row: "Calories toward goal · Worked out". Header: "3 workouts · 5 days logged".
- **Fuel card:** "1,048 cal left" as the headline (over goal: "120 cal over"), **Eaten** and **Burned** beside it, one
  bar toward the goal split by the macros' calorie shares; Protein leads with "47 g to go", Carbs and Fat compact.
  Burned = the day's workout calories known to the app now; Health's active energy joins in N9. **Burned never changes
  the goal or "left"** (D71).
- **Today's log:** foods by meal (calories and macros) and the day's workouts with calories burned; tap to edit (N4).
- **Moved here from N4 (the user, 2026-11-10):** edit a logged entry (servings, meal, numbers) and delete it, with
  Undo; Today's totals update after a log / Undo (N4's acceptance 1).
- **Log food pill:** black, above the tab bar, on Today only; opens Log Food (N4). *Built in N4 (the user, 2026-11-10).*
- **No goals yet:** the fuel card asks to set goals (opens N3) and still shows Eaten.
- AX sizes: rings become one row per day ("Pull Day, Indoor Run · 2,140 of 2,288 cal"); the fuel card stacks.

## Added 2026-11-09 (the user, with N3)

- **No goal yet → an invitation, not empty numbers:** Today's food area says "Set your goals" (wording to approve) and
  opens Personal details → Nutrition goals. Existing testers never see the onboarding step (N3), so this is how they
  meet goals.

## Acceptance

1. Totals, left/over and ring fills match the entries and the dated goal (unit tests incl. a goal change mid-week).
2. Burned shown and never added (test).
3. Captures (default / AccessibilityL, light / dark, with and without goals, over goal); Today UI test; Codex clear.

## Code map

- Today (S2); `Domain/WeekSummary.swift`; prototype `Screens/Soft/SoftTodayTop.swift`, `SoftTodayScreen.swift`.

## Progress

Not started.

## Comments
