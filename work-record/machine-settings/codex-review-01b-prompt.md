Round 2 of your review of machine-settings 01 (same rules, simulator and derived data as round 1:
work-record/machine-settings/codex-review-01-prompt.md). Your round-1 report: work-record/machine-settings/codex-review-01.md.

The fix for #1 (P2, canonical-row demotion with a backward clock): `git diff a84a6b4e..HEAD -- WorkoutTracker WorkoutTrackerTests`
— `MachineSettings.save` now sets `updatedAt = max(previous, date)` on the edited row; regressions
`anEditAtAnEarlierTimeKeepsTheRowCanonical` (clearing and editing duplicates at an earlier time) and
`anEqualDateTieStaysWithTheEditedRow` (equal dates, the UUID tie). The rest of the diff since a84a6b4e is STATE and the ticket.

Check the fix closes the scenario without breaking the failed-save restore, and that nothing else regressed. This round
changes domain code and unit tests only (no UI code), so build and run the affected unit suites
(`-only-testing:WorkoutTrackerTests/MachineSettingsTests -only-testing:WorkoutTrackerTests/MachineSettingsMigrationTests`,
or the whole Unit plan if you judge it needed); inspect build/results/unit-ms3.xcresult rather than rerunning UI tests,
and say so. Write work-record/machine-settings/codex-review-01b.md, ending with exactly "Verdict: clear" or "Verdict: not clear".
