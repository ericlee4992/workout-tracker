# Ticket 03 — app-half review, round 2

Reviewed `git diff 37a4600..HEAD` on `ericlee4992/beta-03-deploy`, HEAD
`668c1082a2a1ef07464283d31529ff065e3df213`, against
`37a46007cc5a1666592eaca8b120d324c9c923ec`. The working tree was clean at review start.
Read the round-2 prompt, ticket's round-1 response, changed code/tests/documentation, and the
previous report. Checked the deletion interleaving against the unchanged server implementation.
STATE remains an older handoff; the branch, source and supplied artifacts establish this review's scope.

Only this report was modified. No builds, tests, simulators, devices or live-server requests were run.

## Standards

Prior **S1 is resolved**: `AccountStore.swift:21–38` distinguishes deletion-related sign-out from
ordinary failure and documents the UI-test sample exception.

1. **P3 — List the new loading copy.**
   `WorkoutTracker/Features/Account/ProfileSample.swift:139` introduces **“Loading…”**, but the
   ticket's round-1 response lists only “a progress line while loading,” without its actual text.
   Add the literal to the new-string inventory requested by the user. The other newly introduced
   messages and controls are listed.

2. **P3 — Describe cached-profile failures accurately.**
   `WorkoutTracker/Features/Account/AccountStore.swift:43–46` says the profile is nil “after a failed
   load” and describes `loadFailed` as the last profile load failing. At lines 153–156, a failed
   refresh deliberately retains an existing profile and sets `loadFailed` only when no profile
   exists. Clarify that this flag means loading failed **without a usable cached profile**, and
   that an unsuccessful refresh can retain the previous profile. AGENTS.md explicitly requires
   comments to agree with their callers and implementation.

The DEVELOPMENT change records the user-approved parallel UI convention, preserves serial unit
testing, and requires unique artifact paths. Existing identifiers are retained; the unavailable
page's commands have identifiers. Sample stores remain isolated from the account server/keychain.
No additional code-smell finding is warranted.

## Spec

1. **P2 — A 401 caused by the phone's own deletion can suppress the required Apple follow-up.**
   `WorkoutTracker/Features/Account/AccountStore.swift:227` treats every cleared token as a
   superseded deletion, and `WorkoutTracker/Features/Account/ProfileSample.swift:116` discards
   that outcome without showing anything.

   A concrete interleaving permitted by the current UI and server is:

   1. DELETE A claims the account and removes its sessions, then waits for Apple revocation
      (`server/src/index.ts:75–81`; session removal is in `server/src/store.ts`'s `claimDeletion`).
   2. Delete remains enabled (`ProfileView.swift:35–40`, `ProfileSample.swift:79`). A second
      confirmed DELETE B authenticates after the claim and receives 401. Its completion calls
      `forget()` at `AccountStore.swift:232–234`. An overlapping profile refresh can likewise
      clear the token at lines 151–152.
   3. A subsequently returns `appleRevocation: "pending"`. Its captured token no longer equals
      the now-nil current token, so it returns `.superseded`; Settings never receives the Apple
      Settings instruction. B's “You've been signed out” explanation does not supply that step.

   Spec → Accounts requires that the app “shows the user at once how to stop Sign in with Apple
   themselves”; the server contract makes this mandatory for `pending` as well as `manual`.
   Distinguish an intentional session replacement from invalidation while this deletion is in
   progress, or coordinate those operations so the winning deletion can deliver its follow-up.
   Preserve the new protection against touching a genuinely newer session. Add a deterministic
   test holding A's `pending` response while a second request invalidates the old token, then
   verify that the follow-up reaches its surviving UI owner. The current replacement-session
   test exercises explicit sign-out/sign-in and a `done` response, not this case.

This is a code-traced interleaving, not a newly executed reproduction.

### Round-1 resolution check

| Finding | Round-2 assessment |
|---|---|
| #1 Feedback disclosure | Resolved in the production path: `SettingsView.swift:116–119` derives details and bearer from the same observable store; the account line has a signed-in fallback before profile loading. |
| #2 Feedback 401 | Resolved: 401 remains typed, the sender invokes `onUnauthorized`, and `invalidate(token:)` forgets only the matching session. Rebuilding the sheet inputs supplies the signed-out footer and sender while preserving its draft state. |
| #3 Offline Sign Out reachability | Resolved: any signed-in token opens ProfileScreen; its unavailable state exposes Try Again and Sign Out. Profile success no longer depends on usage success. |
| #4 Late deletion clearing a replacement token | The original defect is resolved by the guard and `.superseded` UI branch. The distinct regression above remains. |
| #5 Deletion 401 explanation owner | Resolved in code: `.signedOut` is handed to Settings, which owns the explanation after the page closes; it is not labeled Account Deleted. |
| #6 Mixed refresh failures | Resolved: profile and usage are captured as separate Results, with a 401 from either checked before applying data or transient-failure behavior. |

The new unavailable-page flag remains conditional on `-uiTestReset`; its store has no client and
uses a no-op token slot. The feedback test fixture still substitutes its own disclosure/stub, so
sample screenshots alone do not validate production footer/bearer rebuilding after a 401.

## Evidence inspected

Artifact root:

```text
/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-public-beta/0dc39eb1-054d-49da-bf79-784fabae4a4e/scratchpad/03/
```

- **`unit3.status`, `unit3.log`, `unit3.xcresult`:** exit `test=0`, `TEST SUCCEEDED`, **47 passed,
  zero failed**. Inspected the test tree: Account 19, Feedback 13, Onboarding 6, TrainingProfile 9;
  the four newly added Account cases passed. The device tally of 50 includes the four argument
  cases of one parameterized test. Ignored `unit2.*` as instructed.
- **`mut.log`:** the replacement-session test failed with the two reported expectations
  (`outcome == .superseded` and preservation of the new token), ending `TEST FAILED`. This supports
  the guard's value for that scenario; the log does not exercise the interleaving found above.
- **`ui2.status`, `ui2.log`, `ui2.xcresult`:** exit `test=65`; **34 passed, 3 failed, 1 skipped**.
  The failures were Account dark AccessibilityL (termination/launch failure, with Mach error -308
  in the log), the twelve-inch height validation case, and Settings light AccessibilityL navigation.
- **`ui3.status`, `ui3.log`, `ui3.xcresult`:** exit `test=0`, `TEST SUCCEEDED`, **3/3 passed**;
  its test tree confirms these are exactly the three failed cases from `ui2`. Together the runs
  cover all 37 non-opt-in cases successfully, including the unavailable-page capture/sign-out
  assertions. The initial failures remain recorded; passing reruns alone do not prove their causes.
- **`git diff --check 37a4600..HEAD`:** passed.

The supplied targeted scope fits DEVELOPMENT. The new tests verify store invalidation and error
mapping separately; they do not execute the full production feedback 401 → footer/sender rebuild
→ signed-out retry path, nor the real deletion 401 presentation transition. Those remain evidence
limits rather than additional demonstrated defects. Real Apple sign-in, rename/training save,
sign-out, deletion and revocation on the phone remain pending as previously recorded.

Standards: **2 findings, highest P3**. Spec: **1 finding, P2**.

Verdict: not clear
