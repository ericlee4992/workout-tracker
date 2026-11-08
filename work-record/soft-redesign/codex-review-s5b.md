# S5 independent review — Round 2

Reviewed 2026-11-08 by Codex; implementation by Claude.

## Scope

Reviewed `git diff bd09df9..5248d44 -- WorkoutTracker WorkoutTrackerTests WorkoutTrackerUITests` against the three
Round 1 findings and the updated brief. Branch `ericlee4992/soft-05-today-up-next`, initial HEAD
`11241f5e0167952eb356003593e628397035b847`. Read the current state, ticket, relevant callers/tests, and item 7 of
`work-record/dev-speed/issues/01-testing-workflow.md`. Only this report was written in the repository; no commit
or push. Own simulator work used WT-iPhone27. The existing Test progress (Claude r2) tab was reused; no new terminal.

## Standards

No additional standards findings. The fixes preserve existing assertions, shared Today/Train reading, stored
preference shape, and application start paths. The new UI assertion extends the Choose → Next sequence rather
than removing checks.

## Spec

### 1. P2 — Next in order still cannot advance without recent real history

**Location:** `WorkoutTracker/Domain/UpNext.swift:103–105,139–141,173–175`.

With My split Off and three unused templates (Push, Pull, Legs), the fallback initially suggests Legs. Repeated
Next in order continues to suggest Legs. Choosing Pull manually and then pressing Next repeatedly likewise keeps
Pull. This is a normal first-use/new-template case covered by the ticket's all-template fallback and its promise
that Next skips the displayed suggestion.

The simulated completed run becomes the only template considered used within the 42-day window. The fallback
then restricts its pool to that same synthetic template, so every subsequent skip repeats it. The new chosen-run
path has the same problem. The ordered-split and established learned-cycle examples now work, but Round 1 finding 2
is not fully closed.

**Fix:** keep real-history eligibility separate from virtual advancement. With no recent real history, skip through
the all-template fallback pool rather than narrowing it to the synthetic run. Add focused tests for multiple unused
templates, repeated Next, Choose → Next, wraparound, and history entirely outside the 42-day window.

**Reproduction:** `/tmp/codex-s5/round2/spec-repro.swift` uses the reviewed `UpNext.swift` and the existing
`TemplateStats.dueNext` implementation. It ran with **exit 0** and produced:

```text
No history, no manual choice, skip 0..3: Legs each time
No history, chose Pull, skip 0..3: Pull each time
```

Full output: `/tmp/codex-s5/round2/spec-repro.log`. This is a deterministic domain reproduction, not a UI-test
failure. The current tests cover established rhythms and explicit ordered splits, not this fallback transition.

## Closure of the other findings

- **Round 1 #1 — closed:** `UpNextReading.make` reads the render-time clock and uses the later of it and the day
  snapshot. Query-driven renders after a finish admit the new run for both Today and Train. The new in-memory
  `UpNextReadingTests` case verifies advancement with a snapshot an hour old.
- **Round 1 #2 — partially closed:** Choose resets skip, Next retains the chosen template, and ordered/established
  learned cycles advance and wrap correctly. Weekday mode retains its documented progression through assigned
  dates; a manually chosen template need not have a unique assigned weekday. The missing no-recent-history path
  above remains actionable.
- **Round 1 #3 — closed:** the reading selects the latest actual `finishedAt` not later than the effective current
  time. `isCurrent` also rejects future completions as an expiry trigger, and a workout started before the choice
  but completed after it expires the choice. Future starts are also excluded from the Last done caption.

## Verification

**Verified independently:** Xcode 27.2 (27B52), iOS 27.0, WT-iPhone27
`47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`. Artifacts: `/tmp/codex-s5/round2/`; rebuilt using
`/tmp/codex-s5/DerivedData`.

- `build-for-testing`: **exit 0**, xcresult `succeeded`, **0 errors, 12 warnings** in the incremental build.
  Evidence: `build.log`, `build.xcresult`, `build-summary.json`.
- Requested serial units: **exit 0**, **16 passed, 0 failed, 0 skipped** — `UpNextTests` 15 and
  `UpNextReadingTests` 1. Evidence: `unit.log`, `unit.xcresult`; counts read directly from the result summary.
- Pure-code reproduction above: **exit 0**, with the incorrect outputs recorded explicitly.
- `git diff --check bd09df9..5248d44 -- WorkoutTracker WorkoutTrackerTests WorkoutTrackerUITests`: **exit 0**.

**UI evidence reviewed, not rerun:** Claude's `s5ui5.status` records **exit 0** and its xcresult confirms
**10 passed, 0 failed, 0 skipped** (warm-up 1 + TodayUpNext 9) on WT-Floodlight. The log at lines 656–665 contains
the added Next tap followed by the `Start Push Day` assertion. Evidence base:
`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/7de0aa3c-5c42-4616-b226-c172ad5bea55/scratchpad/`
(`s5ui5.log`, `s5ui5.status`, `s5ui5.xcresult`).

**Not verified:** no additional UI suite, device install, or fresh capture matrix was run in this round. Per the
updated brief, the completed UI evidence was inspected. The remaining concern is fully reproducible in pure domain
code; rerunning the existing history-based UI fixture would not cover it. A focused domain regression test is the
appropriate next check. Round 1's visual evidence remains applicable to the unchanged layout.

**Known flaky:** the previously tracked cardio-start/warm-up issue remains a separate follow-up; Claude's reviewed
UI run passed it. This review does not claim the flake has been eliminated.

Standards: **0 additional findings**. Spec: **1 P2**. Resolve the remaining fallback transition and re-review.

Verdict: not clear
