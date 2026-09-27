# Codex independent review — ticket 06, round 2

2026-09-27. **Not clear: one medium finding remains.** Reviewed `d49a5b9..39db76c29076fa5488f7f839f3939a34ec2e3b5b` on `ericlee4992/redesign-floodlight-gyms` in `/tmp/wt-floodlight/gyms`. The working tree was clean before this report. No `xcodebuild` or `simctl` was run; only this report was written.

## Medium — Grouping buttons still shrink below 44 pt at smaller text sizes

**`WorkoutTracker/Features/Gyms/GymDetailView.swift:365`** — round-1 finding 6 is partially resolved.

Moving the vertical padding inside each button fixes the default-size hit region, but its height is still `height + 6`, where `height` is `@ScaledMetric(relativeTo: .subheadline)` starting at 38 (line 341). At Small or xSmall Dynamic Type, the metric becomes smaller than 38, so the individual rectangular hit regions become smaller than 44 pt. Neither this screen nor the app imposes a lower Dynamic Type bound. The fix also removes the enclosing group's previous 44 pt minimum.

**Failure case:** select Small text size and open a gym with at least two machines. The Body area / Exercise / A–Z buttons have targets below the minimum required by REVIEW item 7. This is established by the layout code; no new runtime measurement is claimed.

Add `.frame(minHeight: 44)` inside each button after its padding and before `.contentShape(Rectangle())`, or compensate for the scaled height as `TypeChip` already does in `ModelPicker.swift:436`. Check the individual target bounds at Small as well as default size. The existing default and AXL checks do not cover this case.

## Resolution of the other findings

| Round-1 finding | Round-2 assessment |
|---|---|
| 1 — Chart mixes exercises | Resolved. The view calls `GymOverviewMath.series(of:on:in:)`, which filters the exercise before applying the existing equipment/preset/load-type scope. The new station regression test passed. |
| 2 — Warmup usage counts | Resolved. Scopes group completed sets first; counts and recency include warmups, while best selection still requires eligibility. Entirely warmup-only scopes have usage and no best. The new count/order test passed. |
| 3 — Frozen names | Resolved. Snapshot exercise/preset names reach `MachineBest.title`; live-name lookup is removed, and the progress sheet receives the exercise name separately. The two-preset value test and real-store exercise-rename test passed. |
| 4 — Home's archived selection | Resolved. Delete clears the matching remembered ID, and Home clears its cached gym when that object becomes archived. The new current-gym deletion UI test passed. |
| 5 — Reduce Motion | Resolved for the reported paths. The monogram replacement uses opacity under Reduce Motion; New Model gates its type/chip animations and symbol replacement. Verified by source, not a new motion test. |
| 7 — Assisted VoiceOver label | Resolved. Secondary bests now include “Assisted” in their replacement label. Verified by source. |
| 8 — Visit-rhythm VoiceOver label | Resolved. The gym card now includes the eight weekly counts when it draws the rhythm. Verified by source. |

No additional regression was established in the reviewed fixes.

## Verification evidence

Independently read `/tmp/wt-floodlight/results/gyms-ui-4.exit`, the log, and the xcresult summary and individual test records: **exit 0; 52/52 passed; zero failures or skipped tests**. This comprises 39 unit tests (GymOverview 12, EquipmentLifecycle 12, ProgressSeries 15) and 13 UI tests (GymsFlows 3, CoreLoop 9, the light/default Gyms capture 1). The named new regression tests are present and passed. The result retains four invalid-frame runtime warnings; these are not test failures and are already recorded as an unresolved project issue. The targeted scope is appropriate under DEVELOPMENT; resolving the remaining hit-region issue calls for a focused Small-size bounds check, not a full UI suite.
