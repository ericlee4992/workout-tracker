# Codex cross-review 05e — Finish summary heart-rate graph

Review boundary: `4748203...59267bc` (commit `59267bc`). Verdict: **not clear**.

## Standards

### Low — Possible Speculative Generality remains in `liveVitals`

`HeartRateMonitor.liveVitals` is documented as serving “the LIVE screen and tests,” but no production code calls it; repository-wide, only `HeartRateMonitorTests` and `CodexReviewRegressionTests` reference it (WorkoutTracker/Domain/HeartRateMonitor.swift:155-164). Renaming the old unbounded `vitals` property makes its semantics honest, but it does not close round 4's unused-abstraction finding, and the live-screen claim is currently false. Remove the property and have those tests exercise the pure summary math or bounded API directly, unless a real production caller is intended. This remains a low-severity **Speculative Generality** judgement call, not a documented-standard violation.

The substantive Standards finding is closed. `summarySamples(from:to:)` bounds raw samples inclusively before both source selection and handoff merging; the extracted pure `dominantSource(among:)` preserves the previous count rule and higher-precedence tie-break; and `coordinator.end` passes the same bounded result to the aggregate and series folds (WorkoutTracker/Domain/HeartRateMonitor.swift:143-177, WorkoutTracker/Domain/WorkoutVitals.swift:42-51, WorkoutTracker/Domain/WorkoutHeartRateCoordinator.swift:107-128).

## Spec

Clear. `HeartRateMonitor.summarySamples(from:to:)` first applies `[start, end]` to the raw samples, then chooses the dominant source from only that bounded collection and merges handoffs (WorkoutTracker/Domain/HeartRateMonitor.swift:166-177). `WorkoutHeartRateCoordinator.end` captures one end instant—recorded `finishedAt` or the current time for an active workout—and uses the resulting collection for both vitals and series (WorkoutTracker/Domain/WorkoutHeartRateCoordinator.swift:107-128). `WorkoutSummaryBuilder.capture` has no other production caller, and no production path reaches `liveVitals` or otherwise persists an unbounded summary. The new cross-source regression directly covers the prior post-finish dominance failure (WorkoutTrackerTests/HeartRateSeriesTests.swift:285-307). No missing, incorrect, or out-of-scope Spec behavior was introduced.

`HeartRateSeriesTests`, `HeartRateMonitorTests`, and `CodexReviewRegressionTests` passed 43/43. `git diff --check 4748203...59267bc` passes. No source files were modified by this review.

Standards — 1 finding (worst: Low); Spec — 0 findings (clear).
