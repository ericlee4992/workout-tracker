# C1 + N9b independent review — round 1

Reviewed by Codex on 2026-11-10–11 in the continuing reviewer session. Branch `ericlee4992/c1-n9b`, requested and initially clean HEAD `09e471b413408307a4b0628412810ffc75e43ee9`; diff `ed4ec5a..09e471b`. Read the combined brief, both tickets, relevant decisions (D52/D71/D74/D80/D83), project verification rules and applicable review/SwiftUI/SwiftData/design guidance. Separate standards and spec passes completed. Reviewer changes only this report; no commit, push, deployment or phone installation. No live inference request or key access.

## Standards

### T1 — P2: Imported Health weight enters outgoing Ask AI requests

`WorkoutTracker/Domain/HealthNutritionSync.swift:389–391`, with `Features/Templates/AIRoutineSheet.swift:198–203,209–218`, `Features/Templates/AIRoutine/AIRoutineFlowModel.swift:144–146,219–221`, and `Domain/NutritionGoalStore.swift:45–48`.

Import a recent scale weight from Health, then open Ask AI with no weight in the saved training profile. The new `.health` row becomes `latestWeight`; Ask AI automatically uses that value as its fallback and marks it as typed. Generate includes it in the outgoing routine request. If Save to my training profile is enabled, it also enters the account's server-side profile. This is a user-triggered generation with an automatic Health-derived prefill, not a background upload.

That path contradicts the newly approved Health usage string and `AppleHealthView.swift:63` promising that Stacked does not upload Health data. The privacy draft makes the same promise (`server/src/pages.ts:40–46`). The issue is new Health data entering an existing consumer, even though the consumer files themselves are unchanged.

**Fix:** restrict the automatic remote-routine/profile fallback to app-entered weights, while preserving Health readings for local display and nutrition calculations. If sending Health-derived measurements is intended instead, explicitly reopen the privacy decision and obtain appropriate user-approved behavior/disclosures. Add a focused integration regression with a newer Health weight and an older app weight, and with a Health-only history. This finding is source-traced; no live upload was performed.

C1's wording changes otherwise follow the approved scope. The exhaustive string review found documented feature names/exemptions, comments and fixture strings; shared error splits retain sensible title/action text, and expectations moved. Camera/library disclosures are the ticket's explicitly deferred wording exception, not an unreported missed substitution. iPhone Debug/Release Health strings match the approved wording with typeset apostrophes; Watch strings are unchanged.

## Spec

### S1 — P2: Turning a part off does not invalidate its outstanding pass

`Domain/HealthNutritionSync.swift:275–282,326–360,378–393`; `Features/Nutrition/AppleHealthView.swift:45–50`.

A background weight query can suspend, the user can turn Read body weight off, and the late reply then inserts Health rows again. Later passes skip that disabled part, so the imported rows remain. Similarly, a write query begun while enabled can finish after the switch is off and initiate a new save. Disabling controls during authorization does not cover an ordinary sync query.

**Reproduced:** the unmodified production engine, compiled with minimal SwiftData domain stubs and a suspending `HealthStoring`, inserted one Health row after read-off; the row survived another sync while off. A write-off case submitted one weight after the pending query resumed. Evidence: `/tmp/codex-c1n9b/health-engine-probe-stubs.swift`, `health-engine-probe.log/.status`, build/run **exit 0**. This is an engine probe on macOS, not real HealthKit or app UI.

**Fix:** invalidate each part's generation when settings change, and recheck enabled state/generation after awaits before importing, deleting, or initiating saves. Add delayed read and write-query tests that toggle off before delivery. An already-submitted Health operation is different from the reproduced case, where saving starts only after off.

### S2 — P2: The comparison tolerance drops ordinary weight edits

`Domain/HealthNutritionSync.swift:162–163`.

The relative tolerance is 0.1%, not merely floating-point conversion noise. An edit from **100.0 to 100.1 kg**, one supported editor step with its measurement time unchanged, is considered identical (`0.1 < 0.1001`). Health keeps the old value. The engine probe above produced **zero planned saves and one match** for that edit. Similar small deliberate food changes can be suppressed.

**Fix:** use a tight numerical comparison appropriate for conversion error, or a revision/payload comparison that preserves deliberate edits. Test the normal kg/lb editor steps and small nutrition edits. D74 requires writes to follow edits; display rounding must not decide whether an edit reaches Health.

### S3 — P2: Dirty work is stranded at the three-pass limit

`Domain/HealthNutritionSync.swift:248,304–321`.

A save during a running pass sets `dirty` and returns without scheduling a task. If that save occurs after the third pass has fetched its entries, the loop exits at its cap with `dirty` still set and no follow-up scheduled. The last log/edit/delete remains unsynced until another save or foreground event.

**Reproduced using the actual engine and its real `ModelContext.didSave` observer:** insert/save weights during three successive suspended queries. After the third pass and a two-second wait (beyond the debounce), the app contains **81, 82, 83 kg**, Health's stand-in only **81, 82 kg**, with three queries and two saves. An explicit extra sync then writes 83. No manual `scheduleSync` replaced the observer in this probe. Evidence: `/tmp/codex-c1n9b/health-observer-probe.swift`, `.log/.status`, build/run **exit 0**; minimal domain stubs and fake Health storage, not real HealthKit.

**Fix:** retain bounded batches but schedule a continuation when a batch exits dirty. Test save observation/debounce and a save during the final pass. All existing engine tests that attach a context use `observesSaves: false`, and the fake has no deliberate suspension points, so the current suite cannot exercise this wiring/liveness defect.

### S4 — P2: Wall-clock versions cannot guarantee HealthKit replacement

`Domain/HealthNutritionSync.swift:372`; `Domain/HealthKitNutritionStore.swift:53–56,60–71`.

The version is only `Int(now * 1000)`, and existing Health versions are discarded when querying. If the phone's clock moves backward after a successful write, subsequent edits get a lower version and cannot replace the existing sample until the clock catches up. Equal-version updates have the same ordering problem. The fake replaces unconditionally and ignores the supplied version, masking this contract.

Apple documents that replacement requires a **greater** version, and the SDK header states the same. This is an API-contract finding; the real store's lower-version completion behavior was not exercised. The adapter must also avoid treating a newly allocated UUID as proof that a replacement was accepted. [Apple: sync version](https://developer.apple.com/documentation/healthkit/hkmetadatakeysyncversion), [sync identifier](https://developer.apple.com/documentation/healthkit/hkmetadatakeysyncidentifier).

**Fix:** retain/query existing versions and generate a version strictly above the relevant existing/persisted maximum. Model version ordering in the fake and test equal/backward clocks plus accepted sample-ID write-back.

### S5 — P2: Burned keeps the old day's boundaries after a time-zone change

`Domain/HealthNutritionSync.swift:202,210–215,292–298`; `Features/Today/TodayView.swift:143–145`.

Today explicitly refreshes on time-zone changes, but HealthSync retains `Calendar.current` from launch. That calendar does not track preference changes. After moving from New York to Los Angeles while the app remains alive, Today refreshes its date, yet Health's active-energy query still starts at New York midnight. Burned therefore covers the wrong interval for the current local day; D71's goal/remaining-calorie math remains separate and unchanged.

A process-local Foundation probe at `2026-11-11T01:00Z` demonstrated the retained calendar still starting the day at **05:00Z**, while the new current calendar starts it at **08:00Z**. Evidence: `/tmp/codex-c1n9b/calendar-probe.swift`, `.log/.status`, **exit 0**. This tests calendar semantics, not a device journey. [Apple: Calendar.current](https://developer.apple.com/documentation/foundation/calendar/current).

**Fix:** obtain the current calendar at query time or use an autoupdating default, preserving explicit test injection; refresh/invalidate cached day values when boundaries change. Test a zone change within one HealthSync lifetime and assert the requested start/end.

### S6 — P3: Rename-only food edits leave old metadata in Health

`Domain/HealthNutritionSync.swift:53–62,151–163`; `Domain/HealthKitNutritionStore.swift:53–56`.

Rename a scanned meal without changing its time or nutrients. `HealthWrite.foodName` changes, but the queried `HealthSample` has no food-name field and equality compares only time/value. Nothing is saved, leaving the old `HKMetadataKeyFoodType` in Health. The observer probe's rename-only diff produced zero saves/one match; the adapter source establishes the dropped metadata.

**Fix:** carry and compare the food-name metadata, and replace the affected samples for a name-only edit. Extend the fake to retain the metadata it is meant to model.

### S7 — P3: Existing Health weights do not follow a unit-preference change

`Domain/HealthNutritionSync.swift:383–390,409–412`; `Features/Nutrition/DetailEditorSheets.swift:242–244`.

Read Health weights while using metric units, then change Preferences to U.S. customary. Existing Health UUIDs are matched without refreshing their displayed values/units; `DetailFormat` continues displaying the stored kg. New readings can appear in lb beside old kg readings, contrary to the ticket's choice to show Health readings in the app's unit system. App-entered weights should still retain their entered units.

**Reproduced:** actual engine plus minimal domain stubs prints `80.0 kg` before and after changing preferences to lb and syncing. Evidence: `/tmp/codex-c1n9b/health-unit-probe.swift`, `health-unit-probe-build3.log/.status`, `health-unit-probe-run3.log/.status`, build/run **exit 0**. Earlier scratch compiler-plugin lookup failures are retained separately; these were not app build failures.

**Fix:** render Health-origin rows from normalized kilograms in the current display unit, or explicitly refresh only those mirrored rows on preference changes. Keep app-entered `(value, unit)` unchanged; test an existing Health sample across the preference change.

## Other assessment and coverage

- D71's `max(workouts, Health)` rule is the ticket's documented choice; Today changes only `burned`, leaving goal and calories left untouched. It avoids blindly adding overlapping sources, though it is not a precise reconciliation of partially uploaded workout totals.
- The happy-path plan handles duplicate own sync IDs, zero-macro deletion, refused write types, other apps' sample preservation, own-weight exclusion by sample ID/sync ID/source, and the documented 365-day read window. The real delete predicate includes both source and sync IDs. Apple confirms denied reads reveal only the app's own samples; no request for read permission is needed merely to reconcile its own writes. [Apple: Health authorization](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data).
- Plain dietary quantity samples can support the four totals and independent type permissions. However, the claim in `HealthKitNutritionStore.swift:4–7` and N9b own decision 1 that correlation authorization makes reliable replacement/deletion impossible is not established. HealthKit supports food correlations, and sync-ID replacement updates samples inside their correlations. Correct the rationale and confirm the plain-sample design as a choice; this review does not require changing it solely to satisfy an inaccurate API premise. No real correlation operation was tested. [Apple: correlations](https://developer.apple.com/documentation/healthkit/hkcorrelation), [sync replacement](https://developer.apple.com/documentation/healthkit/hkmetadatakeysyncidentifier).
- Root injection/attachment uses the user's context and excludes the tour's sample world. UI resets select fake Health and separate defaults. Health rows on Body weight are read-only; Log weight takes its unit from the latest app-origin entry. The switches disable during a permission request and show refused-write notes. Those safeguards do not resolve S1's background-query race.
- Omitting the full AskAIUITests class is reasonable for C1's text substitutions alone. It is insufficient reasoning for N9b's new Health-to-Ask-AI data path (T1): add a focused prefill/outgoing-request regression. Running unrelated existing Ask AI cases would not substitute for that missing assertion.

## Verification

Fresh `build-for-testing` into `/tmp/codex-c1n9b/dd`, then unchanged binaries. Prepared WT-iPhone27 **`47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`** first; Xcode **27.2 (27B52)**, iOS **27.0**. Commands/process paths: `/tmp/codex-c1n9b/run.py`, `runner.log`, `runner.pid`. Progress reused the existing requested Orca tab. Scratch engine probes use production `HealthNutritionSync.swift` with explicitly minimal model stubs/fake storage; they do not validate the real HealthKit adapter.

- **Build:** exit **0**, `build.log` / `build.status`. The generated Debug app's approved Health strings were inspected directly and saved as `built-health-usage.json`; Release strings were checked in the project diff.
- **Unit plan, serial:** **1,247/1,247 definitions, 1,267 successful executions, 0 failures, 0 skips**, exit **0**. `unit.xcresult`, `unit-summary.json`, `unit.log` / `.status`.
- **HealthNutritionSyncTests separately, serial ×10:** **15 definitions / 150 successful executions**, **0 failures, 0 skips**, exit **0**. `health10.xcresult`, `health10-summary.json`, `health10.log` / `.status`.
- **Requested UI selection from Full, two workers:** **69/69 passed, 0 failures, 0 skips**, exit **0**. `ui.xcresult`, `ui-summary.json`, `ui-tests.json`, `ui.log` / `.status`. Counts below are from the completed result tree (one console line was interrupted by Xcode logging). No serial failure rerun was needed.

| UI class | Passed |
|---|---:|
| AAAWarmUpUITests | 1/1 |
| AppleHealthUITests | 4/4 |
| BodyWeightUITests | 3/3 |
| TodayFoodUITests | 7/7 |
| FloodlightProfileUITests | 10/10 |
| FloodlightScanUITests | 20/20 |
| FloodlightAIRoutineUITests | 15/15 |
| NutritionGoalsUITests | 9/9 |

- **Consistency:** `python3 scripts/test-plans.py --check` exit **0**, `test-plans.log` / `.status`; `git diff --check ed4ec5a..09e471b` passed. HEAD and product/test source stayed unchanged through verification.
- **Captures:** exported fresh Apple Health and scanner PNGs with manifests to `health-attachments/` and `scan-attachments/`. Opened the light/default Apple Health screen, dark/AccessibilityL scrolled refusal/footnote screen, updated light/default scanner sign-in screen and dark/AccessibilityL scanner error screen. The inspected copy is readable. Also inspected the author's matching Apple Health default/AXL captures. No live permission sheet or human VoiceOver session was exercised.
- **Author bundles independently inspected:** `c1n9b-health10` **15 definitions / 150 executions**; `c1n9b-unit` **1,247 definitions / 1,267 executions**; `c1n9b-ui1` **5/5**; `c1n9b-ui2` **65/65**; all summaries report passed, no failures/skips. Saved as `author-*-summary.json`. Reviewer results above independently cover the requested combined selection.
- **Additional probes:** actual engine with controlled stubs reproduced S1, S2, S3, S6 and S7 as described; the Foundation calendar probe supports S5. Inspected their source, output and successful status files. S4 is a source/API-contract finding, and T1 is a traced outgoing-data path, not a live network reproduction.

Verified: fresh build **exit 0**; Unit **1,247/1,247 definitions / 1,267 executions**, **exit 0**, `/tmp/codex-c1n9b/unit.xcresult`; isolated Health suite **150/150 executions**, **exit 0**, `/tmp/codex-c1n9b/health10.xcresult`; eight named UI classes **69/69**, **exit 0**, `/tmp/codex-c1n9b/ui.xcresult`; test-plan consistency **exit 0**; compiled Health strings; inspected captures and scoped probes. All evidence is under `/tmp/codex-c1n9b/`.

Not verified: real HealthKit authorization/denial sheets, real save/replacement/delete semantics (including lower/equal sync versions and correlation operations), cross-source active-energy totals, physical-device behavior, background delivery, or a phone install. The source-derived upload path was not exercised against a live server; delayed-query/observer/unit probes use minimal domain stubs and stand-in storage rather than the full app. Time-zone change was tested at the Foundation level, not in end-to-end UI. AskAIUITests and the full UI suite were not run; T1 needs focused new consumer coverage. Human VoiceOver and runtime Reduce Motion were not exercised.

Known flaky: **none observed in the requested runs this round**. No test failed or required a serial rerun. Prior unrelated UI failures remain outside this selection; passing fixtures do not validate the missing race/version/consumer cases above.

Standards: **one distinct P2** (T1), with S1 also a shared ownership concern and not counted twice. Spec: **five P2 and two P3** (S1–S7). Total: **six P2 and two P3**, no P1. C1's reviewed wording changes are clear within the documented exceptions; N9b needs the fixes above before independent clearance.

Verdict: not clear
