# Codex cross-review 01b — Apple-shaped heart-rate graph

Review boundary: `32dad6f..cb6559f` (`cb6559f`, one commit).

Verdict: **do not merge yet.** The fixture, export-pair, and schema-documentation findings are closed. The duration finding is only partially closed, and its regression test misses both remaining caller/merge cases.

## Standards

### Low — contradictory source documentation

- `WorkoutTracker/Domain/ChartFixture.swift:15-17` still says the fixture argument “also selects the throwaway UI-test container,” while the new explanation at `WorkoutTracker/Domain/ChartFixture.swift:27-32` correctly says that the argument never selected it and that `-uiTestReset` is separately required. The guard is safe now; the file's two explanations cannot both be true.

### Low — judgement call: possible Duplicated Code

- `WorkoutTracker/Domain/ChartFixture.swift:31-33` and `WorkoutTracker/Domain/HeartRateHistoryFixture.swift:30-32` duplicate the exact safety rule `fixture flag && reset flag`. This fix already had to repair two files for the same defect. A shared fixture-enablement helper on `WorkoutTrackerStore` would give the “never seed a real store” invariant one owner instead of relying on every future fixture to copy it correctly.

No documented repository-standard violation remains. `docs/SPEC.md:102` now names schema 9 and its pair invariant; `docs/STATE.md:113` accurately distinguishes milestone 9's original schema 8 from the current schema 9. The new decision logic remains pure in `Domain/` and unit-tested.

## Spec

### Medium

- `WorkoutTracker/Domain/HeartRateSeries.swift:153-176` — the positive-duration horizon is applied **after** `perSlot` is derived from the entire corrupt series and after every bucket in the slot has contributed to `lowest`/`highest`. With 111 buckets and the default cap, `perSlot == 2`; if duration is 10 seconds, bucket 0 is `118...125`, and bucket 1 is `185...195`, the retained slot is clamped to `0...10` but still reports `118...195`. Post-duration data therefore still changes the visible bar and y-axis. A long corrupt tail also forces needless merging of the few in-horizon buckets, violating the bucket-for-bucket behavior of what is effectively a short series. Derive an effective bucket count from the positive horizon before calculating `perSlot`/`slotCount` and before aggregating ranges. The new test at `WorkoutTrackerTests/HeartRateSeriesTests.swift:184-193` uses only two buckets, so `perSlot == 1` and cannot catch this.

- `WorkoutTracker/Features/History/HeartRateSummarySection.swift:39-44` — the helper now defines a non-positive duration as “no horizon,” but the real caller converts every non-positive duration to `xEnd == 1` and passes that as a positive horizon. A two-bucket series with duration 0 is consequently clipped to one second and only its first display slot survives, rather than using the nominal 30-second series extent. The direct Domain assertion at `WorkoutTrackerTests/HeartRateSeriesTests.swift:190-193` passes `0` itself and never exercises this view-facing conversion. Derive `xEnd` from the series extent when duration is non-positive, then pass that sensible extent to both `displaySlots` and the chart scale.

The other three Round 1 findings are closed exactly. Both fixtures expose pure `isEnabled(arguments:)` checks requiring their own flag plus `WorkoutTrackerStore.uiTestResetArgument`; every UI launch using either fixture supplies both flags, and the app's only seed calls go through those guarded properties. `HeartRateSeriesMath.exportableRange` returns one tuple only when the mean is non-empty and both arrays match its length, and `ExportCollector.swift:248-281` reads both optional fields from that one tuple, so it cannot emit only one. SPEC and STATE now identify schema 9.

Regression audit against `32dad6f`: all three new tests reject the old implementation. The fixture and export tests reference pure helpers absent at `32dad6f` and therefore do not compile there; behaviorally, the old fixture accepts its flag alone and the old collector emits the mismatched arrays independently. The duration test's first three assertions fail against the old code because it returns two slots and range `118...195`; only its duration-0 sub-assertion already passed. No history rewrite was used.

Verification: `git diff --check 32dad6f..cb6559f` passed. The current `HeartRateSeriesTests` suite passed **24/24**, including all three new regressions; that green run does not cover either duration case above.

Summary: Standards — 2 low findings (worst: contradictory fixture documentation). Spec — 2 medium findings (worst: post-horizon buckets still contaminate merged display slots).
