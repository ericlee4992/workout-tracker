# Codex review 02 — Round 1

## Standards

- **Medium — hard standards violation: the mandatory source-of-truth state is stale.** `CLAUDE.md:3-7` says cold agents must treat `docs/STATE.md` as the first and current source of truth, but `docs/STATE.md:13`, `:170`, `:239`, and `:393-395` still describe `≈` as following chart contributors and the `(estimated)` mark as required or awaiting verification. That now contradicts D52 and can send the next agent toward restoring deliberately removed UI. Ticket 02 explicitly required updating “STATE” (`work-record/finish-graph-and-plain-numbers/issues/02-remove-approx-and-estimated.md:28-29`), yet STATE is absent from the commit.

- **Low — judgment call, Duplicated Code / Shotgun Surgery:** canonical-kg conversion and plain number/unit composition remain independently implemented in `WorkoutTracker/Features/ActiveWorkout/PreviousPerformanceSheet.swift:141-145`, `WorkoutTracker/Features/ActiveWorkout/WorkoutFinishedSheet.swift:178-183`, and `WorkoutTracker/Features/History/ExerciseProgressView.swift:244-253,285-289`. D52 therefore required the same presentation-policy edit in three feature modules. A `WeightMath` helper for rendering canonical kg in a requested unit would centralize conversion, rounding, suffixing, and any future display-policy change, in line with `CLAUDE.md:29`; the labels represent different concepts, so this is a maintainability judgment rather than a hard violation.

## Spec

- **Medium — the central removal is incomplete.** `WorkoutTracker/Features/History/ExerciseProgressView.swift:43` still defines `case e1rm = "Est. 1RM"`, and `:75-77` renders that raw value in the on-screen metric picker. The ticket says, “Every on-screen ≈ and every on-screen ‘estimated’ / ‘(estimated)’ / ‘est.’ goes” (`issues/02-remove-approx-and-estimated.md:9-11`). This is the lone surviving prohibited UI literal across the app, widget, and watch targets, and it makes the resolution’s “Every on-screen mark is gone” and metric “1RM” claims (`:45-46`, `:52-53`) false.

- **Low — STATE was required but omitted.** Independently of the standards breach above, `docs/STATE.md:13`, `:170`, `:239`, and `:393-395` leave current/open work that promises marks D52 removed, despite the explicit “Docs: ... STATE” requirement (`issues/02-remove-approx-and-estimated.md:28-29`). Historical wording at `docs/STATE.md:223` is harmless; these current claims are not.

- **Low — the promised WeightMath comment cleanup is incomplete.** `WorkoutTracker/Domain/WeightMath.swift:3-5` still says converted display values “are marked with ≈,” directly contradicting its implementation at `:56-66`. The ticket specifically required misleading WeightMath comments to be updated (`issues/02-remove-approx-and-estimated.md:24-26`), and the resolution claims they were (`:57-59`).

- **Low — the decision documentation contains false or self-contradictory claims.** `docs/DECISIONS.md:54` still begins D45 with the bold rule that an estimated maximum “is marked as estimated wherever it reaches a screen,” then immediately says that on-screen rule was dropped. At `docs/DECISIONS.md:61`, D52 says “no conversion is ever stored (D25),” but `WorkoutTracker/Domain/Models.swift:528-533` intentionally persists `normalizedKg`, which is a conversion for every pound entry; the truthful invariant is that a converted *display* value never replaces the stored as-entered pair. These fail the prompt’s requirement to check the annotated decisions for consistency and every D52 claim for truth (`codex-review-02-prompt.md:4-7,37-40`). D52’s stated user-facing costs themselves are accurate.

- **Low — CLAUDE’s decision index was not advanced.** The same commit adds D52 and edits `CLAUDE.md`, but `CLAUDE.md:7` still tells cold agents that `docs/DECISIONS.md` contains only D1–D51. This is a stale source-of-truth claim introduced by adding the new decision without updating its index.

Verification: `git diff --check 8e6e43a..2262b0f` passed; the diff contains exactly 17 files; the full unit run passed 654 tests in 64 suites; and the six named UI classes passed 25/25. The `hrZoneEdit` button retains the old condition and action, no app/test reference to `hrZoneEstimated` remains, the three `ProgressPoint` provenance fields are still produced and domain-tested, the inverted prefix assertions would fail if the prefix returned, and `CodexReviewRegressionTests` 1.1 still asserts the stored data flag.

Summary: Standards — 2 findings, worst Medium (stale mandatory source of truth). Spec — 5 findings, worst Medium (surviving on-screen `Est. 1RM`).
