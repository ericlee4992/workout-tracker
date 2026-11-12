# N13 — Goal setup: current and desired weight, pace, then the nutrition goals

Type: feature
Status: **approved — for 0.2.1** (the user, 2026-11-11; after [P1 workout lag](../../performance/issues/01-workout-lag.md))
Implementer: Claude; Reviewer: Codex (visible Orca terminal), to "clear".
Branch (when built): `ericlee4992/nutrition-13-goal-setup` off `main`.
Spec: [nutrition](../spec.md). Decisions: D70 (goals calculated, every number editable), D80 (Profile), D52 (units).
Builds on: N3 (`Domain/NutritionGoals.swift`: Mifflin–St Jeor × activity, goal adjustment, calorie floor; Personal
details), N9 (body weight), the onboarding welcome (`OnboardingCoordinator`).

## Goal (the user, 2026-11-11)

A more specific goal setting: current weight, desired weight, how much to gain or lose per week — and the nutrition
goals made from those. **Required** on a new install: the app opens straight into it (no skip — the user's choice).
Existing users run it from Nutrition goals.

## Reference

The user's screenshots of another app (local only, never committed or sent to another model: `~/Downloads/IMG_5912`
… `IMG_5919.PNG`): workouts per week (0–2 / 3–5 / 6+), height & weight with an Imperial/Metric switch and wheel
pickers, goal (lose / maintain / gain), desired weight on a ruler, pace (slow / recommended / fast, kg a week, "you
should reach your goal in …", the daily calorie goal), "your plan is ready" (gain N kg by <date>; calories, carbs,
protein, fat — each editable), an Edit nutrition goals page and a Profile row "Goals & current weight". Stacked's
version is its own design in the Soft look (`ios-design` skill) — the steps and ideas, not a copy of those screens.

## Scope (to be shaped with the user from a prototype first — UI-first)

- **Steps** (draft): sex (incl. "Prefer not to say") and date of birth (the user: ask them in the flow) → height and
  current weight (units as entered, D52) → workouts per week (sets the activity level) → goal (lose / maintain /
  gain) → desired weight (not for maintain) → pace per week (slow / recommended / fast with bounds; time to the
  desired weight and the daily calories shown live) → the plan (calories, protein, carbs, fat; each editable) → done.
- **First launch:** a new install opens into it, before anything else; it cannot be skipped. Where the welcome and
  the guided tour go relative to it: decide with the prototype.
- **Existing users:** Profile → Nutrition goals runs the same flow prefilled from Personal details, the latest body
  weight and the current goal; finishing makes a new dated goal (D70: past days keep theirs).
- **Calculation:** today's energy (N3) ± the pace (≈ 7,700 kcal per kg ÷ 7 a day), never below the floor; protein
  for lifting (N3); pace bounds and the "recommended" pace to be set with care (safe rates), stated in the ticket.
- **Data (a stored-format change):** the desired weight `(value, unit, normalizedKg)` and the weekly pace on the
  goal; current weight saved as a body-weight entry (N9; to Apple Health when that is on). Migration + safety copy
  (N1) + `StoreFormatGuardTests`; export/import (D28) carry the new fields; Gate S before the user's phone installs it.

## Acceptance

1. The user approves the flow from a tappable Simulator prototype (light/dark, AccessibilityL).
2. Unit tests: the pace math, bounds, floors, units, time to goal; migration from 0.2.0's store; export round trip.
3. UI tests: a new install is taken into the flow and cannot leave it unfinished; an existing user's run from
   Nutrition goals; edits on the plan step; captures.
4. Codex clear; shipped in 0.2.1 with P1.

## Progress

Not started (after P1).

## Comments
