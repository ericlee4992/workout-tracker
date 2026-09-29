Round 3 of the independent review (T6) of ticket 11, same branch and checkout. Range for this round:
`ede5583..HEAD` (your round-2 report `codex-review-11b.md` reviewed up to `ede5583`). Read `issues/11-system.md` →
"Codex review 11b — response (round 2)" and the round-3 verification, then check each response against the code
and tests: the composite provider's rest replay (`WorkoutActivityProvider.sendRest` / `applyDesired`) and whether it
can resend a stale or ended rest; `coordinator.ready()` / `settled()`; the injectable provider factory; the fallback
marker's new clearing rule in `updateRest`; the coordinator's per-workout reset (`monitor(for:)` for another
workout, `releaseAlarm`); the new and changed tests (including the timing bounds). Report anything the round-2
fixes broke elsewhere (the Watch messages in the normal, warm path; phase switches; minimise / resume).
Do NOT run xcodebuild or simctl. Do not modify files other than the report. Report findings by severity with
file:line and a concrete failure case, or say "clear" in one paragraph. Write the report to
`work-record/redesign-floodlight/codex-review-11c.md`.
