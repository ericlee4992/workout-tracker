# Nutrition N3 — independent Codex review, round 2

Reviewed 2026-11-09. Claude implemented; Codex reviewed **`git diff af1441f..055f33d`**, target
`055f33da951c87a33511a44730ce1c8dd0fd96e2`, on `ericlee4992/nutrition-03-goals`. The checkout was clean before
this report. Read STATE, the ticket's round-1 response and the prior report; Spec and Standards/design were checked
independently. Requested verification used a pinned archive in `/tmp/codex-n3b/source/`.

Only this report was written in the repository. Additional reproductions used a separate scratch archive with
explicitly recorded test-only fixture hooks. No product fixes, commit, push or merge were made by this reviewer.

## Spec

### 1. P2 — Apply the pending override reset when details become complete

**Location:** `WorkoutTracker/Features/Nutrition/NutritionGoalsView.swift:50–51,72–73`.

An existing overridden goal still offers Recalculate while details are incomplete. Pressing it clears
`pending.overrides` and hides the command, apparently accepting the reset. When DOB is restored, Personal details
refreshes the stored goal using its old overrides. The completion handler then copies only pending activity and
goal, discards pending state, and leaves the old override intact. Recalculate has silently been lost.

**Reproduced through the UI:** set Protein to 200, clear DOB through the zones sheet, open Nutrition goals and press
Recalculate, then restore DOB through that page's Personal details destination without discarding its navigation
state. Protein returns as **“200 … Typed by you”** and Recalculate reappears. The probe log, screenshots and
accessibility tree record both the accepted-looking reset and its reversal.

**Fix:** replay the complete pending Choices, including overrides, or explicitly prevent Recalculate while details
are incomplete. Add the override → clear DOB → Recalculate → restore DOB sequence as a regression.

### 2. P2 — Freeze a measurement draft's unit while its editor is open

**Location:** `WorkoutTracker/Features/Nutrition/PersonalDetailsView.swift:62–64,95–98`.

Late profile loading can prefill the store while a user is editing a missing measurement. The weight editor's unit
and save closure are derived from the live `weights` query, while its typed text is retained in `@State`. A profile
weight arriving in a different unit can therefore reinterpret the user's unfinished input.

**Reproduced with a controlled profile-arrival fixture:** Preferences is Metric and the missing-weight editor opens
in **kg**. After typing **80**, a delayed sample profile containing **180 lb** arrives. The open editor changes its
unit to **lb**, retains the text **80**, and Save produces the Personal details row **“Weight, 80 lb.”** This is an
incorrect measurement, not merely a changed display conversion.

**Fix:** capture the draft's value/unit and save semantics for the lifetime of the sheet, or defer prefill for a field
being edited and retry safely after dismissal. Do not derive an active draft's unit from a query that background
prefill can change. Test a late profile in a different unit after the first typed character.

The fixture uses the existing no-network sample AccountStore, leaves its token unchanged, and changes only its
profile after the draft text becomes 80. Original editor state/save logic remains unchanged. The hook and exact
scratch changes are recorded in `probe-patch.diff` and `probe-manifest.json`; this is a simulated response arrival,
not a live-server test.

**Spec: 2 P2 findings.**

## Standards

### 3. P3 — Keep accepted fractional heights valid when reopening

**Location:** `WorkoutTracker/Features/Nutrition/DetailEditorSheets.swift:139–149,156–160`; disabled Save at `:116`.

HeightFields accepts `5 ft 11.999 in` and stores `71.999 in`. Its formatter rounds the remaining inches to two decimal
places without carrying a resulting 12 into feet, so reopening produces **`5 ft 12 in`**. The parser rejects inches
greater than or equal to 12, disabling Save even though the stored input was accepted. Cancel still works; the issue
is the invalid round trip, not deletion of the stored height.

**Evidence:** the extracted production HeightFields implementation reproduces the accepted value followed by
`reopened feet=5, inches=12; valid=false` in `height-boundary.log`, **exit 0**. A control confirms that stored 180 cm
retains its unit and an unchanged Save writes nothing. This is arithmetic evidence, not a claimed UI interaction.

**Fix:** use round-trippable precision or normalize the carry when formatting feet/inches. Add a boundary test near
12 inches that checks an accepted stored value can reopen as valid without changing it.

No additional visual or heuristic findings. **Standards: 1 P3 finding.**

## Round-1 disposition and captures

- Explicit store edits with incomplete details now throw; plain refreshes remain harmless. Goal numbers are hidden
  until details are complete, and the zones save refreshes the goal. The original silent direct-edit case is fixed;
  finding 1 concerns the newly deferred Recalculate path.
- Missing measurements now prefill from the training profile, preserving entered units and existing stored values.
  Finding 2 concerns an unsaved draft during late arrival, which the stored-value regression does not cover.
- The original 180 cm and 71.5 in unchanged-save cases are fixed, and unchanged number-editor Save avoids duplicate
  weight entries. Finding 3 is the remaining fractional boundary.
- README now describes goals, Personal details and optional onboarding as unreleased. The prior P3 is resolved.

Inspected the author contact sheets in `n3-caps5/` and `n3-caps6/`, current full-resolution two-row height editors at
light Default and dark AccessibilityL with the keyboard visible, and dark AccessibilityL onboarding empty/filled
states. The latest `n3-caps6` height captures supersede the older one-row layout in `n3-caps5`. Fields and Cancel/Save
fit above the keyboard; the onboarding content wraps and scrolls. No additional layout defect was established.
The independent reproduction screenshots were also inspected, including the relabeled weight editor, saved 80 lb
row, and returned typed override.

## Verified

Independent runs on **WT-iPhone27** `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`, iOS 27.0. Preparation ran first,
**exit 0**. Artifacts: **`/tmp/codex-n3b/`**. Main runner `verify.sh`, PID `67330`; isolated probe runner
`run-probes.sh`, PID `72145`; restoration PID `74251` — completed. No heavy runs overlapped. UI used two workers;
the investigative probes ran serially. The existing Orca progress tab was reused.

| Scope | Actual result |
|---|---|
| Build for testing | **exit 0**, succeeded, 0 errors, 33 warnings; `build.xcresult`, `build-summary.json` |
| Requested affected unit suites, serial | **39/39**, no failures/skips, **exit 0**; `unit.xcresult`, `unit-summary.json` |
| NutritionGoalsUITests + HeartRateUITests + standard warm-up | **14/14**, no failures/skips, **exit 0**; `ui.xcresult`, `ui-summary.json` |
| Height boundary reproduction/control | **exit 0**; `height-boundary.swift`, `.log`, `.status` |
| Isolated UI reproductions + warm-up | Probe build **exit 0**; **3/3 completed, exit 0**; `probe-ui.xcresult`, `probe-ui.log`, `probe-captures/` |

The unit scope was NutritionGoalStoreTests, HeightFieldsTests, NutritionGoalsTests, TrainingProfileTests and
StoreFormatGuardTests. Result bundles and shell exit files were inspected directly. The reproduction tests
**intentionally assert the defective outcomes**; their successful completion is evidence for findings 1–2, not
product clearance. The pending-Recalculate test uses the normal public UI without enabling the late-profile hook.

The probe archive is based on `055f33d`. Its only changes are the guarded sample-profile injection, its guarded
post-typing trigger, and the review-only UI test class. No network call is made. Afterward the pristine reviewed app
was reinstalled and its executable/debug dylib hashes verified. Original Application Support, Preferences and
Documents were restored while shut down and verified **byte-for-byte before and after reboot**
(`restore-original.json`, `restore-original.status` **0**).

Author results inspected directly under
`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/f473a23d-3eaa-41a2-9817-2ebe24bda24e/scratchpad/`:
`n3-r2-unitplan.xcresult` **1183/1183**, `n3-r2-ui.xcresult` **14/14**, and `n3-r2-goals.xcresult` **9/9**, all with
passing result bundles and no failures/skips. No standalone author numeric exit files were present; the ticket
records exit 0. The latest goals result follows the two-row height-editor change.

## Not verified

No full Unit plan or broader UI suite rerun beyond the named scopes this round. No repeated migration rehearsal:
the model schema, exporter and store-opening path are unchanged, so round 1's rehearsal remains applicable.
No physical-device, CloudKit, live-profile-service, Health or human VoiceOver check. The late-profile probe controls
response timing through a guarded local fixture; real-network timing was not exercised. The height boundary was
verified through production arithmetic, not a separate UI tap sequence. No merge, phone installation or release is
claimed.

## Known flaky

No failures, skips or timeouts in the requested independent suites; no serial failure rerun was necessary. The
requested UI run reports one invalid-frame runtime warning; affected unit and probe UI results report none.
The build reports two unused-result warnings in the updated `withoutActuallyEscaping` calls, in addition to the
existing warnings. These are recorded separately from the confirmed findings; no failing test was waived.

Spec: **2 P2 findings**. Standards: **1 P3 finding**. Resolve and re-review.

Verdict: not clear
