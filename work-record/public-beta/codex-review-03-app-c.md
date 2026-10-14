# Ticket 03 — app-half review, round 3

Reviewed `git diff 668c108..HEAD` on `ericlee4992/beta-03-deploy`, HEAD
`ee19a7cc0b4dc18893fed2c30ee9a12c4c19d22f`, against
`668c1082a2a1ef07464283d31529ff065e3df213`. The working tree was clean at review start.
Read the round-3 prompt, ticket's round-2 response, changed source/tests, and the existing
ProfileScreen → Settings outcome path. STATE remains an older handoff; Git and the supplied
artifacts establish the reviewed revision.

Only this report was modified. No builds, tests, simulators, devices or live-server requests were run.

## Standards

No new findings. Both round-2 P3 findings are resolved:

- The ticket now lists **“Loading…”** verbatim, matching
  `WorkoutTracker/Features/Account/ProfileSample.swift:139`.
- `WorkoutTracker/Features/Account/AccountStore.swift:43–49` distinguishes a failed initial
  load with no profile from a later failed refresh retaining cached data. The `superseded`
  comment also describes both replacement sessions and duplicate deletion calls.

The deletion coordination and regression test introduce no substantive standards violations
or warranted code-smell findings. Existing copy and accessibility identifiers are unchanged.

## Spec

No new P1–P3 findings. The round-2 P2 is resolved without reopening round-1 #4:

- **An ended session retains its deletion result.** At
  `WorkoutTracker/Features/Account/AccountStore.swift:235`, only a different, non-nil current
  token suppresses the outstanding deletion's outcome. A refresh's 401 clearing the original
  token no longer discards `pending`/`manual`; those still return `.deletedNeedsAppleStep`.
- **A newer session remains protected.** `forgetIfCurrent` at lines 253–254 clears only the
  token belonging to the deletion request. The different-token guard returns `.superseded`
  before any result-specific mutation. These operations run on the MainActor without another
  suspension between the guard and state update.
- **Only one DELETE is sent at a time.** Lines 227–229 set `deleting` before the network await,
  reject a duplicate call, and clear the flag with `defer` on completion, including supersession
  and failure.
- **The Apple follow-up reaches the surviving owner.** The unstructured task at
  `ProfileSample.swift:79` retains the deletion operation and its callback after the profile
  page closes. Lines 112–119 forward the terminal outcome to Settings; Settings owns the
  follow-up state and alerts at `SettingsView.swift:91–110`. A `.superseded` result still performs
  no callback or dismissal. This code path satisfies the Accounts requirement to provide the
  iOS Settings route when revocation is pending/manual.

The new deterministic test holds a `pending` deletion response, checks that a duplicate sends
no request, clears the session through refresh's 401, and verifies the eventual Apple-step
outcome and reset busy flag. The existing sign-out/sign-in race test remains complementary.

## Evidence inspected

Artifact root:

```text
/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-public-beta/0dc39eb1-054d-49da-bf79-784fabae4a4e/scratchpad/03/
```

- **`unit4.status`, `unit4.log`, `unit4.xcresult`:** `test=0`, `TEST SUCCEEDED`, **48 passed,
  zero failed or skipped**. Inspected the result summary and test tree: Account 20, Feedback 13,
  Onboarding 6, TrainingProfile 9. Both `aDeletionStillReportsWhenItsSessionEndsMeanwhile`
  and `aLateDeletionAnswerLeavesANewerSessionAlone` passed. The device tally of 51 includes
  the four argument cases of one parameterized test.
- **`mut2.log`:** the older replacement-session test passes; the new session-ended test fails
  exactly at its `.deletedNeedsAppleStep` expectation. The log records two tests with one issue.
  It has no normal final xcodebuild result marker; the ticket reports the hung command was
  stopped with exit 143. Treat this as a recorded test-level mutation failure, not a normally
  completed xcodebuild run. The reviewed source contains the restored non-nil/different-token
  rule, and the working tree was clean.
- **`git diff --check 668c108..HEAD`:** passed.

The focused unit verification fits this store-level change. No UI source changed this round;
the previous UI evidence remains `ui2` plus the successful `ui3` reruns, as documented in the
round-2 review. Delivery of the delayed outcome to Settings was traced in code, not newly
exercised in a UI run. Real Apple sign-in, rename/training save, sign-out, deletion and revocation
on the phone remain pending. This clearance covers the reviewed app implementation, not those
device acceptance checks or installation.

Standards: **0 findings**. Spec: **0 findings**.

Verdict: clear
