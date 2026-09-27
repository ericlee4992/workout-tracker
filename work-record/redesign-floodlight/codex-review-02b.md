# Codex review 02b — round 2

**Not clear: three medium findings and one low finding.** Reviewed
`git diff 934a5ba..37f16a0` and the ticket's round-one response on
`ericlee4992/redesign-floodlight`, HEAD `37f16a065961cf75fe8cd0f0d861d41ff01e138d`.
No critical or high finding remains from the original review.

## Medium

### 1. A moved exercise can join a different existing superset — Spec

**`WorkoutTracker/Features/Start/TemplateEditorSheet.swift:361`–`:367`**;
original run IDs enter unchanged at `:119`–`:126`.

`moving` checks neighboring UUIDs before distinguishing the original contiguous runs.
An existing template can contain `[A(g), B(g), X(nil), C(g), D(g)]`: the old editor's
`onMove` preserved IDs when a group was interrupted. Under D48, A/B and C/D are separate
visible supersets. Drag B between C and D. Because C/D still carry `g`, B keeps that ID;
normalization then produces `[A(nil), X(nil), C(h), B(h), D(h)]`, where `h` is a fresh group
ID. B silently joins the other superset, so starting the template suppresses rest after B.
This contradicts the new rule that a card moved away from its group travels alone.

Distinguish the original contiguous runs before testing membership (for example, normalize
their IDs before the move), then normalize the resulting order. The new two-card UI test
correctly closes the original A/B reversal case, but cannot expose reused IDs across runs.
Add this case alongside moving within, out of, and into a group.

### 2. Numeric animations still ignore Reduce Motion — Standards

**`WorkoutTracker/Features/Start/TemplateEditorSheet.swift:262`** and
**`WorkoutTracker/Features/Design/Look/Lists.swift:310`–`:312`**.

The panel transitions and explicit editor transactions are now gated correctly. However,
the summary and `NumberStepperPill` still apply unconditional `.animation(.snappy, value:)`
to `.numericText` transitions. With Reduce Motion enabled, adding/removing a set still rolls
the summary digits; changing reps, rest, or cardio minutes still rolls the stepper digits.
These child animation modifiers supply their own animation even when the parent transaction
has none. Gate these remaining animations/transitions as well. Original finding 4 is only
partly resolved; none of the new UI cases enables Reduce Motion.

### 3. The new coverage leaves part of the accepted verification finding open — Standards

**`WorkoutTrackerUITests/FloodlightWorkoutTabUITests.swift:132`–`:155`**, with
`:47`–`:74` and `:181`–`:199`.

The Appearance test checks Light/Dark in Settings, then Dark on the detail and editor sheet.
It never selects System, opens a full-screen cover, or checks an alert's appearance. A scheme
regression confined to the active-workout/AI cover or an alert would still pass. The capture
tests launch with an explicit appearance argument, so they do not close the System/stored
preference gap. They also capture only the initial viewports, with the rest-open capture
conditional on hittability.

The new interaction tests meaningfully verify pair linking plus drag/save, dirty Cancel,
and authored-rest → Default save/reopen. They do not exercise unlink, VoiceOver reorder,
or the resulting superset behavior after starting a workout. Extend the focused checks for
these remaining branches and the Reduce Motion case above; no full-suite rerun is requested
for this correction. Original finding 5 should remain partially open rather than “all fixed.”

## Low

### 4. The ticket overstates the third batch's UI count — Standards

**`work-record/redesign-floodlight/issues/02-workout-tab.md:131`**.

The response says “UI 9 of 10 passed.” `area1-ui-3.log` records **9 UI tests: 8 passed,
1 failed**. Its result bundle contains **15 total tests: 14 passed, 1 failed**, including
the six domain tests. Correct the count. The separately rerun Appearance test does pass;
this is an evidence-record error, not another test failure.

## Fixes verified

| Original finding | Round-two result |
|---|---|
| 1 — reorder loses supersets | Two-card reversal fixed; both input methods share `moving`. Interrupted-run case remains above. |
| 2 — narrowed target ranges | Fixed: cardio steps by one through 1…180; rest allows 0…600 in 15-second steps. |
| 3 — light zone contrast | Fixed for the reported chips: approximately 5.13:1 / 5.04:1 / 4.85:1 against their 12%-tinted white backgrounds. |
| 4 — Reduce Motion | Panel movement fixed; numeric animations remain. |
| 5 — interaction/presentation coverage | Substantially improved; remaining branches are listed above. |
| 6 — daily minutes | Fixed: seconds survive into `WeekDaySummary.minutes`, which sums before rounding; the new unit test directly covers two 30:59 workouts yielding 61 minutes. |
| 7 — hit targets | Fixed: Clear and drag handle have 44×44 content regions. |
| 8 — Ask AI reachability | Fixed: the final assertion checks hittability and clearance above the tab bar. |
| 9 — Add Set invents a target | Fixed: the final slot's zero/no-target value is copied unchanged. |

No additional regression was found in the restored ranges, nil-target copying, or daily
duration calculation. The rest save/reopen test asserts the authored value on the detail and
after reopening, then verifies Default survives another save. The reorder test checks actual
row order as well as both superset labels, so a drag that did nothing would fail it.

## Evidence and limits

Read the original report, ticket response, changed source/tests and relevant D48 rules.
Inspected the committed default/AccessibilityL detail/editor/rest-open captures in light and
dark, plus Home captures. No additional definite rendering defect was established from the
visible regions; the unrecorded scrolled regions are not visually cleared.

Read existing logs and used read-only `xcresulttool` summaries:

- `area1-ui-3.xcresult`: 14 passed, 1 failed, 0 skipped; its only failure is the Appearance
  test's Dark Settings pixel assertion. The log separately confirms 6/6 unit and 8/9 UI.
- `area1-ui-4.xcresult`: the corrected Appearance test passed, 1/1, 0 skipped.
- `area1-captures.xcresult`: 4/4 passed, 0 skipped; all four rest-open PNG variants exist.

No `xcodebuild`, `simctl`, or simulator interaction was performed, and no new test execution
is claimed. Only this report was written; pre-existing untracked files were left untouched.

**Axes:** Spec: one medium finding. Standards: two medium findings and one low finding.
