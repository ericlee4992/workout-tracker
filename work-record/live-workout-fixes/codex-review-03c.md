# Live-workout 03 — Codex review, round 3

Target: `4bf4d638..6b3912b3922e94cd25e837b83e8e5c91583988c6`, branch
`ericlee4992/workout-chart-machines`. Clean checkout at start. Reviewed the round-three brief, ticket response,
previous findings and current source against the established D23/D36/D87 requirements.

**Final report — 2026-11-13. All previous findings resolved; no new findings.**

## Standards

No findings. `ExerciseHistory.Item` retains its originating entry without altering stored models or actor usage.
Domain code remains free of UI imports. ProgressTabView and AddChartSheet use the named `.input`/`.workout`
members and shared alias; the added `.entry` does not change their ranking, selection or pin behavior.

## Spec

No findings. Round-2 #1 is resolved: the item carries the actual entry, `bestPerDay` retains that item, and the
pooled row formats that entry's frozen machine/gym fields. There is no lookup through another entry of the workout.
The new `eachPooledSessionNamesTheEntryThatSetItsBest` regression exercises two entries in the same workout on the
same machine, with different frozen names and presets; the heavier set outside the chosen preset stays out.

Compared `bestPerDay` with the removed view implementation and `ProgressSeriesMath.series`: eligibility, load
type/equipment/preset scoping, calendar-day grouping, bodyweight rep ranking, other load types' `outranks`, and
first-item retention on ties are preserved. Session navigation and machine names now derive from the same winner.
The earlier draft-name and AccessibilityL fixes remain intact. No layout, typography, color or new copy changes
this round; the reviewed round-2 captures remain applicable.

## Verification

Only WT-Redesign-2 `EB4328A1-87BD-4850-A3B2-A6E604701F1C`; preparation script before runs. Derived data
`/tmp/wt-live03-codex`; logs, exits and results `/tmp/wt-live03-codex-review-r3/`.

- Independent build-for-testing: passed, exit 0 (`build.log`, `build.exit`).
- Independent Unit plan: 1358/1358 passed, exit 0 (`unit.log`, `unit.exit`, `unit.xcresult`), summary inspected.
- Independent focused UI: 5/5 passed, exit 0 (`ui.log`, `ui.exit`, `ui.xcresult`), summary inspected.
  Scope: `Full` plan narrowed with `-only-testing` to
  `FloodlightLiveUITests/testLiveChartOpensOnTheMachineInUseAndSwitchesMachines` and the four
  `ProgressChartTooltipUITests` methods. This covers machine switching, per-variation charts, History's selected
  variation, sparse-history navigation and as-entered tooltips. Existing area-plan evidence from round 2 remains
  applicable; the full UI suite was not rerun.
- Author xcresult summaries inspected directly: `unit-03d.xcresult` 1358/1358 passed, `ui-03d.xcresult` 5/5 passed.
- `git diff --check 4bf4d638..HEAD` and `python3 scripts/test-plans.py --check`: passed.

Verified: independent build exit 0; Unit 1358/1358, exit 0, `/tmp/wt-live03-codex-review-r3/unit.xcresult`;
          focused UI 5/5, exit 0, `/tmp/wt-live03-codex-review-r3/ui.xcresult`;
          source and caller review; author's current xcresult summaries.
Not verified: phone behavior; full UI suite this round; live-sensor performance measurements.
Known flaky: the live New Best band's warmup test, assessed in round 2 as intermittent automation timing;
             no change to that code this round. Its testing follow-up remains separate.

Standards: 0 findings. Spec: 0 findings. This clearance covers the reviewed commit and ticket's code, not a device
installation or release. Only this report was changed by the reviewer.

Verdict: clear
