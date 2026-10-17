# Ticket 13 — review of Claude's test changes

Reviewed `git diff 915b84e..3834135 -- WorkoutTrackerUITests/FloodlightAIRoutineUITests.swift` against the replacement
prompt, ticket acceptance criteria and "Claude after Codex's blocked report" entry. Inspected all nine committed
captures. HEAD `6f1cb2c` adds only the review prompt after `3834135`. No simulator tests or network calls were made;
the 7/7 and 57/57 results are recorded evidence from Claude, not independently rerun results.

Product-code confirmation: `git diff 915b84e..3834135 -- WorkoutTracker` is empty. AIGoalsStep has identical blob
`3165c9a423683280fbe0463609dc58e5afa9e48e` at both commits. This review assesses Claude's test edits, not independent
clearance of my own product implementation.

1. **P2 — The midpoint assertion permits substantially more occlusion than the evidence supports.**
   **Location:** `WorkoutTrackerUITests/FloodlightAIRoutineUITests.swift:99–100` (`assertFieldAboveDone`).
   The ticket explains a three-point edge overlap, but replacing `maxY` with `midY` permits nearly half the field
   below Done's top: almost 22 points for a 44-point field, more for a taller accessibility field. Hittability does
   not establish that the entered value is fully visible. This no longer proves the explicit requirement that
   focused height/weight stay above Done. The captures do not justify that relaxation: light/default Weight is
   clipped by the accessory strip, and dark/default and dark/AccessibilityL Weight are behind the number pad.
   Baseline parity can establish that a symptom predates this change; it cannot establish that the symptom is
   harmless or only a screenshot artifact. **Correction:** compare the field's bottom with the actual accessory
   boundary using a narrowly evidenced decoration allowance, or check the text-entry bounds. Keep focused-field
   visibility unresolved until reliable visual evidence establishes it; do not substitute a midpoint pass for that
   acceptance criterion.

2. **P2 — The new keyboard-settling wait silently succeeds when its condition never becomes true.**
   **Location:** `WorkoutTrackerUITests/FloodlightAIRoutineUITests.swift:85–88`, together with the removed
   keyboard-relative Next assertion at the former line 53.
   After 15 unsuccessful polls, the helper merely sleeps another 0.4 seconds and returns. Its earlier checks prove
   that keys exist and the reported keyboard is tall, not that it has entered the viewport. Consequently the
   previously observed off-screen keyboard frame can still pass this helper, and no subsequent Next check rejects
   it. Comparing Next with its resting Y correctly tests that Next does not rise, but does not prove the keyboard
   covers it. The committed Goals captures still include absent or only partly visible keyboards, so they do not
   supply that missing guarantee. **Correction:** use a bounded expectation whose timeout fails, assert that the
   settled keyboard/key bounds intersect the visible screen, and then check Next's relationship to that settled
   keyboard (retaining the resting-position assertion). A fixed sleep is not a successful settlement condition.

The other changes are reasonable harness corrections: allowing 64 points accommodates the recorded 52-point
suggestion-strip offset while retaining an above-keyboard bound; scrolling to Weight avoids the minutes control;
full-screen screenshots are appropriate for capturing another window. They do not resolve the documented
AX/rendering disagreement. The tests still exercise Return dismissal without a newline, a unique hittable Done
that dismisses editing, and Next's unchanged position followed by successful navigation after dismissal. They do
not yet establish all the requested visible-keyboard and focused-field guarantees. No separate style/smell finding
was identified in the standards pass; the two findings concern specification and verification coverage.

Verdict: not clear
