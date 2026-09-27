Independent review (T6) of ticket 03 of the Floodlight redesign: the live lifting workout and its
sheets, on branch `ericlee4992/redesign-floodlight-live`. Range: `b2c0329..HEAD` (b2c0329 is
the ticket-02 branch you cleared in codex-review-02c). Claude implemented; you review.
You are running in the checkout `/tmp/wt-floodlight/live`; stay in it.

Read first: AGENTS.md; `work-record/redesign-floodlight/issues/01-implement-redesign.md` (user
decisions: Floodlight everywhere + Paper-structure live workout, light/dark Appearance, new
wording approved as shown in the prototype); `issues/03-live-workout.md` (scope, kept rules and
identifiers, decisions flagged for the user, new strings, verification);
`reference/look-api.md`, `reference/brief/constraints.md` §1–2, `reference/brief/domain-data.md`
§3. Approved screens: `reference/captures/{dark,light}/L01-final.png`, `L01-end-final.png`,
`L03-final.png`, `L06-final.png`. Actual captures of this branch:
`captures/03/floodlight-03-live-{light,dark,axl,empty}.png`. Prototype source (read-only):
`/Users/ericlee06/orca/workspaces/Health App/redesign-prototype/RedesignPrototype/Sources/`.
Old implementation for comparison: `git show b2c0329:<path>` (notably the old
`Features/ActiveWorkout/ExerciseEntryCard.swift` set row and `ActiveWorkoutView.swift`).

Review for:
1. `LiveSetRow` versus the old set row: every commit, prefill, dirty-draft, A1 (not loggable
   until valid), bar-mode, unit toggle, set-type change, focus/keyboard-Done and delete rule must
   be carried over. Any path where a typed value is lost, a row is logged with stale prefilled
   values (D36), or a row is created without a deliberate action.
2. Derived data on screen: `Domain/NextSet.swift` (`NextSetMath`, superset alternation, warmups,
   the "Next · …" text in the rest slab) and `SetBadges.swift` now wired (when marks are
   recomputed; scope; that "New best" never appears on a first workout; that a history edit or a
   deleted/uncompleted set cannot leave a stale mark). The vitals strip: total volume (warmups
   excluded, assisted/bodyweight/bar handling, unit), active calories, the heart-rate source line
   (always named; zones only with a basis; no beat when stale). The "N/M sets" ring.
   Known, pre-existing and not in scope: `PerformanceHistory.prefill` returns nil for completed
   sets, so a completed row shows PREVIOUS "—" (unchanged from main) — say so only if the new
   design makes it actively misleading next to the "New best" sticker.
3. Behaviour preserved in `ActiveWorkoutView` and the sheets: finish flow entry, minimise/resume,
   rename, Discard moved from the toolbar to "Discard Workout…" (same confirmation), planned
   cardio with explicit Start, the Lifting | Cardio switch, Add Exercise / Add by Machine /
   Add Cardio, rest bar (+15s / Skip, D46 scheduled alarm untouched, D48 rest skipped between
   superset members), the "…" menu actions, superset badges, preset chips and their freeze rules,
   equipment/bar pickers, previous-performance sheet, max heart rate sheet.
4. Look and accessibility: `Look.live(dark:)` in both schemes; sheets over the cover get the
   right scheme/tokens; AccessibilityL layout (the rest slab overlays content — can the last
   rows and the add block still be scrolled clear of it?); 44 pt targets; VoiceOver labels and
   values (PREVIOUS reads the full "105 lb × 8", set marker, check, stickers); Reduce Motion for
   the stamp/ripple and the rest ring.
5. UI tests: `LiveWorkoutHelpers.discardActiveWorkout()` and the edited Core Loop / Heart Rate
   tests — do they still test what they claim? The five failures in the run are claimed
   pre-existing (identical on main a0364f2, `base-5.log`); note `ExercisePresetUITests` fails
   at line 107 before reaching the live preset chips, so live preset behaviour has no passing UI
   coverage in this run — is the ticket's verification scope enough per DEVELOPMENT's policy?
6. Any change to product behaviour or visible wording that ticket 03 does not list.

Do NOT run xcodebuild or simctl (the simulator is in use). Do not modify files other than the
report. Report findings by severity (critical / high / medium / low) with file:line and a
concrete failure case, or say "clear" in one paragraph. Write the report to
`work-record/redesign-floodlight/codex-review-03.md` (in this checkout).
