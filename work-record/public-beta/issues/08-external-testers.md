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

### Codex review 08 — response (round 1)

Report [codex-review-08.md](../codex-review-08.md) (HEAD `4cda004`): **not clear**, 17 findings (one P1); all taken in a
rewrite of the draft. The draft now states up front that it describes the external-test build (03/04/05/06/07 wired,
server deployed) and is not true of today's app. Corrections: Health reads named (heart rate, active/resting energy,
distances) and "never sent" narrowed to "not uploaded; leaves only if you send it" (#1); Apple Maps imagery requests for
a route's area disclosed as Apple's (#2, P1); the whole text scoped to the intended build, today's direct-to-OpenAI
flow recorded (#3); uninstall vs Health records, exports, backups and server data (#4); consent disclosures as a
release gate across all four surfaces and the consent-flag question (#5); height/weight declared as Health (#6);
Apple's collection/linkage definitions and OpenAI's 30-day abuse retention with the current link (#7); performance
diagnostics, Product Personalization, purpose names corrected, the address code and logs left open (#8); Cloudflare
logs 3 days Free / 7 Paid as placeholders pending a deployed check, no unverified "never what you sent" (#9); a
TestFlight section (#10); export formats (#11); deletion split into immediate live deletion, screenshot retries,
unlinked revocation retries and the iOS Settings remedy (#12); AI daily counts ~2–3 days and hourly clean-up (#13);
session expiry vs record removal (#14); manufacturer/model in the suggestion payload (#15); D1 Time Travel, backups
and downloaded screenshots (#16); release gates collected at the end (#17).

### Codex review 08b — response (round 2)

Report [codex-review-08b.md](../codex-review-08b.md) (HEAD `f9c70fb`): **not clear**, 4 findings (2 × P3, 2 × P2);
round 1 otherwise confirmed. Taken: the label reader vs AI identification (#1); "does not automatically include your
workout history or readings from Apple Health" instead of "Health data are not sent" (#2); a failed revocation's token
"kept separately from your deleted account record, solely to retry" — not "no longer linked to you" — and any failure,
not just Apple unreachable (#3); manual D1 exports' retention and the deletion of downloaded feedback copies (signed in
too) added to the deletion text as placeholders and to release gate 3 (#4).

### Codex review 08c — round 3: clear

Report [codex-review-08c.md](../codex-review-08c.md) (HEAD `d08306f`): **Verdict: clear** for the unpublished draft;
all four round-2 findings closed. Not a clearance of the release gates or of publication: the user's details and
decisions, the wired build, the deployed checks and the user's approval of the wording remain (draft → *Release gates*).

## Comments
