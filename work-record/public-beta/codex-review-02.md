# Ticket 02 — independent Codex review

Reviewed `git diff main..HEAD` on `ericlee4992/beta-02-onboarding`: base
`68e2a99186060bd9840024fd0afbbb4236f7d80f`, HEAD
`8a2bbbcd37829896fc650d9943c17e890044a51d`. The working tree was clean before this report.
Read AGENTS, the ticket and its revised choices/isolation design, public-beta Onboarding/Q8b,
D60, ios-design SKILL/REFERENCE/REVIEW, and DEVELOPMENT's verification policy. Standards and
spec received separate review passes. Findings below are source findings except the expressly
identified capture evidence; this review did not launch the app or run new tests.

## Standards

1. **P1 — The underlying app remains actionable through accessibility.**

   **Location:** `WorkoutTracker/App/RootView.swift:69`; also
   `WorkoutTracker/Features/Onboarding/Tour.swift:117`, `:165`, `:195`.

   **Failure:** The TabView receives an overlay, but its controls remain enabled and exposed to
   accessibility. Focusing the caption and using `.accessibilityElement(children: .contain)` do
   not restrict VoiceOver to the tour. The only elements hidden from accessibility are the
   dimmer, highlight and illustration. VoiceOver can navigate to the underlying **Start
   Lifting**, **Start Cardio**, **Ask AI**, or **Settings** and activate their actions without
   performing the coordinate tap that the overlay intercepts. Hardware accessibility focus is
   likewise not excluded. This violates the ticket's point-only isolation contract and
   ios-design's accessible navigation requirement.

   The Start Lifting path is concrete: `StartWorkoutView.swift:194` sets `startRequest`,
   `WorkoutStartFlow.swift:80` starts a sample workout, and `RootView.swift:81` presents its
   full-screen cover **above** the overlay. `ActiveWorkoutView.swift:391` then calls the shared
   heart-rate coordinator and pushes the Live Activity. Production side-effect providers are
   still selected because this is not `-uiTestReset`. Settings also exposes real per-device
   preferences and credentials. The in-memory store does not contain these effects. Minimizing
   an escaped sample workout and skipping the tour can leave its shared runtime alive after
   the coordinator drops the sample container.

   **Suggested fix:** Disable input and hide the underlying app subtree from accessibility
   for the entire tour, with the tour controls outside that disabled subtree. Make the caption
   and navigation the accessible modal content. Verify VoiceOver traversal/activation and Full
   Keyboard Access, including that no live screen, settings page, sheet or menu opens. Assert
   zero system-service calls with injected spies; `-uiTestReset` alone masks those calls.

2. **P2 — Next/Done and Skip Tour do not give their labels the required hit region.**

   **Location:** `WorkoutTracker/Features/Onboarding/Tour.swift:172–184`.

   **Failure:** Both controls use the string-label Button initializer, then apply the 44-point
   frame outside the Button. Next's padding and painted capsule are also outside its label.
   This enlarges layout/appearance without making the label's whole apparent button region
   interactive. At default text size, taps near the capsule's edges or above/below Skip Tour's
   text can miss, contrary to ios-design's minimum 44-point hit-region rule. Existing tests tap
   the center, which does not check this. This is a static finding; edge-coordinate activation
   has not been reproduced in this review.

   **Suggested fix:** Use explicit labels with padding, the minimum frame and `contentShape`
   inside the Button, as WelcomeView already does for Skip, or use the established button
   component/style. Check activation near all four edges at default size and AccessibilityL.

3. **P3 — The History highlight crosses the tab bar at AccessibilityL.**

   **Location:** `WorkoutTracker/Features/History/HistoryView.swift:168–169`.

   **Failure:** The tour anchors the first row without scrolling it clear of the tab bar.
   `work-record/public-beta/captures/02/tour-s6-dark-AXL.png`, inspected directly, shows the
   outline crossing the tab icons and part of the row behind the bar. The caption and row text
   remain readable; this is a safe-area/composition defect, not demonstrated text loss. The
   ticket records it as known, but does not record an accepted design exception.

   **Suggested fix:** Add a tour-only History scroll hook that positions the complete target
   above the tab bar and leaves room for the caption. Retake the same default/AccessibilityL
   captures after the change.

## Spec

4. **P1 — Touch isolation fails open when the current anchor has no geometry.**

   **Location:** `WorkoutTracker/Features/Onboarding/Tour.swift:112`.

   **Failure:** Q8b requires that the tester's “own store and system state are never touched.”
   The entire overlay, including its input shield, exists only when
   `tour.frames[step.anchor]` exists. A new controller starts with an empty dictionary; the
   first visit to another tab also needs that tab's layout callback to supply its frame. In
   the missing-frame state, the enabled sample app has no shield at all. A tap delivered then
   can execute a real control action; a missing/offscreen anchor can prolong the state. This
   is independent of accessibility activation in finding 1: hiding accessibility elements
   alone would still leave this touch path open. The exact transition timing was not measured
   at runtime; the fail-open branch is explicit in the source.

   **Suggested fix:** Keep an interaction barrier for the complete lifetime of the tour,
   independent of geometry. Geometry should only position the highlight/caption. Provide a
   safe waiting state with Skip if a target is unavailable. Add checks with empty/missing
   frames and during first entry to each tab; assert that attempts to activate Start, Settings,
   AI and navigation cannot escape.

## Verification and remaining limits

- Inspected all three `welcome-tour-*` sheets and the full-size History AccessibilityL capture.
  The welcome/captions are readable in the supplied states. The new step/scroll animations
  honor Reduce Motion in source; no runtime Reduce Motion or VoiceOver session was performed.
- The welcome predicate, opt-in `-uiTestOnboarding`, and reset-scoped
  `-uiTestOnboardingFresh` are consistent. Every UI-test source file that directly launches
  the app contains `-uiTestReset`. `launchVariants: true` preserves the old fixture flag
  expressions; false excludes the live/extra variants. Normal tour construction uses an
  in-memory container, finished sample workouts and a weak completion closure. Root recovery
  is guarded, and the real root is rebuilt on the original container after normal completion.
  No additional non-tour behavior regression was established in the anchor/scroll changes.
- Settings' Show Tour and refusal alert are wired. The refusal uses mutating
  `resumableWorkout()` and treats fetch errors as no active workout. A read-only, fail-closed
  check would better uphold the contract. This is not a separate finding: ordinary root
  recovery already reconciles stray active workouts before Settings is reachable.
- Traced the Live Activity intent bridge: it retains the real container, but commands require
  an unfinished real workout, which normal tour entry refuses. No independent deep-link,
  scene-restoration, Siri or background entry that starts a sample workout was found. After
  the interaction escape in finding 1, however, the live screen's existing background/runtime
  behavior applies. No claim of hardware validation or runtime leak testing is made.
- Independently read the saved `t1.xcresult`, `adj.xcresult`, `re.xcresult`, `main.xcresult`,
  their logs, and the available exit files under
  `/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-public-beta/d61f90bf-e3f8-44b7-845e-3831238bedab/scratchpad/b02/`.
  All result bundles name **WT-Onboarding / 2CEC4AD8-F702-421F-B3B2-D68C302A3453**.
  `t1` reports 13/13 (6 unit + 7 UI) and `TEST SUCCEEDED`; `build3.log` reports
  `BUILD SUCCEEDED`. Separate success exit files were not retained for those two runs.
  The adjacent run reports 930 unit + 57/60 UI, with actual exit **65**. The focused rerun
  has two failures/one pass. The separate main-run log and bundle have the same three failures:
  CoreLoop model picker at line 274, History dark/light chart assertion at line 100; its exit
  file is also **65**. This supports the ticket's pre-existing-failure attribution; the
  removed temporary main checkout's exact HEAD cannot be independently reread now.
- Targeted adjacent coverage is appropriate under DEVELOPMENT; a blanket full-suite rerun is
  not the missing gate. The missing checks are interaction/accessibility containment, missing
  geometry, real-service isolation, button edges, and the active-workout refusal UI. The
  existing “blocks every other tap” test checks only two coordinates after layout settles.
  The unit store-preservation test constructs a sample container; it does not exercise an
  interacting tour or prove that system services remain untouched.

Standards: 3 findings, highest P1. Spec: 1 additional finding, P1. Only this report was written;
no phone, Apple account, backup, application or test state was changed by this review.

Verdict: not clear
