# Codex review — ticket 20, round 2

Reviewed 2026-10-18: `git diff 19438e7..bd7a2b9` on
`ericlee4992/beta-19-bug-fixes`, HEAD `bd7a2b957dcd965ba07e2f1d1bbd8e41321ae4aa`.
Read the round-2 prompt and ticket response against the round-1 findings. Working tree was clean.

## Standards

**P3 closed.** `README.md:46` now explicitly describes removing one set, exercise or cardio
activity from History. Retaining the existing screenshots is appropriate: the gallery does
not show the changed workout-detail screen. No new standards findings.

## Spec and acceptance

**P2 closed.** `WorkoutTrackerTests/CardioHistoryDeleteTests.swift:90` now creates an outdoor
run with a 61-point route and 1.8 km distance, plus a separate outdoor walk with its own route.
The test asserts the run has a nonempty route and multiple splits before deletion. It then
deletes the run, saves, and uses a fresh `ModelContext` to verify that only the walk's segment
remains, its route count is preserved, the workout contains only the walk, and export contains
exactly that surviving activity. Splits derive from the deleted segment's data; they are not
separately stored entities. This closes the requested route/split persistence and export
regression without relying on the deleting context's cached relationships.

No new spec findings or product regressions identified. The complete diff contains only the
README, this test addition, the prior review report, the ticket response and the round-2 prompt.
Application source, UI tests, build configuration, schema and images are unchanged.

## Independent verification

Ran:

```sh
xcodebuild test -project WorkoutTracker.xcodeproj -scheme WorkoutTracker \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' \
  -derivedDataPath /tmp/codex-20/DerivedData \
  -resultBundlePath /tmp/codex-20/unit-round2.xcresult \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -only-testing:WorkoutTrackerTests/CardioHistoryDeleteTests \
  -only-testing:WorkoutTrackerTests/CardioExportTests
```

**Exit 0; TEST SUCCEEDED; 6 passed, 0 failed, 0 skipped.** Inspected the actual process exit,
`/tmp/codex-20/unit-round2.status`, `unit-round2.log`, and xcresult summary. The result confirms
WT-Floodlight on iOS **27.0** and no runtime warnings.

`git diff --check 19438e7..bd7a2b9`: **exit 0**. No separate build or UI rerun was needed:
product/UI sources are unchanged, the test command rebuilt the changed test target, and the
round-1 successful product build and UI evidence remain applicable. Independent UI tests were
skipped; round-1 runtime/VoiceOver coverage limitations remain unchanged.

Only this new report was written. No commit or push.
Standards: **0 open findings**. Spec/acceptance: **0 open findings**.

Verdict: clear
