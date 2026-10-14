# 03 — Server foundation and Sign in with Apple

Type: task
Status: in progress — server half merged (Codex clear, 4 rounds) and **deployed 2026-10-13**; **app half
implemented** (mock approved by the user; unit 43/43, UI 37/37 + 1 opt-in skip); Codex review of the app half next,
then the phone (branch `ericlee4992/beta-03-deploy`)
Blocked by: 01 (the paid team is required for the Sign in with Apple capability)
Implementer: Claude (the user's go-ahead to start the server half, 2026-10-02); Reviewer: Codex.
Branch: `ericlee4992/beta-03-server-apple` off `main`.
Spec: [spec.md](../spec.md) → *Accounts*, *Server*. Decision: D60.

## Goal

A deployed Cloudflare Worker with D1 that signs people in with Apple, keeps a session, stores a display name,
signs out, and deletes accounts completely — and the app's Account row in Settings that uses it.

## Scope

**Server (`server/`, TypeScript, Cloudflare Workers + D1):**
- Project skeleton, `wrangler` config, D1 migrations (accounts, identities, sessions), `server/README.md` with
  setup, local dev and deploy steps for the user.
- `POST /v1/auth/apple`: verify the identity token (Apple's JWKS, issuer, audience = bundle ID, expiry, the
  nonce's SHA-256), exchange the authorization code for Apple's refresh token (client secret JWT signed with the
  Sign in with Apple key) and keep it for revocation; create or find the account; store the first-sign-in name
  and email; return an opaque session token (random, stored hashed; 90-day expiry renewed by use).
- `POST /v1/auth/signout`; `GET`/`PUT /v1/profile` (display name only here); `DELETE /v1/account` (every row for
  the account; Apple token revocation; idempotent).
- Stub `GET /privacy` and `GET /support` pages (filled in ticket 08).
- **Secrets only in Cloudflare** (`wrangler secret`); `.dev.vars` and any key file git-ignored; a pre-commit or
  CI check that rejects key-shaped strings. **The repository is public.**
- Tests with the Workers test runner: token verification against fixture keys (good, expired, wrong audience,
  wrong nonce, bad signature), session expiry, sign-out, deletion cascade, malformed input.

**App:**
- Sign in with Apple capability (`com.apple.developer.applesignin`) on the paid team.
- An account client over `URLSession`; the server URL is one build setting. Session token in its own Keychain item
  (this device only). Errors fail closed with a one-line message; signed-out use is unchanged.
- Settings: an **Account** row at the top (Sign in / name and email) opening a minimal account sheet with Sign in
  with Apple, Sign out, and **Delete account** (confirmation states that workouts on this phone stay). Ticket 05
  builds the full profile page on top of it.
- Onboarding page 5 (ticket 02) gains Sign in with Apple / Not now.

## User steps (cannot be done by an agent)

Create the Cloudflare account; create the Sign in with Apple key in the developer portal and hand it to
`wrangler secret put` locally (never in chat or the repo); approve the first production deploy.

## Progress

### Server half — 2026-10-02 (Claude)

Branch `ericlee4992/beta-03-server-apple` from `main` `f6895a5`. `server/` (TypeScript, Cloudflare Workers + D1):
`wrangler.jsonc` (D1 binding `DB`, vars `APPLE_CLIENT_ID` = the bundle ID and `APPLE_TEAM_ID` = empty until the paid
team; compatibility date 2026-08-22, the newest the local runtime supports), `migrations/0001_accounts.sql` (accounts,
identities, sessions; cascades), `src/` — `crypto.ts` (base64url, SHA-256, tokens, UUIDs, AES-256-GCM, PKCS#8 import),
`jwt.ts` (decode, RS256 verify, ES256 sign), `apple.ts` (identity-token verification: Apple JWKS by `kid` with one
refetch, issuer, audience, expiry with 60 s leeway, `iat` not in the future, nonce = SHA-256 of the raw nonce, subject;
client-secret JWT; code exchange; revocation), `store.ts`, `index.ts` (router; `createHandler(deps)` takes the clock,
fetch and randomness so tests replace them), `pages.ts` (stub privacy/support). Fail-closed choices: no encryption key
→ sign-in 503; Apple refuses the code → 502 and **no account**; deletion revokes first, then deletes every row whatever
Apple answers and reports `appleRevoked`. Session tokens stored only as SHA-256; 90 days, renewed at most daily by use.
Errors are `{error: code}`; no bodies or tokens logged.

Secrets: `server/.gitignore` (`.dev.vars`, `*.p8`, `*.pem`), `.dev.vars.example`; `scripts/check-secrets.sh`
(`--staged` / `--all`: PEM private keys, OpenAI/Anthropic/AWS/GitHub/Google key shapes, filled `.dev.vars` names;
boundary-anchored after a false positive on CSS `mask-image-…` in a prototype bundle); opt-in hook
`scripts/git-hooks/pre-commit`; CI `.github/workflows/server.yml` (secret scan over every tracked file + `npm ci`,
`tsc`, `vitest` on Ubuntu). `server/README.md`: endpoints, dev/test, the developer's one-time deploy steps.

Tooling notes: npm 10.9 crashes resolving vitest 4's peer graph (`edgesOut`) → `server/.npmrc` `legacy-peer-deps=true`
with every needed package listed; the Workers pool (0.22) keeps one D1 per test file → the harness empties the tables
before each test.

**Evidence:** `tsc --noEmit` exit 0; `vitest run` **26/26** — token checks (good; expired; wrong audience; wrong issuer;
forged signature; unknown `kid`; `alg` none; no subject; `iat` in the future; wrong nonce; garbage tokens; malformed,
array and oversize bodies), the code exchange with a client secret verified against the fake key's public half and
the refresh token stored encrypted, no account when Apple refuses the code or the server lacks its key, the first-sign-in
name kept and cleaned, the newest refresh token kept, users kept apart, profile read/rename/validation, missing and
unknown tokens, expiry after 90 days unused and renewal by use, sign-out of one session only, deletion (revocation
with the decrypted token, every row of that account only, the dead session refused, rows deleted even when Apple refuses
and reported), re-sign-in after deletion is a new account, pages and 404s, no secrets in errors. **Mutations:**
removing the nonce check fails exactly the nonce test; removing the audience check fails exactly the audience test.
**Local smoke** (`wrangler dev`, local D1 migrated): `/v1/health` 200, `/privacy` 200 HTML, sign-in 503
`server_not_configured` without keys, profile 401 without a session. Secret scan: `--all` clean over the repository;
`--staged` catches a planted OpenAI-style key and a PEM key and passes the CSS line.

**Not done (needs the user / the paid team):** the Cloudflare account, D1 creation, secrets, deploy; the app half
(capability, account client, Settings Account row, onboarding sign-in).

## Codex review 03 — response (round 1)

Review: [codex-review-03.md](../codex-review-03.md) — not clear (P1 ×2, P2 ×5, P3). All accepted.

1. **P1 code ↔ identity binding** — `exchangeAppleCode(code, expectedSubject, …)` verifies the `id_token` Apple returns
   (same checks as the sign-in token, minus the nonce) and requires its `sub` to equal the sign-in token's, else
   `401 code_identity_mismatch` before any database write; a missing/empty/oversize refresh token or a bad/unsigned/
   wrong-audience `id_token` → 502. The fake Apple now binds each code to its user, makes codes single-use and returns a
   signed `id_token`. Tests: A's token + B's code → 401, nothing stored; a reused code → 502; four malformed answers → 502;
   tokens without numeric `iat`/`exp` → 401. Mutation: removing the subject check fails exactly the A/B test.
2. **P2 body limit** — the body is read from the stream counting bytes and cancelled past 64 KB. Tests: 80 KB of `é`
   (40 k characters) → 413; a stream without Content-Length is cut off (≤ 64 KB + 3 chunks pulled of 1 MB); exactly
   64 KB is read and judged (401).
3. **P2 JWKS refetches** — one cached key set per hour; concurrent fetches share one request; an unknown `kid` forces a
   refetch at most once per 5 minutes; every Apple call has a 5 s timeout. Tests: after warming, 5 sequential + 3
   concurrent bogus `kid`s → exactly 1 extra fetch; a rotated key is accepted after the cooldown. Mutation: removing the
   cooldown fails exactly that test.
4. **P2 first-sign-in race** — `createOrFindAccount`: on the identity primary-key conflict it joins the winner's
   account and keeps its own newer refresh token; if the winner was deleted meanwhile it creates afresh. Tests: two
   simultaneous first sign-ins → one account, two sessions; the deterministic loser path joins the winner.
5. **P2 deletion with Apple down** — every account row is deleted at once in one batch, and in the same batch an
   unrevoked token is queued in `pending_revocations` (migration 0002: ciphertext, SHA-256 key for idempotence, no
   account link); the hourly cron (`triggers.crons`) retries with backoff (1 h doubling to 24 h) and drops it after 30
   days. The answer is `appleRevocation: "done" | "pending" | "manual"` (manual = no token kept → iOS Settings, TN3194),
   documented in README and the spec. Tests: outage → pending → still down → revoked when back; key unavailable at
   deletion → revoked once restored; tampered ciphertext → retried, dropped after 30 days; no token → manual; two
   simultaneous deletions → nothing left, queued once.
6. **P1 scanner false negatives** — detectors now catch PEM headers followed by escaped `\n` + base64 or inline base64,
   and the project's secret names with optional quote, spaces and `:`/`=` (value ≥ 16 key characters).
7. **P2 staged diff parsing** — `--staged` runs `git grep --cached` over the staged files: the index version, whole
   files, no diff parsing; `--all` runs `git grep` over the tree (2,749 files in ~1 s).
8. **P3 printed secrets** — reports `FILE:LINE [detector]` only.
   `scripts/test-check-secrets.sh` (in CI): 12 cases — an `sk-` key, a `+`-prefixed line, PEM alone and escaped,
   named secrets in JSON / spaced / `.dev.vars`, four look-alikes that must pass (CSS `mask-image`, code `btoa(…)`,
   an empty example, the PEM regex in source), and `--all` finding a committed key without printing it. Its synthetic
   secrets are assembled at run time. Two of my own bugs found on the way: the first rewrite lost its "found" flag in
   a pipeline subshell, and put the pattern after `--`; both caught by this test.

**Evidence after the fixes:** `tsc --noEmit` exit 0; `vitest run` **42/42** (26 + 16 in `test/hardening.test.ts`);
mutations as above; `scripts/test-check-secrets.sh` exit 0 (12/12); `scripts/check-secrets.sh --all` clean.

## Codex review 03b — response (round 2)

Review: [codex-review-03b.md](../codex-review-03b.md) — round-1 #1, #2, #4, #7, #8 resolved; #3, #5, #6 partly; six
findings. All accepted.

1. **P2 rotation waiters** — `appleKeys`: a forced refresh joins the one in flight before the cooldown applies. Test:
   the key-set response held open while three valid rotated-key sign-ins arrive → all 200 on exactly one fetch.
   Mutation: removing the join fails exactly that test.
2. **P2 concurrent deletion reporting "done"** and 3. **P2 sign-in during deletion** — deletion is now *claimed* in one
   D1 transaction (`claimDeletion`): read the current Apple tokens, `INSERT … SELECT` them into the queue, delete sessions,
   identities, the account; `won` = the account row was deleted by this request. Revocation happens after, removing each
   success from the queue. A losing deletion returns `409 deletion_in_progress`. Sign-in: `updateRefreshToken` and
   `createSession` report whether the identity / account still exist (`INSERT … WHERE EXISTS`); if not, the sign-in
   makes a new account (twice at most, then `409 try_again`). Migration 0002 reshaped (not deployed anywhere):
   `token_enc` is the key. Tests: simultaneous deletions → exactly one 200 "pending", the other 401/409 without "done";
   the deterministic loser → null; a newer token written before the claim is the one queued; after the claim the token
   update and session insert refuse and a new sign-in gets a new account.
4. **P2 the 30-day drop** — the contract now makes manual recovery part of `"pending"`: the app shows the iOS Settings
   route (TN3194) at once (README, spec, the handler's doc comment); the wrong "tokens long gone" comment is corrected
   (Apple tokens stay valid until revoked). The terminal drop remains bounded retention, now stated as such.
5. **P2 escaped CRLF PEM** — the PEM detector accepts `\r\n` as well as `\n` after the header (and whitespace before
   inline base64). Test case added (a JSON `APPLE_PRIVATE_KEY` with an escaped-CRLF key).
6. **P3 pathspec magic** — `git --literal-pathspecs grep`, and a `git grep` failure (exit > 1) now refuses (exit 2)
   instead of reporting clean. Test: a staged file named `:(glob)abc.txt` holding a key is caught; the previous scanner
   (`f1e20de`) exits 0 on the same case.

**Evidence:** `tsc` exit 0; `vitest` **46/46**; `scripts/test-check-secrets.sh` **14/14**; `--all` clean.

## Codex review 03c — response (round 3)

Review: [codex-review-03c.md](../codex-review-03c.md) — round-2 #1, #2, #4, #5, #6 resolved, #3 partly; one P2.

1. **P2 a claimed token reused by the sign-in retry** — the retry loop is gone. A sign-in stores its token (on the
   existing identity, or via create-or-find); only when the identity was already gone *before* storing may a new
   account hold the token. Once stored, a vanished account at the session insert means a deletion claimed this token
   too: the request ends `409 reauthorize` (the app starts a fresh Apple authorization). `Deps.pause` is a test-only
   seam (absent in production) awaited just before the session insert. Tests (both revoke outcomes): pause → deletion
   runs → sign-in answers 409 `reauthorize`; no account, identity or session is recreated; with Apple accepting, the
   revoked token is exactly T2; with Apple failing, T2 stays queued and no active identity holds it.

**Evidence:** `tsc` exit 0; `vitest` **48/48**; scanner tests 14/14 unchanged.

**Round 4 (codex-review-03d): clear** — the round-3 finding resolved (Codex's own interleaving probes, independent of the
test seam, and the two new tests); no new findings. The clearance covers the server implementation locally — not a
deployment, a real Apple exchange/revocation, or the app half.

## First deploy — 2026-10-13 (Claude, with the user)

- Cloudflare (earlier the same day, with the user): `wrangler login`; D1 `stacked` (`3652ad5c-…`), migrations
  0001–0005 applied remotely; R2 `stacked-feedback`.
- **Apple Developer portal:** Sign In with Apple enabled on App ID `com.ericlee4992.workouttracker` as a primary App
  ID (Claude, at the user's "yes"; the first save did not take — Claude misread the checkbox's `value="on"` as its
  checked state and reported success; caught when the key page still showed "no identifiers"; saved again and
  verified on a fresh load: ticked, Save disabled). The user created the **Sign in with Apple key** themselves and
  keeps the `.p8` outside the repository (`~/WorkoutTracker-Backups/keys/`, 0600 in a 0700 folder).
- `APPLE_TEAM_ID` = `X68M8SR6NA` in `wrangler.jsonc` (not secret).
- Before deploying: `tsc --noEmit` exit 0; `vitest run` **196/196** (5 files); `wrangler deploy --dry-run` bindings
  DB, FEEDBACK, APPLE_CLIENT_ID, APPLE_TEAM_ID.
- **`npm run deploy` (the user: "yes") exit 0:** wrangler 4.147.0 registered the account's workers.dev subdomain;
  **`https://stacked-server.stacked-server.workers.dev`**, cron `23 * * * *`, version `6cfac3a8-2f32-4ee1-b48d-e9c86eeb1381`.
- **Secrets:** `APPLE_KEY_ID` piped by Claude (an identifier, not secret; deliberately not committed);
  `APPLE_PRIVATE_KEY` (from the `.p8`), `TOKEN_ENC_KEY` (`openssl rand -base64 32`, never displayed) and
  `OPENAI_API_KEY` (piped from `~/.config/workouttracker/openai.env`) **run by the user** — values never in chat or
  the repository. (A first OpenAI attempt failed harmlessly: the pasted line wrapped and wrangler printed its help;
  the second went through a scratch script holding only the command.) `wrangler secret list`: the four names.
- **Live smoke:** `/v1/health` 200 `{"ok":true}`; `/privacy`, `/support` 200; `/v1/profile`, `/v1/ai/usage` 401
  without a session; unknown path 404; `POST /v1/auth/apple` with empty or garbage tokens → `invalid_token` (no longer
  `server_not_configured`: the secrets are loaded). A real Apple sign-in waits on the app half.

## App half — design (UI-first, ios-design steps 1–4)

**The user's choices (2026-10-13, from previews):** the welcome page keeps **Show Me Around** as the one primary
command with **Sign in with Apple under it** and Skip last ("Under the tour", over "Sign-in first" and "At the end of
the tour"); Settings → Sign In opens **a small sign-in sheet** (over going straight to Apple's sheet; Google's button
joins it in 04).

**Job, state, bold element.**
- *Sign-in sheet:* exists so the tester can sign in with one tap knowing what it is for; the eye lands on **Apple's
  button** in the thumb's reach. Runner-up: "Sign In" (the title). Show-only → Close, no Cancel/Save.
- *Welcome page:* unchanged job (take the tour); Apple's button is second, under it; once signed in it gives way to
  "Signed in as …" and the tour / Skip choice stays.
- *Delete confirmation:* an action-sheet popover on the Delete Account… row (iOS 26 points it at its source;
  attached to the page it pointed at the middle — fixed); then, when Apple's revocation is pending or impossible, an
  alert with the iOS Settings route (TN3194).

```
Sign-in sheet (medium detent)          Welcome
┌──────────────────────────────┐       ┌──────────────────────────────┐
│                       (Close)│       │        (illustration)        │
│ Sign In                      │       │ Stacked                      │
│ For AI and a training profile│       │ Know your numbers. …         │
│ ✓ Your workouts stay on this │       │ [      Show Me Around      ] │ ← primary
│   iPhone.                    │       │ [   Sign in with Apple    ] │ ← Apple's, capsule
│ ✓ Delete your account any …  │       │             Skip             │
│ [   Sign in with Apple    ] │ ←bold └──────────────────────────────┘
│ (failure line, destructive)  │
└──────────────────────────────┘
```

**Approved copy:** sheet **Sign In**, *Your workouts stay on
this iPhone.*, *Delete your account any time.*, **Close**, *Signing in…*; failures *Can't reach Stacked right now. Try
again later.* / *Couldn't sign in. Try again.*; welcome *Signed in as {name}.*; delete **Delete your account?** /
*Your name, email, training profile and feedback are deleted from Stacked's server. Your workouts on this iPhone
stay.* / **Delete Account** / **Cancel**; after it **Account Deleted** / *One more step: in the Settings app, tap your
name, then Sign-In & Security, Sign in with Apple, Stacked, and stop using it.* / **OK**. Apple's button label is
Apple's ("Sign in with Apple").

**Tells.** Same container on everything — absent (the sheet has no cards; facts are notice lines). Chips — absent.
All-caps — absent. Middle dots — absent. Accent overuse — the violet is only the tour button; Apple's button is
black/white by Apple's rules. Equal-weight stacked blocks — deliberate on the welcome page: two full-width buttons,
distinguished by colour and order (the user's choice). Phone-sized website — absent. More than the job above the
fold — absent. A control dressed as primary — absent. Layout only at default — AccessibilityL captured (the sheet
goes to the large detent).

**Mock captures** (`../captures/03/`, `FloodlightAccountUITests` 4/4 on WT-Floodlight, iOS 27): sign-in sheet and its
failure line, delete confirmation and follow-up, welcome before and after signing in — light/dark × Default/
AccessibilityL (24). Sample flags: `-uiTestProfileSignedOut` (row → sheet), `-uiTestSignInFailed`,
`-uiTestWelcomeSignedIn`; nothing is sent yet (Apple's button is live but its handlers are empty).

**The user's approval (2026-10-13):** "just get rid of phrases 'for ai and training profile'. Rest looks good." —
removed from the sign-in sheet **and** from the Settings row signed out (it now reads "Sign In" alone; ticket 05's
`profile-settings-signedout-*` captures show the older row). Everything else above approved as shown. Recaptured
(`FloodlightAccountUITests` 4/4); `../captures/03/` holds the approved versions.

## App half — implementation (2026-10-13, Claude)

- `Domain/AccountClient.swift`: the account endpoints (sign-in, sign-out, profile GET/PUT, usage, delete) over
  `URLSession`, typed failures (`unauthorized` on any 401, `reauthorize`, `deletionInProgress`, `unreachable` for no
  answer / 408 / 429 / 5xx, `refused(code)`); `SignInNonce` (32 random bytes base64url; SHA-256 lowercase hex to
  Apple, the raw value to the server — server `apple.ts:105`); `AccountSessionStore` (keychain, generic password,
  `AfterFirstUnlockThisDeviceOnly`; in memory under `-uiTestReset`). Dates are the server's milliseconds.
- `Features/Account/AccountStore.swift`: the app-wide `@Observable` state. Signed out unless a token is in the
  keychain. Sign-in stores the token only after the server's answer; a keychain write that fails ends the server's
  session and reports a failure. Apple's cancel shows nothing. Every async answer is applied only if the token is
  still the same one. A 401 anywhere signs the phone out; offline keeps the session. Sign-out forgets locally first,
  then tells the server. Deletion: `done` → page closes; `pending`/`manual` → Settings shows the approved iOS Settings
  follow-up after the page closes; `409 deletion_in_progress` → signed out, the follow-up (another request has the
  real outcome); **401 → "You've been signed out. Sign in again to delete your account."** (nothing was deleted, so
  never "Account Deleted"); offline → "Couldn't delete your account. Check your connection and try again."
- Wiring: the app makes one store (`AccountStore.forThisApp()`: the build's server; under `-uiTestReset` the sample
  store when a ProfileSample flag asks, else no server) and refreshes it once per launch; **the guided tour gets a
  server-less store** so its sample Settings never shows the tester's account. Settings shows the Account row only
  when the build has a server (`WT_SERVER_URL`); signed out → the sign-in sheet; signed in → the profile page
  (`ProfileScreen`: rename by an alert with a text field, training save via `PUT /v1/profile`, sign out, delete).
  The welcome page shows Apple's button only with a server, the progress line while signing in, the failure line,
  then "Signed in as …". Feedback sends the session when signed in.
- `Config/WorkoutTracker.entitlements`: `com.apple.developer.applesignin` = `[Default]`. `Config/Shared.xcconfig`:
  `WT_SERVER_URL = https://stacked-server.stacked-server.workers.dev` (Local.xcconfig can still override for `wrangler
  dev`). This also turns on Settings → Send Feedback in normal builds (ticket 07's row, hidden until a server existed).
- **New strings beyond the approved mock (the user's decision):** *Signed In* (the Settings row while a stored
  session's profile loads), *Your Account* / *Not shared* (no name / no email on the server), the rename alert
  **Name** with **Cancel / Save**, *Couldn't save. Check your connection and try again.*, the two deletion failures
  above, *Signing in…* on the welcome page (the sheet's approved line).
- Known, not in this ticket: a feedback send with an expired session gets the server's 401 and shows the generic
  "Couldn't send" line without signing out; the next profile refresh signs out. The AI flows still use the on-device
  key until ticket 06's app switch.

**Verification (targeted, DEVELOPMENT):** device-independent build `build2.log` **BUILD SUCCEEDED** (no warnings in the
changed files). Unit `unit1.xcresult`: **43/43** — AccountTests 15 (requests, nonce vector, failure mapping, profile
and usage parsing, update bodies, deletion answers incl. an unknown one → cautious, no connection; the store:
sign-in keeps the token then loads, a refused keychain write is not a sign-in and ends the server session, failure
lines, 401 signs out vs. offline keeps, sign-out offline, deletion outcomes incl. 401 → never "deleted"),
FeedbackTests 13, OnboardingTests 6, TrainingProfileTests 9. UI `ui1.xcresult`: **37 passed, 0 failed, 1 skipped**
(the opt-in live-server feedback smoke) — FloodlightAccount 4, Profile 7, Settings 10, Tour 10, Feedback 7.
Artifacts: `…/scratchpad/03/` (session scratchpad, ephemeral). **Not yet verified:** a real Apple sign-in, the
server's code exchange, rename/training save, sign-out and deletion with revocation — on the phone (TestFlight
build 2 proposed).

## Codex review 03 app half — response (round 1)

Review: [codex-review-03-app.md](../codex-review-03-app.md) — not clear (Standards 1 P3; Spec 6 P2). All accepted.

- **S1 (comments):** `DeleteOutcome` now distinguishes `deleted`, `deletedNeedsAppleStep`, `signedOut` (a 401: nothing
  deleted, signed out), `failed` (still signed in) and `superseded`; the `client` comment separates a server-less
  build/tour/UI-test store from the UI-first sample store.
- **#1 feedback footer:** `FeedbackDetails.forThisPhone(account:)` takes `AccountStore.feedbackAccountLine` ("Name ·
  email", or "Signed In" while the profile loads; nil signed out). Settings rebuilds the sheet's details and sender
  from the store on every change, so the line shown and the session sent always agree.
- **#2 feedback 401:** `FeedbackClientError.unauthorized` (401); the sender calls `onUnauthorized(token)` →
  `AccountStore.invalidate(token:)`, which forgets the session only if it is still the current one. The draft stays;
  the line reads *You've been signed out. Send again to send it without your account.* (new string) and the footer
  then says "Not signed in", so a second Send goes signed out, as disclosed.
- **#3 offline cold launch:** tapping the row signed in always opens the page; without a profile it shows
  `AccountUnavailableView` — title *Signed In*, *Loading…* with a spinner while loading or *Couldn't load your
  account. Check your connection.*, then **Try Again** and **Sign Out** (new strings). `refresh()` no longer needs both calls: the
  profile shows without the AI figures (keeping the previous figures if any) when only usage fails; `loadFailed`
  marks a failed profile load.
- **#4 late deletion:** `deleteAccount()` captures the token and returns `.superseded` — no `forget()`, no UI — when
  the session changed while the request was out. Test `aLateDeletionAnswerLeavesANewerSessionAlone` holds the
  DELETE (a gate in the stub), signs out and in again, then releases it: outcome `superseded`, the new token kept.
  **Mutation:** removing the guard fails exactly that test (2 issues, `mut.log`).
- **#5 the 401 explanation:** deletion outcomes that end the session go to Settings (`onDeleteOutcome`), which owns
  both follow-ups — the iOS Settings step and *You've been signed out. Sign in again to delete your account.* — so
  they survive the page closing. Offline failure stays on the page (still signed in).
- **#6 mixed failures:** profile and usage are awaited as separate `Result`s; a 401 from either signs out, winning
  over a transient failure of the other (test `usageRefusalSignsOutEvenWhenTheProfileFails`).

**Evidence:** unit `unit3.xcresult` **47/47** (AccountTests 19 incl. the four new cases and 409/401 deletion checks;
FeedbackTests 13 with the 401 mapping and line; Onboarding 6; TrainingProfile 9). A first attempt at the gate test hung
because the stub answered on URLSession's loading thread (the held DELETE blocked the sign-in); the stub now answers on
a global queue. **UI:** `ui2.xcresult` 34 passed, 3 failed, 1 skipped (the opt-in smoke). The failures:
`FloodlightAccountUITests.testCaptureAccountDarkAccessibility` — its launch died ("Mach error -308, server died") at
21:45:26, the moment the stale hung unit run finished on the same simulator; `FloodlightProfileUITests
.testTwelveInchesKeepsSaveOffAndClearingBothClearsTheHeight` and `FloodlightSettingsUITests
.testCaptureSettingsLightAccessibility` — screens this round did not change, both passed in `ui1`. Rerun alone,
serially (`ui3.xcresult`): **3/3 passed**, so no product failure. Unit rerun clean (`unit3.xcresult`): 47/47. New
capture `account-unavailable-*` (the offline page; Sign Out returns the row to "Sign In").

## Codex review 03 app half — response (round 2)

Review: [codex-review-03-app-b.md](../codex-review-03-app-b.md) — not clear: round-1 #1–#3, #5, #6 resolved, #4
resolved for its case; one new P2 and two P3. All accepted.

- **P2 — a session ended during the deletion swallowed the Apple step.** `deleteAccount()` now returns `superseded`
  only when a *different, non-nil* session is current (a genuine sign-out-and-in); a session merely ended meanwhile
  (a refresh's 401 after the server's claim, or Sign Out) still gets the answer, so `pending`/`manual` reach Settings'
  follow-up. Forgetting goes through `forgetIfCurrent`, so a newer session is still never touched. A `deleting` flag
  stops a second DELETE while one is out (the second call returns `superseded` without a request). The page's Task
  outlives the page, and `onDeleteOutcome` writes Settings' state, so the follow-up shows even after the page closed.
  Test `aDeletionStillReportsWhenItsSessionEndsMeanwhile`: DELETE held (`pending`), a second delete refused, a
  refresh's 401 signs out, release → `deletedNeedsAppleStep`, exactly one DELETE sent.
  **Evidence:** unit `unit4.xcresult` **48/48** (AccountTests 20). **Mutation** (`mut2.log`): restoring the round-1 rule
  (`guard token == self.token else { return .superseded }`) fails exactly the new test while
  `aLateDeletionAnswerLeavesANewerSessionAlone` still passes; the file was restored and checked (no marker; the real
  rule present). xcodebuild hung after reporting that run and was stopped by its PID (exit 143). No UI change in this
  round, so no UI rerun (ui2 + ui3 stand).
- **P3 — "Loading…"** is now listed (round-1 #3 above).
- **P3 — comments:** `profile` / `loadFailed` say a later failed refresh keeps the profile shown and `loadFailed`
  means "failed with no profile to show"; `superseded` describes both cases.

## Acceptance

- [ ] Server tests green; `wrangler dev` smoke from the Simulator: sign in, rename, sign out, delete.
- [ ] Deployed Worker; sign-in and deletion work from a development build on the phone; Apple's "Apps using Apple
      ID" list no longer shows the app after deletion.
- [ ] Signed-out app behaviour unchanged (targeted UI tests); Account row captures, Default and AccessibilityL.
- [ ] No secret in the diff or history (check run and recorded).

## Verification scope

Server unit tests; app targeted unit/UI tests for the account client and Settings; captures. No full UI suite.

## Comments
