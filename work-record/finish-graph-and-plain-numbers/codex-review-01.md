# Codex cross-review 01 — Apple-shaped heart-rate graph

Review boundary: `af0a52a..32dad6f` (`32dad6f`, one commit).

Verdict: **do not merge yet.** The graph and fold are sound on valid data, but the screenshot fixture can write synthetic history into the real store, and schema 9 is not kept self-consistent at either the export boundary or in the source-of-truth docs.

## Standards

### Medium — hard standards violation

- `docs/STATE.md:113` and `docs/SPEC.md:102` still declare export schema 8, while `WorkoutTracker/Domain/ExportSnapshot.swift:55` emits schema 9. `CLAUDE.md:3-7` makes STATE and SPEC the repository's sources of truth; both are now false about the current backup format. This is not harmless stale prose: a future implementation following SPEC can reject, mislabel, or downgrade a real v9 backup. Update both schema statements and the v9 field description together.

No additional documented-standard breach warrants a finding. The new pure logic is correctly in `Domain/`, the persisted fields are CloudKit-safe scalar arrays with migration defaults, and the synchronized project layout requires no `project.pbxproj` edit.

## Spec

### High

- `WorkoutTracker/App/WorkoutTrackerApp.swift:14-16` and `WorkoutTracker/App/WorkoutTrackerApp.swift:40-42` — `-uiTestHeartRateHistory` does **not** imply a throwaway store. The container switches only when the separate `-uiTestReset` flag is present, but fixture seeding checks only its own flag at `WorkoutTracker/Domain/HeartRateHistoryFixture.swift:20-24`. Launching the app with the screenshot flag alone therefore runs `seed` against the normal container and, when that store has no workout, inserts fake workout history. The claim at `HeartRateHistoryFixture.swift:15-16` that the argument “also selects the throwaway UI-test container” is false. The UI test hides the defect by supplying both flags. Refuse fixture enablement unless `WorkoutTrackerStore.isUITestReset` is also true, or make the fixture flag itself select the test container.

### Medium

- `WorkoutTracker/Domain/ExportCollector.swift:272-275` — schema 9 does not enforce that low/high travel with the mean. The four fields are omitted independently, while `WorkoutTracker/Domain/Models.swift:380-383` permits independently populated arrays. A workout can therefore export low/high with no mean, only one range array, or mismatched lengths, contradicting the ticket's “beside the mean” contract (`issues/01-apple-shaped-heart-rate-graph.md:13-15`), the resolution's “same shape as the mean array” claim (`:59-62`), and `WorkoutTracker/Domain/ExportSnapshot.swift:249-252`. Current capture and fixture writers happen to be coherent; the export boundary is not. Validate equal non-empty lengths against the mean and omit the entire range pair otherwise.

- `WorkoutTracker/Domain/HeartRateSeries.swift:157-174` — corrupt durations are not clamped. When `durationSeconds <= startSeconds`, line 171 deliberately falls back to the nominal bucket end. For two 15-second non-gap buckets and duration 10, the helper returns a second slot spanning 15...30, wholly outside the workout. `HeartRateSummarySection.swift:39-48,106-107` clips that mark outside the x-domain but still includes its values in `drawnRange`, so invisible post-duration data can set the visible y-axis. This contradicts the resolution's unconditional claim that the last slot ends at the workout's end (`issues/01-apple-shaped-heart-rate-graph.md:65-69`). Drop slots starting at/after duration and clamp every surviving end.

No chart-shape defect was reproduced. The extracted `history-heart-rate-hour` attachment shows thin floating red ranges, visible gaps, two right-edge values, three fitting clock labels, and the average below the plot. The single-value y-domain has nonzero padding; the +/-0.5 ink contains the labelled extrema; `.shortened` respects 24-hour locales; both callers pass `summary.date`; and the accessibility summary remains truthful for valid records. The fold initializes low from the first admitted positive sample, applies one admission/cap horizon to all three arrays, guarantees `low <= mean <= high`, and leaves gaps at `0/0/0`. Display-slot ceiling math stays at or below the cap, a zero range entry falls back to its positive mean, mismatched arrays fall back wholesale, and the v8 mean-range fallback is documented in both the feature spec and product SPEC. All named new identifiers have callers. All three schema-version assertions moved from 8 to 9. The fixture generator is deterministic, preserves its invariants, and sets maximum heart rate to `max(high)`. Nothing in this diff touches Live Activity, alarm, notification, or deadline execution paths; D46 is unaffected.

Verification: `git diff --check af0a52a..32dad6f` passed. The full unit suite passed **649/649 in 64 suites**. The focused hour-long History UI test passed and produced the inspected `history-heart-rate-hour` attachment. The named UI classes contain the claimed 3 + 5 + 9 + 2 = 19 tests; only the new screenshot test was independently rerun in this review.

Summary: Standards — 1 finding (worst: medium, both source-of-truth docs still advertise schema 8). Spec — 3 findings (worst: high, the fixture flag can seed synthetic history into the real store).
