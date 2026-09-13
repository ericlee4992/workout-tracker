Independent cross-review. Everything under review was written by Claude agents; you are the second pair of eyes required by `docs/DECISIONS.md` T6 (solo project — this is the only independent check that exists). Be adversarial, not agreeable.

REVIEW THIS RANGE: `git diff 29e07b9...HEAD` — four commits:
  7a469b0  Add UI test target and core-loop walkthrough
  a33d13c  Docs: record the GitHub remote
  ea00903  Ticket 17 (active workout): loggable-set guard, carry-forward prefill, minimise
  739fc6c  Ticket 17 (history/gyms): discard empty workouts, editable gyms, real titles

THE SPEC: `work-record/milestone-2-core-loop/issues/17-dogfooding-fixes.md` — fifteen faults found by
driving the app. Every box is ticked; verify the code actually earns each tick. The two ticket-17
commits were written by two DIFFERENT agents working in parallel on separate file sets (active
workout vs history/gyms), so pay particular attention to seams between them.

BINDING CONTEXT: `docs/SPEC.md`, `docs/DECISIONS.md` (especially D9 as-entered display, D10 model
correction scoping, D18 drift prompt, D19 equipment freeze, D20/D21 records + volume, D22 rest
precedence, D23 snapshot-keyed history, D24 seeded rows read-only, D25 unit contract),
`CLAUDE.md` conventions.

Review along these axes:

A. **Regressions.** These commits changed load-bearing behaviour: set completion is now guarded,
   `finish()` can DELETE a workout, prefill has a new within-session path that competes with
   ticket 11's cross-workout prefill, and history titles/gym names moved to snapshot sources.
   Hunt for anything broken by those — especially interactions between the two parallel commits.

B. **Locked-decision violations.** Does any change contradict D9/D10/D18–D25? Two specific things
   to check hard: (1) the new carry-forward prefill must not fabricate logged data — a row may
   arrive populated but must never be completed without a user tap; (2) history rendering must
   still group/read by SNAPSHOT values, never live relationships, including the new title and the
   gym-name change in 739fc6c.

C. **The empty-workout deletion.** `finish()` now deletes when nothing survived cleanup. Is that
   safe in every path (cancel, stray auto-finish, minimise-then-finish, a workout whose only sets
   were un-completed)? Can it delete something a user would expect to keep? Is the caller's
   handling of a now-deleted object sound (no use-after-delete, no dangling sheet subject)?

D. **Test quality.** Several pre-existing tests were ADJUSTED to accommodate the new guard
   ("fixtures that completed empty sets now log weight+reps", "startWorkoutFinishesLingeringActives
   now logs a set", the walkthrough's History assertion). Verify each adjustment preserves the
   test's original intent rather than weakening it to fit the new code. Also: do the new tests
   actually pin the claimed behaviour, or would they pass against the old buggy code?

E. **What the fixes missed.** The fifteen faults came from one driving session. Reading this code
   as a critical first-time user, what else is wrong, awkward, or missing? Prefer concrete,
   reproducible problems over style opinions.

OUTPUT: Markdown to stdout. Section 1: per-item verdict on ticket 17's fifteen boxes
(earned / partially earned / not earned, with evidence). Section 2: new findings by severity
(Critical / Important / Minor). Section 3: one-line overall verdict — is this safe to dogfood in a
real gym session? Be terse. No praise.
