Independent review (T6) of ticket 10 of the Floodlight redesign: Ask AI for Templates (the AI routine
flow), on branch `ericlee4992/redesign-floodlight-ai-routine`. Range:
`ericlee4992/redesign-floodlight-settings..HEAD` (stacked on ticket 09's settings branch, tip `c286b59`).
Claude implemented; you review. Run in the checkout `/tmp/wt-floodlight/ai-routine` and stay in it.

Read first: AGENTS.md; `work-record/redesign-floodlight/issues/01-implement-redesign.md` (user decisions);
`issues/10-ai-routine.md` (scope, the user's four decisions of 2026-09-28 — the prototype's timed
percentage/stages while generating, the Saved step, asking before any unsaved week is lost, the profile in
the user's units — prototype-only features, the consent-line wording, identifiers, tests, verification);
`.claude/skills/ios-design/REVIEW.md`; `reference/look-api.md`, `reference/brief/constraints.md` §1–2;
DECISIONS D6, D22, D56, D57, D58 (and the September 22 D58 follow-up) and `work-record/ai-gym/spec.md`.
Prototype captures `reference/prototype-ai/{dark,light}/`; prototype source (read-only)
`/Users/ericlee06/orca/workspaces/Health App/redesign-prototype/RedesignPrototype/Sources/Screens/AI/`.
Actual captures: `captures/10/`. The old flow: `git show ericlee4992/redesign-floodlight-settings:WorkoutTracker/Features/Templates/AIRoutineSheet.swift`.

Review for:
1. Behaviour kept from the old sheet (D56–D58): the request's contents and limits (goal ≤ 1,000, height
   50–250 cm, weight 20–400 kg, 1–7 days, 15–120 min), `RoutineAvailability` eligibility at the chosen
   gym, the routine consent flag (same `@AppStorage` key; revoking it mid-flow), the Terra call and fixture,
   validation, the stale-reply guard (cancel, Back to preferences, Cancel, a second Generate), the atomic
   save and duplicate-submit protection, planned cardio units, the gym choice written back to Home, machines
   scanned/added during setup surviving a cancelled routine, the missing-key path.
2. `AIRoutineFlowModel`: step transitions (Back from each step, Change preferences, error → retry/back,
   Saved), what is discarded when, `hasUnsavedWeek` and every path that can lose a week without asking
   (decision 3), the stage timer and its cancellation, `AIRoutineDay`'s new local id (never encoded or
   decoded; equality now includes it — any caller comparing routines?).
3. `Domain/AIRoutineFlowMath.swift` and its tests: goal phrase toggling, unit conversions and rounding
   (lb ↔ kg, ft/in ↔ cm, whole numbers, the 11-inch clamp), the minutes estimate agreeing with
   `AIRoutine.validated`, family counts/shares (Core / Full Body excluded), the error split.
4. The steps (`Features/Templates/AIRoutine/`): A01–A05, the error and Saved steps against the prototype
   captures and the ticket; the day editor (reorder, swipe, undo restoring the exact prior day, the picker's
   eligible-and-unused list, 10 / 3 limits, cardio activities limited to those sent); a saved tile opening
   its template on the Workout tab (`StartWorkoutView`).
5. Identifiers and tests: kept identifiers now on different element types (`routineEquipment.*`,
   `routineCardio.*` became tiles); the moved `AskAIUITests` cases and what they no longer prove; the new
   `FloodlightAIRoutineUITests` assertions that could pass vacuously.
6. Look and accessibility per REVIEW.md: one bold element and one filled command per step, light/dark,
   AXL layouts, VoiceOver (tiles' selected state, the day cells' and minutes bar's adjustable values, the
   off primary's hint, the step indicator header, the ring's label/value, cards' labels, the undo bar),
   44 pt targets, Reduce Motion (step transitions, ring sweep, board shimmer, reveal stagger, undo bar).
7. The consent line wording (implementer's, listed in the ticket) against what the request actually sends.
8. Verification scope per DEVELOPMENT, and any product change ticket 10 does not list.

Do NOT run xcodebuild or simctl. Do not modify files other than the report. Report findings by
severity (critical / high / medium / low) with file:line and a concrete failure case, or say
"clear" in one paragraph. Write the report to `work-record/redesign-floodlight/codex-review-10.md`.
