# Codex review — soft redesign S6 (Profile like the prototype)

You are the independent reviewer; Claude implemented. Read AGENTS.md first. Checkout
`/Users/ericlee06/orca/workspaces/Health App/UI_design`, branch `ericlee4992/soft-06-profile` (off `main` `5f8ff92`).
Review `git diff 5f8ff92..HEAD`.

Read first: `work-record/soft-redesign/issues/06-profile-layout.md` (the user's approval and groups; Design: job,
wireframe, the reachability checklist, the strings, the tells; Progress: what was built, the test scope, evidence),
`work-record/soft-redesign/spec.md`, D68, the approved prototype `SoftProfileScreen` (`git show
design/soft-approved-2026-11-07:DesignPrototype/Sources/Screens/Soft/SoftProfileAndAdd.swift`), and the design review
checklist `.claude/skills/ios-design/REVIEW.md` (with `SKILL.md` and `REFERENCE.md` as it directs). The swiftui-pro
skill applies to the SwiftUI code; project rules override it.

Check in particular:
1. **Like the prototype, within the approved scope:** account card, Settings group, Help, version; no Training group
   (D68); Goals & tracking left for N3/N9 (not drawn while empty — agree?).
2. **Nothing lost:** every control the old one-page `SettingsView` had is reachable (the ticket's checklist): units,
   appearance, rests, ask to update templates, the history note, heart rate zones, Ask AI, export (counts, last export,
   the only-copy notice), N1's Safety copy (and its restore-failure message, also shown on Profile), Show Tour, What's
   New, Send Feedback, the account (sign in, account page, deletion alerts). Sheets/alerts still attach to a view that
   is on screen when they fire (e.g. the account deletion alerts after the account page closes; the tour-failure alert).
3. **Code:** `Features/Settings/ProfileTabView.swift` (`ProfileRow`: the AX-size value-under-title layout and the one
   VoiceOver label), `ExportBackupView.swift`, the trimmed `SettingsView.swift`, `SettingsAccountRow` in
   `Features/Account/ProfileView.swift`, `RootView`; the removed `SettingsZoneLadder`. Dead code, duplicated logic
   between Profile and Export & backup (the only-copy rule), identifiers.
4. **Design (REVIEW.md):** one bold element per state, cards vs lists, type, colour, Dynamic Type, the strings list
   (new strings are the user's decision — check the ticket lists every new or changed one).
5. **Tests:** the helpers `openProfileSettings()` / `openExportBackup()` in `WorkoutTrackerUITests/TabNavigation.swift`
   and every updated test — do they still test what they are named for (e.g. the tour's "nothing escaped" check now
   uses `profileSettings`)?

Per AGENTS' reviewer rule (round 1): build; run as UI classes, with `-parallel-testing-enabled YES
-parallel-testing-worker-count 3`: `AAAWarmUpUITests`, `FloodlightSettingsUITests`, `ExportUITests`,
`FloodlightFeedbackUITests`, `FloodlightTourUITests`, `SafetyCopyUITests`, `FloodlightAccountUITests`,
`FloodlightProfileUITests`, `FloodlightAIAccessUITests`, `FloodlightWhatsNewUITests`, plus
`RedesignScreenshotUITests/testUnitSystemDefault`, `HeartRateUITests/testZonesAreReachableFromSettings`,
`FloodlightWorkoutTabUITests/testAppearanceReachesScreensAndSheets` (rerun any failure serially before judging; a
share-sheet close on a parallel clone is a known flake). Open the captures and look at them as pictures: Claude's are
in `/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/f473a23d-3eaa-41a2-9817-2ebe24bda24e/scratchpad/s6-caps/`
(`named/`, the contact sheets `sheet-*.png`) and its results `s6-ui1.xcresult`, `s6-ui1-rerun.xcresult`.

Run on **WT-iPhone27** `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B` (`scripts/prepare-test-simulator.sh <id>` first), paths
under `/tmp/codex-s6/`. Show progress in the existing Orca tab "Test progress (Claude r2)"
`term_ac1339dc-202d-4c10-bab3-b528de726cbd` once it is back at its prompt — do not open a new terminal. Do not modify
files other than the report; do not commit or push.

Write `work-record/soft-redesign/codex-review-s6.md`: findings P1/P2/P3 with file:line, failure scenario and fix; a
Verified / Not verified / Known flaky block; end with exactly `Verdict: clear` or `Verdict: not clear`.
