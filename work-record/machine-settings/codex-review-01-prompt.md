You are the independent reviewer (AGENTS.md T6) for machine-settings ticket 01, "My settings": a free-text setup note
per gym machine × exercise (seat, pins, pads, "hurt my elbow at 4"). Claude implemented it. Repository:
/Users/ericlee06/.paseo/worktrees/1qmeipq9/machine-settings, branch `ericlee4992/my-settings`. Diff under review:
`git diff 0916cc97..HEAD` (0916cc97 = the approved throwaway prototype, tag `design/my-settings-prototype`, on top of
`main` 9d7ac436; the diff removes the prototype and builds the real feature). For the whole change against main:
`git diff 9d7ac436..HEAD`.

Read first: AGENTS.md (the self-check defect classes, the delete rules, CloudKit rules); the ticket
work-record/machine-settings/issues/01-my-settings.md (the user's decisions 2026-11-16 and approval 2026-11-17, the
design, the build notes, the evidence); D91 in docs/DECISIONS.md (and D23, D28, T2); docs/SPEC.md "My settings" and
the data-model line; docs/DEVELOPMENT.md → "When a backup is required" and Verification scope.

This is a **stored-format change** (new `@Model` `MachineSettingsNote`, new relationship `MachineInstance.settingsNotes`,
cascade). Review for correctness, data safety and regressions:

1. Data: WorkoutTracker/Domain/MachineSettings.swift, Models.swift. One note per machine × exercise is app-side (no
   `@Attribute(.unique)`): is the canonical-row choice total and used consistently by read, save and the machine page?
   A blank canonical row means cleared — can an older duplicate ever resurface, or a cleared/blank note show anywhere?
   Can a note leak to another machine (same model, other gym) or another exercise? Is the failed-save undo exact for
   both the update and the insert path, and does nothing of a failed edit stay pending in the screen's context (the
   live workout shares it)? Delete rule (cascade from the machine; archive keeps notes); CloudKit compatibility.
2. Migration: `StoreFormatGuardTests` (`build16Fingerprint`, new `approvedFingerprint`), the fixture
   `WorkoutTrackerTests/Fixtures/Build16.store` (made per the ticket — is it truly in 0.2.0 (12)–(16)'s format?), and
   `MachineSettingsMigrationTests`. Anything that rewrites existing rows on first launch?
3. Privacy (D91): the note must never reach an AI prompt, the server, feedback, the Lock Screen / Live Activity, or
   History, and is not in the D23 snapshot. Check every reader (`rg settingsNotes\|MachineSettings`).
4. Export v15 (ExportSnapshot.swift, ExportCollector.swift): every row and field carried; counts; a note's exercise
   counted as referenced (D28); v14 files still decode; CSV unchanged. Does the N1 safety copy carry the new table?
5. UI: ExerciseEntryCard.swift (the line under the machine, the first-use chip, the "⋯" item only with a machine, the
   sheet; the history check once per machine × exercise via `.task(id:)` — any per-render fetch? a stale answer after
   the machine changes on a draft entry, or after the first workout finishes?), MachineDetailView.swift (rows per
   served exercise plus noted ones; station vs single), MySettingsViews.swift (Cancel discards, Save keeps, blank
   clears, failed save keeps the text and says so; AccessibilityL wraps, never truncates; VoiceOver labels/values).
   Strings: "My Settings", "My Settings…", "My settings", "Add My Settings", "Add…", the placeholder, the footer,
   "Couldn't Save" / "Your settings weren't saved. Try again."
6. Fixture `-uiTestDesignMySettings` (DesignSampleFixture.swift): UI-test stores only?
7. Tests: WorkoutTrackerTests/MachineSettingsTests.swift (+ migration), WorkoutTrackerUITests/MySettingsUITests.swift,
   the v14→v15 pin updates. Do they prove the claims? Gaps worth a test? Is the scope (Unit plan + MySettingsUITests)
   enough per DEVELOPMENT → Verification scope?
8. Docs: README, SPEC, DECISIONS D91, AGENTS.md delete-rule line, the ticket — do they say more than the code does?

Run: build and the Unit plan yourself (`-testPlan Unit`), and `-only-testing:WorkoutTrackerUITests/MySettingsUITests`
(round 1 reruns UI tests). Use ONLY simulator WT-Redesign-2 (EB4328A1-87BD-4850-A3B2-A6E604701F1C) with
`-derivedDataPath /tmp/wt-ms01-codex`; WT-Floodlight and WT-iPhone27 belong to other runs — do not touch them. The
author's results: build/results/unit-ms2.xcresult (Unit plan 1327/1327, exit 0) and build/results/ui-ms1.xcresult.

Rules: modify nothing except the report; no phone, Apple account or ~/WorkoutTracker-Backups access, no network
deploys, no desktop control. Write the report to work-record/machine-settings/codex-review-01.md: numbered findings
with severity (P0 … P3), file:line, the failure scenario and a suggested fix; say what you ran (commands, counts, exit
codes); then a last line that is exactly "Verdict: clear" or "Verdict: not clear".
