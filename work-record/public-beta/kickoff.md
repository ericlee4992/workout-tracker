# Public beta — kickoff (2026-10-01)

**Planned 2026-10-01/02:** the questions below were answered one at a time with the user; the answers, the
contract and the final ticket order are in [spec.md](spec.md), the decision is D60, the tickets are
[issues/01…09](issues/). The ticket order below was revised there (Google sign-in, profile and the App Store got
their own tickets).

The starting brief for the public-beta effort. The first session turns it into `spec.md`, a DECISIONS entry and
numbered tickets under `issues/`; this file stays as the record of what the user asked and decided at the start.

## What the user wants (2026-10-01, their words summarised)

The user joined the **Apple Developer Program** (paid) "since I want to launch app in future, and I also want to
invite others to test the app". They want to turn the private app "into something others can start using":

1. **Profile page — real accounts** (user decision 2026-10-01: "for profile: real accounts", not a local-only
   profile).
2. **AI features for testers under the user's own API key** ("people can use AI features under my API").
3. **An app navigation tutorial for new users** (onboarding).
4. **A feedback section in the app.**
5. **Inviting testers** (TestFlight) now; an App Store launch later.

**AI budget (user decision 2026-10-01):** "No monthly AI budget for now, since I'm only gonna have a few testers."
Per-user limits and abuse controls are still needed — the key pays for every request — but no spending cap
is set yet. Ask before choosing numbers.

## Locked decisions this reopens (reopen explicitly, with the reason, per AGENTS.md)

- **SPEC "No backend, accounts, or third-party runtime dependencies"** and **D41** ("no backend, no accounts …
  still fully offline"). Real accounts and a shared AI key need a server.
- **D53, D56, D58** — the OpenAI key is the developer's own, kept only in the phone's Keychain, never bundled;
  "private trial first; backend/usage controls required before shared-key public use" (D58). Testers using the
  user's key = that backend. The key must never ship in the app binary (it can be extracted).
- Possibly the CloudKit-compatible SwiftData conventions and the export format, depending on what accounts sync.

## Questions for the planning session (ask the user; record answers in the spec)

- **Accounts:** sign-in method (Sign in with Apple is the natural first choice; others?). What does an account
  hold — only identity and profile fields, or the workout history too (sync / multi-device / backup)? Is data
  still local-first with the account optional, or required to use the app? Account deletion is required by
  App Store rules for apps that let people create accounts.
- **Backend:** where it runs and who operates it (a managed platform vs. a small server of the user's own);
  what it stores; the AI proxy's per-user limits; logging and privacy. No third-party *runtime* dependencies in
  the app (AGENTS.md) — a server-side choice does not change that rule for the app itself, but confirm.
- **AI scope for testers:** all three AI flows (Scan Machine, Ask AI for Templates, manual-model suggestions)
  or a subset; consent flows stay (D56/D58).
- **Onboarding:** first-launch walkthrough vs. contextual tips; skippable; reachable again from Settings.
- **Feedback:** in-app form to the backend, email, or TestFlight's built-in screenshot feedback (free with
  TestFlight) — or a mix.
- **Testers:** how many, internal (on the team, no review) vs. external (needs Beta App Review, a privacy
  policy, App Privacy answers, HealthKit justification).

## Must be handled early — the paid team and the user's own data

- Signing moves from the free **Personal Team `X68M8SR6NA`** to the paid team. Check the paid team's ID and
  whether the bundle ID `com.ericlee4992.workouttracker` (and `.widget`, the Watch target) can stay. **If the
  bundle ID changed, the phone would see a new app and the user's history would stay with the old one** — do
  not change it without a plan the user approves, a fresh full backup, and a migration path (e.g. export →
  import). Paid-team development profiles last about a year, which ends the 7-day renewals (current free
  profiles expire **2026-10-06 04:45 EDT**).
- App Store Connect: the app record, TestFlight, privacy policy URL, App Privacy details.

## Proposed ticket order (for the planning session to confirm)

1. **Paid team + TestFlight build** — signing on the paid team with the bundle IDs kept, an archive, an
   internal TestFlight build installed over the current app with the data-preservation check.
2. **Onboarding** — self-contained, no backend.
3. **Backend foundation + accounts** — Sign in with Apple, profile page, account deletion.
4. **AI through the backend** — the proxy with per-user limits; the app's AI flows switch from the device key.
5. **Feedback section.**
6. **External testers** — Beta App Review, privacy policy, App Privacy labels.

## Workflow (unchanged rules)

AGENTS.md applies: STATE first; Claude implements and Codex reviews each ticket in a visible Orca terminal to
"clear" (or the reverse); short-lived branches off `main`, one per ticket, fast-forward merge; the verification
scope in DEVELOPMENT; backup, signing, fresh-binary and launch checks before any install; ask the user before
merging to `main` or touching the phone. Screen work follows the ios-design skill (real Default/AccessibilityL
captures); the Floodlight look (D59) applies to new screens. UI-first: show new screens with sample data before
wiring logic (the user's standing preference).
