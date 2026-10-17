# Ticket 15 — feedback triage review

Reviewed `git diff 617421b..b0b1757` against ticket 15, D61, the published Feedback/deletion wording, and the server's
storage and restore procedures. During review HEAD advanced from `63b98bb` to `0cf7438`; changes after `b0b1757`
are only STATE and the review prompt, so the reviewed implementation is unchanged.

1. **P2 — Global `--local` is detected but still consumes positional arguments.**
   **Location:** `server/scripts/feedback.mjs:28–35,53–54,71`.
   The review contract requires `--local` anywhere. `done --local <id> fixed` instead treats `--local` as the ID and
   exits 2; `--local done <id> fixed` treats it as the command and exits 2 with usage. The same positional problem
   affects `wontfix` and `reopen`. A suffix after the ID works. These failures were reproduced with the actual script
   evaluated against mocked process/filesystem/child-process boundaries; no Wrangler process was invoked.
   **Fix:** determine the environment from raw arguments, then remove the global flag before deriving command,
   ID and note. Add CLI-level cases for prefix, between-command-and-ID, and suffix placements, including preservation
   of multiword notes and local-only routing. The new SQL-only tests cannot catch this parser defect.

2. **P3 — Unicode line separators bypass the single-line note rule.**
   **Location:** `server/scripts/feedback.mjs:71–73`.
   A note containing `alpha\u2028beta` or `alpha\u2029beta` is accepted and stored verbatim, although these are line
   and paragraph separators. The validator only rejects CR/LF, so the promised single-line format is not enforced
   for pasted Unicode text. Both cases were reproduced with the mocked CLI. This is a validation gap, not SQL
   injection. **Fix:** reject Unicode line/paragraph separators as well as CR/LF, and cover those inputs through
   the script's validation path.

No additional standards or migration finding. In-memory SQLite 3.54.0 verification (exit 0) applied migrations
0001–0005, inserted a made-up feedback row, then applied 0006: existing data survived with `new`/NULL/NULL defaults,
the CHECK rejected an invalid status, and an SQL dump restored with identical row contents and integrity `ok`.
The Workers tests also apply 0006 through local D1. No production migration was attempted.

The Worker names its original insert columns, so defaults supply the added fields. Expiry, account deletion and
the CLI delete remove entire feedback rows; their metadata cannot survive separately. The screenshot queue is
unchanged. `check-export.sh` enumerates tables and compares row counts, so these added columns do not invalidate
it. README's reconciliation of deleted feedback rows also removes the added metadata. Restoring an older backup
can roll back triage edits like other later writes; this introduces no separate retention exception.

The UTF-8 hex cast safely isolates note text from SQL syntax; the strict UUID check and fixed status choices keep
the other interpolations constrained. Quote/SQL-looking text round-tripped in the mocked check. Length is counted
as Unicode code points, not bytes: 200 emoji passed and 201 failed. Reopen clears note/time. All three triage commands
enter the existing download prune. `list --open` filters `new`; the separate count includes all open rows, not just
the displayed limit. The three added tests cover new-row defaults, status CHECK/hex SQL storage, and account
deletion, but do not execute CLI parsing or validation. Existing rows were checked by the separate SQLite probe.

**Privacy policy:** no wording change is required for the described implementation. Nonpersonal developer status
and resolution notes serve the already stated purpose of fixing and improving the app, remain on the same feedback
row, and introduce no new recipient or retention period. This conclusion depends on following the documented rule
against personal details and separate copies; it is a consistency assessment of the code and published promises.

**Required verification, personally run from `server/`:** `npx vitest run` — **exit 0**, **6 files / 228 tests passed**;
`npx tsc --noEmit` — **exit 0**. Offline mocked-CLI and in-memory SQLite probes also exited 0. Fixtures existed only
in memory, so there were no local D1 rows to clean up. No remote/production command, deployment, or real feedback
CLI invocation was made. Only this report was added; no commit or push.

Verdict: not clear
