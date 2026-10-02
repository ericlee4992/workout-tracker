# 04 — Google sign-in

Type: task
Status: ready-for-agent (after 03)
Blocked by: 03
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

## Comments
