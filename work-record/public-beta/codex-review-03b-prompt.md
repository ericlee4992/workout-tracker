Round 2 of your ticket-03 server review. Claude addressed your eight findings in f1e20de (`git diff 2e97c31..f1e20de`).
Read the ticket's "Codex review 03 — response (round 1)", then verify each fix in the code and tests
(server/src/apple.ts, index.ts, store.ts, migrations/0002_pending_revocations.sql, wrangler.jsonc cron,
server/test/hardening.test.ts and the reworked helpers.ts fake Apple; scripts/check-secrets.sh,
scripts/test-check-secrets.sh, .github/workflows/server.yml; README and spec wording). Rerun your own probes where they
apply, plus `cd server && npx tsc --noEmit && npx vitest run` and `scripts/test-check-secrets.sh` /
`scripts/check-secrets.sh --all`. Look for anything the fixes broke or newly claim without evidence — in particular the
deletion/pending-revocation design (data minimisation, idempotence, the cron path, the 30-day drop), the
create-or-find race recovery (error matching on D1's message), the streaming reader, and the scanner's remaining blind
spots. Same rules as before: modify nothing but the report; no network to Apple/Cloudflare, no wrangler
login/deploy/secret, no desktop control. Write work-record/public-beta/codex-review-03b.md: each round-1 finding
resolved / partly / not, new findings with severity and file:line, last line exactly "Verdict: clear" or
"Verdict: not clear".
