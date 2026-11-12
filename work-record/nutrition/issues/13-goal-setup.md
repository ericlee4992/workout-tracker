# N13 — Goal setup: current and desired weight, pace, then the nutrition goals

Type: feature
Status: **approved — for 0.2.1** (the user, 2026-11-11; after [P1 workout lag](../../performance/issues/01-workout-lag.md))
Implementer: Claude; Reviewer: Codex (a Paseo Codex agent), to "clear".
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
- **Calculation — on the phone only (the user, 2026-11-11: option A; AI-generated goals considered and declined):**
  no server, no sign-in, works offline, same inputs give the same plan; sex, age and weights stay on the phone (the
  data rules and the privacy page unchanged). Today's energy (N3) ± the pace (≈ 7,700 kcal per kg ÷ 7 a day), never below the floor; protein
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

### 2026-11-12 — prototype (UI-first), waiting for the user's choices

Branch `ericlee4992/nutrition-13-goal-setup` off `main` `e6255e85`. Built in the app itself (not the separate
DesignPrototype project), so the approved screens become the real ones:

- `Domain/GoalPlan.swift` — the pace math (real, to be unit-tested): paces, the floor, calories at a pace, time to
  the desired weight, the desired-weight range, workouts a week → activity.
- `Features/GoalSetup/GoalSetupDraft.swift` (the answers in memory), `GoalSetupFlow.swift` (the pages).
- `Features/GoalSetup/GoalSetupPrototype.swift` — **PROTOTYPE, throwaway**: sample answers, saves nothing, an orange
  switcher for the welcome/tour order (A/B/C) and new install vs existing user. Run: launch with
  `-uiTestReset -goalSetupPrototype` (`-goalSetupPrototypeStep N` starts at page N; `-goalSetupPrototypeCapture` hides
  the switcher; `-goalSetupPrototypeOrder B`, `-goalSetupPrototypeExisting`). Hooked in `WorkoutTrackerApp` with one
  `.goalSetupPrototype()` line. Removed after the user picks.
- Build: `xcodebuild build` (simulator, WT-iPhone27) exit 0. No tests yet (prototype).
- Captures: `work-record/nutrition/captures/13-prototype/` — contact sheets `a-*` (welcome A + pages 1–5) and `b-*`
  (pages 6–9), light/dark × default/AccessibilityL; single pages in `steps/`.

**The flow (pages):** sex → date of birth (wheel, "N years old") → height (wheel: cm, or ft + in) and weight (the
figure with − / +; Metric/Imperial switch) → workouts a week → goal → desired weight (− / +, "−5 kg from now") → pace
(slider + Slow / Recommended / Fast, then "Goal reached <date> · in N weeks" and "Daily calories") → the plan
("Lose 5 kg by Feb 20, 2027"; calories hero + protein / carbs / fat tiles, tap to type over, Recalculate) → Start.
Maintain skips desired weight and pace. Back on every page but the first; Close only for existing users.

**Safe rates (the pace bounds; `GoalPlan`):**

| Goal | Slow | Recommended | Fast | Hard cap | Sources |
|---|---|---|---|---|---|
| Lose | 0.25 % body weight a week | 0.5 % | 1 % | 0.9 kg (2 lb) a week | CDC "1 to 2 pounds a week"; Helms et al. 2014 (JISSN): 0.5–1 % a week keeps muscle for people who lift |
| Gain | 0.125 % | 0.25 % | 0.5 % | 0.5 kg a week | Iraki et al. 2019 (Sports): 0.25–0.5 % a week for a lean gain |

- Energy: ≈ 7,700 kcal per kg → pace × 1,100 kcal a day per kg a week.
- The calories never go below the N3 floor (1,200 women / 1,500 men / 1,350 unspecified). A loss pace that would need
  fewer is not offered: Fast is held to what the floor allows, and the page says "Held so your calories stay at or
  above 1,200 cal a day." If not even 0.05 kg a week fits, no pace is offered (to decide: the flow then suggests
  Maintain).
- A desired weight to lose to stops at a BMI of 18.5 for the height (WHO underweight line; "The lowest healthy weight
  for your height."); a gain goal goes up to +30 kg.
- Paces round to 0.05 kg / 0.1 lb; desired weight steps 0.5 kg / 1 lb.
- Example (prototype sample): woman, 30, 168 cm, 68.5 kg, 3–5 workouts → maintenance 2,207; recommended 0.35 kg a week
  → 1,822 cal; 5 kg in 15 weeks.

**Own decisions (for the user to confirm):** workouts a week 0–2 → Light (1.375), 3–5 → Moderate (1.55), 6+ → Very
active (1.725) — Sedentary and Extra active stay reachable from Nutrition goals' Activity menu; sex and date of birth
are two pages (one question a page); height on a wheel, weight as a figure with − / + (the Log weight pattern);
existing users start on page 1 with every answer prefilled.

**New strings (the user's decision):** "What's your sex?" / "Used to estimate your calories." · "When were you born?"
/ "N years old" · "Your height and weight" / "Metric" "Imperial" / "Height" "Weight" · "How often do you work out?" /
"Sets how active you are for the estimate." / "0–2 a week" "Now and then" / "3–5 a week" "A few times a week" / "6 or
more a week" "Most days" · "What's your goal?" · "What weight are you aiming for?" / "−5 kg from now" / "The lowest
healthy weight for your height." · "How fast do you want to lose?" / "…to gain?" / "kg a week" / "Slow"
"Recommended" "Fast" / "Held so your calories stay at or above N cal a day." / "Goal reached" "in N weeks" "Daily
calories" · "Your plan is ready" / "Lose N kg by <date>" / "Stay at N kg" · "Continue" "Start" "Save Goals" "Get
Started".

**The user's answers (2026-11-12, D84):** order **A** (welcome first with Get Started, no Skip; the plan page offers Show Me Around); the pace bounds **as proposed**; existing users get a **Goal weight row under Based on** on Nutrition goals (it replaces the Goal menu). Wording and look: no change asked.

~~Open for the user:~~ (asked) (1) welcome and tour order — A: Welcome ("Get Started", no Skip) → setup → plan offers Show Me
Around; B: setup → today's Welcome (tour / Skip); C: setup only, tour from Profile → Show Tour; (2) the pace bounds
above; (3) the existing-user entry on Nutrition goals; (4) anything in the look or wording.

## Comments

### 2026-11-12 — built (after the user's answers)

**Code.** `Domain/GoalPlan.swift` (paces, bounds, calories at a pace, arrival, desired range, workouts → activity);
`Domain/GoalSetupStore.swift` (prefill, commit: Personal details, a weigh-in only when the weight changed, height kept as
entered when unchanged — D52, the goal through `NutritionGoalStore`); `NutritionGoals.Inputs.paceKgPerWeek` (nil = N3's
fixed −500 / +250, so goals from before N13 keep their numbers); `NutritionGoalStore.Choices` carries `desired` and
`paceKgPerWeek`. UI: `Features/GoalSetup/GoalSetupDraft.swift`, `GoalSetupFlow.swift`; `Onboarding/FirstLaunchView.swift`
(welcome → setup in one cover; `OnboardingCoordinator.beginSetup` / `finishSetup`; the welcome counts as answered only
once the setup is saved, so quitting part-way brings it back; Show Me Around saves, then tours; `startTour` refuses
while the welcome is up); `WelcomeView` → one Get Started, no Skip; Nutrition goals → **Goal weight** row (opens the
setup prefilled, Close allowed) replacing the Goal menu (`ActivityMenu` keeps Activity). Removed: N3's
`FoodGoalsSetupSheet` and the `-uiTestFoodGoalsStep` path, and the prototype wrapper. A new install starts in the app's
units (lb / ft-in in the US).

**Data (stored-format change).** `NutritionGoal` + `desiredWeightValue`, `desiredWeightUnit`, `desiredWeightKg`,
`paceKgPerWeek` (additive optionals; lightweight migration). `StoreFormatGuardTests.approvedFingerprint` `d339bba6…`;
`release020Fingerprint` `ad42bc46…` = 0.2.0's shipped format. New fixture `WorkoutTrackerTests/Fixtures/Release020.store`
(0.2.0 format, written by `main` `e6255e85` with the design sample, Personal details, food sample + diary, nutrition
charts: 7 workouts, 58 sets, 18 food entries, 7 saved foods, 2 meals, 1 goal, 29 weights) + `GoalSetupMigrationTests`
(format proven from metadata; the safety copy sees the change; rows and checksums survive; new fields nil). Export
v13 (the four fields, omitted when nil; a v12 file decodes). **Gate S before the user's phone installs 0.2.1.**

**Own decisions (after the answers):** the existing user's run starts on page 1 with every answer prefilled; an
unchanged prefilled weight adds no weigh-in; a finer stored activity (Sedentary / Extra active) survives a run that
leaves the workouts answer alone; Lose is refused with a line when already at BMI 18.5 ("You're already at the lowest
healthy weight for your height.") or when no loss fits above the floor ("Losing would take your calories under N cal a
day."); the Goal weight row reads "63.5 kg · 0.35 kg a week", "Maintain", or a pre-N13 goal's name. Not in scope (follow
up if wanted): telling the user when the latest weight reaches the desired weight.

**Design (ios-design).** Job per page: "On each setup page the user answers one question in a tap or two; the eye lands
on the question (top-leading, title style); Continue, the one filled command, sits in the thumb's bottom third." Plan
page: "the user checks the plan and starts; the eye lands on the calories (the one hero number); Start is the command,
Show Me Around a plain secondary." Wireframe (every page):
```
[‹ Back]  ▬▬▬▬▬▬▬▬ progress          (Close: existing users only)
Question (title)                     ← largest type
Subtitle (subhead, optional)
┌ answer panel / option list ┐       ← one surface; options equal rows
└────────────────────────────┘
(stats panel: pace page only — 2 equal stats)
…
[        Continue / Start        ]  ← one filled command
          Show Me Around            (plan page, first launch)
```
Tells: same container on everything — absent (a list for options, one panel for an answer); chips where a caption
would do — the pace stops are three equal options (deliberate: a jump to the named paces); all-caps labels — absent;
middle dots — the Goal weight row value (deliberate, the frozen-stat style); accent on many things — violet/ink only on
the selected state, progress done-segments and the command; equal blocks — absent (question leads); phone-sized website
— absent; empty first viewport — the short pages leave space above Continue (deliberate: the thumb zone holds the
command); control dressed as primary — absent; layout only at default size — AccessibilityL captures: options and
stats stack, pace stops stack, the page scrolls under the fixed command.

**Evidence (2026-11-12, `WT-Floodlight`, derived data `/tmp/n13-dd`).** Captures (light/dark × Default/AccessibilityL,
welcome + 8 pages, from `GoalSetupUITests` capture tests): `work-record/nutrition/captures/13/`; prototype captures in
`captures/13-prototype/`; the prototype's code stays at commit `49b9c585` (tag `design/n13-prototype`).

```
Verified: Unit plan — 1320/1320, exit 0, /tmp/n13-unit2.xcresult (incl. GoalSetupTests 27, GoalSetupMigrationTests 3,
  OnboardingTests, StoreFormatGuardTests with the new fingerprint, export v13 pins)
Verified: GoalSetupUITests new-install + existing-user — 2/2, exit 0, /tmp/n13-ui1.xcresult
Verified: ProfileAI -only-testing AAAWarmUp, GoalSetupUITests (6), FloodlightTourUITests (10), FloodlightAccountUITests (4),
  FloodlightGoogleUITests (4), NutritionGoalsUITests (7) — 32/32, exit 0, 2 workers, /tmp/n13-ui2.xcresult
Not verified: the user's phone (Gate S before 0.2.1 installs: a stored-format change); Apple Health receiving the setup's
  weigh-in on a device (same save path as Personal details' weight, which N9b's sync follows); the full UI suite (not
  required by the tier; ask first)
Known flaky: none seen
```
