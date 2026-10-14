# Ticket 04 — Google sign-in review

Reviewed by Codex, 2026-10-14, on `ericlee4992/beta-04-google`.
Base: `1be076856557014c66f6dc774023f24200122bd1`. Final reviewed HEAD:
`37702e43ca53b2f9741b0e3e3828eebb7cb3ca51`.

Scope: `git diff 1be0768..HEAD -- server WorkoutTracker WorkoutTrackerTests WorkoutTrackerUITests Config`.
HEAD advanced from `7037466` during review, but the added checkpoint changes only STATE and the ticket;
the implementation remains `df67c22`. The initial TestFlight documentation commit is excluded from
the review. Working tree was clean before this report. Read ticket 04 (including Progress and setup),
the public-beta Accounts contract, D60, relevant project rules, and the cleared ticket-03 server/app
reviews. Standards and Spec were independently inspected in parallel and checked against callers.

Only this report was written. No builds, tests, simulators, devices, deployment, or live authentication
requests were run. External lookups were limited to published standards/documentation.

## Standards

1. **P2 — Validate the complete callback destination and state before interpreting its result.**
   `WorkoutTracker/Domain/GoogleOAuth.swift:80–85` checks only the scheme, then handles `error` before
   checking state. Consequently, `<scheme>:/wrong-path?state=<correct-state>&code=x` yields a code,
   and `<scheme>:/oauth2redirect?error=access_denied` with missing or incorrect state becomes a silent
   cancellation. `GoogleSignIn.swift:24` supplies a scheme-only callback matcher, so it does not enforce
   the missing destination check. [RFC 8252 §8.10](https://www.rfc-editor.org/rfc/rfc8252.html#section-8.10)
   requires matching the received redirect URI to the one used for authorization; §8.9 requires binding
   responses to the initiating session. Compare the destination components against `redirectURI`
   (excluding response query parameters), and validate state before accepting either code or OAuth
   error. Add wrong-path/authority and missing/wrong-state error cases to `GoogleOAuthTests`.
   PKCE and server nonce verification still protect token acceptance; this finding does not establish
   an account takeover.

2. **P3 — Preserve provider-specific errors for every shared JWKS refresh waiter.**
   `server/src/jwks.ts:31` returns the raw `inflight` promise before the exception mapping at lines
   37–40. With a warm cache, simultaneous unknown/rotated-key tokens, and a refresh returning non-2xx
   or malformed `keys`, the initiating request receives `503 apple_keys_unavailable` or
   `google_keys_unavailable`; joined requests instead propagate `KeySetError` to
   `server/src/index.ts:191–195`, producing `500 server_error`. The previous Apple implementation
   threw `AuthError` directly for these failures, so the extraction changes Apple's behavior despite
   the ticket's “unchanged behaviour” requirement. Normalize rejection on the shared promise or route
   all waiters through the mapping. Add a deferred, failed-refresh concurrency test. This is a traced
   regression, not an executed reproduction.

3. **P3 — The custom button's typography does not match the cited Google branding.**
   `WorkoutTracker/Features/Account/SignInViews.swift:47` explicitly uses the system font. Google's
   current [branding guide, Font and Padding](https://developers.google.com/identity/branding-guidelines)
   specifies Google Sans Medium; its iOS example also uses a 12-point logo-to-label gap, while line 40
   uses 10. Use the prescribed typeface and iOS spacing while retaining Dynamic Type and equal button
   prominence; document the provider-brand exception to the app's normal system-font rule. The
   approved wording, gradient G, light/dark colors and capsule treatment otherwise match the intended
   branding. This is a published-guideline discrepancy, not a preference for a different composition.

No additional actionable code-smell findings. The PKCE implementation uses 32 random bytes, an
unpadded base64url verifier, and S256, consistent with [RFC 7636](https://datatracker.ietf.org/doc/html/rfc7636).
The corrected expected challenge matches the RFC example. The authorization URL requests a code and
`openid email profile`, includes independent state and hashed nonce, and uses the reversed-client-ID
redirect documented for [Google native apps](https://developers.google.com/identity/protocols/oauth2/native-app).
The exchange includes the verifier and no secret; its body explicitly escapes `+` as `%2B`.

`ASWebAuthenticationSession` uses a retained presenter/session, a key-window anchor, and the modern
custom-scheme callback. The store sets `signingIn` before awaiting authorization, preventing a second
Google session; user cancellation produces no failure message. Apple's installed SDK header explicitly
allows supplying the callback scheme instead of registering it in Info.plist; absence of a URL type
is not a finding. Browser presentation/lifecycle still needs the live acceptance check.

## Spec

1. **P2 — A concurrent Google deletion can display the Apple-only follow-up.**
   `WorkoutTracker/Features/Account/AccountStore.swift:319–323` maps every `409 deletion_in_progress`
   to `.deletedNeedsAppleStep`. This previously Apple-only branch is now reachable by Google accounts:
   two authenticated devices can delete the same account concurrently, and the loser receives that
   response from `server/src/index.ts:176–180`. `ProfileSample.swift:106–113` forwards the outcome to
   `SettingsView.swift:88`, which displays the instruction to stop using Stacked under Sign in with
   Apple. A Google-only account has no such Apple authorization. The Accounts contract limits the
   Apple revocation obligation to “for Apple accounts”; ticket 04 keeps no Google token to revoke.
   Preserve provider context across the asynchronous deletion (including a concurrent refresh clearing
   the profile), or return a provider-aware race result. Add a Google losing-deletion regression test;
   retain the existing Apple fallback and session-supersession protections. Normal Google deletion's
   `appleRevocation: "done"` already works correctly.

2. **P3 — A failed Google token exchange is reported as a Stacked outage.**
   `WorkoutTracker/Features/Account/AccountStore.swift:176–178` maps Google's timeout/network/5xx
   failures to `SignInFailure.unreachable`, whose text at `ProfileSample.swift:160` is
   “Can't reach Stacked right now. Try again later.” At this point the app has contacted only Google's
   token endpoint; Stacked may be healthy and has not received this sign-in. Use the existing generic
   sign-in failure or approved provider-appropriate copy for this stage, and keep the Stacked-specific
   message for `adopt`'s server call. Cover the Google exchange failure mapping without live services.

Otherwise the inspected implementation follows Accounts and D60:

- `server/src/google.ts:36–64` verifies RS256 with the selected published key, both Google issuer
  forms, configured audience, `azp` when present, numeric expiry/issued-at with the stated 60-second
  leeway, a bounded nonempty subject, and the hashed raw nonce. Only boolean-verified email is retained.
  Missing client configuration yields 503. These checks follow
  [Google's ID-token validation and claim semantics](https://developers.google.com/identity/openid-connect/openid-connect#validatinganidtoken).
- Identity lookup uses provider plus subject, never email. The atomic creation conflict path accepts
  a null provider token and joins the winning account; session insertion detects deletion between
  lookup and insertion and returns `reauthorize`, without recreating that deleted account. Profile
  reads/writes obtain the actual provider. Google deletion removes account data without creating
  Apple revocation work. No provider token is persisted by either app or server.
- Both real button callers use `GoogleSignIn.isAvailable`; the empty build setting hides Google.
  The mock exception requires `-uiTestReset` through `ProfileSample.flag`. The shared `adopt` retains
  keychain-failure session cleanup, profile refresh, and the existing server-failure behavior.
  Only Stacked's session enters Keychain. Signed-out/offline workout behavior is unchanged.
- The captured buttons have equal heights, Apple first and at least as prominent, readable labels at
  Default and AccessibilityL, and the expected light/dark treatments. Inspected exported captures in
  `shots2` via their manifest, including both sheet sizes/appearances, welcome, and AccessibilityL
  failure. The welcome tagline behind the controls at AccessibilityL is already disclosed and
  explicitly user-approved; this review does not reopen that composition decision.
- Setup correctly separates the iOS client ID's app setting from the server setting. The client is
  not yet created/configured; live Google sign-in, sign-out and deletion on Simulator and phone remain
  explicitly open. Neither code review nor mock captures establish those acceptance results.

## Test evidence and limits

Root: `/tmp/wt-floodlight/results/04/`.

- `build5.log:230`: **TEST BUILD SUCCEEDED**. This is a recorded build-for-testing success, not a new
  build performed by this review.
- `unit1.xcresult`: summary **1011 tests, 1009 passed, 2 failed**. Both failures are the incorrect
  expected RFC challenge constant, in the PKCE-example and authorization-URL tests; the recorded
  actual result matches the corrected constant in current source.
- `unit2.xcresult`: summary **27/27 passed**, no failures or skips, after that correction. The device
  tally of 30 counts parameterized invocations separately.
- `cap2.xcresult`: **4/4 passed**, no failures or skips. These test sample rendering/reachability and
  equal button heights, not browser authentication.
- `ui1.status` is absent; `ui1.xcresult` lacks `Info.plist` and cannot be opened by `xcresulttool`.
  The log contains no completed result. The latest ticket checkpoint says the run was stopped.
  **FloodlightGoogle + FloodlightAccount regression is unfinished, not passed**; finish the targeted
  run before closing the ticket. No rerun was attempted under the review's constraints.
- Server **218/218** and clean TypeScript compilation are accepted as supplied ticket evidence,
  not independently rerun. `google.test.ts` contains the claimed 22 tests, including 13 rejection
  cases with real test-key signatures. It checks sequential repeated sign-ins, not the Google
  null-token creation race; shared failed-refresh concurrency is also uncovered.
- `GoogleOAuthTests` checks pure request/callback/extraction behavior and the server request. Existing
  `AccountTests` exercises shared adoption via Apple; it does not exercise the complete Google store
  flow or session presentation. The form test reparses with `URLComponents`, which does not decode
  `+` as a form-space, so it would miss removal of the production `%2B` substitution; assert that
  encoding explicitly or decode with form semantics when extending this test.
- The reviewed scoped diff passes `git diff --check`. Findings above were established by source and
  caller inspection; no new execution-based reproduction is claimed.

Standards: **3 findings**, worst **P2** (callback binding). Spec: **2 findings**, worst **P2**
(Google deletion's Apple follow-up). No P1 finding established.

Verdict: not clear
