# S4 independent review — History journal and training charts

Reviewed 2026-11-07 by Codex; implementation by Claude.

## Scope

Requested diff: `git diff 55831f0..1e298e3`, S4 only, stacked on cleared S3. Branch
`ericlee4992/soft-04-history-progress`, initial HEAD `3bed228bacfa0bec9a2b05eaab8ff146c8ea5a4c`; that final commit changes
only the prompt's diff range. The checkout was clean at review start. Read AGENTS, STATE, the full brief, S4 ticket,
Soft spec, D52/D63/D67–D76, applicable SwiftUI/SwiftData/design guidance, and the approved prototype's Progress and
journal files. The approved Soft direction governs over the design skill's older Floodlight palette.

I wrote only this report in the repository; no implementation changes, commit, or push. All simulator work
used WT-iPhone27, not WT-Floodlight. At finalization, another session had advanced HEAD to `126713e` (STATE only)
and begun uncommitted product/test fixes, including `RefreshingNow.swift` and a new prompt section. Those concurrent
edits are outside this pinned review and have not been reviewed or tested here. Findings and line references below
refer to the requested S4 revision; a subsequent fix review must assess the new diff separately.

## Standards / consumer correctness

### 1. P2 — Do not describe one weekly bucket as one session

**Location:** `WorkoutTracker/Features/Progress/ProgressPanel.swift:152–155,192–194`.

`ProgressReading.training` supplies one point per week, but the shared panel treats a single point as a single
session. With three completed workouts all in the first tracked week, Workouts per week displays **3**, **This week**,
and **One session**. Training volume and running distance inherit the same false description. The math is correct;
the consumer assigns the wrong meaning to the number of points. This is source-traced, not a failing unit assertion.

**Fix:** give weekly readings an appropriate single-point caption (or omit the extra session caption), preserving
the existing lift/cardio behavior. Cover multiple workouts in one calendar week through the reading/panel behavior.

## Spec

### 2. P2 — Refresh the new relative-day/week readings at calendar boundaries

**Location:** `WorkoutTracker/Features/Progress/ProgressTabView.swift:166–168`,
`WorkoutTracker/Features/Progress/TrainingProgressView.swift:7`,
`WorkoutTracker/Features/History/HistoryView.swift:140–143`.

The new training figure promises this week so far, but `trainingReading` reads `.now` only when rendered. Neither
Progress nor its presented detail observes day/week, clock/timezone, or foreground changes; the detail receives a
plain reading value. Leave the chart open across the locale's week boundary with no active workout or store change:
the old week's total can remain labeled **This week**, rather than advancing to a new zero-valued current week.
The new journal's **Today/Yesterday** headings have the same missing invalidation at midnight. Reading `Date.now`
inside rendering is not an observable clock. This is source-traced; the review did not change the system clock.

**Fix:** use a refreshed observable date/calendar snapshot, including day/significant-time/timezone notifications
and foreground activation, and ensure the presented detail receives the updated reading. The S2 Today refresh is
an existing project precedent. Cover day/week rollover and timezone changes without requiring a workout mutation.

### 3. P2 — Provide the specified visible chart-options menu

**Location:** `WorkoutTracker/Features/Progress/ProgressTabView.swift:59–63`,
`WorkoutTracker/Features/Progress/ProgressPanel.swift:182–186`.

S4 explicitly requires **“‘…’ for Move Up / Remove”**, matching `SoftProgressBoard.swift`'s `SoftChartCard` in the
approved prototype. The implementation still exposes only a chevron opening the chart and a hidden long-press
context menu. Someone looking for the specified menu cannot discover chart management from the card's controls.
The underlying Move/Remove actions exist and preserve pins; the visible affordance is missing.

**Fix:** add a labeled ellipsis menu using the existing actions, with no metric choices for a training pin. Keep
chart opening as a separate action and retain the context menu if desired. Verify menu-based move/remove and pin
persistence, rather than relying solely on the existing long-press test.

## Other checked paths

- **Pin compatibility:** compared actual `main` and S4 `ProgressPins.swift` and all `main` ProgressTabView save
  callers. Old lifting/cardio JSON retains its shape. Training pins use the old cardio subject with unknown
  `training.<metric>` activity and valid `.time` placeholder. Old code hides these via `CardioActivity(rawValue:)`
  and saves from the complete decoded `pins`, not filtered `shown`; Add, metric changes, Move and Remove preserve
  hidden training pins. Independent temporary Swift verification uses the actual old synthesized enum and current
  coding implementation, with only non-serialization dependencies stubbed; it checks old→new→old values and
  downgrade mutations followed by upgrade. No all-pins-loss path found for supported data.
- **Test limitation:** `TrainingProgressTests.swift:83–91`'s `LegacyPin` is not the actual old decoder: it models
  the subject as a struct with an optional cardio member and the metric as unrestricted String. Its comment
  overstates fidelity. Production compatibility passed the separate actual-decoder check; strengthening this
  repository test would protect that result against later regressions.
- **Weekly math:** calendar first weekday, metric-specific first data week, zero gaps and 12-week cap are respected.
  Future starts do not contribute to totals. A future-only input later in the current week produces a zero point
  rather than an empty series; it does not inflate the total. Inputs reject unfinished/deleted workouts, use the
  existing History volume calculation (completed weighted non-warmup sets), and sum only indoor/outdoor runs.
  `CardioSegment.distanceMeters` normalizes manually entered km/mi or returns automatic metres; display conversion
  does not rewrite stored values. Training detail uses full number formatting, not abbreviated axis values.
- **Journal:** workouts group by local start day and month, newest first. Current/previous day and other-year
  formatting are covered by unit tests. The combined `historyDay` heading supplies date context after rows hide
  their date column. The month card/calendar, `tour.historyList`, workout destinations, and editing/deletion paths
  remain. No remaining `HistoryWeekHeader` consumer was found. Small documentation follow-up: HistoryView's header
  comment still describes weekly panels; it should describe the day journal.
- **Add Chart:** Training is the third segment, its search prompt is Charts, and one tap appends and dismisses.
  Training pins have no metric-picker options. No store/schema change or unrelated modernization was requested.

## Independent verification

Xcode 27.2 (27B52), iOS 27.0, WT-iPhone27 `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`.
Artifacts and derived data: `/tmp/codex-s4/`.

- `build-for-testing`: **exit 0**, xcresult `succeeded`, **0 errors, 31 warnings**; `build.log`, `build.xcresult`,
  `build-summary.json`.
- Requested serial units: **exit 0**, **26 passed, 0 failed, 0 skipped** in `HistoryJournalTests`,
  `TrainingProgressTests`, `HistoryOverviewTests`, `ProgressPinTests`; `unit.log`, `unit.xcresult`.
- Actual-decoder compatibility experiment: **exit 0**; `compat/main.swift`, `compat/run.log`. A second
  structural-JSON equality check also passed, **exit 0** (`compat/shape.swift`, `compat/shape.log`).
- Requested serial UI run: **exit 0**, `TEST EXECUTE SUCCEEDED`; xcresult **15 passed, 0 failed, 0 skipped**:
  cardio saved-distance warm-up **1/1**, `FloodlightProgressUITests` **9/9**, `HistoryEditFlowsUITests` **5/5**.
  Evidence: `ui.log`, `ui.xcresult`; counts read directly with `xcresulttool get test-results summary`.
  The bundle contains five `Invalid frame dimension (negative or non-finite)` runtime warnings; they caused no
  test failure and this review does not establish their origin. No retries were needed. The visible Orca Test
  progress terminal `term_11430473-a06d-4c7b-8210-bf26c9cffbc2` reported 15/15 and returned to its shell prompt.
- Exported captures and inspected the new Training add/tab/detail sequence in dark/default and light/AccessibilityL.
  Figures and full weekly volume labels fit, the add rows show a plus, and the captures confirm the missing
  visible options affordance in finding 3. Evidence: `captures/manifest.json`, original PNGs, and inspected contact
  sheets `captures/review-dark.png` and `captures/review-light.png`. This is targeted Progress visual evidence;
  the requested HistoryEditFlows run exercises navigation and mutations, not fresh journal layout captures.
- `git diff --check 55831f0..1e298e3`: **exit 0**.

All test commands used the stated project/scheme, Debug simulator build, `/tmp/codex-s4/DerivedData`, the sole
WT-iPhone27 destination, and `-collect-test-diagnostics never`. Unit/UI runs used `test-without-building` with
`-parallel-testing-enabled NO`; their logs preserve exact selections and invocations.

The full combined Phase 1 capture/core-flow run remains deferred. No device install, clock manipulation, actual
VoiceOver traversal, or full-suite clearance is claimed. Fixed-calendar unit tests do not validate view refresh,
and the existing Progress tests do not cover a one-week aggregate's session wording or visible options menu.

Standards/consumer correctness: **1 P2**. Spec: **2 P2s**. Resolve and re-review before clearance.

Verdict: not clear
