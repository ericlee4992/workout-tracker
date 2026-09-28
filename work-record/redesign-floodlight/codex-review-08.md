# Ticket 08 — independent Codex review

**Not clear.** Reviewed `ericlee4992/redesign-floodlight-scan..HEAD`, base
`7655aa79e82c782fb4376c811ab5b26106e4df68`, HEAD
`06d365112e9201dff02a286e6397c24e7f47b4bc`, on
`ericlee4992/redesign-floodlight-exercises` in `/tmp/wt-floodlight/exercises`.
The checkout was clean before this report. No critical or high findings.

## Medium

### 1. Recent sessions apply the first entry's context to every set — Spec

**`WorkoutTracker/Domain/ExerciseOverview.swift:434–437`**, consumed by
`WorkoutTracker/Features/Exercises/ExerciseDetailView.swift:520–525`.

`recentSessions` merges every entry of the exercise in a workout, but retains only
the first entry's equipment, preset and load type. Log narrow grip, switch to wide
grip and log again: E02 labels both sets as narrow grip. More seriously, if two
entries have different frozen load types (for example, retype one entry through
History), every set is formatted using the first type. A later assisted `25 × 8`
can appear as `25 × 8` lifted rather than `−25 × 8`, or weighted sets can appear as
`BW × 8`. Opening the workout shows the correct separate contexts. This violates
ticket 08's snapshot-history requirement and D23/D36. Preserve context per entry
or per displayed set; cover multiple entries/presets and mixed frozen types.

### 2. The hero's “set last session” mark is calculated by day — Spec

**`WorkoutTracker/Features/Exercises/ExerciseDetailView.swift:201–205`**;
the spoken claim is in `ExercisesPieces.swift:168`.

`ProgressSeriesMath.series` groups by calendar day, not workout. On an exercise's
first day, finish a morning workout at `100 × 8`, then an evening workout at
`110 × 8` on the same variation. The catalog and receipt recognize the evening
new best, but E02 has one chart point and suppresses its burst. Conversely, a
first-ever workout spanning midnight, with `100 × 8` before midnight and
`110 × 8` afterward, produces two points and a false new-best burst despite no
earlier workout. A later lower workout on an already-record-setting day also
leaves the hero claiming “set last session.” Derive this mark from workouts and
their eligible sets; retain day grouping for the chart. Add same-day and
midnight-crossing cases.

### 3. Load Type's historical ledger misstates previously frozen types — Spec

**`WorkoutTracker/Features/Exercises/EditExerciseLoadTypeSheet.swift:81–83`**.

Log three Weighted sets, change the exercise to Assisted, then reopen Load Type
and select Bodyweight. The ledger says “3 sets already logged: Assisted,” although
all three snapshots remain Weighted. Mixed historical types likewise receive
one incorrect badge. The old screen accurately said sets retain their logged
type; the new ledger substitutes the exercise's current type. Derive the ledger
from snapshots, or use wording that accurately covers mixed types. This affects
both visible and VoiceOver output and contradicts D23 and ticket 08's frozen
history rule.

### 4. Preset field's only visible label fails dark-mode contrast — Standards

**`WorkoutTracker/Features/Exercises/ExercisePresetsSheet.swift:228–238`**.

With an empty preset field in dark mode, “New preset (e.g. Wide grip)” uses
`textTertiary` (`#7F858E`) on `field` (`#22252A`): **4.134:1**, below REVIEW §6's
4.5:1 minimum. The Look API explicitly prohibits this pairing for essential
text. `NewExerciseSheet.swift:87–95` repeats the pairing for “Name.” Use a token
that meets the required contrast and retake the affected dark captures.

### 5. Preset Edit transitions bypass Reduce Motion — Standards

**`WorkoutTracker/Features/Exercises/ExercisePresetsSheet.swift:134,143`**.

With Reduce Motion enabled and at least two presets, Edit and its Done button
still change `editMode` inside unconditional `withAnimation`, animating the list
as delete/reorder controls enter or leave. The existing Reduce Motion gate on
preset-ID changes does not gate these transactions. Suppress their animation or
use an allowed crossfade, per REVIEW §10.

## Low

### 6. Capture traversal can succeed without reaching its target — Spec / verification

**`WorkoutTrackerUITests/FloodlightExercisesUITests.swift:49–57`**.

`page(to:)` exhausts its swipe limit without asserting that the target exists
and is visible. Remove the recent-session rows or the custom Rename row: the
capture sequences at lines 132, 171 and 187 can still pass while collecting
repeated screenshots. Assert the target was reached after traversal so these
tests prove the required content is present.

### 7. AccessibilityL sheet captures omit required content — Standards / verification

**`WorkoutTrackerUITests/FloodlightExercisesUITests.swift:157–161,198–210`**.

The actual E03 AccessibilityL captures show the name/load choices but never
scroll to Body area and Equipment. The E05 changed AccessibilityL captures stop
at the beginning of the ledger; the logged-set row is offscreen. Therefore these
blocks have no complete default/AccessibilityL visual pair, as required by
ios-design step 6 and REVIEW §12. This is a verification gap, not proof that the
offscreen layout is broken. Add scrolled captures and inspect every block in
both appearances.

## Review and verification scope

Read ticket 01, ticket 08, relevant SPEC/DECISIONS, the Look API and constraints,
the iOS design checklist, prototype source/captures, changed source and callers,
and tests. Compared the four default/AccessibilityL light/dark contact sheets,
the additional state sheet, and individual actual captures for detailed checks.

Existing `.exit` files and logs under `/tmp/wt-floodlight/results/` corroborate:

- `exercises-unit-3`: exit 0, 15 domain tests passed.
- `exercises-build-1` and `exercises-build-10`: exit 0, build-for-testing succeeded.
- `exercises-ui-7`: exit 65, 20/22 passed, including all six new flows; its two
  preset failures are documented.
- `exercises-ui-8`: exit 65, all four capture passes succeeded; preset failures
  remained in that run.
- `exercises-ui-11`: exit 0, both preset tests passed.
- `exercises-ui-12`: exit 0, eight affected neighbour tests passed.

Targeted verification is appropriate under DEVELOPMENT; a full UI run is not
requested for this review. The specific missing cases above need coverage.
Human VoiceOver, runtime Reduce Motion and drag reordering remain unverified,
as the ticket states. No `xcodebuild` or `simctl` was run for this review.

No additional finding in the combined catalog filters, family persistence and
legacy value mapping, seeded rename restriction, creation callbacks/model link,
body-area save, live-name refusal, preset deletion/default fallback, override
flag, or fixture reset guard. Neighbour test helper changes retain their prior
substantive assertions. No unrelated product expansion identified.

**Totals:** Spec: three medium readout defects and one low test defect.
Standards: two medium accessibility defects and one low capture gap.
Only this report was changed.
