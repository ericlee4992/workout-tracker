# N3 — Goals: calculation, onboarding step, Profile → Nutrition goals

Type: feature
Status: **proposed** (2026-11-07) — awaiting the user's approval
Blocked by: N2
Implementer: Claude; Reviewer: Codex (visible Orca terminal), to "clear".
Branch (when built): `ericlee4992/nutrition-03-goals` off `main`.
Spec: [nutrition](../spec.md). Decisions: D70.

## Goal

The app suggests daily calories and protein / carbs / fat from the user's body and goal, and the user can change any
number.

## Proposed calculation (confirm with the user at the start)

- **Energy:** Mifflin–St Jeor resting energy from weight, height, age and sex (sex options: Male / Female; a "Prefer
  not to say" uses the average of the two), times an activity factor: Sedentary 1.2 · Light 1.375 · Moderate 1.55 ·
  Very active 1.725 · Extra active 1.9.
- **Goal:** Lose −500 kcal/day (about 0.5 kg a week) · Maintain 0 · Gain +250 kcal/day; never below a floor of
  1,200 kcal (women) / 1,500 kcal (men) without the user typing it.
- **Protein:** 1.8 g per kg of body weight (set for lifting); **fat:** 25 % of calories; **carbs:** the rest.
- Every number is editable; an edited number stays fixed when the inputs change ("Recalculate" restores the
  calculation). A goal change creates a new dated goal (N2), so past days keep their old goal.
- Height and weight prefill from the training profile (ticket 05) when present; weight later from Health (N9).

## Scope

- Domain: the calculation with unit tests (known examples, unit conversions, floors, overrides).
- **Onboarding:** an optional "Food goals" step (skippable; Today works without goals).
- **Profile → Nutrition goals:** inputs, the calculated numbers with edit fields, Recalculate. New strings listed here
  before building.
- A plain line that this is an estimate, not medical advice (wording to approve).

## Acceptance

1. Calculation unit tests pass for the examples in the ticket (to be written with the user's numbers).
2. Onboarding: skip and complete paths; Profile edits persist and create a dated goal.
3. Captures at default and AccessibilityL; Onboarding/Tour and Profile UI tests; Codex clear.

## Code map

- New `Domain/NutritionGoals.swift`; `Domain/TrainingProfile.swift` (height/weight); `Features/Onboarding/`;
  Profile (S2).

## Progress

Not started.

## Comments
