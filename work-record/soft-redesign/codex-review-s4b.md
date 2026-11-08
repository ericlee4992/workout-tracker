# S4 independent review — Round 2

Reviewed 2026-11-07 by Codex; implementation by Claude.

## Scope

Reviewed `git diff 1e298e3..224289c` against all three P2s in [Round 1](codex-review-s4.md), following the complete
updated [brief](codex-review-s4-prompt.md). Branch `ericlee4992/soft-04-history-progress`, initial HEAD
`945754cb5b3c5998370ae38b3e6cdd64033c7f83`; the later commit is prompt-only. Read the current state and ticket,
the prior findings, changed source/tests, and affected callers. Existing project and SwiftUI/SwiftData/design
guidance applies, with the approved Soft prototype governing the visual direction.

Only this report was written in the repository. Round 1's report is unchanged; no implementation edits, commit,
or push. All simulator verification uses WT-iPhone27. The existing requested **Test progress (Claude r2)** tab
`term_ac1339dc-202d-4c10-bab3-b528de726cbd` was verified idle and reused; no terminal was opened.

## Standards

No new source findings. Prior finding 1 is closed: `ProgressReading.singleNote` defaults to **One session** for
existing lift/cardio consumers, while nonempty training readings set it to nil and the panel conditionally renders
it (`ProgressPanel.swift:35–37,155–158,196–201`). A single training week keeps its figure and **This week** without
the false session count. The added tests cover three workouts in one week, kg/lb display conversion, and last-week
caption/no-change-badge behavior.

The legacy fixture is also strengthened: `BuildNinePin` now matches the old stored properties and synthesized
two-case enum coding, using the unchanged metric and variation types. The test decodes a mixed list with the old
shape, reorders/re-encodes it, and confirms S4 restores the training identity and order. Production pin coding and
the full-list save paths are unchanged from the independently verified Round 1 implementation.

## Spec

No new source findings. Prior findings 2 and 3 are addressed:

- **Clock refresh:** `RefreshingNow.swift:17–36` preserves the S2 Today handling: local day, significant-time,
  timezone notifications on the main run loop, plus activation. Today uses the extracted modifier; History and
  Progress own date state and bind it to the same modifier (`HistoryView.swift:36,138`,
  `ProgressTabView.swift:19,121`). Journal and training calculations read that state. The presented training
  detail is built through the sheet's `destination` from `trainingReading(metric)` using the parent's current
  `now` (`ProgressTabView.swift:113–114,183–185,230–231`), rather than an independent frozen state in the detail.
  No additional notification-driven test is required as a clearance gate for this direct reuse of the accepted
  S2 mechanism. Actual notification delivery/live rollover remains source-reviewed, not driven by this run;
  day-boundary unit tests validate calendar semantics rather than notification delivery.
- **Visible options:** each panel overlays a labeled `ProgressPanelMenu` in its reserved top-right area
  (`ProgressTabView.swift:62–70`, `ProgressPanel.swift:171–237`). The visible menu and long press share the same
  Show/Move/Remove builder. Training has no metric choices; changes still save from the full decoded pin list.
  The menu has its own identifier and title-specific spoken label, while tapping the card still opens the chart.
  The new UI test passed: one menu per panel, the Training volume spoken label, Move Up, no Time choice for training,
  Remove, and the resulting order surviving relaunch. Existing chart-opening and long-press flows also passed.
  Fresh light/dark captures show the visible ellipsis and reserved title space at default and AccessibilityL;
  no title/menu overlap was found in the inspected fixtures.

## Independent verification

Xcode 27.2 (27B52), iOS 27.0, WT-iPhone27 `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B` only.
Logs/results: `/tmp/codex-s4/round2/`; reused `/tmp/codex-s4/DerivedData` after rebuilding the changed code/tests.

- `build-for-testing`: **exit 0**, `TEST BUILD SUCCEEDED`; xcresult status `succeeded`, **0 errors, 31 warnings**.
  Evidence: `build.log`, `build.xcresult`, `build-summary.json`.
- Requested serial unit run: **exit 0**, **18 passed, 0 failed, 0 skipped** — `TrainingProgressTests` 8,
  `TodayDayBoundaryTests` 3, `ProgressPinTests` 7. Evidence: `unit.log`, `unit.xcresult`; counts read directly from
  `xcresulttool get test-results summary`.
- Requested serial UI run: **exit 0**, `TEST EXECUTE SUCCEEDED`; **11 passed, 0 failed, 0 skipped** — cardio
  saved-distance warm-up **1/1**, then `FloodlightProgressUITests` **10/10**, including the new visible-menu test.
  Evidence: `ui.log`, `ui.xcresult`; counts read directly with `xcresulttool get test-results summary`.
  No retry was needed. The bundle records five non-failing `Invalid frame dimension (negative or non-finite)`
  runtime warnings, as the Round 1 run did; this review does not establish their origin.
- Exported and visually inspected Progress captures in light/dark at default/AccessibilityL, plus the Training
  panels in dark/default and light/AccessibilityL. Evidence: `captures/manifest.json`, original PNGs, and inspected
  contact sheets `captures/review-light.png`, `captures/review-dark.png`.
- The existing **Test progress (Claude r2)** tab reported **11/11, 0 failed, TEST EXECUTE SUCCEEDED** and returned
  to its shell prompt. No new terminal was opened.
- `git diff --check 1e298e3..224289c`: **exit 0**.

Both test runs used `test-without-building`, `-parallel-testing-enabled NO`, the requested `-only-testing:`
selections, and `-collect-test-diagnostics never`. The logs preserve the complete build/test invocations.

The full combined Phase 1 capture/core-flow run remains deferred. No device installation, hardware/sensor check,
system-clock manipulation, or person's VoiceOver traversal is claimed. The earlier History editing and actual
old/new pin compatibility evidence remains in Round 1; it is not represented as a new Round 2 run.

Standards: **0 new findings**. Spec: **0 new findings**. All three Round 1 P2s are closed within this review's scope;
the deferred combined Phase 1 verification remains a separate merge gate.

Verdict: clear
