# Public beta — Stacked

Planning session 2026-10-01/02 (Claude with the user; nothing implemented). The starting brief is
[kickoff.md](kickoff.md); the decision is **D60** in [DECISIONS](../../docs/DECISIONS.md). This spec is the
product and engineering contract for the tickets under [issues/](issues/).

**Goal.** Testers other than the developer use the app: they install it through TestFlight, can sign in with
a real account that has a profile, use the AI features on the developer's OpenAI key through a server, learn
the app from an onboarding walkthrough, and send feedback from inside the app. The App Store follows later.

## Tickets

| # | Ticket | Blocked by |
|---|---|---|
| 01 | [Paid team, data move and TestFlight](issues/01-paid-team-testflight.md) — deadline **2026-10-06 04:45 EDT** | — |
| 02 | [Onboarding walkthrough](issues/02-onboarding.md) | 01 |
| 03 | [Server foundation and Sign in with Apple](issues/03-server-and-apple-sign-in.md) | 01 |
| 04 | [Google sign-in](issues/04-google-sign-in.md) | 03 |
| 05 | [Profile page and training profile](issues/05-profile.md) | 03 |
| 06 | [AI through the server](issues/06-ai-proxy.md) | 03 |
| 07 | [Feedback section](issues/07-feedback.md) | 03 |
| 08 | [External testers](issues/08-external-testers.md) | 02, 04, 05, 06, 07 |
| 09 | [App Store launch](issues/09-app-store-launch.md) (later; stub) | 08 |

The order is the user's choice (Q12): the deadline first; onboarding needs no server; the server before
anything that uses it; external testers last, because friends invited earlier would get an app whose AI cannot
work for them. 03–07 each touch the server, so they run one at a time on short branches, not in parallel.

## User decisions (2026-10-01/02)

| Q | Question | Answer |
|---|---|---|
| — | Join the paid program; testers; App Store later | Kickoff (2026-10-01) |
| — | AI budget | No monthly budget for now (few testers); per-user limits and abuse controls still required (kickoff) |
| 1 | The bundle ID may be held by the free Personal Team | **Keep `com.ericlee4992.workouttracker`.** If the paid team is refused it, ask Apple Developer Support to release it, and keep the free signing alive (renew ~Oct 4) while waiting |
| 2 | Sign-in methods | **Sign in with Apple and Google** |
| 3 | What an account holds; required? | **Identity and profile only; workouts stay on the phone. The app works signed out**; sign-in is offered in onboarding and required only for AI. History sync, if ever, later through the tester's own iCloud |
| 4 | Profile extras | **A saved training profile** (goal, experience, days, minutes, optional height/weight) that prefills Ask AI for Templates. No photo |
| 5 | Backend platform | **Cloudflare Workers + D1** (R2 for feedback screenshots) |
| 6 | AI scope | **All three flows** through the server (Scan Machine, Ask AI for Templates, new-model exercise suggestions); **the phone's OpenAI key field is removed** for everyone, the developer included |
| 7 | AI limits | **Loose:** per signed-in person per day, 60 machine scans, 10 Ask AI weeks, 60 exercise suggestions; plus an off switch for one person or everyone |
| 8 | Onboarding | **A first-launch walkthrough** (4–5 pages, skippable), replayable from Settings; not shown automatically on a phone that already has workouts |
| 9 | Feedback | **In-app form saved on the server**, plus TestFlight's built-in screenshot feedback |
| 10 | Testers | **The developer alone on internal TestFlight now** (ticket 01); friends invited by email as **external** testers once 02–07 and the privacy policy exist (ticket 08) |
| 11 | Name | **Stacked**, App Store subtitle **"Every machine. Every gym."** (30-character limit); tagline **"Know your numbers. Every machine. Every gym."** (description, promotional text, onboarding). Changeable until the App Store submission |
| 12 | Ticket order | As in the table above |
| 13 | Enrollment | **Paid but still pending** at 2026-10-02 (Apple can take up to 48 h). Xcode on the Mac shows only the free team `X68M8SR6NA` |
| 8b | Onboarding, revised 2026-10-02 after seeing the walkthrough prototype (A/B/C) | **One welcome page, then a guided tour of the real app** ("a tutorial that actually takes the user click through the app, so they can see where to find features and know what they do"): coach marks over the real screens, step by step across the tabs, **on temporary sample data** — the tester's own store and system state are never touched; skippable; replayable from Settings. Replaces Q8's swiped walkthrough |
| 14 | Build on the developer's phone after ticket 01 | **TestFlight** (what testers get). Before a risky update, briefly install a development build from the Mac to take a full container backup; in-app Export for routine backups |

## Product contract

### Name

The home-screen name becomes **Stacked** (`CFBundleDisplayName`; the widget keeps its own "Workout" label).
The bundle ID, the stored data and the export format do not change. The App Store Connect record uses
"Stacked"; if the name is taken there, ask the user for the next choice (do not pick one).

### Accounts

- **Optional.** Logging, history, gyms, templates, export and onboarding work signed out, exactly as today.
  Signing in is required only for AI (and attaches a name to feedback). Apple's guideline 5.1.1(v) forbids
  forcing sign-in for features that do not need an account.
- **Sign in with Apple** through `AuthenticationServices` (first-party). **Google** through
  `ASWebAuthenticationSession` and Google's OAuth 2.0 authorization-code flow with PKCE for an iOS client: no
  Google SDK (no third-party runtime dependencies). The app sends the provider's ID token to the server; the
  server verifies its signature against the provider's published keys, the issuer, the audience (the bundle ID
  for Apple, the iOS client ID for Google), expiry and the nonce.
- One account per provider identity. Linking Apple and Google into one account is out of scope for the beta.
  An Apple "Hide My Email" relay address is stored and shown as given.
- **Session:** the server issues an opaque random token (stored hashed); the app keeps it in its own Keychain
  item, this device only. Expiry 90 days, renewed by use. Sign out deletes it on both sides.
- **Delete account** (App Store guideline 5.1.1(v)) is on the profile page, with a confirmation. It deletes
  every server row for the account (profile, training profile, sessions, usage counts, feedback and its
  screenshots) and, for Apple accounts, revokes the Apple tokens through Apple's revoke endpoint, which
  Apple requires — a revocation that fails is queued (encrypted, unlinked) and retried hourly for up to 30 days; if
  no token was ever kept, the app tells the user to stop Sign in with Apple in iOS Settings (Apple TN3194). The
  phone's workouts are not touched, and the confirmation says so.

### Profile page

Reached from Settings (an "Account" row at the top: "Sign in" signed out; name and email signed in). It shows
the display name (editable; prefilled from Apple's first-sign-in name or Google's name), the sign-in method and
email, "Member since", **today's AI use** against each limit, the **training profile**, Sign out, and Delete
account. Floodlight look (D59); UI-first: sample-data captures (Default and AccessibilityL, light and dark)
are approved by the user before wiring.

**Training profile (amends D58).** Goals, experience, days per week, minutes per session, and optional height
and weight — the inputs Ask AI for Templates already asks for. Stored with the account on the server. Height
and weight keep the value and unit entered (D52; never silently converted). Ask AI for Templates prefills its
form from the profile; whether edits made in Ask AI offer to update the profile is settled in ticket 05's mock.
Signed out, Ask AI is unavailable anyway (it needs the server), so there is no local copy to reconcile. The app
may cache the last fetched profile for display; the server is the source of truth.

### Server

A single **Cloudflare Worker** (TypeScript), its source in this repo under `server/`, with **D1** (SQLite) for
rows and **R2** for feedback screenshots. Free tier; the developer's Cloudflare account. It is a separate
deployable: the app gains no dependency. Every secret — the OpenAI key, the Sign in with Apple private key, the
Google client details, any admin token — lives only in Cloudflare secrets. **The GitHub repository is public:**
no secret, tester data, feedback, database export or `.dev.vars` is ever committed; `server/.gitignore` and a
pre-commit check of `git diff --cached` for key-shaped strings are part of ticket 03.

Endpoints (versioned under `/v1`, JSON over HTTPS, bearer session token where signed in):

| Endpoint | Purpose | Ticket |
|---|---|---|
| `POST /v1/auth/apple`, `POST /v1/auth/google` | Verify the provider token; create or find the account; return a session | 03, 04 |
| `POST /v1/auth/signout` | Delete this session | 03 |
| `GET`/`PUT /v1/profile` | Display name and training profile | 03 (name), 05 |
| `DELETE /v1/account` | Delete everything for the account; revoke Apple tokens | 03 |
| `POST /v1/ai/{flow}`, `GET /v1/ai/usage` | The AI proxy and today's counts | 06 |
| `POST /v1/feedback` | Store feedback (signed in or out) | 07 |
| `GET /privacy`, `GET /support` | Static privacy policy and support pages | 08 (stub in 03) |

Development uses `wrangler dev` with a local D1 and fake secrets; tests use the Workers test runner. The
production deploy is a deliberate step the user approves; the Worker's URL (the free `workers.dev` subdomain
unless the user buys a domain) is a build setting in the app, not hard-coded in several places.

### AI through the server (reopens D53/D56/D58 key rules)

- The app's three Terra flows (`TerraAccess.client` → `TerraClient`) call `POST /v1/ai/{flow}` with the
  session token instead of `api.openai.com` with a device key. Flows: `scan-machine`, `routine-week`,
  `model-exercises`.
- **The server owns each flow's instructions, JSON schema, model (`gpt-5.6-terra`), `store=false`, reasoning
  effort and output-token cap.** The app sends only the flow's input text and, for `scan-machine`, the one
  reencoded JPEG. A signed-in tester therefore cannot use the endpoint as a general-purpose GPT relay, and
  prompts can be fixed without an app update. The app keeps validating every reply exactly as today (IDs,
  bounds, catalog resolution, confirmation): the server is not trusted to have checked anything.
- **Limits per account per calendar day (America/New_York):** 60 `scan-machine`, 10 `routine-week`, 60
  `model-exercises`. Successful replies count; attempts are separately capped at twice the limit so a failure
  loop cannot run unbounded. Over the limit, the reply is a clear message ("You've used today's 60 machine
  scans. They reset at midnight.") and the manual paths stay available. No monthly budget (user, 2026-10-01).
- **Off switch:** a server setting turns AI off for everyone or for one account, effective immediately, without
  an app build. The app shows "AI is paused right now. You can continue manually."
- **What the server keeps:** per request, the account, flow, time, status, latency and OpenAI's token counts.
  Never the photo, the input text or the reply; request bodies are never logged. OpenAI's own retention policy
  still applies (D56).
- **Consent is unchanged:** the three versioned local consent flags (photos, routine details, model
  suggestions) still gate each flow before anything is sent (D56/D58); the disclosure now names both the
  developer's server and OpenAI.
- **Removed:** the Settings OpenAI-key field and `AskAIKeyStore` use in production, for everyone; the AI rows
  instead say "Sign in to use AI". The legacy Anthropic Messages client remains test-fixture-only (it already
  reads no key in production); ticket 06 confirms that and removes anything key-related it finds.

### Onboarding

**Revised 2026-10-02 (Q8b): one welcome page, then a guided tour on sample data.** The welcome page is the
prototype's page 1 (Stacked, the tagline; later the sign-in buttons) with **Show me around** and **Skip**. The tour
dims the real app except one highlighted control at a time, with a one-line caption and Next / Skip, switching tabs
and opening screens itself, about 7–8 steps (gym picker, Start Lifting, a set row in a live workout, templates and Ask
AI, a gym and Scan Machine, History and records, Exercises, Settings). It runs the real screens against a temporary
in-memory sample store; nothing it shows or does reaches the tester's store, Health, the Lock Screen, notifications or
settings, and the app returns to the tester's own data when it ends. Shown automatically once on a phone with no
workouts; Settings → Show Tour replays it. Details and the isolation design: ticket 02. The text below (the original
swiped walkthrough) is superseded.

*Superseded:* A first-launch walkthrough of four or five pages in the Floodlight look: (1) **Stacked — Know your numbers.
Every machine. Every gym.**; (2) logging a set in a live workout; (3) gyms and machines — each machine
remembered, Scan Machine; (4) history and records; (5) AI and the account, ending with Sign in with Apple /
Google / Not now once ticket 03/04 exist (until then "Get started"). Skip on every page. Shown automatically
only on a phone with no workouts that has not seen this tutorial version (a versioned `@AppStorage` flag);
**Settings → Show tutorial** replays it. It uses illustrations or sample-data screens, never the user's data,
and supports Dynamic Type (AccessibilityL), VoiceOver and Reduce Motion. UI-first: captures approved before
wiring.

### Feedback

**Settings → Send Feedback**: a category (Bug / Idea / Other), a message (required, up to 4,000 characters), an
optional screenshot chosen from Photos, and an automatic footer the user can see before sending: app version
and build, iOS version, phone model, and the account if signed in. A line states what is sent and to whom.
Works signed out; signed-out submissions are rate-limited per hashed IP (10 per day). Stored in D1 (text) and R2
(screenshot, up to 5 MB, PNG/JPEG only). The developer reads feedback in the Cloudflare dashboard or with a
small `server/scripts` command. TestFlight's built-in feedback also stays on. Notifications of new feedback are
deferred.

### Testers and distribution

- **Ticket 01:** an App Store Connect record ("Stacked"), an internal TestFlight group with the developer
  only, and a Release archive uploaded and installed on the developer's phone.
- **Ticket 08:** an external TestFlight group, invited by email; the first build of each version passes Beta
  App Review. Needs a beta description, a feedback email, a privacy policy URL (the Worker's `/privacy`), and
  App Privacy answers. Expected categories (to confirm then): contact info (name, email), identifiers (account
  ID), fitness (training profile, height/weight), user content (feedback, screenshots; photos sent for
  identification), diagnostics (app/iOS version, phone model) — linked to the account, not used for tracking.
- An individual developer's legal name appears as the seller on the App Store; settle this before ticket 09.

## Data safety on the developer's phone

The phone holds the only copy of the developer's history (24 workouts, 343 sets, 2 templates on 2026-09-29).

- **The team change cannot be installed over the top.** iOS keys an installed app to its application
  identifier, which includes the team ID (`X68M8SR6NA.com.ericlee4992.workouttracker`); a paid-team build is
  `<paidTeam>.com.ericlee4992.workouttracker`, and iOS rejects it as an upgrade ("application-identifier
  entitlement does not match"). Deleting the app deletes its container. **The move is therefore: full container
  backup and verification → delete the app → install the paid-team development build without launching it →
  copy the backed-up container into the new app's container (`devicectl device copy to --domain-type
  appDataContainer`) → launch → row-by-row preservation check against the backup.** Not carried over: the
  OpenAI key in the Keychain (team-scoped; re-enter it until ticket 06 removes it) and Health permissions
  (grant again). Details and stop points: ticket 01.
- After that, development and TestFlight builds share the paid team's identifier, so either installs over the
  other and keeps the container.
- **TestFlight builds cannot be backed up by container copy** (no `get-task-allow`). On a TestFlight build, the
  developer uses in-app Export routinely; before any risky update (a schema change, a migration), a development
  build **of the exact commit of the installed TestFlight build** is installed over it **without launching**, with
  TestFlight's Automatic Updates off, to take the full container backup (Q14; DEVELOPMENT → *Container backup and
  restore*, "backup bridge"). New code must never open the store before that backup. An Import feature is not planned yet; add
  a ticket if the user wants backups without the Mac.
- No SwiftData schema change is planned in this effort: account, session and training profile live on the
  server and in the Keychain / `@AppStorage`, not in the store. A ticket that finds it needs one follows
  DEVELOPMENT's migration rules and stops for approval.

## Engineering constraints

- No third-party runtime code in the app (AGENTS.md): only `AuthenticationServices`, `URLSession`, Security.
  The server's npm development tooling (wrangler, the test runner) is not app runtime and is acceptable
  (confirmed by the user's backend choice, Q5).
- SwiftData stays CloudKit-compatible; the export format is unchanged.
- New entitlement: Sign in with Apple (`com.apple.developer.applesignin`), ticket 03; it needs the paid team.
  Export compliance: the app uses only standard HTTPS, so `ITSAppUsesNonExemptEncryption = NO` (ticket 01).
- Signing identity stays out of tracked files: the four hard-coded `DEVELOPMENT_TEAM = X68M8SR6NA` lines in
  `project.pbxproj` move to `$(WT_DEVELOPMENT_TEAM)` from the git-ignored `Config/Local.xcconfig`, as
  `Config/Shared.xcconfig` already intends (ticket 01).
- The Watch companion is not embedded in the app and is not part of this effort; register its App ID on the
  paid team when the Watch work resumes.

## Verification

Per DEVELOPMENT → Verification scope: targeted unit and UI tests for each ticket's area, Default and
AccessibilityL captures for every new screen, and an escalation to the full UI suite only where DEVELOPMENT
requires it (for example, before ticket 08's first external build if 02–07 together cannot be bounded). The
server has its own unit tests (token verification with fixture keys, limits, deletion, the off switch,
oversize and malformed input) and a `wrangler dev` smoke test from the Simulator. A live AI smoke test per flow
uses the real key on the deployed server, never in logs or the repo. Every phone install follows DEVELOPMENT's
backup, signing, fresh-binary and launch checks and needs the user's approval.

## Deferred / out of scope for the beta

Workout history sync or server backup (later, through iCloud if at all), account linking, profile photos,
monetization, an AI spending cap (revisit when testers grow), feedback notifications, an Import feature, the
Watch companion, Android or web clients, App Store pricing and storefront material (ticket 09).
