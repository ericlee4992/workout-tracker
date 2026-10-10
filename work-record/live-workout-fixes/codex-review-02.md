# Independent review — live-workout-fixes 02

Reviewed `git diff 70e8499..HEAD` in `/tmp/wt-live02`, branch `ericlee4992/live-02-discard-top-left`, HEAD `a985928f9f1f898bd1e2a95ea145a13fefb36d74` (implementation `a088d15`). Claude authored; Codex reviewed against the ticket, SPEC/D59 changes, DEVELOPMENT, and the iOS design skill/checklist. The working tree was clean before this report.

## Findings

1. **P2 — Preserve the chosen Cancel control at accessibility sizes.** `WorkoutTracker/Features/ActiveWorkout/ActiveWorkoutView.swift:292–295` substitutes a trash symbol whenever `typeSize.isAccessibilitySize`. Ticket 02:17–20 explicitly records “Chevron + Cancel” and rejects a trash icon; the committed AccessibilityL capture confirms that this rejected alternative is what those users receive. Ticket :31 calling it “within the user's choice” does not resolve that conflict. SPEC and D59 likewise record red Cancel beside minimize, without this exception. **Suggested fix:** keep the visible Cancel label and adapt the title/chrome layout, for example by placing the editable title on a separate line when space is insufficient. Alternatively, explicit user acceptance of the symbol exception must be recorded before treating it as the agreed design. Retake affected captures after the layout is settled. This is a mismatch with the recorded decision, not a claim that a labelled trash button is inherently inaccessible.

2. **P3 — Capture the changed end of the list.** `work-record/live-workout-fixes/issues/02-discard-top-left.md:66–67` explicitly says the new list ending was not captured. Removing the discard row and changing the add block's bottom spacing is part of this change and the agreed wireframe. The existing top-of-screen captures cannot establish the final spacing or visibility above the rest inset at either text size. **Suggested fix:** preserve default and AccessibilityL captures scrolled to show the add block and list ending, and link them from the ticket. The iOS design skill's capture step requires every block named in the wireframe to be on record; source inspection alone does not satisfy that visual check.

## Correctness and accessibility assessment

No additional demonstrated product correctness regression found.

- The new button only sets `confirmingCancel = true`. The confirmation title, destructive action, Keep Logging action, explanatory message, and `cancelWorkout()` handler are unchanged (`ActiveWorkoutView.swift:291,333–342,865–872`). Merely pressing the toolbar control does not stop sensors or delete the workout.
- Toolbar items are outside the lifting/cardio branches and are not conditioned on entries or rest state. Cancel therefore remains available for empty workouts, cardio focus, and running rest. A modal rename alert temporarily owns interaction, as expected; its Cancel closes that alert, and the toolbar remains available afterward. No new direct discard path was added to renaming or minimization.
- `ToolbarSpacer(.fixed, placement: .topBarLeading)` is available from iOS 26 in the installed SwiftUI interface. The project's iPhone deployment target is 26.0, so no availability guard is missing. The committed captures show distinct leading capsules rather than an accidental combined command.
- Both label variants inherit the same `discardWorkout` identifier and explicit “Cancel workout” accessibility label. The destructive colour has the appropriate meaning and the control uses native toolbar sizing. The captures show conventional approximately 44-point chrome; they do not independently measure hit regions or prove VoiceOver/Switch Control operation. A trash symbol beside a chevron is distinguishable, but its desirability cannot override the user's recorded rejection.
- All five `discardActiveWorkout()` callers are covered by the selected two CoreLoop and three HeartRate tests. The helper now waits for and taps the toolbar identifier without scrolling, then requires the unchanged confirmation button. Searches found no remaining executable UI query for the removed list-row text. `HealthKitHeartRateProvider.discardWorkout()` references are unrelated framework calls. An optional stale comment remains in `Features/Design/Look/FinalLook.swift:12`, describing the old list-end layout.

## Layout judgment and scope

Opened the preserved light/default, dark/default, and light/AccessibilityL captures. The default Cancel, “Push Day”, pencil, and Finish fit; the accessibility symbol variant also fits. New/removed strings are listed accurately in the ticket. SPEC/D59 correctly reopen the old list-end placement, subject to finding 1's unresolved exception.

Adding a leading capsule reduces the title's available width at default size too. The unchanged one-line title with `minimumScaleFactor(0.8)` can still truncate once its width is exhausted; switching controls solely by text-size category is not a general overflow solution. The supplied short-title captures do not establish a particular newly truncated title, so this is **layout advice, not a separately proven regression**: define a width-sensitive title rule while fixing finding 1, and include a realistic longer workout name in the resulting default/AccessibilityL evidence. Reflowing the title would preserve the requested commands; accepting a truncated navigation title should be an explicit design exception, with the full name still accessible through renaming.

The selected targeted checks are proportionate under DEVELOPMENT. A full UI suite is not warranted for this relocation. The tests cover empty-workout minimize/resume/discard and confirmation through the helper; the live captures cover a running rest. Cardio-focus interaction, rename-alert interaction, Keep Logging, and assistive-technology operation were assessed in source rather than newly exercised by these tests. Finding 2 identifies the specific missing visual evidence.

## Verification

Independently inspected the final implementer run: `r2.status` is **exit 0**, `r2.log` ends **TEST SUCCEEDED**, and `xcresulttool get test-results summary` reports **Passed, 8 passed, 0 failed, 0 skipped**, with no runtime warnings. Breakdown: 2 CoreLoop, 3 HeartRate, 3 Floodlight live captures. The test action built the app. Evidence root:

`/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-public-beta/0dc39eb1-054d-49da-bf79-784fabae4a4e/scratchpad/live02/`

Files: `r2.status`, `r2.log`, `r2.xcresult`. Committed visual evidence is under `work-record/live-workout-fixes/captures/02/`. `git diff --check 70e8499..HEAD` passed. No new build/test run, simulator interaction, desktop control, phone/account/backup access, or deployment was performed. Only this report was written.

## Separate check — ticket 01 advisory

Confirmed in `/Users/ericlee06/orca/workspaces/Health App/public-beta`, branch `ericlee4992/live-01-weight-unit`, HEAD `2464183a15b6fcb0f3e38a22b065b4d5f3fcfb43`. The committed diff from `49cd666` replaces the negated existence wait with `XCTAssertTrue(unitSwitch.waitForNonExistence(timeout: 5))` in `FloodlightLiveUITests.swift:83`. This correctly waits for teardown and implements the round-two advisory. No objection; no rerun claimed for this separate check.

Standards: one P3 missing visual record. Spec: one P2 deviation from the chosen control. Ticket 01 advisory: accepted.

Verdict: not clear
