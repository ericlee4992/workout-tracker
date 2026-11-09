# Codex review — nutrition N1 (automatic safety copy)

You are the independent reviewer; Claude implemented. Read AGENTS.md first. Checkout
`/Users/ericlee06/orca/workspaces/Health App/UI_design`, branch `ericlee4992/nutrition-01-safety-copy` (off `main`
`52c1270`). Review `git diff 52c1270..HEAD`.

Read first: `work-record/nutrition/issues/01-safety-copy.md` (the user's decisions 2026-11-09 — all as proposed, then
"files only"; Progress: the decisions made while building, screens, strings, evidence), the original
`work-record/public-beta/issues/11-safety-copy.md` (facts found 2026-10-14), D28, DEVELOPMENT → *When a backup is
required*, and `WorkoutTrackerTests/StoreFormatGuardTests.swift`.

This protects testers' only copy of their data before N2 changes the stored format. Check in particular:
1. **When** (`SafetyCopies.storeNeedsCopy`): metadata vs `NSManagedObjectModel.makeManagedObjectModel(for:)` — does it
   predict exactly when SwiftData's open would migrate (no false negatives: a lightweight migration N2 might add; a
   store with only a WAL change; `nil` model; an unreadable store), and never fire on ordinary launches?
2. **The copy** (`make`): copied while closed — is anything able to hold the store open at that point
   (`WorkoutActivityCommands`, the widget/Live Activity, a background launch from a Lock Screen command, the onboarding
   tour's sample container)? WAL/SHM consistency, the space check, staging + rename, sizes, prune (never the pending
   copy), the manifest, backup inclusion (Application Support, not excluded).
3. **Restore** (`scheduleRestore`, `performPendingRestore`, `SafetyCopyLaunch.run`): staged beside the store, a failure
   part-way, removing side files the copy has none of, the request cleared either way, no copy of the restored files,
   the failure surfaced in Settings; a restore then a format-changing build.
4. **Start-up refactor** (`WorkoutTrackerApp`, `App/StoreGate.swift`): every step that ran after the container was
   created still runs, in the same order, before any screen reads the store (`prepare(_:)`); UI-test paths
   (`-uiTestReset`, fixtures) unchanged; the copy-failed screen keeps the store closed; Try Again / Continue; nothing
   else reads `modelContainer` before it exists; the `preconditionFailure` getter's reachability.
5. **UI** (`Features/Settings/SafetyCopyViews.swift`, the Settings section): identifiers, AX sizes, the overlay for the
   pending restore (why not a cover — see the ticket), the "Data restored" alert, the strings list.
6. **Tests:** `SafetyCopyTests` (Core Data–written stores — is that a faithful stand-in?), `SafetyCopyUITests`,
   `scripts/test-plans.py` mapping; the guard's updated messages.

Per AGENTS' reviewer rule: build; run the Unit plan (or at least `SafetyCopyTests`, `StoreFormatGuardTests`,
`SchemaTests`) and, as round 1, the UI classes `AAAWarmUpUITests`, `SafetyCopyUITests`, `CoreLoopUITests` serially.
Repeat the Simulator rehearsal on WT-iPhone27 if you can (the ticket's steps: a store in the app's real store location,
`-safetyCopyRehearsal` → one copy, ordinary launch → none, damage with the app closed, `restore-pending.json`, launch,
`scripts/container-tools/compare_stores.py`) — back up that simulator's own store first and put it back after.
Inspect Claude's evidence in
`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/b075476f-cb86-4797-a96b-088b73936c7a/scratchpad/m/`
(`n1-*.xcresult`, `rehearsal/`, `n1-caps/`).

Run on **WT-iPhone27** `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B` (`scripts/prepare-test-simulator.sh <id>` first), paths
under `/tmp/codex-n1/`. Show progress in the existing Orca tab "Test progress (Claude r2)"
`term_ac1339dc-202d-4c10-bab3-b528de726cbd` once it is back at its prompt — do not open a new terminal. Do not modify
files other than the report; do not commit or push.

Write `work-record/nutrition/codex-review-n1.md`: findings P1/P2/P3 with file:line, failure scenario and fix; a
Verified / Not verified / Known flaky block; end with exactly `Verdict: clear` or `Verdict: not clear`.
