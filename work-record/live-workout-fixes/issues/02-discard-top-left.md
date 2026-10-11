# 02 — Cancel workout at the top left

Type: task
Status: **Codex clear (round 2)**; merged to `main` with ticket 01 at the user's go-ahead (2026-10-10)
Blocked by: —
Implementer: Claude; Reviewer: Codex (visible Orca terminal), to "clear".
Branch: `ericlee4992/live-02-discard-top-left` off `main`.
Decisions: vetoes the D59 item "Discard moved to 'Discard Workout…' at the end of the live list" (it was adopted as
implemented and open to veto); SPEC's live-workout paragraph updated.

## Request (the user, 2026-10-10)

"For cancel workout, I'd rather just have it at top left."

## Decision (the user, 2026-10-10, from three options)

**Chevron + Cancel.** The minimize chevron stays at the top left (C1: leaving keeps the workout running); a red
**Cancel** sits beside it in its own toolbar capsule (`ToolbarSpacer(.fixed)`), and "Discard Workout…" is removed
from the end of the list. The confirmation dialog is unchanged ("Cancel this workout?" → Discard Workout / Keep
Logging). Rejected: Cancel alone with the chevron moved right; a trash icon.

## Change

- `ActiveWorkoutView.swift`: the `DestructiveRowButton("Discard Workout…")` row is gone; a `topBarLeading`
  `Button("Cancel")` in `look.destructive` sets `confirmingCancel`. Identifier `discardWorkout` kept (VoiceOver label
  "Cancel workout"). The add block, now the list's last row, takes the 28 pt end spacing the discard row had.
- `LiveWorkoutHelpers.discardActiveWorkout()` no longer scrolls to the end; it taps the toolbar button.

- **At accessibility text sizes** the button is a red trash symbol instead of the word: with "Cancel" the title was
  cut to "Push D…" at AccessibilityL ([superseded capture](../captures/02/superseded-live-fixes-02-cancel-light-axl-truncated-title.png)),
  which the design rules forbid ("nothing the user needs truncates"). Claude's call within the user's choice; the user
  sees it before merge.

**New strings:** "Cancel" (visible), "Cancel workout" (VoiceOver). Removed: "Discard Workout…".

## Design (ios-design steps 1–4)

- *In the logging state this screen exists so the user can log the next set in one tap; the eye lands on the next
  set's check.* Cancel is chrome: a plain text button in the destructive colour, never filled; Finish stays the
  bold trailing command. The primary role never destroys (Cancel is leading, destructive-coloured, confirmed).
- Wireframe (agreed with the user):
  ```
  ⌄ | Cancel     Push Day ✎      Finish
  ─────────────────────────────────────
    exercises … add block (end of list; no Discard row)
  ```
- Tells: all absent. Risk to check in the captures: a long workout title between two leading items and Finish
  (the title scales to 0.8 and truncates to one line).

## Verification scope (layout within one screen + a moved command)

Build; the tests that discard through the helper — `CoreLoopUITests/testSwipeToDeleteRemovesASetAndLeavesTheExerciseIntact`,
`CoreLoopUITests/testMinimizeKeepsTheWorkoutActiveAndResumeReopensIt`, `HeartRateUITests` (its discard case);
`FloodlightLiveUITests` live captures (the nav bar at default and AccessibilityL, light and dark).

## Evidence

- **Targeted UI run 1** (code before the accessibility-size symbol): exit 0, `** TEST SUCCEEDED **`, Passed 8/0/0 on
  WT-Floodlight (`9E822EF6…`, iOS 27.0). Its AccessibilityL capture showed the truncated title → the symbol.
- **Targeted UI run 2** on the final code (same 8 tests: the 2 CoreLoop, the 3 HeartRate discard cases, the 3 live
  captures): `xcodebuild test` exit 0, `** TEST SUCCEEDED **`, xcresult **Passed, 8 passed / 0 failed / 0 skipped**
  (`…/scratchpad/live02/r2.xcresult`, `r2.log`, `r2.status`; session scratchpad, ephemeral).
- **Captures** looked at: [light default](../captures/02/live-fixes-02-cancel-light-default.png) and
  [dark default](../captures/02/live-fixes-02-cancel-dark-default.png) — `⌄ | Cancel   Push Day ✎   Finish`, Cancel in
  the destructive colour in its own capsule, the title whole; [light AccessibilityL](../captures/02/live-fixes-02-cancel-light-axl.png)
  — `⌄ | 🗑   Push Day ✎   Finish`, title whole. Not captured: the confirmation dialog (unchanged).

## Codex review 02 — response (round 1)

Review: [codex-review-02.md](../codex-review-02.md) — not clear (1 P2, 1 P3); no correctness regression found; ticket
01's advisory test tweak confirmed.

1. **P2 — the trash symbol at accessibility sizes is the option the user rejected.** Accepted that this is the user's
   call, not Claude's. Asked the user 2026-10-10: keep the symbol at accessibility sizes, or keep the word "Cancel"
   there too (the title then truncates, "Push D…", at AccessibilityL; the full name stays reachable by tapping it to
   rename). Codex's other route — reflowing the title onto its own line — is a larger layout change, offered if the
   user wants neither. Codex's layout advice (longer titles can truncate at the default size too, now that two
   leading items share the bar) went to the user with the same question.
   **The user, 2026-10-10:** "merge both fixes into the build" — the reply to that message, which asked the
   symbol question and whether to merge; taken as accepting the build as it stands: the word "Cancel" at default
   sizes, the red trash symbol at accessibility sizes (an explicit exception to "Chevron + Cancel", recorded here
   and in SPEC). A truncated long title at the default size is accepted with it; the full name stays reachable by
   tapping the title to rename. Claude's reply tells the user it read the message this way, so they can still
   ask for the word at all sizes.
2. **P3 — the list end was not captured.** Added `FloodlightLiveUITests/testCaptureListEndLight` and
   `…LightAccessibility` (scroll to the end; assert Add Cardio is hittable above the rest slab and no "Discard
   Workout…" exists): exit 0, `** TEST SUCCEEDED **`, xcresult **Passed 2/0/0** (`…/scratchpad/live02/r3.xcresult`).
   Captures: [default](../captures/02/live-fixes-02-list-end-light-default.png),
   [AccessibilityL](../captures/02/live-fixes-02-list-end-light-axl.png) — the add block ends the list, clear of the
   rest slab, at both sizes.
- The stale comment Codex noted (`FinalLook.swift:12`, "Discard Workout…" at the end) is corrected.

## Codex review 02b — clear; combined verification

[codex-review-02b.md](../codex-review-02b.md): clear, no new findings; the rebase conflict (both tickets' test
additions in `FloodlightLiveUITests.swift`) kept both. **Combined targeted run** of tickets 01 + 02 after the rebase
(FloodlightLiveUITests, CoreLoopUITests, BarbellUITests, HeartRateUITests on WT-Floodlight `9E822EF6…`, iOS 27.0):
`xcodebuild test` exit 0, `** TEST SUCCEEDED **`, xcresult **Passed, 32 passed / 0 failed / 0 skipped**
(`…/scratchpad/merge/combined.xcresult`; session scratchpad, ephemeral). The user said to merge both into the build
they install with the re-sign.
