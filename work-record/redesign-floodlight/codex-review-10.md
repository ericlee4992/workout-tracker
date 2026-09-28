# Ticket 10 — independent Codex review

**Not clear.** Reviewed `c286b5991eb299000cfee82b6616e5d3bf767c6f..0af7c45660cf4b3817b76ea601ac4427eae941ff` on `ericlee4992/redesign-floodlight-ai-routine`, in `/tmp/wt-floodlight/ai-routine`. The base is also the merge-base. Claude implemented; Codex reviewed. No `xcodebuild` or `simctl` commands were run, and only this report was written.

## Critical / high

None found.

## Medium

### M1 — Off-state guidance cannot be activated with VoiceOver [Standards / Spec]

**`WorkoutTracker/Features/Templates/AIRoutine/AIRoutineComponents.swift:225–226`.** The visible off-state button invokes `onDisabledTap`, but its accessibility replacement is explicitly disabled. With no goal, a sighted tap on Next focuses Goals; with consent off, tapping Generate scrolls to and outlines consent. VoiceOver cannot activate either guidance action. The generic “Unavailable” text also does not identify the missing requirement. Keep the guidance action accessible, give it a requirement-specific hint, and continue to gate actual generation separately. This breaks the ticket’s off-button behavior and accessibility parity; checking only `isEnabled == false` does not cover it.

### M2 — Schedule and availability animations ignore Reduce Motion [Standards]

**`WorkoutTracker/Features/Templates/AIRoutine/AIGoalsStep.swift:147–153,386`; `AIEquipmentStep.swift:83,313–314`.** The schedule figures use unconditional numeric transitions and `.animation(.snappy)`, and the minutes track/thumb also animates unconditionally. Changing days/minutes with Reduce Motion on still slides digits and moves the thumb with animation. Equipment/cardio and saved-machine counts have the same omission. Gate these modifiers, as the ring, step transitions and editor already do. REVIEW item 10 applies to all animations on the screen, not only the generating step.

### M3 — Cardio editing loses one-minute precision and cannot reach its lower bound [Spec]

**`WorkoutTracker/Features/Templates/AIRoutine/AIDayEditor.swift:578–580`.** The old sheet’s cardio Stepper changed by one minute; this replacement changes by five over `1...180`. An added 15-minute block can reach 10 and 5, but cannot be set to 3 minutes. The shared `NumberStepperPill` disables minus when `value - step < lowerBound` (`Features/Design/Look/Lists.swift:311`), so it cannot even reach 1 from 5 using the visible buttons. VoiceOver clamps to 1 instead, making the two control paths disagree. Generated values need not be multiples of five, so a generated 12-minute block also cannot be adjusted to 10. The prototype used five-minute increments, but ticket 10 does not list loss of the real editor’s precision. Preserve minute-level editing, or explicitly settle and document that product change with a control that can reach its bounds.

### M4 — The displayed machine can disagree with the saved template’s actual resolution [Spec]

**`WorkoutTracker/Features/Templates/AIRoutineSheet.swift:49–53`; `AIRoutine/AIDayEditor.swift:227–230,727–729`.** `machineLabels` chooses the alphabetically first compatible machine and displays it under the exercise in the editor and picker. With Press A and Press B both supporting Chest Press, it shows Press A even when gym memory chooses Press B. Without memory, it still shows A although startup deliberately leaves the machine unassigned. `WorkoutTemplateService.resolvedMachine` (`Domain/WorkoutTemplates.swift:143–152`) implements the D58 remembered-or-sole rule. Use that same resolution for an assigned-machine label, or explicitly present multiple available machines without implying one was selected. No persistence corruption was found; the defect is the misleading equipment preview.

### M5 — Consent revocation retains a silent week-discard path [Spec]

**`WorkoutTracker/Features/Templates/AIRoutineSheet.swift:90–94`.** A routine-consent update from true to false while the model is on Preview calls `model.back()` directly. That calls `discardWeek()` and clears both the generated week and sent request (`AIRoutine/AIRoutineFlowModel.swift:83–85,98–102`), bypassing `hasUnsavedWeek` and the confirmation. Any edits are lost without asking, contrary to decision 3’s “edited or not” rule. Stop requests immediately on revocation, but preserve the local draft or route its disposal through confirmation. **Reachability limitation:** the current Preview/editor has no Settings entry; this finding concerns a consent change delivered through the observed preference, not an ordinary Preview button. The existing Cancel, Back and Change preferences buttons correctly ask first.

## Low

### L1 — The shortened consent line omits sent fields [Spec]

**`WorkoutTracker/Features/Templates/AIRoutine/AIEquipmentStep.swift:232–233`.** The line names goals, schedule, optional profile and exercise list, but the encoded request separately includes `experience` and `cardioActivities` (`Domain/AIRoutine.swift:62–70`). “Optional profile” is the screen’s height/weight section; Experience is a separate mandatory choice. For example, choosing Experienced and Outdoor Walk sends both even though neither category is named. Include experience and available cardio in the disclosure. The claims about excluding Health data and workout history match the request.

### L2 — The undo consequence truncates at AccessibilityL [Standards]

**`WorkoutTracker/Features/Templates/AIRoutine/AIDayEditor.swift:508–512`.** The message is limited to two lines beside Undo. The supplied `captures/10/floodlight-10-a05-undo-light-axl.png` visibly reads “Cable / Crossover r…”, hiding “removed”; the dark AXL capture does likewise. This is an ordinary fixture name, not an extreme string. Stack the action or allow the complete message to wrap at accessibility sizes (REVIEW item 9).

### L3 — Day cells have undersized targets on narrower iPhones [Standards]

**`WorkoutTracker/Features/Templates/AIRoutine/AIGoalsStep.swift:273–299`.** Seven equal-width buttons have six 6-point gaps, within 20-point screen margins and 16-point panel padding. On a 393-point-wide iPhone, each target is `(393 - 40 - 32 - 36) / 7 ≈ 40.7` points wide. Only height has a minimum, and `.lookPressable` adds no target padding. Preserve 44×44 targets with adaptive spacing/layout. The recorded Pro Max captures do not cover this width (REVIEW item 7).

### L4 — Retry and exact undo restoration are not proved by the new tests [Standards / Spec]

**`WorkoutTrackerUITests/FloodlightAIRoutineUITests.swift:268–269,295–308`.** The error test asserts that Retry is enabled, then presses Back; it still passes if Retry’s action does nothing. The undo test verifies a count decrease and restoration of the first exercise’s name, but never checks the restored count, prescriptions, cardio, name of the session or figures. It would pass if Undo recreated only that exercise with default values while losing the rest of the prior day. Add a real retry transition and compare a deliberately edited day before removal and after Undo. The nonempty-label assertions do fix the earlier empty-label vacuity.

## Review coverage and evidence

- Read the user decisions, ticket 10, design checklist/reference, constraints, D6/D22/D56–D58 and September 22 follow-up, AI spec, verification policy, old sheet, changed source/tests, relevant callers and prototype source. Inspected the four prototype/actual comparison sheets and the full-size AXL undo capture. The approved palette, filled-command hierarchy and overall A01–A05/Saved composition are retained. No fresh interactive VoiceOver or Reduce Motion run is claimed.
- Request contents, goal/profile bounds, bounded schedule controls, chosen-gym eligibility, consent key, Terra/fixture transport, validation, token-based stale-reply rejection and stage-task cancellation remain present. The stages match 0/0.8/1.7/2.5 seconds and do not delay a completed reply. The isolated-context save, duplicate-submit guard, planned cardio units, gym write-back and independent machine saves remain intact. Missing-key Settings is reachable from Equipment.
- The editor filters to sent, unused exercise IDs, uses sent cardio activities, enforces 10/3 limits and restores a value snapshot for Undo. `AIRoutineDay.id` is excluded from CodingKeys; synthesized equality includes it. The only located routine equality assertion compares validation’s returned value with the original (`AIGymTests.swift:107`), so no caller regression was found. Profile conversion constants, whole-number rounding and the 11-inch clamp are consistent on inspection; the clamp and field bindings are not covered by the pure conversion tests. Minutes use the validator’s estimate; Core/Full Body remain excluded through `MuscleFamily`.
- The moved AskAI tests retain repeated scanning, cancelled scanning, input preservation, gym write-back, machines surviving routine cancellation, template visibility, duplicate-save checking and explicit planned-cardio Start. Tile queries now check selected traits. The old tests did not prove cardio-only units or request cancellation either; the refactored asynchronous model still needs focused cancellation/stale-reply coverage rather than relying on those tests as evidence for it.
- Independently read retained `.exit` files and logs: `ai-build-1` exit 0; `ai-unit-1` exit 0; `ai-ui-1/2/3` exit 65; `ai-ui-4` exit 0. Read existing result summaries with `xcresulttool`: unit **33 passed, 0 failed/skipped**; UI run 4 **13 passed, 0 failed/skipped**. Run 3 had **13 passed / 7 failed** across 20 cases; run 4 covers the failures plus all eight new tests. The UI result reports ten invalid-frame runtime warnings; these alone do not identify a new ticket-10 defect.
- Targeted AI/domain and adjacent template flows are an appropriate bounded scope under DEVELOPMENT. Address the findings with focused checks and affected captures; this review does not request a full UI suite for ticket 10 alone. The all-at-once redesign release gate remains separate.

**Summary:** Standards findings M1/M2/L2/L3/L4; Spec findings M1/M3/M4/M5/L1/L4. Worst severity on each axis: medium. No independent clearance yet.
