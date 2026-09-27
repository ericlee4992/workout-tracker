Independent review (T6) of the Floodlight redesign's first two commits on branch
`ericlee4992/redesign-floodlight`: the design foundation and the Workout tab / template detail /
template editor. Range: `a0364f2..HEAD` (main is `a0364f2`). Claude implemented; you review.

Read first: AGENTS.md; `work-record/redesign-floodlight/issues/01-implement-redesign.md` (the
user's decisions: Floodlight everywhere + Paper-structure live workout, light/dark Appearance,
new wording approved as shown in the prototype, D54 reopened); `issues/02-workout-tab.md` (scope,
kept rules, changed strings and tests, decisions flagged for the user, verification);
`reference/look-api.md`, `reference/brief/constraints.md` §1–2 (product rules and the UI-test
contract), `reference/brief/domain-data.md` §3 (derived-data rules). The approved screens are in
`reference/captures/{dark,light}/W01-final.png`, `T01-final.png` (and the prototype source at
`/Users/ericlee06/orca/workspaces/Health App/redesign-prototype/RedesignPrototype/Sources/`,
read-only).

Review for:
1. Correctness of the derived data: `Domain/WeekSummary.swift` (finished workouts only, start-day
   bucketing, week boundaries in the locale calendar, warmups excluded, family counts,
   last-week count), `Domain/TemplateStats.swift`, `Domain/SetBadges.swift` (not wired to UI yet;
   rules in its header), and their tests. Any case where a number on screen would be wrong.
2. Behaviour preserved by the rewritten screens (`Features/Start/StartWorkoutView.swift`,
   `TemplateDetailView.swift`, `TemplateEditorSheet.swift`): start flow and dialogs, resume,
   gym selection memory (D1), no long-press tile menu, delete confirmation and consequence line,
   supersets carried through edits (codex-review 2 critical), cardio target rules, unknown cardio
   targets blocking save, template start machine resolution (`WorkoutTemplateService
   .resolvedMachine` was extracted from `start`; the detail now previews it — can they disagree?).
3. New editor behaviour: superset link/unlink and `normalizedSupersets`, drag reorder, rest chip
   Default vs a set time (and its fallback value vs what `RestTimerService.durationSeconds` would
   actually use), discard confirmation, Save enablement.
4. The Appearance setting (per-device `@AppStorage`, not `AppPreferences`: see ticket 01 Progress
   for the reasoning) and `.lookLayer()`: does every presentation (sheets, full-screen covers,
   alerts) get the right scheme and token set? The legacy `Theme` bridge: any colour pairing
   that becomes unreadable in light mode on a screen not yet rebuilt?
5. Accessibility: 44 pt targets, labels (MakeTile/DestructiveRowButton now carry explicit labels),
   AX layouts, Reduce Motion alternatives, VoiceOver values on the rep pills and rest chip.
6. The UI-test changes: do the edited tests still test what they claimed (the removed
   "Machines resolve" caption, the rest chip replacing the switch, the picker helper)? Is the
   verification scope in ticket 02 enough for this change, per DEVELOPMENT's policy?
7. Any change to product behaviour or visible wording that ticket 02 does not list.

Do NOT run xcodebuild or simctl (the simulator is in use). Do not modify files.
Report findings by severity (critical / high / medium / low) with file:line and a concrete
failure case, or say "clear" in one paragraph. Write the report to
`work-record/redesign-floodlight/codex-review-02.md`.
