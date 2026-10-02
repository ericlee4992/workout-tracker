# Ticket 02 — independent Codex review, round 2

Reviewed `git diff 8a2bbbc..HEAD` on `ericlee4992/beta-02-onboarding`, HEAD
`961905736253a9b93f019065248524ff7507af18`. The implementation fix is `2dcca74`;
`f4c08d4` and `9619057` add/update the review prompt, excluded from the product review.
The working tree was clean before this report. Read the round-1 report, the ticket's
“Codex review 02 — response (round 1)” and final evidence, Q8b/Onboarding, D60,
AGENTS, DEVELOPMENT's verification policy, and the ios-design checklist/reference.
Standards and spec received separate review passes.

## Round-1 findings

### Standards

1. **P1 — Underlying app actionable through accessibility: resolved.**

   `WorkoutTracker/App/WorkoutTrackerApp.swift:129–137` puts the entire sample
   `RootView` under `.disabled(true)` and `.allowsHitTesting(false)`. `TourOverlay`
   is an enabled sibling, so disabling the app does not disable Next/Done/Skip.
   This boundary is present for the whole sample root's lifetime. The concrete
   Start Lifting/Cardio, Settings and gym-picker routes identified in round 1
   are now disabled; template and AI entry controls share the same boundary.

   The UIKit tab bar remains an exception to disabled activation.
   `WorkoutTracker/App/RootView.swift:78–85` selects the step's tab and reverts
   other selection changes. This can transiently select another sample tab;
   it is not a claim that UIKit never receives activation. No inspected tab
   appearance callback starts a workout or reaches an external service.

   **Contract judgment:** allowing focus/read access to disabled sample content
   meets the “never touched” isolation contract in the inspected implementation.
   That contract protects the user's store and external effects; it does not
   require sample text to disappear from accessibility. The ineffective
   `.accessibilityHidden` is not counted as protection, nor is `.isModal` assumed
   to provide containment that the saved accessibility tree contradicts.
   This is source clearance with the runtime limits below, not hardware validation.

2. **P2 — Next/Done and Skip hit regions: resolved.**

   `WorkoutTracker/Features/Onboarding/Tour.swift:183–200` now places minimum
   44-point frames and content shapes inside explicit Button labels; Next/Done's
   padding and painted capsule are also inside the label. The saved passing
   `testTourButtonsTakeTapsAtTheirEdges` checks Next near its top-left and
   bottom-right edges and Skip near its top edge
   (`WorkoutTrackerUITests/FloodlightTourUITests.swift:138–146`). It does not test
   every edge, Done's edges, or edge activation at AccessibilityL.

3. **P3 — History highlight crosses the tab bar: resolved.**

   `WorkoutTracker/Features/History/HistoryView.swift:148–155` anchors the month
   summary instead of the first workout row. I inspected the updated full-size
   `captures/02/tour-s6-dark-default.png` and `tour-s6-dark-AXL.png`: the outlined
   card is entirely above the tab bar, and caption/navigation remain readable.
   Also inspected the dark AccessibilityL and light default contact sheets.
   The changed target is recorded in the ticket and remains a History overview;
   it does not add navigation or change non-tour History behavior.

### Spec

4. **P1 — Barrier fails open without anchor geometry: resolved.**

   `WorkoutTracker/Features/Onboarding/Tour.swift:113–132` requires an active
   step, but no longer requires its frame. The dimmer and caption exist without
   geometry; only the highlight depends on it. The caption is centered in that
   case (`:210–212`), preserving Skip/Next. Independently, the underlying root
   remains disabled and excluded from hit testing before any frame arrives.
   The passing immediate-start tap test (`FloodlightTourUITests.swift:130–135`)
   is supporting evidence; XCTest waits mean it does not deterministically
   exercise an empty-frame interval. The unconditional boundary is the decisive
   source fix.

## Supplemental fix and remaining activation paths

- **Read-only refusal:** `OnboardingCoordinator.swift:53–60` counts unfinished
  workouts and refuses both a fetch error and a nonzero count. It no longer calls
  the mutating `resumableWorkout()` during tour entry. The existing unit refusal
  test and new UI test (`FloodlightTourUITests.swift:149–162`) passed. Fetch-error
  injection was not exercised. The required welcome-seen preference is still
  recorded; that is the specified onboarding bookkeeping.
- **VoiceOver custom actions and rotor:** no directly reachable custom or
  adjustable accessibility action was found on the four sample root screens.
  Existing custom actions live in deeper workout/detail/editor views, behind
  disabled entry controls. No app-defined rotor handler or enabled-environment
  override was found that provides an alternate entry.
- **Swipe actions/context menus:** History's Delete action
  (`HistoryView.swift:217–223`) and Exercises' context-menu actions
  (`ExercisesView.swift:180–195`) are ordinary Buttons within the disabled root.
  Touch gestures cannot reach that root. No source bypass was established;
  native accessibility/keyboard invocation of these menus was not exercised.
- **Tab bar and Full Keyboard Access:** the snap-back guard checks the current
  step and is inactive outside a tour. All four tabs retain the disabled root
  boundary even during a transient selection. The tests tap tab coordinates
  through the barrier; they do not activate a tab through accessibility or
  prove the snap-back at runtime. No keyboard shortcut/command route was found.
- **Scene restoration/lifecycle:** the sample root has fresh identity and local
  navigation state; `RootView.swift:124` skips active-workout recovery when a tour
  exists. No scene-storage restoration, URL or user-activity navigation hook was
  found that reopens a sample destination. The Live Activity bridge retains the
  real container, and normal tour entry refuses an unfinished real workout.
  Background/foreground, process restoration and external-command timing were
  not exercised in this review. No new lifecycle regression was established.

## New findings

**Standards — P3, nonblocking documentation only:**
`WorkoutTracker/Features/Onboarding/Tour.swift:102` still says the overlay “is the
only accessible content.” That contradicts the ticket and saved diagnostic tree.
Change the comment to describe disabled underlying activation and the modal trait,
without claiming hidden content. This does not reopen the fixed activation defect.

**Spec:** no new finding. No remaining activation path or product regression was
demonstrated by the inspected source and saved evidence.

## Independently inspected evidence and limits

Evidence directory:
`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-public-beta/d61f90bf-e3f8-44b7-845e-3831238bedab/scratchpad/b02/`.

- Read `t7.xcresult` with `xcresulttool`, its log and actual `t7.exit`: **exit 65**,
  **23 passed / 1 failed / 0 skipped**, all on **WT-Onboarding**
  `2CEC4AD8-F702-421F-B3B2-D68C302A3453` (iOS 27). Breakdown: **OnboardingTests
  6/6, FloodlightTourUITests 10/10, FloodlightHistoryUITests 7/8**. This combined
  run is not green; its only failure is the dark History chart assertion at
  `FloodlightHistoryUITests.swift:100`, “a multi-day series draws.”
- Re-read `main.xcresult`: it contains that same dark History failure, the light
  equivalent, and the model-picker failure documented in round 1. This supports
  the pre-existing classification; the removed main checkout's HEAD cannot be
  independently verified now. `build4.log` records `BUILD SUCCEEDED`; `t7.log`
  also shows compilation of the later RootView/History changes and execution of
  the final selected tests. No fresh build/test run was performed for this review.
- Read `diag.log`: Start and Settings are present but disabled, while History's
  tab button is enabled. That diagnostic predates the final run and its temporary
  test was deleted. The retained final test verifies disabled status for four
  Workout controls (`FloodlightTourUITests.swift:114–116`); it does not establish
  actual VoiceOver or keyboard activation behavior across every tab.
- No runtime VoiceOver traversal/custom actions/rotor, Full Keyboard Access,
  accessible tab switching, native swipe/context-menu activation, forced missing
  geometry, scene restoration, or Reduce Motion session was performed. No real
  HealthKit/ActivityKit/notification spies or device checks were run. The UI tests
  use `-uiTestReset`; they cannot prove zero production-service calls. Store
  preservation testing constructs a sample store rather than exercising every
  interactive runtime path. These remain stated verification limits, not observed
  failures or claims of coverage.

Standards: no blocking finding; one P3 documentation note. Spec: no new finding.
All four round-1 findings are resolved. Only this report was written; no app/test
source, simulator, phone or desktop state was changed. Next: the implementer can
correct the stale comment and record this clearance in the ticket before the
repository's merge checkpoint.

Verdict: clear
