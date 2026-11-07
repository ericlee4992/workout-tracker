# S4 — History journal and Progress pin-anything (training metrics)

Type: change
Status: **proposed** (2026-11-07) — awaiting the user's approval
Blocked by: S2
Implementer: Claude; Reviewer: Codex (visible Orca terminal), to "clear".
Branch (when built): `ericlee4992/soft-04-history-progress` off `main`.
Spec: [soft-redesign](../spec.md). Decisions: extends D63 (Progress pins).

## Goal

History reads as a daily journal; Progress can pin more kinds of training metric. Food and body-weight metrics join
in Phase 2 (N9).

## Scope

- **History journal:** one section per day — each workout with its muscle families, time and key figures; the
  calendar stays. A day's **food line** ("1,240 cal eaten · 1,048 under goal") is added in N9, not here. Workout
  detail, editing and deleting (tickets 19–20) unchanged.
- **Progress:** the shipped model (pinned charts + Add Chart, D63) with these pinnable training metrics: exercises
  (best set — today), cardio activities (today), **workouts per week**, **training volume**, **running distance**.
  Each card: title, what it measures, the figure, its change, a chart; "…" for Move Up / Remove. Add Chart groups:
  Training now; Body and Nutrition in N9.
- Pins stay in UserDefaults (`ProgressPins.swift`, "a view preference, not workout data") — **no store change**.
  A new pin kind must decode alongside old pins (older builds ignore unknown kinds; test both directions).

## Acceptance

1. History shows days as journal sections at default and AccessibilityL; tapping a workout opens its detail as today.
2. The three new metrics compute correctly (unit tests: warmups excluded, assisted load rules, as-entered units with
   plain-number display — D52) and chart over the existing ranges.
3. Existing pins survive the update unchanged (decode test with today's JSON).
4. Progress / ProgressChart / History UI tests pass; captures; Codex clear.

## Verification scope

New metrics → `ProgressSeries` / `ProgressPins` unit tests; History, HistoryCalendar, HistoryEdit, Progress UI classes.

## Code map

- `Features/History/HistoryView.swift`, `HistoryPieces.swift`; `Domain/HistoryOverview.swift`, `HistoryRendering.swift`.
- `Features/Progress/*`; `Domain/ProgressPins.swift`, `ProgressSeries.swift`, `WeekSummary.swift`.
- Prototype: `Screens/Soft/SoftProgressBoard.swift`, `SoftProgressScreen.swift`, `SoftRound3Screens.swift` (journal).

## Progress

Not started.

## Comments
