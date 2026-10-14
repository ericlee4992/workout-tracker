# Ticket 03 — app-half review

Reviewed 2026-10-13 on `ericlee4992/beta-03-deploy`, HEAD
`37a46007cc5a1666592eaca8b120d324c9c923ec`, against local `main`
`a602d3ca2b7b97b06b43a0bb538eda4aedcfa9a2`, using exactly:

```sh
git diff main..HEAD -- WorkoutTracker WorkoutTrackerTests WorkoutTrackerUITests Config
```

The working tree was clean at review start. Sources of requirements: ticket 03's **First deploy**,
**App half — design**, **Approved copy**, and **App half — implementation**; public-beta spec's
**Accounts**, **Profile page**, and the feedback disclosure affected by this wiring; AGENTS.md,
DEVELOPMENT's verification scope, SPEC and D60. Checked the contract against `server/README.md`,
`server/src/index.ts` and `server/src/apple.ts`. The server diff is only `APPLE_TEAM_ID` and its
comment; this review does not reopen the cleared server half. Ticket 10 is outside this app diff.

Only this report was modified. No builds, tests, simulators, devices or live-server requests were run.

## Standards

1. **P3 — Correct the session-state comments.**
   `WorkoutTracker/Features/Account/AccountStore.swift:26` documents `.failed` as “still signed in,”
   but the unauthorized deletion branch at lines 195–198 calls `forget()` before returning `.failed`.
   Likewise, line 30 says a nil client means “no Account row, no sign-in anywhere” in UI tests, while
   the sample initializer at lines 54–59 deliberately has a nil client and `isAvailable` at line 42
   exposes those surfaces. Distinguish ordinary failures from an expired session, and server-less
   production/tour stores from UI-test sample stores. AGENTS.md explicitly requires checking internal
   functions and doc comments against their callers.

The approved sign-in, welcome and deletion copy matches the implementation, including removal of
“For AI and a training profile.” Additional user-facing strings are listed in the ticket. Existing
accessibility identifiers are preserved. Domain gains no UI imports, third-party runtime dependencies
or SwiftData schema changes. No additional code-smell finding is warranted.

## Spec

1. **P2 — Authenticated feedback falsely says “Not signed in.”**
   `WorkoutTracker/Features/Settings/SettingsView.swift:104–105`.
   Spec → Feedback requires the footer to show “the account if signed in.”
   `FeedbackDetails.forThisPhone` constructs details with `account: nil`
   (`FeedbackSheet.swift:461–472`), so `FeedbackSheet.swift:274` displays “Not signed in,” while the
   newly supplied bearer associates the submission with the tester's real account
   (`server/src/index.ts:156–159`). Populate the disclosed account from the same session used to send,
   including when a token exists but the profile has not loaded.

2. **P2 — Feedback 401 never signs out.**
   `WorkoutTracker/Features/Settings/FeedbackSheet.swift:543–544`.
   Ticket: “A 401 anywhere signs the phone out”; the user's review scope explicitly includes feedback.
   `FeedbackClient.error` reduces 401 to `.refused` (`Domain/FeedbackClient.swift:97–105`), and this
   catch only returns generic failure text. The token remains stored and retries keep sending it.
   Preserve unauthorized as a typed outcome and invalidate only the matching session, while retaining
   the draft. The ticket acknowledges this limitation, but it contradicts the requested lifecycle
   requirement and is not clearance to leave it unresolved.

3. **P2 — Offline cold launch removes access to Sign Out.**
   `WorkoutTracker/Features/Settings/SettingsView.swift:47–50`.
   Ticket: “Sign-out forgets locally first.” A restored token starts with no profile; failed refresh
   retains that state. Tapping Account only retries refresh, so the user cannot reach Sign Out without
   connectivity. A failing usage endpoint also blocks the profile because refresh requires both calls
   to succeed. Provide reachable account actions while profile data is unavailable; testing
   `AccountStore.signOut()` alone does not verify that the user can invoke it.

4. **P2 — A late deletion clears a newer session.**
   `WorkoutTracker/Features/Account/AccountStore.swift:192–203`.
   Ticket: “Every async answer is applied only if the token is still the same one.” Delete leaves
   Sign Out and navigation enabled. Start deletion, sign out, then sign in again while the old request
   is outstanding: its success, 401 or 409 calls `forget()` unconditionally and deletes the replacement
   keychain token. Guard deletion completions against session changes, including their UI effects.
   Refresh and save have token-equality checks; deletion does not.

5. **P2 — Deletion's 401 explanation disappears with its page.**
   `WorkoutTracker/Features/Account/ProfileSample.swift:82–83,108`.
   Ticket promises “You've been signed out. Sign in again to delete your account.” The store's 401
   clears `profile`; the screen consequently dismisses itself, while this explanation exists only
   in its local `problem` alert at lines 97–98. Retain and present this result from Settings after
   dismissal, or keep its presenting screen alive until acknowledgment. This path correctly avoids
   “Account Deleted,” but does not retain the promised explanation. Sample deletion keeps its profile,
   so the passing capture test does not exercise the disappearing alert owner.

6. **P2 — Profile failure can hide usage's 401.**
   `WorkoutTracker/Features/Account/AccountStore.swift:134–142`.
   Ticket: “A 401 anywhere signs the phone out.” If profile throws unreachable/5xx while usage returns
   401, awaiting the tuple throws the profile error and the unauthorized result is discarded. The
   catch therefore retains a session the server has refused. Inspect both outcomes independently,
   giving a matching session's 401 precedence over a transient failure of the other request.

No unrelated scope expansion was found.

## Verified behavior and evidence limits

Code inspection confirms the nonce path: 32 random bytes, raw value retained, lowercase SHA-256 hex
sent to Apple, raw nonce sent to the server's matching check. Names are forwarded only from Apple's
credential fields. A server answer precedes the keychain write; the dedicated generic-password item
uses `AfterFirstUnlockThisDeviceOnly`. The new account code logs no credentials or sessions. A failed
keychain write does not install the new session and attempts server sign-out. Apple cancellation is
suppressed. The MainActor `signingIn` guard rejects overlapping server sign-in calls; successful
refresh/save completions check the session before applying state. Actual Apple authorization and
concurrent callback behavior remain unexercised by the supplied tests.

Deletion confirmation uses the approved copy. `done` closes the page; `pending` and `manual` request
the Settings-owned Apple follow-up, as does `409 deletion_in_progress`. The server's 409 follows a
lost deletion claim, consistent with showing the cautious follow-up. A 401 returns the failure outcome,
never a deletion success. The real profile-clearing/presentation transition still needs a targeted
check: the sample UI path leaves the profile intact.

The guided tour receives its own server-less store and cannot display the real account. The account
factory under `-uiTestReset` uses sample/no-server stores and avoids the account keychain; empty
`WT_SERVER_URL` hides both Account and welcome sign-in in ordinary builds. The pre-existing explicit
`-uiTestRealServer` feedback smoke is an exception to feedback's normal test stub and was skipped in
the supplied run. The entitlement and production URL are present; no device signing/install claim
follows from the simulator evidence.

Read the artifacts directly under:

```text
/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-public-beta/0dc39eb1-054d-49da-bf79-784fabae4a4e/scratchpad/03/
```

- `build2.log`: `** BUILD SUCCEEDED **`; listed warnings are outside changed files. No separate build
  exit-status artifact was found, so this report relies on the successful build marker.
- `unit1.status`: `test=0`. `xcresulttool` summary/test tree for `unit1.xcresult`: **43 tests passed,
  zero failed** — Account 15, Feedback 13, Onboarding 6, TrainingProfile 9. The device tally is 46
  because one parameterized test runs four argument cases.
- `ui1.status`: `test=0`. `ui1.xcresult` and its log: **37 passed, zero failed, one skipped** — Account
  4, Profile 7, Settings 10, Tour 10, Feedback 6 passed plus skipped
  `testSmokeSendsToTheBuildsServer()`.
- `git diff --check` for the requested app scope passed.

Targeted verification is appropriate under DEVELOPMENT; a full UI suite is not requested. Existing
tests do not cover authenticated feedback disclosure/invalidation, offline access to account commands,
delayed deletion after session replacement, mixed profile/usage failures, or the real 401 dismissal
path. Add focused regression coverage for those fixes. Real Apple sign-in, rename/training save,
sign-out, deletion and Apple revocation on the phone remain pending, as recorded in the ticket.

Standards: **1 finding, highest P3**. Spec: **6 findings, highest P2**.

Verdict: not clear
