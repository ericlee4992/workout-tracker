# Ticket 07 — independent Codex review, round 3

Reviewed `git diff e593861..HEAD`, with earlier implementation context where needed,
on `ericlee4992/beta-07-feedback`, HEAD `c8e1234a5927cf80d95719caba0e6d2ac4244ec6`,
on 2026-10-03. Read the ticket's round 2 response and checked both fixes against
`codex-review-07b.md`. The working tree was clean before review. Only this report was changed.

Both round 2 findings are resolved. No blocking security, correctness, or design findings remain.

## Standards

Clear. Inspected all four `feedback-loading-*.png` captures in light/dark at Default
and AccessibilityL. The accessibility layout puts the spinner and Remove below the
label, with readable text and controls. The spinner is neutral, Remove retains its
destructive treatment and 44-point minimum hit region, and the loading state shows
Send disabled. The ticket records the user's 2026-10-03 approval of “Loading Screenshot…”.

`FeedbackSample.startsLoading` requires the loading flag, the sample flag, and
`-uiTestReset`. The fixture cannot activate in a normal launch from the loading flag
alone. It uses the actual attachment loader; Remove cancels it through the production
path. The capture tests now assert disabled Send while loading, then Add Screenshot's
return and enabled Send after Remove. The generation guard and picker reset remain intact.

## Spec

The server fixes are clear. One nonblocking documentation correction remains:

1. **P3 — Update the README's sweep statement count.**
   **Location:** `server/README.md:49–50`.
   The README still says “three D1 queries” per sweep. With exact-ID cleanup, a full
   1,000-job batch uses one read, ten deletes, and one counter-cleanup statement:
   **at most 12 D1 statements**. An operator assessing scheduled work would otherwise
   underestimate the remaining query budget. Update the sentence to 12 including
   counter cleanup, and optionally state the combined maximum of 33 with revocations.
   The implementation and ticket already use the correct bound; this stale description
   does not block clearance.

## Queue safety and test review

- `id INTEGER PRIMARY KEY AUTOINCREMENT` prevents reuse after the queue empties.
  Account deletion uses `INSERT OR REPLACE` without supplying an ID, so requeueing
  creates a new job identity instead of changing a previously read job in place.
- The sweep deletes only the IDs in its selected batch, with at most 100 bound
  parameters per statement. A concurrent insertion or replacement has a different
  ID and survives stale cleanup. A failed R2 delete leaves jobs queued; failed database
  cleanup also leaves retryable jobs, and repeated R2 deletion is idempotent.
- Upload queueing still precedes the put. Feedback insertion and removal of its upload
  job remain in one transaction; account deletion still queues keys in its deletion
  transaction. The existing one-hour upload grace is unchanged. The live-row check
  excludes live screenshots from the sweep's R2 call; replacement preserves a new
  deletion job if a key classified as live is deleted/requeued after the read.
- Work is bounded to 1,000 selected jobs and one R2 delete call per sweep. At most
  12 D1 statements for feedback plus 21 for the 20-item revocation loop gives **33**,
  within the intended 50-statement budget.
- The new tests cover both the empty-queue/repopulation interleaving and replacement
  of a previously read live key. The 2,501-job test verifies completion across three
  runs, including the last key, and a maximum of 12 prepared statements per run.
- Independently replayed the former race using production `sweepFeedback` and
  `deleteClaimedScreenshots`, the current migration in in-memory SQLite, and an R2
  test double. B received ID 2 after A's job was removed; B survived the first sweep
  and the next sweep deleted its object and job. No object remained.
- As a focused mutation check, the same local harness substituted broad due-time
  cleanup for exact-ID cleanup. B's job disappeared and its object remained after
  the next sweep, reproducing the old failure. This supports the ticket's mutation
  claim; I did not rerun the author's complete mutated Vitest suite or edit source.

## Independent verification

- `cd server && npx vitest run`: exit 0, **88/88 passed**, three files.
- `cd server && npx tsc --noEmit`: exit 0.
- Targeted `WorkoutTrackerTests/FeedbackTests` on WT-Onboarding
  (`2CEC4AD8-F702-421F-B3B2-D68C302A3453`): successful build, `xcodebuild` exit 0,
  **13/13 passed**, no skips/failures. Independently inspected the xcresult summary.
  Derived data: `/tmp/wt-beta07-codex`; result: `/tmp/wt-beta07-codex-round3.xcresult`;
  log: `/tmp/wt-beta07-codex-round3.log`.
- UI tests were inspected but not independently rerun; all four new loading captures
  were visually inspected. The ticket records the implementer's six passing UI tests
  and one skipped opt-in smoke test. Live PhotosPicker/VoiceOver and deployed services
  were not exercised in this review.
- No Cloudflare/Apple API calls, deploy/login/secret commands, phone or backup access,
  or desktop control were used. The local race/mutation harness ran from stdin and
  changed no repository source or tests.

Standards: clear. Spec: clear with one nonblocking P3 documentation correction.
This clears the reviewed implementation; it does not establish deployment, phone
verification, or the separately deferred signed-in app integration.

Verdict: clear
