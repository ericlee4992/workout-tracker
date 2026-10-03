# 08 — External testers

Type: task
Status: ready-for-human (mostly App Store Connect and policy work with the user)
Blocked by: 02, 04, 05, 06, 07
Implementer: Claude with the user; Reviewer: Codex for the privacy policy against the code and the server.
Branch: `ericlee4992/beta-08-external` off `main`.
Spec: [spec.md](../spec.md) → *Testers and distribution*. Decision: D60.

## Goal

The user's friends receive Stacked by email invitation through external TestFlight.

## Scope

- **Privacy policy** at the Worker's `/privacy` and a **support page** at `/support`: what the app keeps on the
  phone, what the server keeps (account, profile, training profile, AI usage counts, feedback), what goes to
  OpenAI and under what consent, HealthKit (read on the phone, never sent), deletion, contact. Checked against
  the code and the server by the reviewer; the user approves the wording.
- **App Privacy answers** in App Store Connect (draft in spec; confirm against the code).
- External group; beta app description using the tagline; feedback email; what-to-test notes; the build's
  Beta App Review; email invitations to the user's list of testers.
- Readiness pass before the first external build: DEVELOPMENT's escalation rule for a release candidate decides
  whether the full UI suite runs over 02–07 together; record the choice and results.
- Server hygiene before strangers use it: AI limits verified in production, the off switch rehearsed, D1 backup
  (export) procedure written down.

## Acceptance

- [ ] Policy and support pages live and approved by the user.
- [ ] App Privacy answers saved; Beta App Review passed.
- [ ] At least one external tester installed the build, signed in, and sent feedback that reached the developer.

## Progress

### Privacy policy and App Privacy draft — 2026-10-03 (Claude)

[privacy-policy-draft.md](../privacy-policy-draft.md) on branch `ericlee4992/beta-08-privacy-draft`: the policy text
(phone-only data, the optional account and training profile, AI through the server to OpenAI, feedback, processors,
deletion, contact) and draft App Privacy answers, written from the code on `main` `7c70d14`. Sections that depend on
unbuilt work are marked *(after ticket NN)*. **Waiting on the user:** legal name, support email, effective date,
feedback retention, the age statement, and approval of the wording. Codex checks every statement against the code
and server before publishing. Open items listed at the end of the draft.

## Comments
