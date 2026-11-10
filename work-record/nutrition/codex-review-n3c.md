# Nutrition N3 — independent Codex review, round 3

Reviewed 2026-11-09. Claude implemented; Codex reviewed **`git diff 055f33d..e30a6a3`**, target
`e30a6a324a6b1d04d731be659c59bf5e6ae939c0`, on `ericlee4992/nutrition-03-goals`. The checkout was clean before
this report. Read STATE, the ticket's “Codex round 2” mapping and the preceding report. Spec and Standards were
reviewed independently.

Requested verification used a pinned archive under `/tmp/codex-n3c/source/`. The prior probe patch was reapplied to
a separate archive of the same commit. Only this report was written in the repository; no product edits, commit,
push or merge.

## Spec

**No findings. Both round-2 P2 findings are resolved.**

1. **Pending Recalculate:** NutritionGoalsView and FoodGoalsSetupSheet now replay the entire pending Choices,
   including overrides. The permanent regression and the reapplied UI sequence pass: after typing Protein 200,
   clearing DOB, pressing Recalculate and restoring DOB, Protein is **144**, the “Typed by you” label is absent,
   and Recalculate stays absent. The pending reset is no longer discarded.
2. **Late profile arrival:** PersonalDetailsList.Field captures the initial value and unit when an editor opens.
   The editor and its save closure use that snapshot rather than the changing query. The reapplied fixture proves
   the profile actually arrived and was applied: underlying rows show **180 lb** and **5 ft 10 in** before Save.
   Meanwhile the open draft still contains **80 kg**, and Save produces **“Weight, 80 kg.”** The prior unit
   reinterpretation no longer reproduces.

**Spec: 0 findings.**

## Standards

**No findings. Round 2's P3 height boundary is resolved.**

HeightFields rounds the shown total before splitting feet/inches, carrying a rounded 12 into feet. The regression
covers `71.999`, `71.9999`, `59.9996` and `72`: each reopens as valid input. In particular, `71.999` retains
`11.999` inches, while `71.9999` carries to 6 feet. The unchanged-Save guard still avoids persistence, preserving the
original stored precision rather than replacing it with the rounded display.

The editor snapshot is a small typed value held in view state; no new persistence or dependency is introduced.
No unrelated modernization, file split or heuristic finding. The earlier README fix remains intact.

**Standards: 0 findings.**

## Verified

Independent execution on **WT-iPhone27** `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`, iOS 27.0. Preparation ran
first, **exit 0**. Artifacts and commands: **`/tmp/codex-n3c/`**. Main runner `verify.sh`, PID `80301`; serial
rerun `87198`; probe runner `88099`; restoration `89824` — completed. The initial UI run used two workers;
subsequent checks were serial, with no overlapping heavy runs. The existing Orca progress tab was reused.

| Scope | Actual result |
|---|---|
| Build for testing | **exit 0**, succeeded, 0 errors, 33 warnings; `build.xcresult`, `build-summary.json` |
| NutritionGoalStoreTests + HeightFieldsTests | **12/12**, no failures/skips, **exit 0**; `unit.xcresult`, `unit-summary.json` |
| NutritionGoalsUITests + standard warm-up, two workers | **9 passed / 1 failed / 0 skipped out of 10**, **exit 65**; `ui.xcresult`, `ui-summary.json` |
| Failed dark-AccessibilityL capture + warm-up, serial | **2/2**, no failures/skips, **exit 0**; `ui-serial.xcresult`, `ui-serial-summary.json` |
| Reapplied regression probes + warm-up, serial | Probe build **exit 0**; **3/3 passed**, **exit 0**; `probe-ui.xcresult`, `probe-ui.log` |

Counts and outcomes were read directly from xcresults and shell-status files. Five-minute per-test limits were
enabled for UI execution; none was reached. No source or test change was made between the requested UI run and its
serial rerun.

**Probe fidelity:** applied `/tmp/codex-n3b/probe-patch.diff` with `git apply` to a fresh `e30a6a3` archive. The guarded
no-network profile-arrival hook is unchanged: it injects the sample profile two seconds after 80 is typed, without
changing the token or production editor save/state logic. Assertions were updated to require the fixed outcomes.
They also require the imported measurement rows before Save, so a hook that never fired cannot falsely pass the
unit-preservation check. PersonalDetailsView and NutritionGoalsView are byte-identical between pristine and probe
archives. Exact scratch changes and hashes are in `probe-patch.diff` and `probe-manifest.json`.

Inspected the probe captures showing the open 80 kg draft after arrival, saved 80 kg row, and calculated Protein 144
without Recalculate. Also inspected the successful dark-AccessibilityL goals capture from the serial rerun.
Screenshots and accessibility attachments are retained under `probe-captures/` and `captures-dark-axl/`.

After probes, the pristine reviewed app was reinstalled and its executable/debug dylib hashes checked. Original
Application Support, Preferences and Documents were restored while shut down and verified **byte-for-byte before
and after reboot** (`restore-original.json`, `restore-original.status` **0**). The probe-instrumented app was not
left installed.

Author evidence inspected directly under
`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/f473a23d-3eaa-41a2-9817-2ebe24bda24e/scratchpad/`:
`n3-r3-unit.xcresult` **12/12** and `n3-r3-ui.xcresult` **10/10**, both passing with no failures/skips. Separate
numeric shell-status files were absent; the ticket reports successful runs. The independent runs above provide
recorded exit codes.

## Not verified

No full Unit plan or broader UI suite was repeated beyond the named scopes. No new migration rehearsal: stored
schema, exporter and store-opening behavior are unchanged, so the prior rehearsal remains applicable. No physical
device, CloudKit, live profile service, Health or human VoiceOver check. Late profile timing is a controlled local
fixture; real-network timing was not exercised. Height boundaries were verified through the production helper and
unit tests, not separate UI entry of every boundary value. This is review clearance, not evidence of merge,
phone installation, release or the user's remaining wording approval.

## Known flaky

`NutritionGoalsUITests/testCaptureDarkAccessibility` initially timed out waiting for `profileNutritionGoals` at
`NutritionGoalsUITests.swift:263`, before reaching the goals page. It passed unchanged in the serial rerun. The
parallel-only startup/navigation failure was not reproduced as a product defect; no failing case was omitted.

The initial UI run records one audio-session runtime warning; selected unit tests, serial UI and probe UI record
none. The build's existing warnings, including the unused optional results noted in round 2, remain separate from
the review verdict.

Spec: **0 findings**. Standards: **0 findings**. All three round-2 findings are resolved for `e30a6a3`.

Verdict: clear
