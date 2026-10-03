# Ticket 05 — independent Codex review, round 3

Reviewed 2026-10-03: `git diff 3c86d78..600561b` on `ericlee4992/beta-05-profile`
(`600561b6ff1ac7db638e2273f4658fbac1f5b94b`). Working tree clean at review start.
Scope: the approved sample-only mock and server implementation. Live app wiring remains deferred.

## Findings

No P0–P3 findings requiring changes in this stage. Both round-2 findings are resolved.

## Spec review

- **Coupled height input:** `MeasureDraft` reads the current feet and inches strings together. Clearing or
  replacing feet no longer discards the inches shown. Clearing both produces an explicitly absent height;
  invalid text produces a distinct invalid result. The editor uses these same staged measurements for
  validation and Save.
- **Strict numeric input:** `TypedNumber` rejects excess precision, extra separators, negative numbers,
  and excess digits. Twelve inches is rejected rather than clamped or carried. Intermediate text such as
  `82.` remains editable but cannot be saved. A measurement whose text is unchanged returns its original
  stored value, preserving precision during unrelated edits.
- **Editor semantics:** invalid measurement syntax prevents creation of a staged profile and disables Save;
  the profile validator additionally enforces the physical bounds. Invalid syntax receives the destructive
  text colour and an accessibility value describing the problem. Save rechecks validity. Changed or invalid
  staged content prevents interactive dismissal, while Cancel remains available without committing.
- **Server race coverage:** the new endpoint test deletes the account after authentication and before the
  real D1 batch, then verifies 401 and zero account/training rows. Deletion uses the original harness rather
  than the proxy, so the test does not recursively intercept itself. Production server code is unchanged
  from the cleared Map/finite-check/atomic-batch fix.

Precision scope is now explicit: new entries accept up to two decimals; display shows up to six decimals;
unchanged stored measurements retain the original value. This clears the reported practical precision cases
for the mock. It is not a claim that display reproduces arbitrary Double precision.

## Standards and tests

No additional standards finding. The parsing and combined measurement logic live in Domain without UI
imports. The editor binds directly to that staged text instead of keeping disconnected field state. Mock
gating, normal-launch behavior, networking, and persistence boundaries are unchanged.

The added unit tests cover strict parsing, sibling preservation, invalid inches, clearing, stored precision,
and default units. The UI tests exercise replacement and clearing through the real editor. The helper's
trailing-edge tap fixes the cursor placement problem for these short fixtures; the replacement test checks
both visible fields and the saved page value, so it cannot pass by merely enabling Save.

## Verification and records

- Independently ran `cd server && npx vitest run`: **196/196 passed**, 5 files, exit **0**.
- Independently ran `cd server && npx tsc --noEmit`: exit **0**.
- Independently inspected the actual result bundles and logs under
  `/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-public-beta/e3a77fd4-c0ec-4e78-bfc8-95296943cde7/scratchpad/`:
  - `prof2.xcresult`, `prof2.log`, `prof2.status`: **9/9 unit tests passed** and **5/7 UI tests passed**;
    the two new editor tests failed, with overall exit **65**. The four capture tests and decimal-weight
    test passed. This was not a wholly successful run.
  - `dbg2.xcresult`, `dbg2.log`: after the helper fix, **3/3 editor UI tests passed**, no skips or runtime
    warnings; the log ends with `TEST SUCCEEDED`. These include both previously failing cases.
  Both bundles identify WT-Onboarding. This review inspected the recorded simulator runs rather than
  repeating them. The earlier 18/18 Ask AI and Settings regression evidence remains applicable.
- `git diff --check 3c86d78..HEAD` passed. The targeted scope covers these changes; no full UI suite is needed.
- The ticket accurately distinguishes failed initial tests from successful reruns, and STATE now identifies
  this branch as holding the unmerged ticket work. README's corrected scope remains accurate. Captured
  whole-number states retain their approved composition. Live prefill/save wiring remains unchecked and
  explicitly deferred; this clearance does not close that work or authorize a merge/deploy/install.

Only this report was modified during review.

Verdict: clear
