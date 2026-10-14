Review public-beta ticket 03's **app half** in /Users/ericlee06/orca/workspaces/Health App/public-beta, branch
ericlee4992/beta-03-deploy: `git diff main..HEAD -- WorkoutTracker WorkoutTrackerTests WorkoutTrackerUITests Config`
(the server half was cleared in codex-review-03d and is unchanged except `APPLE_TEAM_ID`; the branch also adds ticket
10, a docs-only ticket). The ticket is work-record/public-beta/issues/03-server-and-apple-sign-in.md — read *First
deploy*, *App half — design* and *App half — implementation*. Spec: work-record/public-beta/spec.md → *Accounts*,
*Profile page*. The server contract is server/README.md → *Endpoints* and server/src/index.ts, apple.ts.

What changed: Sign in with Apple in the app against the deployed server — `Domain/AccountClient.swift` (requests,
answers, `SignInNonce`, `AccountSessionStore` keychain item), `Features/Account/AccountStore.swift` (the app-wide
signed-in state), the approved sign-in sheet / welcome button / delete confirmation wired to it, Settings' Account row
and the profile page on real data (rename, training save, sign out, delete), feedback sending the session, the
`com.apple.developer.applesignin` entitlement, and `WT_SERVER_URL` set to the production Worker in Shared.xcconfig.

Check, against the code and the server's actual behaviour:
1. **Sign-in correctness and safety:** nonce (raw kept, SHA-256 hex to Apple, raw to the server); the token stored
   only after the server's answer and only in the this-device-only keychain item; nothing logged; the name forwarded
   only as Apple gives it; double taps / concurrent completions; Apple's cancel not shown as an error; what happens
   when the keychain write fails.
2. **Session lifecycle:** a refused session (401) signs out everywhere it can surface (profile, usage, save, delete,
   feedback); offline keeps the session; sign-out forgets locally even when the server cannot be reached; a stale
   async answer cannot resurrect a signed-out state (the `token == self.token` guards).
3. **Deletion:** the confirmation, the three server answers (`done`/`pending`/`manual`), `409
   deletion_in_progress`, a 401 that deleted nothing (must never say "Account Deleted"), and that the iOS Settings
   follow-up is shown after the page closes (Settings owns that alert).
4. **Isolation:** signed-out behaviour unchanged; the guided tour (sample world) never shows the tester's real account
   (it gets a server-less store); UI tests never reach the network or keychain (`-uiTestReset` → sample/no-server
   store); a build with an empty `WT_SERVER_URL` shows no Account row or sign-in anywhere.
5. **Standards:** comments vs. callers, the approved copy used exactly (ticket → *Approved copy*), new strings listed
   for the user, accessibility identifiers kept, AGENTS/DEVELOPMENT conventions.

Claude's evidence (read the artifacts yourself; root
/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-public-beta/0dc39eb1-054d-49da-bf79-784fabae4a4e/scratchpad/03/):
`build2.log` (`** BUILD SUCCEEDED **`); `unit1.xcresult` (AccountTests 15, FeedbackTests 13, OnboardingTests 6,
TrainingProfileTests 9 — 43/43); `ui1.xcresult` (FloodlightAccount/Profile/Settings/Tour/Feedback UI tests). Not yet
done: a real Apple sign-in, rename, delete and revocation on the phone (needs a device build); the ticket says which.

Do not run builds, simulators or devices; modify nothing but your report. Write the report to
work-record/public-beta/codex-review-03-app.md with separate Standards and Spec sections, findings ranked P1–P3 with
file:line, ending with exactly "Verdict: clear" or "Verdict: not clear".
