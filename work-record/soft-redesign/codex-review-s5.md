# S5 independent review — Today's up next

Reviewed 2026-11-08 by Codex; implementation by Claude.

## Scope

Requested diff: `git diff 40b30d6..bd09df9`. Branch `ericlee4992/soft-05-today-up-next`, initial HEAD
`31be6eed07b5d92368e514aa023451f196a33c90`; the final commit only corrects the prompt range. Read AGENTS, STATE,
the full S5 brief/ticket, D77/D68/D52, applicable SwiftUI/SwiftData/design guidance, changed source/tests and callers.
The separate dev-speed ticket in the range is documentation, not a runtime change.

Only this report was written in the repository; no implementation edits, commit, or push. Simulator work uses
WT-iPhone27 only. The existing **Test progress (Claude r2)** tab `term_ac1339dc-202d-4c10-bab3-b528de726cbd` was
verified idle and reused; no new terminal was opened.

## Spec findings

### 1. P2 — Advance the suggestion after finishing a workout in the same foreground session

**Location:** `WorkoutTracker/Features/Today/TodayView.swift:38,110–112`,
`WorkoutTracker/Features/Start/StartWorkoutView.swift:43,242–244`, `WorkoutTracker/Domain/UpNext.swift:97`.

Today and Train pass their retained `now` snapshot into the suggestion. That date updates at day/clock/timezone
changes and activation, not when a workout finishes. Open Today, start Push, then finish without backgrounding:
the new finished run starts after the snapshot and is rejected by `startedAt <= now`. An in-order Push/Pull/Legs
split therefore still suggests Push instead of Pull; learned order also omits the new run. Query invalidation
rerenders the same stale cutoff. A newly constructed Train screen can consequently disagree with retained Today.

**Fix:** refresh the shared reading's effective time when finished history changes, or compute suggestions with
current time while retaining boundary-driven invalidation. Cover start → finish → return to Today/Train without an
activation event, and assert that both advance to the next template.

### 2. P2 — Make Next in order advance from the explicitly chosen template

**Location:** `WorkoutTracker/Features/Today/TodayView.swift:151–163`.

For My split `[Push, Pull, Legs]` with Push currently due, choose Pull through **Choose template…**, then select
**Next in order**. Choosing preserves `skip == 0`; Next discards `chosen` and increments the baseline skip to 1.
That resolves to Pull again, so the visible suggestion does not advance. D77/the ticket describes skipping to the
following suggestion, not discarding the displayed choice and restarting from the original suggestion.

**Fix:** derive the successor from the displayed/chosen template under the applicable order, or translate the
explicit choice into the correct sequence position before advancing. Add a Choose → Next transition test, including
wraparound; the existing UI test chooses a template and then uses Back to plan, so it misses this case.

### 3. P2 — Do not let future-dated history immediately cancel every Not today choice

**Location:** `WorkoutTracker/Features/Today/UpNextReading.swift:25–27`,
`WorkoutTracker/Domain/UpNext.swift:56–58`.

The suggestion excludes future runs, but override expiry takes the maximum `startedAt` of every finished record
without the same temporal filter. With a finished record dated tomorrow (for example after a clock correction or
restore), any choice made today is immediately considered expired: the future start is greater than `madeAt`.
Both Next and Choose appear ineffective although no workout has actually finished after the choice. Expiry also
uses start time rather than the completion event promised by the ticket.

**Fix:** use a consistent valid timeline for suggestion and override reads, ignoring future-dated records for
expiry. Base expiry on valid completion timestamps or explicitly clear the override on the actual finish event.
Cover future history plus a new choice, and an actual completion after the choice.

These three cases were reproduced with the reviewed `UpNext.swift` and extracted `TemplateStats.dueNext` in a
temporary Swift program, **exit 0**: stale clock yields Push while a fresh clock yields Pull; Choose Pull → Next
yields Pull rather than Legs; a new choice with future finished history returns `isCurrent == false`.
Evidence: `/tmp/codex-s5/spec-repro.swift`, `/tmp/codex-s5/spec-repro.log`. This is a pure-logic reproduction plus
source tracing of the callers, not an injected-clock UI test.

## Standards and other checked paths

No additional actionable standards finding.

- Learned order uses the recent 42-day sequence, frequency then latest-follower tie-breaking, and the documented
  used-template/all-template fallbacks. Consecutive self-followers are ignored; ordinary single-template repeats
  still select that template. Split pruning, ordered wrapping, weekday rest/skip behavior, and missing/garbage
  decode paths are bounded by the normal callers. Real future runs are excluded by `suggestion`; virtual skip runs
  are intentionally appended afterward. The issues above concern integration and choice transitions.
- Repeat creates fresh entries/uncompleted sets from completed source structure, remaps superset IDs, and reuses
  Save as Template's cardio-plan mapping. It uses the source machine only when active at the chosen gym. It does
  not rewrite the source workout, save a template, or copy recorded cardio measurements into new activity. The
  caller selects finished repeatable history; the start flow rechecks deletion and falls back to empty if the source
  disappeared. Resume, finish-and-start-new, drift resolution, and heart-rate finalization retain their existing
  paths. The new Repeat unit test checks structure and source preservation, rather than every machine/cardio edge.
- Today and Train call the same reading and preferences. Active workouts show Resume; a planned rest day has no
  Train lead while Train retains its start controls. My Split stages changes until Save, clears the daily override
  on a new plan, and stores only UserDefaults values. No model/schema or `StoreFormatGuardTests` change was found.
  UI-test reset clears both new keys under the established `-uiTestKeepPins` exception.
- The `trainStartButton(_:)` rewrites preserve their downstream assertions and route workout setup through Train.
  Welcome/tour checks still require the underlying flow to be accessible. New Today tests explicitly assert the
  removed Start Lifting/Cardio buttons are absent and exercise the replacement starts. The helper does not reset
  Train when its requested button already exists. No silently removed assertion was found.
- The selected Today tests do not exercise finish → next suggestion, Choose → Next, or future-history override
  expiry. The ticket says 11 Today UI tests; this revision contains **9** test methods, which is the count used below.

## Independent verification

Xcode 27.2 (27B52), iOS 27.0, WT-iPhone27 `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`.
Artifacts and derived data: `/tmp/codex-s5/`.

- `build-for-testing`: **exit 0**, xcresult `succeeded`, **0 errors, 31 warnings**; `build.log`, `build.xcresult`,
  `build-summary.json`.
- Requested serial units: **exit 0**, **25 passed, 0 failed, 0 skipped** in `UpNextTests`, `WorkoutTemplateTests`,
  and `TemplateDueNextTests`; `unit.log`, `unit.xcresult`. Counts read directly from the xcresult summary.
- Requested serial UI run: **in progress**, exec session `76758`; `ui.log`, `ui.xcresult`. Selection: the known
  baseline cardio warm-up first, then `CoreLoopUITests` and `TodayUpNextUITests` in XCTest's class order (19 total).
  Final results and capture inspection will replace this checkpoint before delivery.
- `git diff --check 40b30d6..bd09df9`: **exit 0**.

This review does not claim a new full-suite run, device installation, hardware sensor verification, or a person's
VoiceOver traversal. The known baseline cardio-start failure is tracked separately; actual results will be recorded
without treating a failed warm-up as a pass.

Standards: **0 additional findings**. Spec: **3 P2s**. Resolve and re-review before clearance.

Verdict: not clear
