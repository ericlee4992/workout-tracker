# N10 — Progress body and nutrition metrics, History food line

Type: feature
Status: **proposed** (2026-11-07) — awaiting the user's approval
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

Not started.

## Comments
