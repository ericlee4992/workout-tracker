# Codex review — N16, pick a day on Today (round 1)

You are the independent reviewer (T6). Claude implemented. Review only; **modify nothing but the report**.

- Repository: `/Users/ericlee06/.paseo/worktrees/1qmeipq9/today-pick-day` (a Paseo worktree), branch
  `ericlee4992/today-pick-day`.
- **Diff range:** `cb364043..HEAD` (`git diff cb364043..HEAD`). The branch also carries two prototype commits whose
  throwaway code was removed again; the net diff is the real build plus records. The prototype stays at tag
  `design/today-pick-day-prototype` for reference only.

## Read first

- `AGENTS.md` (the self-check list, "What the reviewer reruns", the conventions).
- The ticket: `work-record/nutrition/issues/16-pick-a-day-on-today.md` (the user's answers and "the real build").
- `docs/DECISIONS.md` **D92** (this change), plus D70 (dated goals), D74 (Apple Health), D82/D83 (scans; D92 amends
  D83(9) while a past day is picked), D77 (Up next), N10's day page (`DayFoodView`).

## Review questions

1. **Entries land on the right day, and nothing else is back-dated** (`Domain/FoodLog.swift` `log` ×2 / `logManual`,
   `Domain/FoodScan.swift` `logLabel`, `Domain/TodayDayPick.swift` `FoodLogDay`). Only `loggedAt` may move; `createdAt`
   and the food's / meal's `lastUsedAt` must stay now. Any path where a picked day is lost (logs to today) or where a
   *today* log is moved (logs to a stale picked day)? Check every log path: Log food's +, search results, Selected
   food, Selected meal, Manual Add (from Log food and from Today's scan), Estimate (`FoodScanQueue.startDescribe`), a
   meal photo from the camera and from the library (`FoodScanFlow.shot`), a label (`LabelFoodStep` → `LabelFoodView`),
   a barcode's food, and Undo (`FoodLog.undo`).
2. **The day is a snapshot, passed explicitly** (`Features/Today/TodayView.swift` `logDay`, `LogFoodView(day:)`,
   `FoodScanFlow(day:)`, …). Can the day change under an open Log food or scan (the pick reset on return, midnight, a
   tab switch)? Can a stale `logDay` from an earlier tap leak into a later Log food or scan from today?
3. **The pick's rules** (`Domain/TodayDayPick.swift`): today's ring goes back; days ahead are not picked; ‹ › and the
   swipe move a week and pick the same weekday, never past today; the rings follow a picked day's week across a week's
   end; a picked day that is no longer past (clock or time zone moved back) shows today and logs at now; the reset when
   the app returns on another day or after an hour (`TodayView` `scenePhase`). Week starts per locale
   (`calendar.firstWeekday`), DST days, year boundaries in `weekTitle`.
4. **The earlier week's summary** (`Domain/WeekSummary.swift` `summary(…weekOf:)`): the window now has an upper bound;
   does anything change for the current week (Today, `StartWorkoutView`)? `lastWeekWorkoutCount` for an earlier week.
5. **Scan cards** (`Features/Food/Scan/FoodScanQueue.swift` `pickedDay`, `shown(on:)`, `finish`; `TodayView`
   `visibleScans` / `scansShown`): a picked day's scan shows on that day and on today while in flight or failed, and
   leaves once logged; retry keeps the day; D83's earlier-day library card (no pick) unchanged. Any case where a failed
   scan is out of sight, or a card duplicates its logged entry?
6. **Today on a past day** (`TodayView`, `Features/Today/TodayPieces.swift`): the fuel card uses that day's goal and
   Burned from its workouts only (Health's active energy is today's); Up next hidden, Resume kept; the log's header and
   empty line; the inline title. Accessibility: day rings as buttons with labels/`isSelected`, the selected vs today
   marks (filled vs outline — not colour alone), AccessibilityL rows (no truncation of what is needed), chevrons ≥44 pt,
   the swipe has the chevrons as its accessible alternative; Reduce Motion. The `todayWeek` container id now uses
   `.accessibilityElement(children: .contain)` — do other UI tests that use it still work?
7. **Claims**: README's "Pick a day" paragraph, D92, the ticket and doc comments against the code.
8. **No stored-format change**: confirm no `@Model` / schema edit, so no migration or Gate S is due.

## What to run

On **your** simulator — **WT-Redesign-2** (`EB4328A1-87BD-4850-A3B2-A6E604701F1C`) with
`-derivedDataPath /tmp/wt-n16-codex` (leave WT-iPhone27 and WT-Floodlight alone):

- Build, then the affected unit suites: `-only-testing:WorkoutTrackerTests/TodayDayPickTests`, `FoodLogTests`,
  `FoodScanTests`, `WeekSummaryTests`, `TodayDayBoundaryTests`, `FoodDayTests` (or the whole Unit plan).
- Round 1 UI: `-only-testing:WorkoutTrackerUITests/TodayPickDayUITests` (`-parallel-testing-enabled NO`; run
  `scripts/prepare-test-simulator.sh EB4328A1-87BD-4850-A3B2-A6E604701F1C` first).

## The author's evidence (inspect)

- Unit plan: `build/results/n16-unitplan.xcresult`; TodayTrain plan (includes `TodayPickDayUITests`, `TodayFoodUITests`,
  `ScanFoodUITests`, `LogFood*`, `TodayUpNextUITests`, …): `build/results/n16-todaytrain.xcresult`; focused
  `TodayPickDayUITests` 6/6: `build/results/n16-ui.xcresult`; focused unit suites 65/65: `build/results/n16-unit.xcresult`.
- Captures: `work-record/nutrition/captures/16/`.

## Rules

Modify nothing but the report. No phone, Apple account, backups, deploys or desktop control.

## Report

Write `work-record/nutrition/codex-review-n16.md`: numbered findings with severity P0–P3, file:line, the failure
scenario and a suggested fix; then what you ran, with counts and exit codes. The last line must be exactly
`Verdict: clear` or `Verdict: not clear`.
