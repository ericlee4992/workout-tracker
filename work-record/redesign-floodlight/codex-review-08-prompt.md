Independent review (T6) of ticket 08 of the Floodlight redesign: Exercises, on branch
`ericlee4992/redesign-floodlight-exercises`. Range: `ericlee4992/redesign-floodlight-scan..HEAD`
(the branch is stacked on ticket 07's scan branch, tip `7655aa7`). Claude implemented; you
review. Run in the checkout `/tmp/wt-floodlight/exercises` and stay in it.

Read first: AGENTS.md; `work-record/redesign-floodlight/issues/01-implement-redesign.md` (user
decisions); `issues/08-exercises.md` (scope, the user's four decisions of 2026-09-27 — Exercise
Detail from the tab and the machine page, presets keep reordering, the shortened load-type copy,
New Exercise with body area and a taken-name refusal — kept rules and identifiers, prototype-only
features, strings, tells, verification); `.claude/skills/ios-design/REVIEW.md`;
`reference/look-api.md`, `reference/brief/constraints.md` §1–2; DECISIONS D20, D23, D24, D26,
D36, D37, D38, D47, D52. Prototype captures `reference/prototype-exercises/{dark,light}/`; prototype
source (read-only) `/Users/ericlee06/orca/workspaces/Health App/redesign-prototype/RedesignPrototype/Sources/Screens/Exercises/`.
Actual captures: `captures/08/`. Old screens: `git show ericlee4992/redesign-floodlight-scan:WorkoutTracker/Features/Exercises/<file>`.

Review for:
1. The readouts (`Domain/ExerciseOverview.swift`, `ExerciseOverviewTests`): history only from
   finished workouts, completed sets, snapshot identity (D23); the catalog best under the CURRENT
   load type only (a re-typed exercise never mixes rankings) and `lastWasNewBest` (never a tie,
   never a first time; "latest workout" meaning the latest that trained the exercise); working
   sets exclude warmups; preset usage/bests; machine uses (archived machines and deleted gyms
   excluded, served-but-unused included); the recent sessions' new-best marks agreeing with what
   the live workout / receipt mark (`SetBadgeMath`); the last-trained week buckets; the family
   filter's D24 no-hide rule and the old stored body-area value; the taken-name rule; the value
   formatter by load type and its unit rule (D52). Any readout that disagrees with History, the
   machine page or the progress chart for the same data.
2. E02 (`ExerciseDetailView`): the main variation and the others (`ProgressSeriesMath` ranking and
   labels, snapshot words — now shared with `ExerciseProgressView.words(for:)`), the hero best and
   its mark, 1RM (weighted only, display unit) and change (assisted improves downward), the records
   per load type, Setup (Rename only for user exercises, D24), the chart opening on the tapped
   variation, machines and workouts pushed from both the Exercises and the Gyms stacks, a deleted
   exercise while its page is open.
3. E01 (`ExercisesView`): search + equipment + family combined, the persisted family (the existing
   `exerciseBrowseMuscleGroup` field now holding a family name — is anything else reading that field
   as a body area?), Group by in `@AppStorage`, the no-match Add “…” prefill, the long-press menu
   still complete, Add from the tab opening the new exercise (the delayed push), rename.
4. E03 (`NewExerciseSheet`, shared with the mid-workout pickers `ExercisePickerSheet` and
   `AddByMachineSheet`): `onCreate` still acts for those callers, `linkTo` still links, the body area
   saved, the taken-name rule (what counts as "live" — deleted rows?), Add disabled states.
5. E04 (`ExercisePresetsSheet`): add / rename / delete (with confirmation) / reorder (Edit and the
   handles, `onDelete` in edit mode also confirming), renumbering after delete, the empty and
   duplicate states, the kept identifiers; D37/D38 (presets as user data on seeded exercises,
   a machine's usual preset pointing at a deleted one).
6. E05 (`EditExerciseLoadTypeSheet`): Save only after a change, `loadTypeUserOverridden` still set
   (D47), the ledger's logged-set count versus what is actually frozen.
7. Identifiers and tests: the kept identifiers in the ticket; the neighbour tests moved to the tab's
   own search field (`app.exercisesTabRow`) — anything they no longer prove; `FloodlightExercisesUITests`
   assertions that could pass vacuously; the `-uiTestDesignExercises` fixture only active with
   `-uiTestReset`.
8. Look and accessibility per REVIEW.md: one bold element per screen state (the family strip;
   the best figure; Add; Save), light/dark, AXL layouts (family tiles two-column, rows stacking
   their trailing values, the stat strip as rows, sheet titles leaving the bar), VoiceOver (the
   family tiles' selected state, the catalog row's combined label, the record tiles, the ledger),
   44 pt targets, Reduce Motion (family strip entry, chips, the ledger), strings listed vs actual.
9. Verification scope per DEVELOPMENT, and any product change ticket 08 does not list.

Do NOT run xcodebuild or simctl. Do not modify files other than the report. Report findings by
severity (critical / high / medium / low) with file:line and a concrete failure case, or say
"clear" in one paragraph. Write the report to `work-record/redesign-floodlight/codex-review-08.md`.
