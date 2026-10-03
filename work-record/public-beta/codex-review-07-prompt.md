You are the independent reviewer (AGENTS.md T6) for public-beta ticket 07 (in-app feedback: the server endpoint and the
app's Settings → Send Feedback form). Claude implemented it. Repository: /Users/ericlee06/orca/workspaces/Health
App/public-beta, branch ericlee4992/beta-07-feedback. Diff under review: `git diff e455222..HEAD` (e455222 = main; the
two earliest commits on the branch are STATE-only handoff notes).

Read first: AGENTS.md; work-record/public-beta/issues/07-feedback.md (scope, Design, Progress — the user approved the
form's captures and copy on 2026-10-03 and chose: phone shown by readable name, the category starts on Bug);
work-record/public-beta/spec.md → Accounts (deletion), Server, Feedback, Engineering constraints; D60 in
docs/DECISIONS.md; server/README.md; .claude/skills/ios-design/SKILL.md and REVIEW.md for the screen.

Review as a security and correctness reviewer of a PUBLIC repository's unauthenticated upload endpoint and the app
that calls it:
1. Server (server/src/feedback.ts, http.ts, index.ts, store.ts, migrations/0003_feedback.sql, wrangler.jsonc):
   multipart parsing and the per-route byte limit (streamed, declared), field validation (message length counted as
   graphemes to match Swift's String.count, control characters, the detail patterns), image type sniffing (JPEG/PNG
   only, never the declared type), R2 key naming, the order of limit → R2 put → row insert, the conditional insert
   for a signed-in account racing its deletion, and the bearer handling (a sent-but-invalid token must not be filed as
   signed out).
2. Rate limits: 10/day signed out per address, 30/day per account, 500/day global, New York day. The address key is
   an HMAC of day|address under a key derived from TOKEN_ENC_KEY — is it non-reversible and unlinkable across days?
   Is anything that identifies an address stored? Can a client reset or evade its counter (headers, IPv6 variants)?
   Does a refused request spend quota when it should not?
3. Account deletion covers feedback: claimDeletion's batch now also selects screenshot keys and deletes feedback rows
   and the account's counter in the same transaction; R2 deletes follow, and the hourly cron sweeps objects without a
   row after a 1-hour grace. Gaps, races, R2 list/delete semantics (batch delete limits, pagination), the sweep's
   cost, a feedback row whose R2 put succeeded but whose insert failed.
4. The reader script (server/scripts/feedback.mjs): command/SQL injection (it interpolates a validated UUID and an
   integer), where screenshots land, anything that could leak tester data into the repository.
5. App (WorkoutTracker/Domain/FeedbackClient.swift, Features/Settings/FeedbackSheet.swift, SettingsView.swift,
   Config/Shared.xcconfig, Config/WorkoutTracker-Info.plist): the WT_SERVER_URL → Info.plist → ServerConfig path
   (xcconfig `//` comment trap, an empty value hides the row), multipart construction, error mapping to the approved
   lines, the screenshot re-encode (EXIF/GPS stripped? size cap vs the server's 5 MB), the message cap (4,000
   Characters) vs the server's count, the UI-test seams (`-uiTestReset` gates; `-uiTestRealServer`,
   `-uiTestFeedbackSample`, `-uiTestFeedbackFail` must not be reachable in a normal launch), PhotosPicker loading,
   interactive dismiss, VoiceOver labels, Dynamic Type at AccessibilityL. Check the form against the ios-design
   REVIEW.md and the approved captures in work-record/public-beta/captures/07/.
6. Tests: server/test/feedback.test.ts (and helpers.ts changes), WorkoutTrackerTests/FeedbackTests.swift,
   WorkoutTrackerUITests/FloodlightFeedbackUITests.swift. Do they prove the claims? Missing cases?
   You may run `cd server && npx vitest run` and `npx tsc --noEmit` (no network needed). You may run
   `xcodebuild test ... -only-testing:WorkoutTrackerTests/FeedbackTests` on the simulator WT-Onboarding
   (2CEC4AD8-F702-421F-B3B2-D68C302A3453) with `-derivedDataPath /tmp/wt-beta07-codex`.
7. README and ticket accuracy.

Rules: modify nothing except the report; no network calls to Cloudflare or Apple, no `wrangler login/deploy/secret`
and no `wrangler dev`, no phone, Apple account or ~/WorkoutTracker-Backups access, no desktop control (`orca
computer`). Write the report to work-record/public-beta/codex-review-07.md: numbered findings with severity (P0 … P3),
file:line, the failure scenario and a suggested fix; then a last line that is exactly "Verdict: clear" or
"Verdict: not clear".
