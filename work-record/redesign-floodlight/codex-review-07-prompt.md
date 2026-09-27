Independent review (T6) of ticket 07 of the Floodlight redesign: Scan, on branch
`ericlee4992/redesign-floodlight-scan`. Range: `ericlee4992/redesign-floodlight-gyms..HEAD`
(the branch is stacked on ticket 06's gyms branch, tip `d45d5c5`). Claude implemented; you
review. Run in the checkout `/tmp/wt-floodlight/scan` and stay in it.

Read first: AGENTS.md; `work-record/redesign-floodlight/issues/01-implement-redesign.md` (user
decisions); `issues/07-scan.md` (scope, the user's four decisions of 2026-09-27 — Scan Machine
adds directly with an Added step, consent stays before the camera, ambiguous stays D56 with no
picking, no picker extras — kept rules and identifiers, prototype-only features, strings, tells,
verification); `.claude/skills/ios-design/REVIEW.md`; `reference/look-api.md`,
`reference/brief/constraints.md` §1–2; DECISIONS D3, D10, D23, D24, D33, D34, D35, D53, D56,
D58. Prototype captures `reference/prototype-scan/{dark,light}/`; prototype source (read-only)
`/Users/ericlee06/orca/workspaces/Health App/redesign-prototype/RedesignPrototype/Sources/Screens/Scan/`.
Actual captures: `captures/07/`. Old screens: `git show ericlee4992/redesign-floodlight-gyms:WorkoutTracker/Features/Gyms/IdentifyEquipmentSheet.swift`,
`…/ScanMachineLabelSheet.swift`, `…/MachineModelCorrectionSheet.swift`, `…/MachineEditorSheet.swift`.

Review for:
1. What a scan saves (`Domain/ScanMachine.swift`, `ScanMachineTests`): `confirmed` (a catalog
   match's exercises, generic / ambiguous clearing the identity, the answer set aside and
   restored), `add` versus the machine form's save (one resolution; a new user model never
   seeded, with the confirmed exercises; instance-local exercises only without a model's own;
   movement-only names model-less), the D3 label prefill (edited names kept; what the field shows
   is what is saved in BOTH modes — the form's own `applyModelDefaultLabel` still runs on the
   handed-back proposal), the duplicate lookup. Any path where Add saves something the result did
   not show, or the form and the direct add disagree for the same answer.
2. The sheet's flow (`IdentifyEquipmentSheet`, `Scan/ScanSteps.swift`, `Scan/ScanResultStep.swift`):
   consent before the camera and before any send (D56); no key; the one-request/one-photo rules
   kept from the old sheet — a late reply after Take another photo, a camera failure after the
   photo, the capture timeout, cancel/dismiss mid-request, consent revoked; the photo kept in
   memory only (D34/D56 — shown back, never written); Scan another machine resetting every
   piece of state; "Choose a catalog model" opening the form after the scan sheet closes (gym page
   and routine setup), and not saving anything; interactive dismissal while identifying / on the
   result. Routine setup (D58): machines added directly still counted, preferences kept.
3. Read Label (`ScanMachineLabelSheet`): only the views changed — D33 preselection and the
   always-a-tap rule, the framing box geometry still identical to what the camera reads
   (`LabelFramingBox` over the same view), one still per shutter, Ask AI still fixture-only (D53),
   create-new paths, failure paths (denied / restricted / no camera).
4. Correct Model (`MachineModelCorrectionSheet`, `ModelCorrection`): D10 — history rewritten only
   on "Apply to Past Workouts Too" and only after the confirmation when there is something to
   rewrite; the impact counts match what `EquipmentLifecycle.correctModel` actually rewrites
   (every entry whose snapshot is this machine, including a running workout?); suggestions;
   None; the pushed catalog picker; disabled until the model changes.
5. Identifiers and tests: the kept identifiers in the ticket; `AskAIUITests` changes (was the
   old behaviour asserted still asserted — e.g. the offline error keeping the flow usable);
   `FloodlightScanUITests` assertions that could pass vacuously.
6. Look and accessibility per REVIEW.md: one bold element per step (the shutter; Allow; Add;
   Done; Use This; Correct Model), light/dark (the camera always dark), AXL layouts (titles
   inline, secondary commands leaving the pinned bar, stacked scope tiles), VoiceOver (the gym
   chip, the stamps, the candidate rows with their scores, the scope tiles' values, the exercise
   counter), 44 pt targets, Reduce Motion (stamp, sweep, instrument, flow dot, flash, count,
   timeline), strings listed vs actual.
7. Verification scope per DEVELOPMENT, and any product change ticket 07 does not list.

Do NOT run xcodebuild or simctl. Do not modify files other than the report. Report findings by
severity (critical / high / medium / low) with file:line and a concrete failure case, or say
"clear" in one paragraph. Write the report to `work-record/redesign-floodlight/codex-review-07.md`.
