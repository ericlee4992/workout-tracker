Cross-review (T6) of the finish-graph work, ticket 02, on branch
finish-graph-and-plain-numbers. Review boundary: 8e6e43a..2262b0f (one commit,
2262b0f). Read .scratch/finish-graph-and-plain-numbers/spec.md and
issues/02-remove-approx-and-estimated.md, and docs/DECISIONS.md D9, D25, D45
and the NEW D52 (this commit writes it — review the decision text itself as
part of the boundary: is the cost stated truthfully, is anything it claims
false?).

## What was built

Copy-only removal of every on-screen ≈ and "estimated"/"(estimated)"/"est."
plus the WeightMath.displayLabel prefix: WorkoutFinishedSheet (volume, zone
header, `summaryZonesEstimated` deleted), PreviousPerformanceSheet ("1RM
(Brzycki)"), ExerciseProgressView (calloutValue, unitSuffix now constant,
"1RM"), AppSettingsSection, HeartRateBar ("· edit zones", identifier
`hrZoneEdit`), MaxHeartRateSheet (preview, "Date of birth" header). Data
fields untouched. Tests inverted in WeightMathTests, HistoryRenderingTests,
DisplayUnitTests. D52 + D9/D25/D45 annotations; SPEC 55/71/93; CLAUDE.md.

## Specific things to attack

1. **Completeness.** Grep the whole app target for any surviving on-screen
   ≈ or "estimat"/"est." string — including string interpolations,
   accessibility labels, alert messages, the widget target, and the watch
   sketch. Comments are allowed to keep the word; screens are not.
2. **Reachability (D45's corollary).** The "· zone estimated" button was the
   mid-workout way to the measured-max field. Is "· edit zones" rendered
   under exactly the same condition, still tappable, and does any test or
   identifier reference the old `hrZoneEstimated`?
3. **Dead code and absence of a caller.** `ProgressPoint.enteredUnits`,
   `bestUnit`, `e1rmUnit` lost their only VIEW consumer. Are they still
   produced and tested in Domain (they should be — D52 says the data keeps
   its provenance)? Anything else left uncalled by these edits?
4. **Tests.** Were any tests weakened rather than inverted? Does every
   inverted test still fail if the prefix came back? Does
   `CodexReviewRegressionTests` 1.1 still assert the data flag?
5. **Docs.** SPEC's copy-policy line, the convert-toggle line, and the
   preferences line; the CLAUDE.md convention; the three annotated decision
   rows — consistent with each other and with the code? Does anything in
   docs/ or the app still promise a mark that no longer exists?
6. **Every claim in the resolution and commit message true**, including
   the 17-file count and the test counts.

Report by severity with file:line, do not soften. Do not modify source
files. Write to .scratch/finish-graph-and-plain-numbers/codex-review-02.md
