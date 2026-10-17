# Codex review — ticket 15 (feedback triage)

You are the independent reviewer (AGENTS.md T6); Claude implemented this. Review branch
`ericlee4992/beta-15-feedback-triage`, commit `b0b1757`, against `main` `617421b`:
`git diff 617421b..b0b1757`.

Read first: `work-record/public-beta/issues/15-feedback-triage.md` (scope, acceptance, Claude's verification),
`server/migrations/0003_feedback.sql`, `server/src/pages.ts` (the privacy policy's Feedback and deletion sections),
`server/README.md` → Reading feedback and Backups and restore, ticket 08's D61 notes in `docs/DECISIONS.md`.

Check in particular:
1. Migration 0006 on the production D1 (SQLite): `ALTER TABLE … ADD COLUMN … NOT NULL DEFAULT 'new' CHECK (…)` is valid
   and safe on a table with rows; the Worker's inserts (`server/src/feedback.ts`), the one-year sweep, account deletion
   (`server/src/store.ts`) and `scripts/check-export.sh` are unaffected; the restore procedure in README still holds.
2. `scripts/feedback.mjs`: the hex-cast note cannot inject SQL; the ID check; the 200-character/one-line rule (counted
   as characters); `--local` handling; argument parsing (note words after the ID; `--local` anywhere); exit codes;
   that `done`/`wontfix`/`reopen` run the download prune like the other commands; `list --open` and the open count.
3. Privacy: whether a status and a developer's note on the feedback row need any change to the published policy
   ("I read it to fix and improve the app"), given notes are rules-bound to hold no personal details and are deleted
   with the row. Say if you think the policy must change.
4. Tests (`server/test/feedback.test.ts`, "triage status") cover the claims; docs match the code.

Run `cd server && npx vitest run` and `npx tsc --noEmit` yourself and report exit codes. You may run the script against
`--local` (made-up rows only; delete them afterwards). **Never** run anything against `--remote`/production, never
apply migrations remotely, never deploy.

Write the report to `work-record/public-beta/codex-review-15.md`: findings numbered with P1/P2/P3, file:line, failure
scenario, and fix; end with a final line exactly `Verdict: clear` or `Verdict: not clear`. Do not commit or push.

## Round 2

Round 1: [codex-review-15.md](codex-review-15.md), not clear (#1 P2 `--local` position, #2 P3 Unicode separators).
Claude's fixes: see the ticket's "round 1 — response" comment and `git diff b0b1757..HEAD -- server .github`. Check
that both findings are closed and that nothing else regressed; rerun `npm test` (vitest + `node --test`) and `tsc`.
Same rules: `--local` only, never production. Write `work-record/public-beta/codex-review-15b.md`, ending with exactly
`Verdict: clear` or `Verdict: not clear`. Do not commit or push.
