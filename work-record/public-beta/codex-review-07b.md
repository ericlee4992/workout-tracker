# Ticket 07 — independent Codex review, round 2

Reviewed `git diff df5dd71..HEAD`, with `e455222..HEAD` context for the affected paths,
on `ericlee4992/beta-07-feedback`, HEAD `e59386159b7b4ba1df197dc9f0db464cc33984d8`,
on 2026-10-03. Read the ticket's round 1 response and checked the fixes against the
previous findings. The working tree was clean before review. Only this report was changed.

## Standards

1. **P2 — Reflow and capture the new screenshot-loading state.**
   **Location:** `WorkoutTracker/Features/Settings/FeedbackSheet.swift:219–233`;
   shared row implementation `WorkoutTracker/Features/Design/Look/Lists.swift:84–106`.
   The new loading row places its label, spinner, and Remove control in a `LookRow`
   that stays horizontal at every text size. At AccessibilityL, the trailing controls
   therefore remain beside the enlarged label, contrary to ios-design's explicit rule
   that trailing accessories stack below text at accessibility sizes. The ticket says
   this state was not captured; the existing captures and unit tests cannot establish
   its layout. Reflow this state at accessibility sizes and capture it at Default and
   AccessibilityL in both appearances using a delayed attachment fixture. That does
   not require driving PhotosPicker and can also assert that Send is disabled and Remove
   cancels the load. Record the user's decision for the new “Loading Screenshot…” copy;
   the response currently labels it new but supplies no approval for that string.

## Spec

2. **P1 — The sweep can erase a newly queued deletion without deleting its screenshot.**
   **Location:** `server/src/feedback.ts:239–245`;
   queue schema `server/migrations/0003_feedback.sql:38–42`.
   The cleanup assumes a newly inserted row always has a higher `rowid` than the rows
   the sweep read. This table has an implicit SQLite rowid, which can be reused when
   the greatest row is deleted, including when the queue becomes empty. A valid race is:

   - The sweep reads queued screenshot A with rowid 1 and due time T, then awaits R2.
   - A's immediate account-deletion cleanup succeeds and removes A's queue entry.
   - Another account deletion queues B. The empty table assigns rowid 1 again. B's
     due time can equal T, or precede it if that deletion captured its time before a
     delayed transaction; choose B's key before A in the same-time ordering.
   - B's immediate R2 deletion fails, so B must remain queued for retry.
   - A's sweep resumes and its broad `DELETE` also matches B's reused rowid and due/key
     order. It removes B's job even though its R2 call only deleted A.

   B's screenshot is now retained indefinitely: the new implementation has no bucket
   scan to rediscover it. I reproduced this using the production `sweepFeedback` and
   `deleteClaimedScreenshots` functions, the actual migration in in-memory SQLite, and
   an R2 test double. A and B both received rowid 1; after the sweep the queue was empty
   but B's object remained, and the next sweep returned `{ removed: 0 }` with B still
   present.

   Delete only the captured immutable job identities, or introduce a genuinely
   non-reused sequence. Deleting the captured keys in groups of at most 100 parameters
   would still be bounded: at most 12 sweep D1 statements plus 21 for the current
   revocation loop, within the intended 50-query budget. The concurrency test at
   `server/test/feedback.test.ts:389–396` leaves A in the table when inserting B, so it
   never exercises rowid reuse. Extend it to remove A first, insert B, fail B's immediate
   object deletion, and verify that a later sweep deletes B.

## Fix verification

- **Round 1 #1 and #2, attachment handling:** the data-flow fixes are connected correctly.
  `canSend` observes `!attachment.isLoading`; the dismissal predicate includes text,
  attached images, and pending loads. Cancellation plus the generation check rejects
  obsolete completions. Remove cancels/invalidates the load and clears picker selection;
  failed transfers or decoding expose the problem and reset the picker. The remaining
  issue is the new state's design/verification gap in finding 1.
- **Round 1 #3, bounded cleanup:** replacing repeated bucket listing with queued work
  fixes the growth-dependent query budget. Uploads queue before R2 put, and successful
  row insertion and unqueueing share one database batch. Account deletion queues keys
  in the transaction that deletes feedback. Failed inserts retain their queued keys;
  failed object deletes retain work for retry. The sweep selects at most 1,000 jobs,
  skips jobs whose feedback row exists at selection, and independently cleans old
  counters. Finding 2 prevents clearing this fix. The tests cover grace, live rows,
  failed inserts, failed R2 deletion, and 2,501 jobs across three invocations, but miss
  the reproduced cleanup/reinsert interleaving.
- **Round 1 #4, conditional account counter:** the single conditional upsert cannot
  recreate an account counter after deletion. If it executes first, deletion removes
  it; if deletion executes first, it returns no row and the request stops with 401.
  The strengthened test now checks the counter, and the additional upload-time deletion
  test covers the later conditional feedback insert.
- **Round 1 #5, R2 batches:** `deleteObjects` chunks keys at 1,000 and reports any failed
  batch. Immediate claim cleanup removes its queue rows only after all batches succeed.
  The 1,001-key test exercises the handler with a fake that rejects oversized calls.
- **Revocation batch:** the default is now 20. `runPendingRevocations` reads one batch
  and makes one update/delete per item, at most 21 D1 statements; the present feedback
  sweep adds at most three. The changed default is used by the scheduled path. The
  combined worst-case query budget was checked from the callers; no dedicated combined
  cron budget test was added.
- **Mutation claims:** the strengthened counter assertion and enforced R2 batch limit
  would catch the reported server regressions. The attachment tests cover stale
  completion after supersession/removal. I did not independently rerun source mutations
  under the report-only restriction. `sendWaitsForAPickStillLoading` checks the model's
  loading state, not the actual button; the source wires the gate, but a loading-state
  UI test should verify it as described in finding 1.
- **README/ticket:** the README now correctly describes feedback as implemented and
  quota as validated attempts, including storage/global-limit failures. The ticket
  accurately distinguishes the tests run from the uncaptured loading state, but its
  claim that the sweep clears exactly the rows it read is disproved by finding 2.
  Editing migration 0003 in place is consistent with the recorded pre-deployment status;
  this review did not access or alter a deployed database.

## Independent verification

- `cd server && npx vitest run`: exit 0, **87/87 passed**, three files.
- `cd server && npx tsc --noEmit`: exit 0.
- Targeted `WorkoutTrackerTests/FeedbackTests` on WT-Onboarding
  (`2CEC4AD8-F702-421F-B3B2-D68C302A3453`): successful build and `xcodebuild` exit 0,
  **13/13 passed**, no skips/failures. Independently inspected the xcresult summary.
  Derived data: `/tmp/wt-beta07-codex`; result: `/tmp/wt-beta07-codex-round2.xcresult`;
  log: `/tmp/wt-beta07-codex-round2.log`.
- The additional queue-race reproduction ran from stdin with local SQLite and R2 test
  doubles, without changing source or tests. UI tests were inspected but not rerun.
  Existing approved captures were reviewed in round 1; no loading capture was supplied.
- No Cloudflare/Apple API calls, deploy/login/secret commands, phone or backup access,
  or desktop control were used.

Standards: 1 finding, highest P2. Spec: 1 finding, highest P1.

Verdict: not clear
