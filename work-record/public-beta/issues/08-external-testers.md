# 08 — External testers

Type: task
Status: in progress — policy pages built, in review (2026-10-15)
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
  **Includes the phone check of New Model → "Suggest exercises with AI"** (the `model-exercises` flow), which the
  user left out of build 4's check (2026-10-15: "include it as 08's final test"); confirm the request on the server.
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

### Server hygiene: D1 backup procedure — 2026-10-15 (Claude)

Written in [server/README → Backups and restore](../../../server/README.md#backups-and-restore-ticket-08), with
`server/scripts/check-export.sh` (restores an export into a throwaway SQLite file; compares every table's row count
with production; integrity and foreign-key checks; read-only on production). Time Travel retention (7 days Free / 30
Paid) checked against Cloudflare's D1 docs. **Rehearsed:** `wrangler d1 export stacked --remote` →
`~/WorkoutTracker-Backups/server/2026-10-15-rehearsal/stacked.sql` (0600, 7,904 bytes, SHA-256 `d48c6cf5…e3e`, only the
user's own two accounts); the check passed (13 tables equal, integrity `ok`, exit 0); the same export with
`training_profiles` rows removed failed (exit 1). Not rehearsed: a Time Travel restore or a restore into a new remote
database (both replace or repoint live data; the user approves). **New for the user:** how long manual exports are
kept — the policy's deletion text depends on it.

**The user skipped (2026-10-15: "Skip both steps")** the production off-switch rehearsal and hitting the AI daily
limits on the live server; the server's unit tests cover both. Server hygiene is otherwise done.

### Privacy terms, pages and enforcement — 2026-10-15 (Claude)

**The user's answers (D61):** feedback kept 1 year; "not directed to children under 13"; manual exports kept 30 days;
**Workers Free for now** ("if something fails because of it, let me know" — check Workers metrics for exceeded-CPU
errors after the final test pass and report); support email the personal Gmail; effective date = the day it goes
live; legal name = the Apple Developer team's, read from build 4's provisioning profile: **Eunchan Lee**.

**Found:** a stored Workers Logs invocation record (dashboard, `PUT /v1/profile`, 2026-10-15 05:05) holds
`cf-connecting-ip`/`x-real-ip`, city, postcode, latitude/longitude, ISP, ASN, user agent and TLS fingerprints
(authorization masked). The server's own `ai request` line holds only flow/status/latency/tokens and script metadata.
Turned off invocation logs and traces (`wrangler.jsonc`) rather than disclose that.

**Built (not deployed):** one-year feedback expiry in the hourly `sweepFeedback` (≤ 1,000 rows a run, screenshots
queued due at once, same-run R2 delete; tests for the boundary, R2 failure and batching); `scripts/feedback.mjs`
deletes downloads older than 30 days or whose feedback is gone, keeps downloads only in `server/.feedback`, and gains
`delete <id>` for signed-out requests; server/README: export retention, re-deleting after a restore, the cron budget
(≤ 37 of Free's 50). `server/src/pages.ts`: the policy (from the cleared draft plus D61, Free-plan figures, logs) and a
support page; `npm run deploy` refuses while `POLICY_EFFECTIVE_DATE` is a placeholder. App: camera/photo usage strings
name Stacked's server; the Health read string names energy and distance and drops "never leaves it" (build 5).

**Verified:** server `vitest` 6 files / 224 tests passed; `tsc --noEmit` exit 0; `wrangler deploy --dry-run` accepted
the config; `npm run predeploy` exit 1 with the placeholder (as intended); `xcodebuild … iphonesimulator Debug build`
exit 0, built Info.plist carries the new strings. **Pending:** Codex review; the user's approval of the wording; deploy
(with the date) and confirm an hourly run; build 5; App Privacy answers; external group; Beta App Review; the final
test pass including New Model → Suggest exercises with AI.

### Codex review 08d — response (round 4)

Report [codex-review-08d.md](../codex-review-08d.md) (HEAD `6865caf`): **not clear**, 7 findings (5 × P2, 2 × P3); the
expiry's correctness/atomicity, the 37-statement budget, the log configuration and the console lines were confirmed.
Taken: download clean-up prunes by age first and independently of the database, keeps unexpired files when the
liveness query fails, has a `prune` command, and README makes "run it at least every 30 days while a download exists"
an operating rule; the policy now promises only "within 30 days" (#1). The restore promise is now honest — deleted data
may reappear; re-delete what can be identified and email testers about the rest — and README's procedure orders pause,
evidence export, restore into a new database, reconciliation of accounts/feedback/sessions/profiles/retention, check,
resume (#2). `--local` downloads in `server/.feedback-local` (#3). "Change or clear" → "change; deleting your account
removes it" (no clear action exists) (#4). New hourly `pruneSessions` (expired sessions; test) and sign-out wording
"if your iPhone can reach my server" (#5). Support page: "your account and the data linked to it", with the exceptions
pointed to (#6). Delete path: "in Settings, tap your name or email at the top, then Delete Account…" (#7). Also from the
notes: "about a year … hourly clean-up job (retries)", and logs described as diagnostic details with per-request
logging off. Server: 225 tests passed, `tsc` exit 0; `prune --local` removed only a file older than 30 days.

### Codex review 08e — response (round 5)

Report [codex-review-08e.md](../codex-review-08e.md) (HEAD `f14607e`): **not clear**; 08d #3–#7 closed, two open and
one new. Taken: downloads are pruned at 15 days or more (inclusive) and README requires `prune` at least every 15 days
while a download exists, so none outlives 30 (#1). Restore: delete every restored session (everyone signs in again),
take evidence twice (before the restore and immediately before switching), email testers about anything in the
unidentifiable gap; the policy adds "sign everyone out" (#2). D61 rewritten: the user's answers separated from Claude's
proposed terms (logs off, session prune, download and restore commitments, with what each narrowed and why), which
await the user's approval with the wording (#8). The 08d tally corrected to 5 × P2, 2 × P3. Verified: server 225
tests passed, `tsc` exit 0; `prune --local` removed files 15 and 20 days old and kept one 14 days old.

## Comments
