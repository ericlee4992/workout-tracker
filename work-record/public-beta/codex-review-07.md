# Ticket 07 — independent Codex review

Reviewed `git diff e455222..HEAD` on `ericlee4992/beta-07-feedback`, HEAD
`df5dd71c16987da70d07da42705a966d9d9c3e00`, on 2026-10-03. Claude implemented;
Codex reviewed. The working tree was clean before review. Only this report was changed.

## Standards

1. **P2 — Wait for the selected screenshot before allowing Send, and discard stale loads.**
   **Location:** `WorkoutTracker/Features/Settings/FeedbackSheet.swift:311–325`, with
   `canSend` at line 42 and draft capture at line 297.
   Selecting an image starts an untracked asynchronous PhotosPicker transfer. While an
   iCloud image downloads, Send remains enabled and captures `screenshot == nil`, so the
   app reports success without the selected attachment. The picker also remains available:
   selecting B while A loads can let A's later completion replace B, including after B
   has been removed. This breaks the form's promise that the attachment is the user's
   chosen screenshot. Track loading and the current selection/task, disable Send until
   resolution, and cancel or ignore obsolete completions. Add delayed-transfer tests for
   Send, replacement, and removal; existing UI tests start with an already-loaded fixture.

2. **P3 — Protect an attachment-only draft from interactive dismissal.**
   **Location:** `WorkoutTracker/Features/Settings/FeedbackSheet.swift:58`.
   The dismissal guard checks only trimmed message text. A tester who chooses a screenshot
   before typing can swipe the sheet away and lose the attachment, contradicting the ticket's
   explicit “a non-empty draft cannot be swiped away by accident” requirement. Include an
   attachment or pending photo selection in the dirty-state guard, and test a screenshot-only
   draft. Explicit Cancel can continue to discard it.

## Spec

3. **P1 — Bound the orphan sweep and preserve progress between invocations.**
   **Location:** `server/src/feedback.ts:180–197`.
   Every hourly invocation starts at the first R2 key and queries D1 once per 50 older
   objects, including objects that still have rows. There is no retained cursor or work
   budget. Cloudflare documents **50 D1 queries per invocation on Workers Free**, the plan
   specified for this server. At 2,501 retained screenshots, checking all objects alone
   requires 51 queries; even 2,500 requires another query for counter cleanup. Subsequent
   runs restart at the same prefix and fail again. Orphans later in key order, including
   screenshots left by failed account deletion or failed row insertion, can remain
   indefinitely, and old counter cleanup is skipped. This defeats the deletion fallback.
   [Cloudflare D1 limits](https://developers.cloudflare.com/d1/platform/limits/).

   A local call to the production `sweepFeedback` with 2,501 simulated retained objects
   and a 50-query binding budget failed at query 51 on page 6 on two successive runs.
   Make each invocation bounded, persist its continuation, reserve room for other scheduled
   D1 work, and run counter cleanup independently. Test multiple pages, budget exhaustion,
   continuation, and an orphan beyond the first invocation's budget. The current two-object
   tests do not exercise this failure. The present sweep also repeats O(total retained
   screenshots) work every hour as storage grows.

4. **P2 — A request racing account deletion recreates the deleted account's counter.**
   **Location:** `server/src/feedback.ts:131–134`; related deletion at
   `server/src/store.ts:147`.
   Authentication happens before multipart loading. If `claimDeletion` commits before
   that request reaches its limits, unconditional `bump(account:<id>)` recreates a row
   containing the deleted account UUID. The conditional feedback insert correctly refuses
   the submission and removes its screenshot, but leaves this counter behind. This violates
   Accounts' requirement to delete “every server row for the account,” including usage counts.
   A local execution of the production submission function against in-memory SQLite with
   an absent account returned `unauthorized`, left zero feedback rows/objects, and retained
   `account:deleted-account` with count 1 (plus a spent global count).

   Make the account counter reservation conditional on account existence in an atomic
   database operation, so deletion either removes the reservation or prevents it. Extend
   `server/test/feedback.test.ts:233–245`: it already simulates this ordering but checks
   only feedback rows and R2 objects, omitting the counter that survives.

5. **P2 — Split account screenshot deletion into supported R2 batches.**
   **Location:** `server/src/feedback.ts:163–168`.
   `deleteScreenshots` passes every key from an account to one `R2Bucket.delete` call.
   R2 accepts at most **1,000 keys per call**. The 30/day account limit does not bound
   lifetime feedback: 1,001 attachments are possible after 34 days. Deleting that account
   predictably exceeds the API limit, logs the failure, and leaves its screenshots for the
   sweep instead of deleting them immediately. Finding 3 can make that fallback ineffective.
   Delete in batches of at most 1,000, preserve fallback handling for failed batches, and
   test 1,001 keys with a fake that enforces the production limit.
   [Cloudflare R2 Workers API](https://developers.cloudflare.com/r2/api/workers/workers-api-reference/).

## Verification and other review conclusions

- **Server:** `cd server && npx vitest run` exited 0: **82/82 passed** across three files.
  `npx tsc --noEmit` exited 0. The additional deletion/sweep reproductions ran from stdin
  without modifying source or tests; they used local SQLite/test doubles, not live services.
- **App:** targeted `WorkoutTrackerTests/FeedbackTests` on WT-Onboarding
  (`2CEC4AD8-F702-421F-B3B2-D68C302A3453`) built and passed **8/8**, no skips or failures,
  `xcodebuild` exit 0. Independently inspected the xcresult summary.
  Derived data: `/tmp/wt-beta07-codex`; result:
  `/tmp/wt-beta07-codex-feedback-retry.xcresult`; log:
  `/tmp/wt-beta07-codex-test-retry.log`. The first sandboxed attempt exited 70 because it
  could not access CoreSimulator; the authorized retry succeeded.
- **Screen:** inspected all 19 supplied captures against the design record and REVIEW.md.
  Required text remains readable across the Default/AccessibilityL pages in both appearances;
  metadata and screenshot details reflow. The readable phone name, Bug default, hierarchy,
  and approved copy match. Source has VoiceOver labels and gates animations on Reduce Motion.
  UI tests were read but not rerun; live VoiceOver and PhotosPicker interactions were not
  exercised. The missing asynchronous loading/dismissal coverage is described above.
- **Endpoint:** declared and streamed body limits are enforced before form parsing; malformed
  fields do not spend quota. Image types come from magic bytes, object names from generated
  UUIDs, and inserts use bound values. Sniffing establishes a signature, not that an entire
  file decodes; the tests intentionally use minimal signature fixtures. Invalid supplied
  authorization is rejected rather than treated as signed out. Conditional row insertion
  handles account deletion, subject to the surviving-counter finding.
- **Address privacy and limits:** the secret-keyed, day-separated HMAC prevents offline address
  enumeration without the secret and direct equality linking across days. No raw address or
  address hash is attached to feedback rows. Ordinary client-supplied forwarding headers do
  not replace the edge's `CF-Connecting-IP`; Cloudflare documents a fixed address for
  cross-zone Worker subrequests. No concrete header-spoofing bypass was established for the
  configured endpoint. Equivalent IPv6 spelling is not normalized by this code; tests that
  directly inject that header cannot prove those spellings are client-controllable at the
  edge. Different actual addresses still receive different allowances, bounded by the global
  limit. [Cloudflare header behavior](https://developers.cloudflare.com/fundamentals/reference/http-headers/).
- **Quota semantics:** counters currently count validated attempts reaching each reservation,
  including storage failures; global refusal also spends personal quota. The tests prove
  malformed requests spend none, but do not prove successful-submission-only accounting.
  Feedback's contract does not explicitly require the success-only policy specified for AI;
  README/ticket wording “submissions” should make the implemented attempt semantics clear.
- **Reader/configuration:** no command or SQL injection found in the UUID/integer arguments;
  execution uses argument arrays. Default downloads are in ignored `server/.feedback/`;
  an explicit `--out` can choose elsewhere and remains the operator's responsibility.
  `WT_SERVER_URL` reaches Info.plist, the documented xcconfig comment escape is correct,
  and an absent/invalid URL hides the row. Sample/failure/real-server seams are gated by
  `-uiTestReset` on production call paths. Multipart construction and typed error mapping
  agree with the server. Both screenshot caps are 5 × 1,024 × 1,024 bytes; the passing test
  verifies GPS and EXIF lens metadata removal. Both sides count message graphemes rather
  than UTF-16 units, although the UI cap boundary itself is not covered by a UI test.
- **Evidence accuracy:** ticket progress correctly distinguishes local implementation from
  deployment, phone verification, and deferred signed-in app wiring. Its deletion/counter
  and cleanup claims need the fixes above. README's introductory “later” feedback wording
  is stale; its endpoint section describes the implemented route. No production API calls,
  deployment/login/secret commands, phone or backup access, or desktop control were used.

Standards: 2 findings, highest P2. Spec: 3 findings, highest P1.

Verdict: not clear
