Independent review (T6) of ticket 06 of the Floodlight redesign: Gyms, on branch
`ericlee4992/redesign-floodlight-gyms`. Range: `ericlee4992/redesign-floodlight-history..HEAD`
(the branch is stacked on ticket 05's history branch). Claude implemented; you review. Run in the
checkout `/tmp/wt-floodlight/gyms` and stay in it.

Read first: AGENTS.md; `work-record/redesign-floodlight/issues/01-implement-redesign.md` (user
decisions); `issues/06-gyms.md` (scope, the user's decisions of 2026-09-27 — Scan is ticket 07,
Add Machine keeps its form — kept rules and identifiers, prototype-only features, strings,
tells, verification); `.claude/skills/ios-design/REVIEW.md`; `reference/look-api.md`,
`reference/brief/constraints.md` §1–2, `reference/brief/domain-data.md` §3; DECISIONS D2, D3,
D10, D20, D23, D24, D35, D36, D38, D52, D53. Approved screen: `reference/captures/{dark,light}/G03-final.png`;
prototype captures `reference/prototype-gyms/{dark,light}/`; prototype source (read-only)
`/Users/ericlee06/orca/workspaces/Health App/redesign-prototype/RedesignPrototype/Sources/Screens/Gyms/`.
Actual captures: `captures/06/`. Old screens: `git show ericlee4992/redesign-floodlight-history:WorkoutTracker/Features/Gyms/GymsView.swift`
and `…/MachineDeletion.swift`.

Review for:
1. Derived data (`Domain/GymOverview.swift` and `GymOverviewTests`): visits as distinct days,
   the eight-week rhythm on the phone's calendar, the tab order; each machine's workouts / last
   used / sets and one best per record scope (exercise × preset × load type) read from SNAPSHOTS
   (D23) — warmups, assisted lower-is-better, ties, bodyweight, a renamed or re-modelled machine,
   a running workout; a group's rows showing only that group's exercises' numbers (Exercise and
   Body area grouping — a station is listed under every body area it serves); relative day words; the New
   Model prefill. Any case where a number is wrong, or two screens (gym page row, machine page,
   progress chart the best opens) disagree.
2. Lifecycle and edits: Delete Gym… (archive, confirmation, the page closing, the Home selection
   and pickers dropping it) and Restore (`EquipmentLifecycle.restore(_ gym:)`); the machine
   page's inline name / unit / usual preset (D2, D38 — applied immediately; blank name; the
   preset rule matching the form's); Delete Machine… from the page; Correct / Choose / Rename
   Model… (D10, D24). The machine form (kept, restyled) and the picker still used from the
   mid-workout machine sheets, AI routine setup and the correction sheet.
3. Behaviour preserved and identifiers the UI tests use (list in the ticket): swipe-to-delete
   and the long-press menu on machine rows, the delete confirmation's text, Deleted Machines and
   Restore, D3 label defaults, the model picker's search / filters / grouping remembered in
   AppPreferences (D23), New Model's AI suggestion rules and consent (D53), scan prefill (D35).
   The iOS 27 model-picker test fix (CoreLoop, formerly :252). The clean-build fix in
   `ExerciseProgressView` (`ProgressSessionLink`) — is it sound? The shared `SheetHeader`'s new
   opt-in `reflowsTitle`; the `-uiTestDesignGyms` fixture (can it touch other captures or a real
   store?).
4. Look and accessibility per REVIEW.md: the bold element per screen (Scan Machine the only
   filled command on the gym page; the top best the only hero figure on the machine page),
   grouping, light/dark, AXL layouts, VoiceOver (gym cards, machine rows now containers with an
   Open action, bests, restore buttons, chips), 44 pt targets, Reduce Motion (rolling counts,
   restore, chart draw-in), strings listed vs actual.
5. Performance: machine use rebuilt from all finished entries on appear and on history changes
   (gym page, machine page, deleted machines); visits per gym per render of the list; the picker's
   served-exercise map. Acceptable as history and the catalog grow?
6. Verification scope per DEVELOPMENT, and any product change ticket 06 does not list.

Do NOT run xcodebuild or simctl. Do not modify files other than the report. Report findings by
severity (critical / high / medium / low) with file:line and a concrete failure case, or say
"clear" in one paragraph. Write the report to `work-record/redesign-floodlight/codex-review-06.md`.
