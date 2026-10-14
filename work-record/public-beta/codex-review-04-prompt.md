Review public-beta ticket 04 — Google sign-in without Google's SDK — in /Users/ericlee06/orca/workspaces/Health App/public-beta,
branch ericlee4992/beta-04-google: `git diff 1be0768..HEAD -- server WorkoutTracker WorkoutTrackerTests WorkoutTrackerUITests
Config` (1be0768 = main; the branch's first commit is a docs record of TestFlight build 3, not for review). Ticket:
work-record/public-beta/issues/04-google-sign-in.md (*Progress*, the server half, the app wiring, the setup steps).
Spec: work-record/public-beta/spec.md → *Accounts* (Apple and Google; no SDK; ID token verified by the server; one account
per provider identity; no linking; deletion). Decision D60. The Apple flow it mirrors was cleared in codex-review-03*.

Check against the code, its callers, the standards (Google's OpenID Connect ID-token validation; RFC 7636 PKCE; RFC 8252
native-app OAuth; Apple's ASWebAuthenticationSession; Google's sign-in branding) and the server's actual behaviour:
1. Server: ID-token verification (signature/kid/alg, both issuer forms, `aud` and `azp`, expiry/iat leeway, subject,
   nonce binding, `email_verified`), the shared key-set cache refactor (`src/jwks.ts`; Apple's behaviour unchanged),
   account create/find races (`createOrFindAccount` with a null token), the profile's provider, deletion of a Google
   account (nothing of Google's kept; `appleRevocation`), not configured → 503.
2. App: the authorization URL, PKCE, state and nonce; the callback parsing (scheme, state, errors, cancel); the code
   exchange (no secret; form encoding); only the ID token used and nothing of Google's kept; `ASWebAuthenticationSession`
   use (anchor, lifetime, double taps); `AccountStore.signInWithGoogle` and the shared `adopt` path (keychain failure,
   sign-in failures and their copy); availability (`GoogleSignIn.clientID`/`isAvailable`; no button without a client ID
   outside the reset-only mock flag).
3. Button: Google's branding (colours, official G asset, label), Apple's button at least as prominent, Dynamic Type.
4. Tests: do server `test/google.test.ts` and app `GoogleOAuthTests` exercise what they claim? What is untestable until
   the client ID exists (a live sign-in) is stated as open.

Evidence (root /tmp/wt-floodlight/results/04/): server `npx vitest run` 218/218 and `tsc` clean (ticket; rerun not needed);
`build5.log`; `unit1.xcresult` (1011 tests: 1009 passed, the 2 failures were a wrong RFC 7636 constant in the test, since
fixed) and `unit2.xcresult` (GoogleOAuthTests + AccountTests 27/27 after the fix); `cap2.xcresult` (captures 4/4);
`ui1.xcresult`/`ui1.status` (FloodlightGoogle + FloodlightAccount UI on this build; may still be running).

Do not run builds, simulators or devices, and do not call the deployed server or Google; modify nothing but your report.
Write work-record/public-beta/codex-review-04.md with Standards and Spec sections, findings ranked P1–P3 with file:line,
ending with exactly "Verdict: clear" or "Verdict: not clear".
