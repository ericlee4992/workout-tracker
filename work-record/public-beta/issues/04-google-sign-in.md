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

## Comments
