# Codex review — ticket 22 (one Add Exercise button: Exercises | Machines)

Same session and rules as tickets 19–21 (you are the independent reviewer; Claude implemented). Branch
`ericlee4992/beta-19-bug-fixes`, checkout `/Users/ericlee06/orca/workspaces/Health App/beta-19-bug-fixes`.

Review the ticket-22 commit: `git diff 2ab1711..<the commit named at the end of the ticket>`.

Read first: `work-record/public-beta/issues/22-one-add-exercise-button.md` (the user's report and decision, build
notes, verification incl. which UI failures were load and which were real), D65 (new) and D7 in `docs/DECISIONS.md`,
milestone 2 ticket 17's D1 (`work-record/milestone-2-core-loop/issues/17-dogfooding-fixes.md`: with no gym the
machine path stays visible and says why), and AGENTS.md's code rules.

Check in particular:
1. **Behaviour.** `AddExerciseSheet` swaps `ExercisePickerSheet` (mode 0) and `AddByMachineSheet` (mode 1), each with
   its own `NavigationStack` and the `AddExerciseModePicker` row. Machine-first logging unchanged (D7: one linked
   exercise → added with the machine; a station → chooser; no model → full catalog; Add Machine…; delete with
   confirmation). Dismissal from either tab, a pushed chooser, the inline New Exercise sheet, state lost on a tab
   switch (search text, a pushed chooser) — anything surprising?
2. **No gym.** The Machines tab shows "Pick a gym to log by machine" (`addByMachineUnavailable`) and no Add Machine…;
   D1 is kept in its new place.
3. **`LiveAddBlock`.** Add Exercise (primary unless resting/cardio focus) + Add Cardio; removed `hasGym`/
   `addByMachine` with no remaining caller; `ActiveWorkoutView` has one sheet; the per-entry machine picker
   (`machinePickerEntry`) untouched.
4. **Other callers.** `ExercisePickerSheet` (`mode` optional; History's Add Exercise passes none) and
   `AddByMachineSheet` (`mode` optional; its title). Onboarding tour / What's New / SPEC references to "Add by
   Machine".
5. **Tests.** The rewritten UI helpers (every former `addByMachine` tap → Add Exercise → Machines; the preset file's
   wrongly-inserted step was removed), CoreLoop's no-gym check, the list-end captures' sheet shots. Accessibility of
   the switch (the pills carry `addExerciseMode`; labels Exercises / Machines; selected trait).
6. **Docs.** D65, README's "Fast logging" line.

Run yourself: `xcodebuild … build` on WT-Floodlight `9E822EF6-DC67-4958-AEA2-D53D2D36D674` (your own paths under
`/tmp/codex-22/`) and report the exit code. UI tests are optional (they take minutes each; say if you skip them and
inspect Claude's result bundles instead). Do not modify files other than the report; do not commit or push.

Write `work-record/public-beta/codex-review-22.md`: findings numbered P1/P2/P3 with file:line, failure scenario and fix;
end with exactly `Verdict: clear` or `Verdict: not clear`.

## Round 2

Round 1: [codex-review-22.md](codex-review-22.md), not clear (P3 header glyph). Claude's response: the ticket's "Codex
round 1" section and `git diff 92e1508..HEAD`. Check the finding is closed, that `LookSectionLabel`'s other callers
(SF Symbols, muscle-family marks) are unaffected, and nothing else regressed; rebuild (new path under
`/tmp/codex-22/`) and look at `runs/shots22r/`. Write `work-record/public-beta/codex-review-22b.md`, ending with exactly
`Verdict: clear` or `Verdict: not clear`. Do not commit or push.
