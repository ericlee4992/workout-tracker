# 15 — Track feedback: mark each one handled

Type: task
Status: **done 2026-10-17** — merged `07af7a6`, migration 0006 applied in production
Blocked by: —
Implementer: Claude; Reviewer: Codex.
Branch: `ericlee4992/beta-15-feedback-triage` off `main` `617421b`.
Related: [07 feedback](07-feedback.md) (the feedback table and `scripts/feedback.mjs`), [08](08-external-testers.md)
(privacy policy, D61 retention promises).

## Request (the user, 2026-10-17)

"why don't we make a separate place to store feedbacks whenever we get them, so it's easy to track of them and check
them off." Claude proposed keeping the tracking on the server, next to the feedback, rather than a second copy; the
user: "yes, make ticket 15 and build it".

## Why on the server, not in the repo or a spreadsheet

The repository is public, so tester messages, names and emails cannot go there. The privacy policy promises feedback
is deleted with the tester's account and about a year after it was sent; a second copy (a sheet, a notes file) would
have to be deleted by hand to keep that promise. A status on the feedback row itself is deleted with the row by every
existing path (account deletion, the one-year sweep, `feedback.mjs delete`, a restore's reconciliation). The policy
already says "I read it to fix and improve the app"; tracking whether it was handled is part of that, so its wording
does not change.

## Scope

- Migration `0006`: `feedback.triage` (`new` | `done` | `wontfix`, default `new`, checked), `triage_note` (optional,
  the developer's own short note, e.g. "fixed in build 7"), `triaged_at` (ms). Additive; existing rows become `new`.
  No Worker code change, no app change, no new build.
- `scripts/feedback.mjs`: `list` shows each row's status; `list --open` only `new` ones; `done <id> [note]`,
  `wontfix <id> [note]`, `reopen <id>`; `show` prints the status and note. The note is single-line, at most 200
  characters, sent to SQL as hex (no quoting of typed text). Notes never hold personal details.
- Work that comes out of feedback becomes a numbered ticket as usual, describing the problem in our own words and
  citing the feedback ID — nothing that identifies the tester.
- server/README → Reading feedback; STATE.

## Acceptance

- [x] Migration applies locally and in tests; existing rows read `new`; an invalid status is refused.
- [x] Every new command works against `--local`; `list --open` hides handled rows; a note with quotes and SQL is
      stored verbatim.
- [x] Server tests and typecheck pass; Codex review clear (round 2, `codex-review-15b.md`).
- [x] With the user's go-ahead: a D1 export before the migration (README), `npm run migrate:remote`, the user's
      feedback row reads `new` in production.

## Comments

**Built (2026-10-17, Claude).** `server/migrations/0006_feedback_triage.sql` (three columns + index);
`server/scripts/feedback.mjs` (`list` status column, `--open`, an open count; `done`/`wontfix`/`reopen`; `show` status;
notes as `CAST(X'<hex>' AS TEXT)`); 3 tests in `test/feedback.test.ts` (default `new`, CHECK + hex note verbatim,
deleted with the account); server/README → Reading feedback. **Verified:** `vitest` 6 files / **228 passed**, `tsc
--noEmit` exit 0. Local D1 (`migrations apply --local`: 0006 ✅) with two made-up rows: `list` shows both `new` and "2
open"; `done` with `fixed in build 7 — it's "quoted"'); DROP TABLE feedback; --` stored and shown verbatim; `wontfix`
without a note; `list --open` → "Nothing open."; `show` prints status, time and note; `reopen` → `new`, note cleared;
unknown ID exit 1, two-line note and 201 characters exit 2, bad ID refused; 200 × "é" accepted (length 200, text). Sample
rows deleted afterwards. Not done: production (needs the user's go-ahead after review).

**Codex review round 1 — response.** Report [codex-review-15.md](../codex-review-15.md) (`b0b1757`): **not clear**,
1 × P2, 1 × P3; migration, deletion paths, restore, hex injection safety and privacy (no policy change needed)
confirmed. Both taken: (#1) `--local` is now removed before the command/ID/note are read — new
`server/scripts/feedback-args.mjs` (`parseArgs`, `noteProblem`) used by `feedback.mjs`; this also fixes the same
pre-existing defect for `show`/`screenshot`/`delete`. (#2) a note refuses CR, LF, VT, FF, NEL, U+2028 and U+2029.
CLI-level tests `scripts/feedback-args.node-test.mjs` (`node --test`, outside the Workers pool): `--local` in five
positions incl. prefix and mid-note, multiword notes, each line break, 200/201 characters incl. emoji; `npm test` now
runs vitest then these, and the Server CI workflow runs `npm run test:scripts`. **Verified:** `npm test` exit 0 —
vitest **228 passed**, node tests **4 pass / 0 fail**; `tsc --noEmit` exit 0. Real script on local D1 (one made-up
row, deleted after): `--local done <id> fixed in build 7` exit 0; `wontfix --local <id> not planned` exit 0 and `show`
prints "wontfix … — not planned"; `reopen --local` exit 0; a U+2028 note exit 2; `--local list --open` → "1 open".

**Codex review round 2: clear.** Report [codex-review-15b.md](../codex-review-15b.md) (HEAD `028ac39`): both findings
resolved, no new ones; Codex ran `npm test` (vitest 228 passed, node 4 passed; exit 0 after Claude approved running it
outside its sandbox — Miniflare could not bind localhost inside) and `tsc` (exit 0). Next: the user's go-ahead to merge,
export D1, `npm run migrate:remote`.

**Live (2026-10-17 ~07:25 EDT, the user's "Yes, all three").** `main` fast-forwarded `617421b..07af7a6` and pushed
(origin confirmed). Export `~/WorkoutTracker-Backups/server/2026-10-17-pre-15-migration/stacked.sql` (0600, 9,877
bytes, SHA-256 `0b9c2e4114926e91…`; the first attempt failed with Cloudflare "Authentication error [code: 10000]", a
read and the retry then succeeded); `check-export.sh` **OK** (restores cleanly, every table's count matches).
**Delete this export by 2026-11-16** (30 days, D61). `wrangler d1 migrations apply stacked --remote`: only 0006 pending
→ ✅, exit 0. Production: the one feedback row reads `new`/NULL/NULL; index `feedback_triage` present;
`feedback.mjs list --open` exit 0, "1 open (new)". No Worker deploy, no app build.
