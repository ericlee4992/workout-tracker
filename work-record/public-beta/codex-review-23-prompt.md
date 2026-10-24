# Codex review — ticket 23 (template editor: Exercises | Machines, Add Machine and Scan)

Same session and rules as tickets 19–22 (you are the independent reviewer; Claude implemented). Branch
`ericlee4992/beta-19-bug-fixes`, checkout `/Users/ericlee06/orca/workspaces/Health App/beta-19-bug-fixes`.

Review ticket 23: `git diff 4ceefc7..<the commit named at the end of the ticket>`.

Read first: `work-record/public-beta/issues/23-template-machines-tab.md` (the user's report and two decisions, build
notes, verification), D66 (new), D6 and D7 in `docs/DECISIONS.md`, ticket 22 (the live workout's switch), and
AGENTS.md's code rules (CloudKit-compatible SwiftData, history rules).

Check in particular:
1. **The memory write** (`WorkoutSession.rememberMachine` and the refactored `upsertMemory`): identical behaviour for
   the logged-set path; canonical-row upsert (no duplicate rows); archived machine/gym refused; written only on
   Save, after validation (a Save that then fails — what is left in the context?); the editor's fetch by id.
2. **D6/D66 consequences.** Anything else that reads `GymExerciseMemory` (prefill, previous performance, Add
   Exercise's machine default, the template detail, AI routines, export) — does a pick without a logged set mislead
   any of them (e.g. "last used" wording, history layers that assume a memory row means a logged set)?
3. **Picker UI.** `TemplateExercisePicker` (lazy Exercises tab, non-lazy Machines tab), `TemplateMachinesTab` (initial
   gym from the selection, the menu, archived gyms excluded, no gyms, a gym with no machines, Add Machine… /
   `MachineEditorSheet` from a sheet inside a sheet, the station chooser, multi-add counts), the card caption, Edit
   Template (existing items have no machine; a re-pick).
4. **Tests.** `TemplateMachineChoiceTests`, `TemplateMachinesUITests` (does it prove the memory came from the pick,
   not the fixture?).
5. Docs: D66, README.

Run yourself: `xcodebuild … build` and `-only-testing:WorkoutTrackerTests/TemplateMachineChoiceTests
-only-testing:WorkoutTrackerTests/EquipmentLifecycleTests` on WT-Floodlight `9E822EF6-DC67-4958-AEA2-D53D2D36D674`
(paths under `/tmp/codex-23/`), and report exit codes. UI tests optional (say if skipped). Do not modify files other
than the report; do not commit or push.

Write `work-record/public-beta/codex-review-23.md`: findings numbered P1/P2/P3 with file:line, failure scenario and fix;
end with exactly `Verdict: clear` or `Verdict: not clear`.
