# 04 — Google sign-in

Type: task
Status: ready-for-agent — fourth in the agreed order (STATE). Needs the user's Google Cloud project and iOS OAuth
client first (~20 min; Claude guides in Chrome, the user signs in and accepts terms).
Blocked by: — (03 done 2026-10-13)
Implementer: Codex (default); Reviewer: Claude — or the reverse.
Branch: `ericlee4992/beta-04-google` off `main`.
Spec: [spec.md](../spec.md) → *Accounts*. Decision: D60.

## Goal

"Continue with Google" beside Sign in with Apple, with **no Google SDK**.

## Scope

- App: `ASWebAuthenticationSession` with Google's OAuth 2.0 authorization-code flow and PKCE for an **iOS client**
  (the reversed client ID as the callback scheme); exchange the code at Google's token endpoint; send the ID token
  to the server.
- Server: `POST /v1/auth/google` verifies the ID token (Google's JWKS, issuer, audience = the iOS client ID,
  expiry, nonce) and creates or finds the account; same session rules as Apple. Deletion removes Google
  identities too (revoking Google's token is best-effort).
- One account per provider identity; no linking of an Apple and a Google account (spec, deferred).
- Sign-in screens (account sheet, onboarding page 5) show both buttons, Apple's per Apple's guidelines.

## User steps

Create the Google Cloud project, OAuth consent screen (app name Stacked, support email, privacy URL from ticket
08's stub) and an iOS OAuth client for the bundle ID; the client ID is not secret and goes in a build setting.

## Acceptance

- [ ] Server tests for Google tokens (good, expired, wrong audience/issuer, bad signature).
- [ ] Sign in, sign out and delete with a Google account on the Simulator and the phone.
- [ ] Captures of the updated sign-in screens (Default and AccessibilityL).

## Verification scope

Server unit tests; targeted app tests for the sign-in screens; captures.

## Progress — 2026-10-14 (Claude implements; Codex reviews — Codex's budget is low)

Branch `ericlee4992/beta-04-google` off `main` `1be0768` (06 + 05 merged, build 3 uploaded). The user chose to build first
and do the Google Cloud setup when the mock is ready.

**Server half (done, `fcae89b`).** `POST /v1/auth/google` `{ idToken, nonce }`: `src/google.ts` verifies Google's RS256
signature (key set `https://www.googleapis.com/oauth2/v3/certs`), issuer (`https://accounts.google.com` or
`accounts.google.com`), audience and `azp` = `GOOGLE_CLIENT_ID` (a `vars` entry; unset → `503 server_not_configured`),
expiry and `iat` (60 s leeway), subject, and the nonce (SHA-256 of the raw nonce, as for Apple); keeps an email only if
`email_verified`. Finds or creates the `google` identity's account (first sign-in's name; no linking with Apple); same
session rules; **no Google token is stored** (the app's PKCE exchange for an iOS client has no secret, so deletion has
nothing of Google's to revoke). Apple's key-set cache moved to `src/jwks.ts` and serves both (unchanged behaviour:
196/196 before the Google tests). `GET/PUT /v1/profile` now report the account's real provider. Tests: **218/218**
(22 new in `test/google.test.ts`: good token and its rows, short issuer, unverified email, 13 rejections incl. wrong
`azp`, Apple's issuer and an Apple token, not configured, key fetch cached, same person → same account, no Apple/Google
linking, deletion of a Google account → `done`, no Apple calls). Mutations — dropping the audience, `azp`, issuer,
nonce, `email_verified` or expiry check — each fail a test.

**App, UI-first (mock).** `GoogleSignInButton` (`SignInViews.swift`): Google's iOS branding — light white with a
#747775 border and #1F1F1F text, dark #131314 with #8E918F and #E3E3E3, Google's own "G" (cropped, unmodified, from the
light and dark logo-only PNGs of Google's sign-in asset package; `Assets.xcassets/GoogleG`), the same 56-pt capsule as
Apple's button and below it, label scaling with Dynamic Type as Apple's does. On the sign-in sheet and the welcome page
when `GoogleSignIn.isAvailable` — a client ID in `WT_GOOGLE_CLIENT_ID` (empty for now) or the mock flag
`-uiTestGoogleButton`. The tap is a placeholder until the wiring. Captures `FloodlightGoogleUITests` 4/4 (`/tmp/wt-
floodlight/results/04/cap2.xcresult`).

**New string:** "Sign in with Google" (Google's own wording, matching "Sign in with Apple"). **For the user:** at
AccessibilityL the welcome page's tagline now starts under the buttons until scrolled (four controls at the bottom).

**The user approved the mock and "Sign in with Google" as shown (2026-10-14)**, including the welcome page at
AccessibilityL; the Google Cloud setup later.

**App wiring (done; needs only the client ID).** `Domain/GoogleOAuth.swift` (pure, unit-tested): PKCE S256, the
authorization URL (`openid email profile`, `prompt=select_account`, `state`, `nonce` = SHA-256 of the raw nonce), the
reversed-client-ID redirect `com.googleusercontent.apps.<id>:/oauth2redirect`, the callback (this attempt's state only;
`access_denied` = cancelled), the code exchange (no client secret: the verifier), the answer → ID token only.
`Features/Account/GoogleSignIn.swift`: `ASWebAuthenticationSession` (callback `.customScheme`, no URL type needed) and
the token call. `AccountStore.signInWithGoogle()`: page → code → ID token → `POST /v1/auth/google` → the shared
`adopt` path Apple uses (keychain, profile); closing Google's page is not an error; "Signing in…" from the page opening
(no second session). `AccountClient.signInWithGoogle`. Nothing of Google's is kept.

### Google Cloud setup (the user's steps, Claude guiding in Chrome)

1. console.cloud.google.com → new project **Stacked** (the user's Google account).
2. **Google Auth Platform → Get started:** app name **Stacked**, user support email (the user's), audience **External**,
   contact email; the user accepts Google's API Services User Data Policy.
3. **Audience:** publishing status **Testing**; add the user's Google account (and later testers') as test users — up to
   100; moving to production is ticket 08 (basic scopes only: no verification review expected).
4. **Data access:** scopes `openid`, `email`, `profile` (non-sensitive).
5. **Clients → Create client → iOS:** name "Stacked iOS", bundle ID `com.ericlee4992.workouttracker`, team ID
   `X68M8SR6NA` → the **client ID** (not secret).
Then Claude: `WT_GOOGLE_CLIENT_ID` in `Config/Shared.xcconfig`, `GOOGLE_CLIENT_ID` in `server/wrangler.jsonc` `vars`;
redeploy the server (the user's go-ahead); sign in, out and delete with a Google account on the Simulator; the phone
with the next TestFlight build.

**Paused 2026-10-14 (the user's battery).** Codex's review (`codex-review-04-prompt.md`) and the UI regression
(`FloodlightGoogleUITests` + `FloodlightAccountUITests`, `/tmp/wt-floodlight/results/04/ui1`) were stopped unfinished —
rerun both. Unit tests: 1009/1011 then the test's RFC constant fixed → GoogleOAuthTests + AccountTests 27/27.

**Codex round 1 (`codex-review-04.md`, finished 14:26 after the pause): not clear, 5 findings — all fixed (`f879314`,
`ef9372c`, `27dbf45`).**
- Standards #1 (P2) callback: `GoogleOAuth.code` now matches the whole redirect URI (scheme case-insensitively, no
  host/port/user, path `/oauth2redirect`) and checks state before reading a code *or* an error (a stateless
  `access_denied` is invalid, not a cancel). Tests: wrong path/host/user, missing/wrong state with an error.
- Standards #2 (P3) `jwks.ts`: requests joining a refresh in flight now pass through the same `unavailable()` mapping →
  every waiter gets `503 apple_keys_unavailable` / `google_keys_unavailable`. New concurrency tests for both providers
  (fakes gained `keysGate`/`keysStatus`) fail against the old code (checked) and pass now. Also added: two simultaneous
  first Google sign-ins → one account (null-token race).
- Standards #3 (P3) branding: the label is Google Sans Medium — Google Fonts' OFL `GoogleSans[GRAD,opsz,wght].ttf`
  instanced at wght 500/opsz 18/GRAD 0, subset to Basic Latin + "…", **renamed** `StackedSignInLabel-Medium` (Google's
  TRADEMARKS.md: no "Google Sans" name on a modified version), 21 KB, with its licence
  (`WorkoutTracker/Resources/Fonts/`, Info.plist `UIAppFonts`); Google's iOS 12 pt logo gap and 16 pt side padding
  (the padding fixed the label touching the border at AccessibilityL). Unit test: the font loads by name. **A look change
  to the approved button — before/after captures shown to the user (`scratchpad/font-compare`, from `shots2` vs
  `shots4`); awaiting their OK.**
- Spec #1 (P2) deletion race: `deleteAccount` reads the profile's provider before the request; a Google account losing
  the race gets `.deleted`, not the Apple step (Apple or unknown keeps the cautious step). The store's provider is the
  *displayed* "Google" — compared case-insensitively (the first version compared "google" and the new test caught it).
- Spec #2 (P3): a failed Google token exchange shows the generic "Couldn't sign in. Try again." (no new string), not
  "Can't reach Stacked…"; the server failing still says Stacked. `completeGoogleSignIn` split out so the whole
  post-browser path is unit-tested (token answer → server → signed in) with the URL stub. The form test now asserts `%2B`.

**Verification (2026-10-14, after the fixes):** server `npx vitest run` **221/221**, `tsc --noEmit` clean.
`build6.log` TEST BUILD SUCCEEDED (font and `UIAppFonts` confirmed in the built app). Unit GoogleOAuthTests +
AccountTests **32/32** (`unit4.xcresult`, at `ef9372c`'s code). UI regression FloodlightGoogleUITests +
FloodlightAccountUITests **8/8** (`ui2.xcresult`, `f879314` — the later commits change a store comparison and padding,
neither in a UI test's path except the captures); captures FloodlightGoogleUITests **4/4** at `27dbf45`
(`cap3.xcresult`, exported `shots4/`). The earlier `ui1` run was killed and is superseded.

**The user kept the new look (Google Sans Medium, Google's iOS spacing), 2026-10-14.** **Codex round 2
(`codex-review-04b.md`): clear** — all five resolved, nothing new. Its notes, handled: the OFL text's CRLF/trailing
whitespace normalised (`git diff --check` clean); the overlapping-Google-sign-ins test renamed — it shows overlapping
sign-ins end on one account, not a forced creation conflict. Open: the client ID, live sign-in/out/delete.

**Google Cloud setup done (2026-10-14, the user in Chrome with Claude guiding; the user accepted Google's API Services
User Data Policy).** Project **Stacked** (`stacked-511700`); Google Auth Platform: app name Stacked, support and contact
email the user's Gmail (the user's choice; changeable for 08), External, **Testing**, test user the user's Gmail (1/100);
scopes `openid`, `email`, `profile` only; iOS client **"Stacked iOS"** (bundle `com.ericlee4992.workouttracker`, team
`X68M8SR6NA`, no App Check): client ID `469208403829-t81d4qhqr5p4amtlm0s47mo8p25bsf3b.apps.googleusercontent.com` (not
secret) → `WT_GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_ID` (`f9953a0`).

**Server deployed from the branch with the user's go-ahead (2026-10-14): version `0f2b49c4`.** Smoke: a fake Google token
→ 401 `invalid_token` (configured, not 503); Apple unchanged (401 `invalid_token` for a fake token). No migration.

**Simulator acceptance (WT-Floodlight, Debug build `build7.log` with the client ID; the user signed in with their own
Google account — Claude entered no credentials): passed.** The real (non-mock) welcome page shows the Google button;
sign-in → "Signed in as Eric Lee."; production D1 then had one `google` identity with `refresh_token_enc` NULL. The user
confirmed Settings → Account, sign-out and sign-in again (same account), and **Delete Account** all worked; D1 afterwards:
0 Google identities, the Apple account and its one session untouched, 0 pending revocations. The phone check comes with
the next TestFlight build.

## Comments
