# Ticket 05 — independent Codex review

Reviewed 2026-10-03: `git diff d761301..5909fe2` on `ericlee4992/beta-05-profile`
(`5909fe2b73d5fa46210b5e2c42b507b19b0e6e8a`). The working tree was clean at review start.
Scope: the approved sample-only mock and the server implementation. Live account wiring, networking from the
app, and saving from Ask AI remain deferred to ticket 03's app half.

## Spec findings

1. **P2 — Inherited unit names pass validation, and a rejected combined PUT changes the name.**
   `server/src/training.ts:32`, `server/src/training.ts:35`, `server/src/index.ts:140`.
   `unit in units` accepts inherited properties such as `toString`, `constructor`, and `__proto__`.
   Multiplying a number by these inherited values produces `NaN`; neither bounds comparison rejects it.
   For example, send a valid display name and an otherwise valid training profile with
   `height: { value: 70, unit: "toString" }`. Validation succeeds, the name update commits, and the
   training insert fails the unit CHECK in `server/migrations/0005_training_profiles.sql:11`. The request
   returns an internal error while the name has changed, violating the promised both-or-nothing PUT.
   An isolated execution of the current validator confirmed that all three inherited keys are accepted;
   the partial-write consequence follows from the route's separate awaited writes and the SQL constraint.
   **Fix:** use an own-property allowlist and reject a nonfinite converted value. Put the name and training
   mutations in one D1 batch transaction so a storage failure also rolls both back. Add endpoint regressions
   for inherited unit names (400, unchanged name/training) and failure of the second write (no partial rename).

2. **P3 — The app displays valid fractional measurements as different values.**
   `WorkoutTracker/Domain/TrainingProfile.swift:57`,
   `WorkoutTracker/Features/Account/TrainingProfileEditor.swift:202`,
   `WorkoutTracker/Features/Account/TrainingProfileEditor.swift:226`.
   The server accepts and preserves decimals, and the new Swift JSON test explicitly uses `82.5 kg`, but
   `BodyMeasure.display` renders it as `83 kg`; `70.5 in` becomes `5 ft 11 in`. The editor's getters round
   these values too. This conflicts with the ticket's as-entered display promise and hides valid precision
   supported by the API. The current whole-number sample does not expose it, and no live user is affected
   at this mock stage. **Fix:** preserve fractional precision in profile formatting and the editor's draft
   fields, with tests for fractional metric and imperial values and an unrelated edit/save round trip.

## Standards and visual review

No additional blocking standards finding for this stage. Every new sample flag passes through
`WorkoutTrackerStore.isUITestReset`; normal launches omit the Account row, return the original empty
`AIRoutineFlowModel`, and omit the save-to-profile switch. There is no new app networking or SwiftData change.

Inspected all 50 committed PNGs: Settings signed in/out, profile with/without training, editor, and Ask AI,
Default and AccessibilityL, light and dark. Content remains readable across the scrolled captures, rows and
experience choices reflow, and the switch is on by default. The two large editor schedule figures are part
of the user's approval as shown; they are not a reason to reopen the accepted composition. The mock's inert
account actions and transient switch are within the expressly deferred wiring scope.

The server otherwise preserves entered units, handles absent/null training and optional measurements,
keeps name-only PUT compatible, prevents insertion after account deletion, and deletes training in the
account-deletion transaction. Numeric ranges and conversions agree with Ask AI. One validation difference
to reconcile when wiring: `TrainingProfile.isValid` accepts blank/control-character goals; the editor
separately rejects blanks, while the server rejects both. The current tests do not establish complete
client/server validation parity.

## Verification and record accuracy

- Independently ran `cd server && npx vitest run`: **190/190 passed**, 5 files, exit **0**.
- Independently ran `cd server && npx tsc --noEmit`: exit **0**.
- Read actual Xcode result summaries, logs, and status files under
  `/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-public-beta/e3a77fd4-c0ec-4e78-bfc8-95296943cde7/scratchpad/`:
  `prof-all.xcresult` / `prof-all.status`: **4/4 passed**, exit **0**;
  `reg05.xcresult` / `reg05.log` / `reg05.status`: **31/31 passed**, exit **0**
  (13 unit tests, 8 Ask AI UI tests, 10 Settings UI tests). Both identify WT-Onboarding. The regression
  result contains five invalid-frame runtime warnings but no failures; this review does not attribute
  those warnings to this diff. No new simulator run was needed to repeat this evidence.
- The recorded test scope is appropriate for the bounded mock changes. The added tests miss finding 1's
  inherited-key and storage-failure cases and finding 2's display precision. Reported mutation results
  were not independently rerun.
- Ticket Progress accurately distinguishes mock/server completion from deferred wiring. Minor record
  cleanup: its Acceptance boxes remain unchecked despite recorded captures and tests; link the result
  artifacts above. `server/README.md:5` still calls training profiles a later addition although its endpoint
  table documents the implemented API. `docs/STATE.md` predates this branch and still describes ticket 06.
  Refresh those records at the implementer's checkpoint; only this report was modified during review.

Verdict: not clear
