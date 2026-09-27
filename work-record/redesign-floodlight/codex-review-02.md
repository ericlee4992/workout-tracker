# Codex independent review — Floodlight foundation and Workout area

Reviewed `a0364f2..934a5babedebb334b36de3e6ee2b18e1a6f41a81` on
`ericlee4992/redesign-floodlight`, 2026-09-26. Product commits: `b22f2c0`, `934a5ba`;
the range also includes the reference/ticket commit `2a1b787`. Claude implemented; Codex reviewed.

**Not clear.** No critical finding. Findings below distinguish product/spec issues from
engineering/accessibility standards. No source or test files changed; no `xcodebuild`, `simctl`,
or simulator interaction performed. Only this report was written.

## High

### 1. Reordering within a superset silently removes its grouping — Spec

**`WorkoutTracker/Features/Start/TemplateEditorSheet.swift:350`** (also `:352`, `:367`, `:375`).
Given two linked exercises A/B, drag B above A and save. `drop()` unconditionally clears B's
group ID, then `normalizedSupersets` clears A's now-singleton ID. The next workout has two
ordinary exercises and starts rest between them, although the edit only reversed their order.
The previous editor preserved IDs during reorder. The VoiceOver Move up action also produces
a different result: it swaps the same two items while preserving their group. Preserve
membership when moving within the same contiguous group, and make drag and accessibility
reorder apply the same rule. Test both paths through save/reopen/start. This affects D48 rest
behavior, not just the displayed chain. Ticket 02 lists drag reorder but not this unlinking.

## Medium

### 2. The new target controls remove previously valid choices — Spec

**`WorkoutTracker/Features/Start/TemplateEditorSheet.swift:724`** and **`:662`**;
`WorkoutTracker/Features/Design/Look/Lists.swift:303`, `:311`.
Cardio minutes previously stepped by one. Starting from the new default 15, the new five-minute
step only reaches 5, 10, 15…180; it cannot create a 1-, 2-, or 12-minute target, although
`PlannedCardio.isValid` still accepts every minute from 1 through 180. The button disables
before crossing the boundary, so its clamp does not make 1 reachable. An existing 17-minute
target can only move to 12 or 22 by touch, not 16 or 18. Similarly, planned rest previously
allowed zero; the new 15…600 range prevents setting zero when the exercise/global default is
nonzero. These restrictions came from the prototype but are unlisted product changes in
ticket 02. Preserve the existing authoring range/granularity or explicitly obtain and record
the decision to narrow it; a visual prototype's model should not silently redefine D57.

### 3. Light Appearance leaves live zone captions at very low contrast — Standards

**`WorkoutTracker/Features/Design/Theme.swift:11`**, with
`WorkoutTracker/Features/Design/ZoneColors.swift:9`–`:11` and
`WorkoutTracker/Features/Design/Chip.swift:13`–`:14`.
Choose Light and display heart rate in zone 1, 2, or 3. The card becomes white, but these zone
colors remain the former dark-mode literals. They are used as caption text by
`Features/ActiveWorkout/HeartRateBar.swift:157` and `Features/Cardio/CardioViews.swift:129`.
Against each chip's 12% tinted white background, calculated contrast is approximately
**1.87:1 / 1.76:1 / 1.65:1**, below the project's 4.5:1 minimum. Adapt the remaining zone text
colors to the scheme. The new Light setting exposes this on screens not yet rebuilt.

### 4. Editor panel motion ignores Reduce Motion — Standards

**`WorkoutTracker/Features/Start/TemplateEditorSheet.swift:533`**, **`:621`**, with
`:488` and `:491`.
With Reduce Motion enabled, tapping a rep pill or rest chip still runs an unconditional
`.snappy` animation and inserts a panel with a `.move(edge: .top)` transition, moving the cards
below it. Reading `reduceMotion` for other gestures does not cover these actions. Add/remove
set transactions (`:553`, `:587`) and accessibility reorder (`:379`) also remain unconditional.
Gate the transactions and use opacity-only/no movement for panel transitions.

### 5. The selected checks do not cover the newly introduced interactions — Standards

**`work-record/redesign-floodlight/issues/02-workout-tab.md:77`**–`:98`.
Targeted checks at this intermediate stage are consistent with DEVELOPMENT; deferring the full
UI suite to the whole-redesign release candidate is reasonable. However, the named tests never
exercise this editor's link/unlink, drag/VoiceOver reorder, dirty Cancel/Keep Editing/Discard,
or switching authored rest back to Default and saving. They also do not switch Appearance
through System/Light/Dark and open sheets, covers, and alerts. Consequently the passing
selected flows can coexist with findings 1–4. Add focused coverage of those interactions,
including save/reopen/start assertions for targets and supersets, plus Reduce Motion and
presentation checks. Retain default/AccessibilityL captures of detail/editor states in both
schemes, including expanded controls; the ticket's loose PNG paths document only W01.

## Low

### 6. Day duration rounds each workout before adding — Spec

**`WorkoutTracker/Domain/WeekSummary.swift:140`** and
`WorkoutTracker/Features/Design/Look/WeekWidget.swift:53`.
Two finished workouts of 30:59 on the same day display **60 min** in that day, while the weekly
Time correctly displays **1 h 1 min** if those are the week's only workouts. Each workout loses
its seconds before the day sum. Keep seconds until the daily aggregation, then round once.
The current rounding test (`WorkoutTrackerTests/WeekSummaryTests.swift:67`) only checks a
single workout and cannot catch this discrepancy.

### 7. Search Clear and drag handle miss the 44-point target — Standards

**`WorkoutTracker/Features/Design/Look/Lists.swift:222`** and
**`WorkoutTracker/Features/Start/TemplateEditorSheet.swift:521`**.
After entering a picker search, Clear's plain button wraps only the small SF Symbol; the
surrounding search field's 44-point height does not enlarge that button. The reorder gesture's
explicit target is 40×44. Give both controls a 44×44 hit region so nearby taps/drags do not land
outside the intended control.

### 8. The replacement AXL check can pass while Ask AI is unreachable — Standards

**`WorkoutTrackerUITests/RedesignScreenshotUITests.swift:278`**.
The loop tries to make Ask AI hittable, but the final assertion only checks `exists`. With the
new eager grid, a button below the visible/scrollable area can remain in the hierarchy and pass
after all four attempts fail. Assert hittability/viewport placement or actually open the flow.
Removing the obsolete Machines caption assertion is appropriate; the new assertion does not
establish the reachability its message and ticket claim.

### 9. Adding a set invents a rep target after an untargeted set — Spec

**`WorkoutTracker/Features/Start/TemplateEditorSheet.swift:554`**.
Set the last rep pill to “—” (stored nil), then tap Add Set. The new row receives 10 reps.
Previously, increasing set count copied the final editor value, including zero/no target.
This unlisted behavior change adds a prescription the user did not enter. Preserve the final
nil target when copying, or explicitly record this new defaulting decision in ticket 02.

## Checks without an additional finding

- Finished-only week inputs, start-day bucketing, calendar week boundaries, previous-week
  count, exclusion of warmups, and live-muscle-family counting follow the stated rules.
  Familyless exercises correctly contribute to no family; assisted/bodyweight sets count.
- `TemplateStats.byTemplate` excludes running workouts through `Workout.duration == nil`.
  Its pure arithmetic test passes; the test named `templateStatsCountFinishedRunsOnly`
  actually tests `make(runs:)`, so it does not itself verify that model bridge/filter.
- `SetBadges` covers the stated ordinary live-workout ranking, ties, first-workout suppression,
  warmups, assisted loads, bodyweight and earlier current sets. It is not wired to UI. Its
  finished-history input assumes that history precedes the live sets; do not reuse it for
  arbitrary historical badges without timestamp filtering. No current reachable regression
  was established for that assumption.
- Gym memory, start dialogs, resume routing, tile-menu removal and the delete consequence line
  remain. Ordinary rename/rep edits carry superset IDs; finding 1 concerns reorder specifically.
  Link/unlink and contiguous-run normalization otherwise follow the intended grouping rules.
- Machine preview and start call the same extracted resolver, with the same remembered-machine
  and AI sole-compatible-machine precedence. No disagreement was found for unchanged data.
- Default rest uses the canonical exercise working-rest override, then the canonical global
  working default, then 120 seconds, matching normal `durationSeconds` fallback. A non-Default
  chip represents the authored prescription; an explicit exercise override still outranks it
  at runtime under D57. Unknown cardio targets block Save; valid cardio-only templates remain
  saveable. Rep pills and rest chips have explicit VoiceOver labels/values.
- Per-device `@AppStorage` is consistent with ticket 01's explicit refinement and needs no
  schema change. No definite scheme/token propagation bug was established by source inspection
  of `.lookLayer()`. Runtime coverage of every presentation remains outstanding, as in finding 5.
- The picker helper still searches and adds each requested exercise. The changed rest assertion
  still verifies nil/default rest, equivalent to the old switch assertion; neither version
  establishes effective timer duration. MakeTile/DestructiveRowButton labels are explicit.

## Evidence inspected

Read the required tickets, product constraints, derived-data brief, Look API, relevant
SPEC/DECISIONS/DEVELOPMENT rules, source and tests, and the prototype editor source. Viewed
approved dark/light W01 and T01 images and actual `w01-dark.png`, `w01-light.png`, `w01-axl.png`.
The actual W01 images support the new composition; they do not establish detail/editor or
all-presentation accessibility acceptance.

Read existing logs and used **read-only `xcresulttool`** summaries:

- `/tmp/wt-floodlight/results/area1-ui-2.xcresult`: 797 tests, 795 passed, 2 failed, 0 skipped.
  The log separates these into 787 unit tests (one obsolete MuscleBody asset assertion) and
  10 UI tests (9 passed, one AI accessibility failure).
- `/tmp/wt-floodlight/results/base-axl.xcresult`: the same AI accessibility test fails;
  baseline and branch logs both identify the equipment reachability assertion. This supports
  keeping it with the AI-area work rather than attributing it to this editor rewrite.
- `/tmp/wt-floodlight/dd-test/Logs/Test/Test-WorkoutTracker-2026.09.26_21-01-33--0400.xcresult`:
  13 passed, 0 failed/skipped; rerun log says `TEST SUCCEEDED`.

These are existing result artifacts, not tests rerun by this reviewer. Original shell exit-code
receipts were not independently recovered; result-bundle statuses and log outcomes were checked
directly. HEAD stayed `934a5ba`; pre-existing untracked `opencode.json` was untouched.

**Summary:** Spec: 4 findings (worst: high, superset loss on reorder). Standards: 5 findings
(worst: medium, light contrast / Reduce Motion / uncovered interaction checks).
