# Ticket 05 — independent Codex review, round 2

Reviewed 2026-10-03: `git diff 5909fe2..3c86d78` on `ericlee4992/beta-05-profile`
(`3c86d78d6945f79e29ea19746c76e476aa881567`). Working tree clean at review start.
Scope remains the approved sample-only mock and server side; live app wiring is deferred.

## Spec findings

1. **P2 — Replacing feet silently loses the inches still displayed in the editor.**
   `WorkoutTracker/Features/Account/TrainingProfileEditor.swift:207–208`, `:243–257`.
   In the sample's U.S. customary editor, start with **5 ft 10 in**, erase the feet value, and type **6**.
   Erasing sets `draft.height` to nil. Typing 6 then obtains the sibling inches from that nil draft, defaults
   them to zero, and stores 72 inches. The inches field retains its independent `@State` text **10** because
   its new `initial` value does not update existing state. Thus the editor shows **6 ft 10 in**, Save is
   enabled, and the page receives **6 ft 0 in**. This is a new consequence of retaining each field's text
   separately while deriving its sibling from the combined numeric draft.
   **Fix:** keep the feet and inches text together in the editor's staged state and derive the measurement
   from both current strings. Preserve the other component during clearing/replacement; decide validity
   from the complete pair. Add UI coverage for replacing feet while retaining fractional inches, replacing
   inches while retaining feet, and clearing both fields.

2. **P2 — The retained text can show a different number from the value Save commits.**
   `WorkoutTracker/Domain/TrainingProfile.swift:78–82`,
   `WorkoutTracker/Features/Account/TrainingProfileEditor.swift:213`, `:273`.
   Typing **82.567** in Weight leaves **82.567** visible, but `parse` silently truncates it to **82.56**;
   Save accepts that value. Similarly, entering **12** in the inches field leaves **12** visible but saves
   **11.99** inches. Keeping raw text has hidden the parser's truncation and the height callback's clamp.
   The unit test currently asserts the truncation, and the new UI test covers only a one-decimal value.
   Round 1's display issue also remains for server-valid values beyond two decimals:
   `BodyMeasure(value: 82.567, unit: .kg).display` rounds to **82.57 kg** at `TrainingProfile.swift:73`.
   **Fix:** make accepted precision and ranges explicit and keep displayed and committed values consistent.
   Preserve supported input exactly; reject unsupported precision/ranges and disable Save rather than
   silently changing them, or visibly normalize before commitment. Preserve the precision of values already
   accepted by the server. Test excess precision, out-of-range inches, and a fractional server value
   followed by an unrelated edit/save.

These are source-traced failure scenarios; this review did not modify tests or run additional UI interactions.
They affect the mock editor, which remains inaccessible in a normal launch.

## Standards and resolved server finding

Round 1 finding 1 is resolved. `Map.get` excludes inherited property names and the finite check rejects
nonfinite converted amounts. Validation precedes one D1 batch containing both mutations; the new constraint
failure test verifies rollback of the name and training changes. The conditional INSERT still checks that
the account exists. If deletion wins before a non-null training save, its zero change count produces **401**
at `server/src/index.ts:146–147`; the batch cannot recreate the account or its training row. Name-only PUT
compatibility is preserved.

Coverage limit: the existing deletion-race test invokes `writeTraining` directly, so it does not exercise the
route's new zero-change-to-401 branch. Add an endpoint race case when touching that branch. Name-only and
`training: null` requests can still return 200 if deletion wins after authentication; this predates the fix,
creates no data, and is not a new finding in this round.

`TrainingProfile.isValid` now checks trimmed nonblank goals, the prohibited ASCII control characters, and
the grapheme limit, addressing the ordinary validation differences noted in round 1. Numeric bounds and
unit conversion remain aligned. No new gating, persistence, networking, or visual composition change was
introduced. Existing whole-number captures remain applicable to the unchanged captured states.

## Verification and record accuracy

- Independently ran `cd server && npx vitest run`: **195/195 passed**, 5 files, exit **0**.
- Independently ran `cd server && npx tsc --noEmit`: exit **0**.
- Inspected the actual `tp2.xcresult` and `prof-dec.xcresult` summaries and their `.log` files under
  `/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-public-beta/e3a77fd4-c0ec-4e78-bfc8-95296943cde7/scratchpad/`:
  **TrainingProfileTests 5/5** and **decimal-weight UI test 1/1**, both Passed, no skips or runtime warnings,
  both on WT-Onboarding. Both logs end with `TEST SUCCEEDED`. These are the implementer's recorded runs;
  this review did not rerun the simulator suites or mutations.
- The weight UI regression proves `82.5` survives typing and saving. It does not cover coupled height fields
  or text that differs from the parsed value. Those are the focused regression gaps for findings 1 and 2;
  a full UI suite is unnecessary.
- README's stale introduction is corrected. Ticket and STATE now identify the mock/server stage and deferred
  wiring. Minor cleanup remains: the ticket says acceptance boxes were checked, but the targeted-tests box
  remains unchecked; its new run evidence lacks the artifact paths above. STATE still says “nothing unmerged
  holds work” while identifying this unmerged ticket branch. The ticket's “no rounding” claim is not yet true
  for all accepted values, as finding 2 explains.

Verdict: not clear
