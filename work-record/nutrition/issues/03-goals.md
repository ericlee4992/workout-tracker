# N3 — Goals: calculation, onboarding step, Profile → Nutrition goals

Type: feature
Status: **approved** (the user, 2026-11-09: the calculation below "as proposed")
Blocked by: N2
Implementer: Claude; Reviewer: Codex (visible Orca terminal), to "clear".
Branch (when built): `ericlee4992/nutrition-03-goals` off `main`.
Spec: [nutrition](../spec.md). Decisions: D70.

## Goal

The app suggests daily calories and protein / carbs / fat from the user's body and goal, and the user can change any
number.

## Calculation (approved by the user 2026-11-09, as proposed)

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

## Added 2026-11-09 (D80): Personal details

- **Profile → Settings → Personal details** (new page, top of Settings): weight, height, date of birth, sex — the one
  place these live. The goal calculation reads them (no separate inputs on the goals page beyond activity and goal);
  the heart rate zones read the date of birth from here (today it is entered in the zones sheet — move it, keep the
  value); the AI training profile's height/weight prefill from here. Weight later comes from Body weight (N9).
  Storage is decided in this ticket (stored-format change before R — the guard pin moves again; testers still get
  one update). Strings to the user.
- **Profile → Goals & tracking → Nutrition goals** goes above Heart rate zones (S6 created the group).

## Acceptance

1. Calculation unit tests pass for the examples in the ticket (to be written with the user's numbers).
2. Onboarding: skip and complete paths; Profile edits persist and create a dated goal.
3. Captures at default and AccessibilityL; Onboarding/Tour and Profile UI tests; Codex clear.

## Code map

- New `Domain/NutritionGoals.swift`; `Domain/TrainingProfile.swift` (height/weight); `Features/Onboarding/`;
  Profile (S2).

## Progress

Branch `ericlee4992/nutrition-03-goals` off `main` `6e53446` (S6 merged).

- **Calculation done** — `Domain/NutritionGoals.swift`: `restingEnergy`, `activityFactor`, `goalAdjustment`,
  `calorieFloor`, `calories`, `suggested`, `resolve(_:overrides:)` (typed numbers stay; fat = 25 % of the calories in
  force; carbs the rest, never negative), `age(birthDate:on:)`. `NutritionGoalsTests` (8, hand-worked examples in each
  test's comment): **80/80 over 10 iterations, exit 0** (`n3-goals.xcresult`). Whole kcal and grams.
  **The user (2026-11-09): "Prefer not to say" uses the average floor, 1,350 kcal** (as the formula's average constant).
- **Storage (proposed):** Personal details live in `AppPreferences` (the canonical settings row, which already holds
  `birthDate` for the zones): new optional `heightValue` + `heightUnit` (entered, D52-style) and `sex`; weight is a
  `BodyWeightEntry` (N2), the latest one shown. Additive — the guard pin moves once more before R.
- **Mock shown and approved (the user, 2026-11-09, `1f0ddb4`, captures `n3-caps/sheet-n3-*.png`):** Nutrition goals =
  the calories (hero) over Protein / Carbs / Fat tiles in the macro hues, then "Based on": Activity, Goal, Personal
  details; Personal details = Weight, Height, Date of birth, Sex rows. **Editing: tap a number → a small sheet with
  Save** (the user chose it over always-open fields); a typed number reads "Typed by you" and Recalculate appears.
  **Strings approved:** "Nutrition goals", "cal a day", "Calculated" / "Typed by you", "Based on", "Activity"
  (Sedentary, Light, Moderate, Very active, Extra active), "Goal" (Lose weight, Maintain, Gain weight), "Recalculate",
  "An estimate from your details, not medical advice.", "Personal details" (Weight, Height, Date of birth, Sex — Male,
  Female, Prefer not to say), "Used for your nutrition goals, heart rate zones and AI suggestions."
- **Next — wire it:** storage (above; export carries the new preference fields; guard pin + migration test move);
  Personal details editors (weight writes a `BodyWeightEntry`; height `(value, unit)`; date of birth = the existing
  `AppPreferences.birthDate`, so the zones keep their value — the zones sheet then points to Personal details);
  goals saved as dated `NutritionGoal`s with inputs + override flags; the AI training profile prefills height/weight
  from here; the onboarding "Food goals" step; UI tests + captures; Codex.

**Built (`a449967` … HEAD):**
- **Storage:** `AppPreferences.heightValue/heightUnit/heightCm/sex` (+ `setHeight`), new stored enum `HeightUnit`
  (pinned); guard `approvedFingerprint` → `0a01d115…` (D80 approval noted beside it); export v12 `preferences` carries
  them (v12 is unreleased, so no new version). Weight = the latest `BodyWeightEntry`; date of birth = the existing
  `AppPreferences.birthDate`, **shared with the heart rate zones sheet** (it still edits the same value — one place in
  storage, two ways in; the zones row then shows e.g. 190 bpm from the age).
- **`Domain/NutritionGoalStore`:** details → inputs → resolve → store; same-day changes update today's goal, a later
  change starts a new dated goal; typed numbers stay; nothing stored while details are incomplete or unchanged.
  `NutritionGoalStoreTests` (6).
- **Screens:** `PersonalDetailsView` (+ shared `PersonalDetailsList`: number/height/date editors with Cancel/Save, Sex
  menu), `NutritionGoalsView` (hero calories, macro tiles, tap → `NumberEditorSheet`, Activity/Goal menus
  (`GoalChoiceMenus`), Personal details row with the summary as subtitle, Recalculate), Profile rows show the goal
  ("2,763 cal" / Not set). Choices made before the details are complete are held and applied to the first goal.
- **Onboarding step:** `FoodGoalsSetupSheet` after the Welcome page is answered (Skip, or the tour it started ends),
  once, when there is no goal; Done (edits apply immediately). UI tests opt in with `-uiTestFoodGoalsStep`.
- **Ask AI:** a height/weight the training profile lacks comes from Personal details (marked typed, so a profile save
  stores it); `TrainingProfileTests` +1.
- **Strings beyond the approved list** (for the user at merge): editor titles "Calories" (and the macro names),
  "Done", placeholders "Feet"/"Inches", the error alert "Couldn't save"; "Not set" reused.

**Evidence:** `NutritionGoalsTests` 80/80 ×10; Unit plan **1177/1177**, exit 0 (`n3-unit.xcresult`, before the Ask AI
test; `TrainingProfileTests` 15/15 after it); UI run 1 (`n3-ui1`): NutritionGoals (5) + FloodlightSettings +
FloodlightTour + FloodlightProfile + HeartRate zones — **37/37**; run 2 (`n3-ui2`): NutritionGoals + all 32
`AskAIUITests` — **38/38** (the "known failure" `testEditingGeneratedWeekKeepsRowsAndSavesOnlyOnce` passed); run 3
(`n3-ui3`, onboarding + tour + account + Google): 23/25 — the warm-up's clone `kAXErrorServerNotFound` and the new
onboarding test, which lacked `-uiTestOnboardingFresh` (fixed; then **2/2** serially, `n3-onb.xcresult`). Captures
looked at (`n3-caps2/`, `n3-caps3/`, `n3-caps4/`): Profile, Nutrition goals, the edit sheet, Personal details, the
onboarding sheet empty and filled, light/dark × default/AXL; the goals page's details summary moved under its title
(it wrapped mid-line as a trailing value).

**Codex round 1** ([report](../codex-review-n3.md), not clear: Spec 2 × P2, Standards P2 + P3) — fixed:
1. Edits with incomplete details: `NutritionGoalStore.update(change:)` throws `.detailsIncomplete` instead of dropping
   the edit; a plain refresh (no change) writes nothing; the goals page and the onboarding sheet show no numbers
   without complete details and hold Activity/Goal until they are; the zones sheet's save refreshes the goal.
2. Prefill: `NutritionGoalStore.prefillMissing(from:)` fills a missing height/weight from the training profile, as
   entered, never over a value (`PersonalDetailsList` runs it when the profile loads, also late).
3. Height: the editor edits a stored height in its own unit at full precision; an unchanged Save writes nothing
   (`HeightFields`, unit-tested); the number editor's unchanged Save writes nothing (no duplicate weight entry).
   Feet and inches on separate rows (side by side they misaligned).
4. README: an unreleased "Nutrition goals" entry.
Regressions: `NutritionGoalStoreTests` +2 (refused edit; prefill), `HeightFieldsTests` (3), UI
`testClearingTheBirthDateInTheZonesSheetLeavesNothingToEdit`, the onboarding flow also at dark/AXL with editor
captures (Codex's coverage note). **Evidence:** Unit plan **1183/1183**, exit 0 (`n3-r2-unitplan`); UI (2 workers)
NutritionGoals + HeartRate + warm-up **14/14** (`n3-r2-ui`), then after the two-row height editor and a test-scroll fix
(full swipes down closed the sheet at AXL) NutritionGoals + warm-up **9/9** (`n3-r2-goals`); captures `n3-caps5/`,
`n3-caps6/` looked at.

**First-time goal setup (the user, 2026-11-09: "Both"):** the onboarding "Food goals" step stays in N3 (new
installs: after Welcome, skippable) **and** N5 adds a "Set your goals" invitation in Today's food area when there is
no goal (reaches the existing testers, who never see Welcome again). The onboarding step's screen and strings are
mocked and shown to the user before building.

## Comments
