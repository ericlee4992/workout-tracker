# N10 — Progress body and nutrition metrics, History food line

Type: feature
Status: **in progress** (2026-11-11, branch `ericlee4992/nutrition-10-progress`) — started on the user's go-ahead
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

## Comments
