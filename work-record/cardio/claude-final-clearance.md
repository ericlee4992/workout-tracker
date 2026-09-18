# Claude final merge-gate clearance — cardio, direction B

Reviewer: Claude (T6; Codex implemented). Date: 2026-09-18.
Product source `03ada3d`; test source `306acf4`; branch tip reviewed `ff63a47` on
`origin/ericlee4992/cardio-implementation`. No build, test, simulator, install or source edit
by me. Every figure below was read by me from the author's exit files, logs and result bundles
in `cardio-implementation/work-record/ui-redesign/results/cardio/`.

## Verdict

**CLEAR TO MERGE**, subject to the two documentation conditions below. This clearance covers
the simulator-verifiable scope only. It does **not** cover AirPods Pro 3 indoor treadmill
distance and pace, background or locked-screen GPS, or any Watch cardio behaviour, and it does
**not** authorize a phone install.

## Artifacts verified independently

| Gate | Source | Result |
|---|---|---|
| Debug build | `build-10-exit.txt` | `0` |
| Full unit suite | `unit-7.xcresult`, exit file | Passed, 748/748, 0 failed, 0 skipped; exit `0` |
| Targeted unit run | `unit-targeted-8.xcresult`, exit file | Passed, 13/13 in 3 suites; exit `0` |
| Focused cardio UI | `focused-ui-6.xcresult`, exit file | Passed, 7/7; exit `0` |
| Full local UI suite | `full-ui-2.xcresult`, log, exit file | Passed, 79/79, 0 failed, 0 skipped, 0 expected failures; `Executed 79 tests, with 0 failures` in 2779.194 s; `** TEST SUCCEEDED **`; exit `0`; log closed 03:58 EDT; scope `-only-testing:WorkoutTrackerUITests` |
| Warnings in the full UI log | `full-ui-2.log` | 24 lines, all one class: "Invalid frame dimension (negative or non-finite)", spread across pre-existing lifting/History tests. Prior baseline 22; non-failing; origin still uninvestigated and already tracked in STATE |

Frozen-source claim checked by diff: `03ada3d..ff63a47` touches no file under `WorkoutTracker/`,
`WorkoutTrackerTests/`, `Config/` or the project; the only test path changed is
`WorkoutTrackerUITests/CardioUITests.swift`. Timing is consistent: `306acf4` was committed at
03:05, `focused-ui-6` closed at 03:12 and `full-ui-2` at 03:58; later commits are docs and
captures. No `xcodebuild` process was running when I checked.

## Final test-only change (`03ada3d..306acf4`)

One line: `app.buttons["Cancel"].tap()` became
`app.navigationBars["Choose Cardio"].buttons["Cancel"].tap()`. While the replacement picker
is up, the workout header's Cancel and the sheet's Cancel both exist, so the unscoped query was
ambiguous; the author reproduced exit 65 in isolation before changing it. The scoped query is
the correct one and narrows rather than weakens the test: it still requires the picker's own
Cancel to exist and dismiss. The header's Cancel opens the discard-workout confirmation, so
hitting it by accident would have been a worse test, not a product defect. No product change
was needed. Accepted.

## Regression check of the existing lifting screen

Four native captures in `screenshots/regression/` (default, AccessibilityL and two scrolled
AccessibilityL). A lifting-only workout shows no Lifting/Cardio switch, the heart-rate bar,
the set table, Add Exercise as the one primary, Add by Machine, the new secondary Add Cardio,
and the rest bar with +15s and Skip intact in the bottom inset. At AccessibilityL the three add
buttons stack and nothing new is truncated. No regression found.

## Review trail

| Report | Subject | Outcome |
|---|---|---|
| `claude-review-01.md` | `b359d7c` | Not clear: F1 High, F2–F4 Medium |
| `claude-review-02.md` | `d0bcb54` | F1–F4 resolved; N1, N2 Medium |
| `claude-review-03.md` | `03ada3d` | N1, N2 resolved; **code clear** |
| `claude-visual-01.md` | 21 captures | Not clear: A1–A3, V1, V6 |
| `claude-visual-02.md` | 29 captures | **Visual clear**; W1–W4 Low recorded |

Open Low items accepted into the ticket, none blocking: F6 route re-encode cost, F8 short
lifting phases saved to Health, N3 phase-switch energy edge, R1 rest bar hidden in Cardio
focus, R2 finish-time row deletion, V3/V4 recorded exceptions, W1–W4, and two copy notes.

## Conditions on this clearance

1. **Commit and push the evidence before merging.** The implementation checkout still has
   uncommitted edits to `docs/STATE.md` and `work-record/cardio/issues/01-implementation.md`
   and an untracked `work-record/cardio/screenshots/regression/` folder. The actual
   `full-ui-2` result, counts, warning class and the regression captures must be in the
   committed record that reaches `main`, with this clearance copied beside the other reports.
2. **Merge only the reviewed source.** Fast-forward `main` from a tip whose product and test
   trees equal `03ada3d`/`306acf4`. Any further product or test change voids this clearance
   for that change and needs a re-review. After pushing, confirm the remote contains the tip.

## Explicitly outstanding after merge

- **Real-device acceptance, not established by anything reviewed:** AirPods Pro 3 indoor
  walk/run distance and pace (phone carried and phone stationary), HealthKit statistics timing
  on iPhone, pause/resume and disconnect behaviour, and outdoor GPS with the screen locked and
  the app backgrounded. Simulator fixtures and the seeded route are not evidence of any of it.
  If indoor distance does not arrive on hardware, the manual and phone-motion fallbacks must be
  described as such, not as AirPods support.
- **Watch:** the companion remains unbuilt, uninstalled and strength-only; cardio phases
  exclude it. No Watch cardio support is claimed.
- **No phone install is cleared.** This change adds models and fields to the store (export
  schema 10). Before any install, follow DEVELOPMENT: fresh export and raw backup, migration
  checks against a current store rather than only the synthetic fixtures, signing and binary
  freshness, and launch verification. The installed build stays `4d70d7d` until the user asks.
- CI runs after merge in this workflow; local verification above is the gate.
