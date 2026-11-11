# N10 — Progress body and nutrition metrics, History food line

Type: feature
Status: **done — Codex clear (round 3), merged** (2026-11-11)
Blocked by: N5, N9
Implementer: Claude; Reviewer: Codex (visible Orca terminal), to "clear".
Branch (when built): `ericlee4992/nutrition-10-progress` off `main`.
Spec: [nutrition](../spec.md); extends S4 and D63.

## Goal

Pin body and food charts on Progress, and see each day's food in History.

## Scope

- **Progress → Add Chart → Body:** body weight (with the goal weight if set), weight trend (90D / 6M / 1Y / All).
  **Nutrition:** calories (per day vs the goal), protein, macros (stacked). Same card form as S4; pins stay in
  UserDefaults (new kinds decode alongside old ones).
- **History journal:** each day's food line — "1,240 cal eaten · 1,048 under goal" (or "over"); tap opens that day's
  food log; days with food and no workout appear too.

## Acceptance

1. Series unit tests (trend smoothing, dated goals, missing days); old pins decode.
2. Progress / History UI tests; captures; Codex clear.

## Code map

- `Domain/ProgressPins.swift`, `ProgressSeries.swift`, `HistoryOverview.swift`; `Features/Progress/`, `Features/History/`.
- Prototype: `Screens/Soft/SoftProgressBoard.swift`, `SoftRound3Screens.swift`.

## Progress

**The user's choices (2026-11-11):** Add Chart gets ONE more tab, **Nutrition**, listing **Body** (Body weight, Weight
trend) and **Food** (Calories, Protein, Macros) as two groups (five tabs would not fit); History's food line opens a
**day's food page**: that day's fuel card, then its food by meal, each entry editable as on Today.

**Own decisions (Claude):** the app has no goal weight (only lose / maintain / gain), so the weight charts have no goal
line; charts follow the approved prototype — a line for weight, daily bars against a dashed goal for calories and
protein, stacked protein · carbs · fat bars for macros.

**Built (Claude, 2026-11-11).**
- **Code:** `Domain/NutritionProgress.swift` (`NutritionChart`, `NutritionRange`, `NutritionProgressMath` — daily
  weights, 7-day trend over weigh-in days, weekly rate, change; food days with each day's own goal, averages over
  logged days, macro shares and whole percents; `HistoryFoodLine`; `FoodDayMath.loggedDays`); pins
  (`ProgressPin.Subject.nutrition`, on disk as the activity `nutrition.<chart>` like S4's training charts — an older
  build skips it, an unknown chart is skipped); `ProgressReading` styles `.bars` / `.macros` with a dashed goal and the
  span's days (`Features/Progress/ProgressPanel.swift`, `NutritionProgressReading.swift`); the chart page
  `NutritionProgressView` (weight 90D / 6M / 1Y / All, food 7D / 30D / 90D; weigh-ins or days listed, a day opens its
  food); Add Chart → **Nutrition** (Body, Food); History: the journal takes days with food (`journal(_:foodDays:)`),
  each day's food row last in its panel, opening `DayFoodView` (fuel card for that day — "cal under … of N goal" on a
  past day — then food by meal; edit, or delete with Undo). Undo toast shared (`FoodDeletedToast`).
- **Panels:** weight: the last 90 days; food: the last 7 days (today included). Figures: body weight — latest, "−7.6 lb
  in 12 weeks"; weight trend — latest average, "−0.6 lb a week" (the trend over its last 4 weeks); calories — daily
  average, "Daily average · 4 of 7 days logged"; protein — daily average, "Daily average · goal 144 g"; macros —
  "45 / 31 / 24 %", "Protein / carbs / fat · 4 of 7 days logged". Weight in the app's unit (all entries, the app's and
  Health's — on the phone only).
- **Own decisions (Claude):** days without food are blank and left out of averages; the goal line is the latest day's
  goal in the span (each day's own goal is used for History's line and the day page); the macros goal line is the
  calorie goal; Burned on a past day's page is its workouts' (Health's active energy is read for today only, N9b).
  `SegmentedPills` gained an opt-in `wraps` (rows of two when a label would not fit whole), used by Add Chart only —
  its four kinds truncated to "Traini…", "Nutri…" at AccessibilityL; other screens unchanged (candidate follow-up:
  adopt it where pills truncate).
- **New strings:** "Nutrition" (Add Chart tab), "Body", "Food"; chart titles and lines "Body weight" / "Each weigh-in",
  "Weight trend" / "7-day average", "Calories" / "Eaten per day vs goal", "Protein" / "Grams per day vs goal", "Macros"
  / "Protein · carbs · fat per day" (the prototype's); "… lb in N weeks" / "… days", "… lb a week", "Daily average ·
  N of M days logged", "Daily average · goal N g", "Protein / carbs / fat · N of M days logged", "One weigh-in", "One
  day"; chart page "Weigh-ins", "7-day average", "Days", ranges 7D 30D 90D 6M 1Y All; History "N cal eaten" / "N under
  goal" / "N over goal" / "At goal"; day page "No food logged.", "cal under", "of N goal".
- **Design (ios-design):** *Progress with body/food pins exists so the user can see their weight and eating at a
  glance; the eye lands on each panel's figure* (the existing panel form). *The day's food page exists so the user can
  see that day and fix an entry in one tap; the eye lands on the fuel card's figure* (Today's composition). Tells:
  second hero — absent (one figure per panel); colour — macros in their fixed colours, bars neutral with the latest day
  full; card around a sentence — absent. Wireframes: the prototype's `SoftChartCard` / `SoftAddChartSheet` and History
  day card (tag `design/soft-approved-2026-11-07`).


**Verification (2026-11-11; scope per DEVELOPMENT — a new feature across Progress and History, plus Today's refactored
toast and fuel card).** Build-for-testing exit 0. `NutritionProgressTests` 12/12; Unit plan 1,269/1,269
(`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/20f5b25b-92e7-448e-a00d-dbd68fee92a9/scratchpad/n10-unit.xcresult`); `NutritionProgressUITests` + warm-up 5/5 (`n10ui.xcresult`; captures looked at — light Default
and dark AccessibilityL: Progress with the five charts, the trend page, Add Chart → Nutrition, History's food lines, a
day's food page; Add Chart's tabs truncated at AXL → `wraps`, recaptured: two rows); the HistoryProgress plan's classes +
warm-up 45/45, 2 workers (`n10-hp.xcresult`); `TodayFoodUITests` 7/7 (`n10-today.xcresult`).

```
Verified: NutritionProgressTests 12/12; Unit 1,269/1,269; HistoryProgress plan 45/45; TodayFoodUITests 7/7 — exit 0 each
Not verified: VoiceOver by a person; runtime Reduce Motion; the full UI suite; other screens' pills (unchanged by design)
Known flaky: none seen
```

## Comments

**Round 1 (`codex-review-n10.md`): not clear — 2 P2, 2 P3.** Fixed:
- **S1** today's food page showed Burned from workouts only: when the page is today it reads Health's active energy as
  Today does (`FoodDayMath.burned`, refreshed by `HealthSync`); a past day stays workouts-only. UI test
  `testTodaysFoodPageShowsHealthsBurned` (with and without a goal: 412 on Today and on the page).
- **S2** the weekly rate (and change) counted days as seconds ÷ 86,400 — a spring week was 6.96 days and vanished: calendar
  days now (`NutritionProgressMath.days`); the bars' last day ends a calendar day later. Test across March 8 and Nov 1,
  2026 (New York).
- **S3** "Each weigh-in" showed daily averages: Body weight now plots each weigh-in as measured (two in a day are two
  points; the list shows date and time); the trend keeps averaging by day.
- **T1** a past day's protein said "50 g to go": "50 g under goal" on a past day (new string). Captures: an explicitly
  chosen past day (the second food line), light Default and dark AXL — "cal under", "50 g under goal".
- Performance note: the trend is now one pass with a sliding window (was quadratic); test against a plain window average.
Evidence: build exit 0; Unit plan 1,272/1,272 (`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/20f5b25b-92e7-448e-a00d-dbd68fee92a9/scratchpad/n10r2-unit.xcresult`); NutritionProgressUITests (5) + TodayFoodUITests
(7) + warm-up 13/13, 2 workers (`n10r2-ui.xcresult`).

**Round 2 (`codex-review-n10-b.md`, a new Codex session): not clear — 1 P2 (R2-S1); round 1's fixes confirmed.** R2-S1:
two weigh-ins at the same instant shared a chart/list identity (points were keyed by date). Fixed: a weigh-in point
carries its entry's id (`WeightPoint.entryID` → `ProgressReading.Point.key`, kept through the chart's mapping); equal
times sort by entry id; daily series keep date keys. Test `weighInsAtTheSameTimeKeepTheirOwnIdentity` (distinct ids,
order-independent, kept through an edit and a delete). Codex's advisory: today's food page now reads Burned again with
each refresh of its `now`, as Today does. Capture added: Body weight's page (weigh-ins with times), light Default and
dark AXL. Evidence: build exit 0; Unit plan 1,273/1,273 (`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/20f5b25b-92e7-448e-a00d-dbd68fee92a9/scratchpad/n10r3-unit.xcresult`); NutritionProgress, FloodlightProgress,
ProgressChart, ProgressChartTooltip UI classes + warm-up 22/22, 2 workers (`n10r3-ui.xcresult`).

**Round 3 (`codex-review-n10-c.md`): clear** — no findings; reviewer's build exit 0, Unit 1,273/1,273, the Progress UI
classes passed. Merged into `main` (the user's standing permission "merge whenever Codex clear"). Known flaky (Codex
round 2, did not recur): a dark nutrition capture's navigation once in a parallel run.
