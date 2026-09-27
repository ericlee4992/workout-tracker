# Codex independent review — ticket 06: Gyms

2026-09-27. **Not clear:** 1 high, 6 medium, 1 low; no critical findings.

Reviewed `ericlee4992/redesign-floodlight-history..HEAD`, base
`646187eb1ab2b0e8c5c33d5f8143ef77df82d1eb`, tip
`d49a5b913407dc8b1628e79c333d8a619b95e909`, in `/tmp/wt-floodlight/gyms`.
The working tree was clean. These are source-traced failure cases; no new app execution,
`xcodebuild`, or `simctl` was performed. Only this report was written.

## High

### 1. The machine chart mixes exercises on the same station — Spec

**`WorkoutTracker/Features/Gyms/MachineDetailView.swift:158`**

`topBest` passes all the machine's record inputs into `ProgressSeriesMath.series`.
`ProgressVariationKey` scopes equipment, preset and load type, but assumes the caller
already filtered the exercise. `rebuild` at line 445 filters only the machine.

Log cable pushdowns at 40 kg in three workouts, then cable flies at 70 kg in another,
both weighted with no preset. The pushdown hero correctly says 40 kg, but its chart
includes the fly's 70 kg and marks it as a new best. Opening that best filters by
`snapshotExerciseID` in `ExerciseProgressView.swift:579`, so the two charts disagree.
This violates ticket 06's chart of the most-used record scope. Filter the inputs by
`best.exerciseID` before deriving the embedded series and cover a multi-exercise station.

## Medium

### 2. Warmup-only workouts disappear from a scope's usage count — Spec

**`WorkoutTracker/Domain/GymOverview.swift:141`**

The code filters out warmups before grouping scopes, then derives each best's workout
count and recency from that filtered group (lines 152–154). These are usage facts:
`MachineBest.workouts` explicitly promises workouts with a completed set, and ticket 06
puts the most-used scope first. Warmups should be excluded from best selection, not usage.

Scope A with one working workout and two completed warmup-only workouts displays
“1 workout”; scope B with two working workouts incorrectly becomes the hero even though
A was used three times. The approved prototype's `Derived.machineStats` counts the whole
scope while filtering only best candidates. Group completed inputs first, compute usage
from the whole group, and rank the eligible best separately.

### 3. Renamed or deleted presets lose their historical identity — Spec

**`WorkoutTracker/Features/Gyms/MachineDetailView.swift:423`**

`title(of:)` resolves historical exercise and preset names through live objects. Log
Narrow grip and Wide grip bests, then delete those presets: both best rows remain but
both are now labelled only with the exercise name. Renaming a preset likewise changes
the machine page's historical label while the opened progress picker uses the frozen
`snapshotPresetName` (`ExerciseProgressView.swift:640`).

Keep snapshot display names with the derived best, matching D23 and the domain brief's
“Use snapshot labels for past rows.” Test renamed and deleted presets, including two
historical scopes whose live preset rows are gone.

### 4. Delete Gym leaves Home using the archived gym — Spec / integration

**`WorkoutTracker/Features/Gyms/GymEditorSheet.swift:203`**

Select Iron Temple on Home, delete it through Gyms → Edit Gym, then return Home without
relaunching. Archiving changes the model flag but does not invalidate Home's cached
`selectedGym`. `StartWorkoutView.swift:322` resolves it only once; line 365 still displays
it, and `WorkoutStartFlow.swift:95` passes it into `WorkoutSession.startWorkout`, which
saves that archived gym on the new workout (`WorkoutSession.swift:78`). The picker options
drop the gym, but the selection and new workout context do not.

This is an inherited archive integration defect retained by the new Delete Gym flow,
not a newly introduced archive mutation. It contradicts the new handler's explicit
Home-selection promise at lines 198–199 and the requested lifecycle acceptance check.
Invalidate the selection when its gym becomes archived. The new UI test deletes
non-current Hotel Gym, so it misses this case.

### 5. Editor animations ignore Reduce Motion — Standards

**`WorkoutTracker/Features/Gyms/GymEditorSheet.swift:95`**, **`:112`**;
**`WorkoutTracker/Features/Gyms/ModelPicker.swift:549`**, **`:664`**

With Reduce Motion enabled, editing a gym name so its initials change still scales the
preview monogram through an unconditional `.snappy` animation. Selecting or removing
linked exercises in New Model also unconditionally animates the chips and layout.
Neither editor reads the setting. Gate these animations or use opacity-only changes,
as required by REVIEW item 10. The rolling counts, restore actions and chart draw-in
have gates; those do not cover these editor paths.

### 6. Individual grouping targets are only 38 pt tall — Standards

**`WorkoutTracker/Features/Gyms/GymDetailView.swift:356`**, **`:363`**

At default text size, each Body area / Exercise / A–Z button has a 38 pt label and a
content shape restricted to that label. The 3 pt padding and 44 pt minimum at lines
370–372 apply to the enclosing group, outside the buttons. The top and bottom padding
therefore do not provide the required individual hit region. Put a minimum 44 pt hit
area inside each button (REVIEW item 7), preserving the quieter visual pill if desired.

### 7. VoiceOver drops “Assisted” from secondary bests — Standards

**`WorkoutTracker/Features/Gyms/MachineDetailView.swift:231`**

`bestRow` ignores its children and supplies a replacement label that omits the visible
Assisted tag. An assisted scope below the hero is announced as an ordinary weight best.
For an exercise whose load type changed over time, the weighted and assisted historical
scopes can consequently sound identical despite opposite ranking rules. Include the
load meaning in the replacement label, as `topBest` already does at line 192.

## Low

### 8. Gym cards hide the visit rhythm from VoiceOver — Standards

**`WorkoutTracker/Features/Gyms/GymsView.swift:150`**, **`:187`**

The card ignores descendants and replaces them with a label containing identity and
totals only. This suppresses `GymVisitRhythm`'s accessible weekly description at
`GymsPieces.swift:318`. A VoiceOver user can hear six total visits but cannot discover
the visible pattern of three visits in each of two weeks. Include that description in
the card's accessible content or expose it separately.

## Verification and remaining assessment

Read the requested ticket, decisions, design rules/reference material, original screens,
changed source and relevant callers. Inspected the approved G03 light/dark renders and
representative actual default/AccessibilityL captures across the list, gym, machine,
editors, picker, empty and deleted states. Scan remains ticket 07 and Add Machine retains
its form. The captures preserve Scan Machine as the gym's sole filled command and the
top best as the machine page's hero figure. The accessibility findings above come from
source inspection; no live VoiceOver or Reduce Motion acceptance run is claimed.

Read the saved exit files and actual xcresult summaries under
`/tmp/wt-floodlight/results/`: `gyms-unit-3` passed 50/50, exit 0;
`gyms-ui-1` passed 157/168 with 11 failures, exit 65; `gyms-ui-2` passed 21/24,
exit 65; `gyms-ui-3` passed 13/13, exit 0. All four summaries have zero skipped tests.
Successful build exits are retained for `gyms-build-4` and `gyms-build-5`. This agrees
with the ticket's initial failures and focused reruns. DEVELOPMENT permits this targeted
scope; a full suite is not needed merely to resolve these findings. Add focused cases
for findings 1–4 and accessibility checks for 5–8, then rerun the affected flows and
retake captures where layout changes.

No additional defect found in snapshot machine scoping, ranking direction/ties/bodyweight,
calendar visits/order, per-group row filtering, blank-name restoration, immediate unit
edits, preset eligibility, archive restoration, kept delete confirmation/actions,
model correction entry points, scan prefill, or AI consent/cancellation. The CoreLoop
chip change tests the replacement filter control. `ProgressSessionLink` pairs the new
navigation value with its destination and hashes by stable workout UUID;
`SheetHeader.reflowsTitle` retains the old default. The Gyms fixture requires the design
sample and reset gates, and its extra mutations require its own flag.

**Performance judgment:** machine-use aggregation scans finished entries/sets on
navigation and history invalidation, and sorts the resulting scopes. It is not rebuilt
per row or animation frame. Deleted Machines rebuilds on appear only. The gyms list
rescans workouts per gym on each list evaluation; this is O(gyms × workouts), plus the
eight weekly day scans. The picker's served-exercise map is cached and rebuilt on catalog
changes. These are reasonable for the app's current personal-use scale, but the history
work is synchronous and unbounded; no large-history latency benchmark was supplied or
run, so this is not a scalability clearance. A shared aggregate/cache is the natural next
step if navigation latency grows. No separate measured performance regression or
unlisted product expansion was established.

Axis summary: Spec/integration — 4 findings, worst high; Standards — 4 findings, worst medium.
