# Ticket 04 — Google sign-in re-review

Reviewed by Codex, 2026-10-14, on `ericlee4992/beta-04-google`.
Base: `37702e43ca53b2f9741b0e3e3828eebb7cb3ca51`. Final reviewed HEAD:
`0e1614e503467d8324dc4bb45b42f720798297a9`.

Scope: `git diff 37702e4..HEAD -- server WorkoutTracker WorkoutTrackerTests WorkoutTrackerUITests Config`.
Implementation fixes: `f879314`, `ef9372c`, `27dbf45`. HEAD advanced during review from `3603245`
to `0e1614e`; that intervening commit changes only STATE. The scoped implementation is unchanged.
Read the previous report, ticket's round-1 progress, Accounts contract, D60, verification policy,
and iOS design skill/reference/checklist. Standards and Spec received parallel independent inspection,
followed by source/caller and saved-evidence verification.

All five round-1 findings are resolved. No new actionable P1–P3 finding was established.
Only this report was written. No builds, tests, simulators, devices, deployments, or live authentication
requests were run. External reads were limited to public documentation.

## Standards

No remaining P1–P3 findings.

1. **Round 1 Standards #1 (P2), callback binding — resolved.**
   `WorkoutTracker/Domain/GoogleOAuth.swift:82–93` compares the scheme case-insensitively and the
   encoded path against the requested redirect, rejects nonempty host, port and credentials, and
   validates state before interpreting either an error or a code. Its production caller remains
   `AccountStore.swift:169–175`; the scheme-only authentication-session matcher is supplemented by
   this destination check. A valid `access_denied` still cancels; closing the browser still cancels
   through `GoogleSignIn.swift:26–29` without manufacturing a callback.

   No legitimate callback newly refused was identified for this authorization-code flow. The requested
   URI is the documented single-slash custom-scheme form ending in `/oauth2redirect`; response query
   ordering, additional Google parameters, and percent-encoded code values remain accepted. The app
   supplies state, so requiring its return on OAuth errors is correct. See
   [Google's native-app redirect documentation](https://developers.google.com/identity/protocols/oauth2/native-app)
   and [RFC 6749 §4.1.2.1](https://datatracker.ietf.org/doc/html/rfc6749#section-4.1.2.1).
   `GoogleOAuthTests.swift:62–79` directly exercises the previously accepted wrong destinations and
   missing/wrong-state errors, plus an uppercase scheme. Existing success/cancellation cases remain.

2. **Round 1 Standards #2 (P3), shared JWKS failure mapping — resolved.**
   `server/src/jwks.ts:28–43` sends every fetch waiter through the provider-specific catch. The path
   audit covers fresh known keys (immediate cache hit), fresh unknown keys with an in-flight refresh
   (join before cooldown), fresh unknown keys without one (five-minute cooldown), and cold/expired
   caches (shared fetch). Starting a forced refresh still updates the cooldown once; joining does not
   move it. A completed failed forced refresh retains the previous cache and cooldown, as before.
   HTTP rejection, transport/timeout rejection, JSON decoding failure, and a missing/non-array `keys`
   all reach `unavailable()` for every waiter. An absent key after a successful refresh remains an
   invalid token, not a key-service outage.

   Checked provider factories/callers at `server/src/apple.ts:25,46`, `google.ts:17,47`, and the
   `AuthError` response mapping at `index.ts:191–195`. Compared with Apple's pre-extraction behavior:
   cache lifetime, refresh limits, key/claim verification and token exchange remain unchanged otherwise.
   The new Google and Apple tests at `server/test/google.test.ts:83–117` warm the cache, hold a failed
   refresh, and require all three responses to be the correct provider's 503 with only one refresh.
   These assertions exercise joining: a request arriving after completion would hit cooldown and
   produce 401, failing the test. The fixed 50-ms hold can be timing-sensitive; it cannot silently
   establish the asserted outcome without the relevant overlap. Only HTTP failure is explicitly
   injected; the other error paths are supported by the common inspected catch.

3. **Round 1 Standards #3 (P3), font and spacing — resolved on the merits.**
   `WorkoutTracker/Features/Account/SignInViews.swift:24–62` documents the provider-brand exception
   to system typography and uses the renamed Google Sans Medium subset, a 12-pt default logo gap
   and 16-pt default side padding. These values scale relative to headline, alongside the logo and
   button. `textSize` is already a `ScaledMetric`; `.custom(_:fixedSize:)` correctly consumes that
   scaled value without applying a second Dynamic Type scaling pass. The label's existing shrink
   allowance preserves its complete text when width is constrained. These changes follow the font
   and iOS spacing in [Google's branding guide](https://developers.google.com/identity/branding-guidelines).

   Inspected the actual TTF name/OS/2 tables: family/full/PostScript names are renamed to Stacked,
   the PostScript name matches `StackedSignInLabel-Medium`, weight is 500, and original copyright,
   author, trademark and OFL metadata remain. The bundled `StackedSignInLabel-OFL.txt:1–98` identifies
   the modified subset and includes the original copyright and complete OFL 1.1. Subsetting and
   embedding with this notice are consistent with the [upstream OFL](https://raw.githubusercontent.com/google/fonts/main/ofl/googlesans/OFL.txt).
   Google's [trademark note](https://raw.githubusercontent.com/google/fonts/main/ofl/googlesans/TRADEMARKS.md)
   explicitly has no OFL Reserved Font Names, but separately restricts trademark use; renaming the
   modified face avoids presenting it under Google's mark. Attribution in the licence/metadata does
   not rename the derivative or claim sponsorship. No licence/trademark packaging defect identified.

   `Config/WorkoutTracker-Info.plist:21–24` registers the exact bundled filename. The saved built app's
   `UIAppFonts` agrees; its font and licence match the repository files byte-for-byte. The runtime
   `UIFont` lookup in `GoogleOAuthTests.swift:125–128` checks that the registered PostScript name
   actually loads, preventing a silent system-font fallback.

   Opened all 12 `shots4` PNGs through their manifest: sheet, failure and welcome, light/dark,
   Default/AccessibilityL. Labels are whole, have visible side clearance, and retain equal button
   heights and Apple-first ordering. The font remains readable and comparable in prominence. The
   previously approved welcome-tagline overlap at AccessibilityL is unchanged. The failure captures
   deliberately use the existing mocked Stacked-outage state; they do not demonstrate a real Google
   exchange failure. **The user's approval of this look change remains pending; this review does not
   supply that approval.**

No additional actionable code-smell finding.

## Spec

No remaining P1–P3 findings.

1. **Round 1 Spec #1 (P2), provider-specific deletion race — resolved.**
   `WorkoutTracker/Features/Account/AccountStore.swift:313` captures the displayed provider before
   suspension. The comparison at `:334` lowercases it, correctly handling the store's actual
   `"Google"` string. A refresh's 401 can erase the profile/session without erasing that capture.
   The newer-session guard at `:321` remains; Apple or an unknown provider retains the cautious
   fallback. `ProfileSample.swift:106–115` and `SettingsView.swift:86–90` propagate `.deleted`
   without displaying the Apple instruction. This matches the Accounts contract's Apple-only
   revocation obligation.

   `WorkoutTrackerTests/AccountTests.swift:300–319` genuinely gates DELETE, verifies the displayed
   Google provider, clears profile and session via a concurrent refresh's 401, releases DELETE with
   409, and checks `.deleted`. It separately checks Apple's fallback. Existing supersession and
   duplicate-delete tests retain their coverage.

2. **Round 1 Spec #2 (P3), Google exchange failure copy — resolved.**
   `AccountStore.swift:179–191` catches Google's token-exchange failures and uses the existing generic
   sign-in message; `adopt` at `:145` still uses Stacked-specific outage copy for the server call.
   The sole production call to the extracted method (`:175`) remains inside `signInWithGoogle`'s
   duplicate-session guard and deferred busy-state cleanup. Both sheet and welcome still call that
   guarded entry point. No new user-facing string or loss of shared adoption/Keychain cleanup found.

   `AccountTests.swift:325–346` exercises the post-browser path through the URL-session stub:
   token response, server sign-in, session storage and Google profile loading. It checks Google
   400/503 against generic copy and server 503 against Stacked copy. It does not simulate browser
   presentation, transport failure, or assert request ordering/host/body in that stub; complementary
   `GoogleOAuthTests` check request shape. The new explicit `%2B` assertion at `GoogleOAuthTests.swift:94`
   fixes the previous form-parser blind spot.

## Evidence and limits

Root: `/tmp/wt-floodlight/results/04/`. Inspected existing artifacts; no verification was rerun.

- `build6.log:606`: **TEST BUILD SUCCEEDED**. Lines 56–62 record copying both font and licence.
- `unit4.xcresult`: **32/32 passed**, no failures/skips; the device tally is 35 because parameterized
  invocations are counted separately. Ticket records this run against `ef9372c`'s code.
- `ui2.xcresult`: **8/8 passed**, no failures/skips; `ui2.status` is 0. Ticket records `f879314`.
- `cap3.xcresult`: **4/4 passed**, no failures/skips; ticket records final padding at `27dbf45`.
  All 12 exported images were visually reviewed. The later provider comparison has targeted unit
  evidence and the later spacing has fresh capture evidence. This is appropriate targeted scope.
- Server **221/221** and clean `tsc --noEmit` are supplied ticket evidence, not independently executed
  or independently established from a saved server result here. Source inspection supports the new
  failure-joining tests. The reported mutation checks were not rerun.
- The extra account test at `server/test/google.test.ts:129–132` verifies one account/identity and
  two sessions for two overlapping sign-ins. It does **not deterministically prove** the null-token
  creation-conflict recovery branch: token generation is awaited while constructing the two requests,
  and no barrier forces both identity lookups to miss. This is a limit on the test's race claim, not
  evidence of a new production defect or an unresolved round-1 finding.
- `git diff --check` is not clean: it reports trailing whitespace in the copied OFL text, principally
  its CRLF line endings. This is a mechanical vendor-text issue, not a functional or licence finding;
  no whitespace edits were made under this report-only request.
- Google client configuration, live sign-in/sign-out/deletion on Simulator and phone, and the user's
  font approval remain open. Mock UI captures and this code review do not complete those acceptance
  steps. No merge, deployment or installation is implied by this verdict.

Standards: **0 remaining findings**. Spec: **0 remaining findings**. All five prior findings resolved;
no new P1–P3 defect established within the reviewed scope.

Verdict: clear
