# 15 — Track feedback: mark each one handled

Type: task
Status: in progress (2026-10-17)
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
- [ ] Server tests and typecheck pass; Codex review clear.
- [ ] With the user's go-ahead: a D1 export before the migration (README), `npm run migrate:remote`, the user's
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
