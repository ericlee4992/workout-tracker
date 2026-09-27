# Ticket 03 — independent review (T6)

**Not clear.** Reviewed `b2c0329..b1e01286833844affb0d0c7d6358ea0f3e4b58db` on
`ericlee4992/redesign-floodlight-live`, in `/tmp/wt-floodlight/live`.
Claude implemented; Codex reviewed. No critical or high findings. Findings below are
ordered by severity and identify the Standards or Spec axis.

## Medium

### 1. Completed sets cannot be corrected without changing their completion time (Spec)

**Location:** `WorkoutTracker/Features/ActiveWorkout/LiveSetRow.swift:274`, `:286`, `:316`.

The new row disables weight, unit and reps once completed. The old row allowed these edits
(only bar mode disabled the unit toggle). Log `100 lb × 8`, then notice that the weight should
be `110 lb`: the fields no longer respond. The available workaround is to uncheck, edit and
check again. That replaces `completedAt` (`Domain/WorkoutSession.swift:833`) and cancels/restarts
rest (`ActiveWorkoutView.swift:741`), turning a correction into a newly timed set. Ticket 03
promises that the old commit rules are unchanged and does not list this new lock.

Preserve direct correction and its commit semantics, with badges recomputed after edits.

### 2. Set-type changes and set deletion leave incorrect badges on screen (Spec)

**Location:** `WorkoutTracker/Features/ActiveWorkout/ActiveWorkoutView.swift:478`;
`LiveSetRow.swift:435`; `ExerciseEntryCard.swift:364`.

Badges refresh on appearance, completion callbacks and **entry count** changes. Changing a
set's type or deleting a set does not trigger any of those. Earn “New best”, then change that
completed set to Warmup: the sticker stays, although warmups are ineligible. In a first workout,
complete two working sets and delete the first: the remaining first eligible set never gets
“First time”. Similarly, deleting an earlier heavier set can leave a later qualifying set
without “New best”. The dictionary is cached view state, so the correct pure calculation does
not repair the display until another refresh happens.

Observe all inputs affecting the marks or notify the owner from every relevant mutation.
`reference/brief/domain-data.md` §3 requires warmup exclusion and marks derived from current
data. Uncompletion through the check already refreshes correctly; the ordinary local
history-edit path through minimise/resume refreshes on appearance.

### 3. The preset regression tests never reach the rebuilt live controls (Standards)

**Location:** `work-record/redesign-floodlight/issues/03-live-workout.md:83`–`:89`;
`WorkoutTrackerUITests/ExercisePresetUITests.swift:107`.

Both preset tests stop at Exercises search during setup, before reaching the live chips,
prefill clearing or frozen-entry split. Reproducing these failures on main establishes that
the setup failures predate this branch; it does not verify the changed live UI. Consequently,
the ticket's selected scope has not yet covered D36, one of the row rewrite's main data risks.

Run focused tests that reach the live screen, using a seeded preset/history fixture if needed:
switch an untouched prefilled draft, confirm stale values clear and Complete disables;
preserve deliberate input; and switch after completion to verify the new entry and frozen old
context. Add focused regressions for findings 1–2. DEVELOPMENT's verification policy requires
affected flows to pass, but does **not** require a blanket full UI rerun for this ticket. The
whole-redesign release gate remains separate.

### 4. The approved L03 completion band is absent (Spec)

**Location:** `WorkoutTracker/Features/ActiveWorkout/LiveWorkoutPieces.swift:341`–`:356`;
`ActiveWorkoutView.swift:199`–`:208`.

The approved light and dark `reference/captures/*/L03-final.png` show a fresh “New best” band
attached above the rest controls, with the exercise, achieved value and prior best. Completing
a record set here can only add the row sticker: `LiveRestSlab` accepts the timer and next-set
text, but no completion result, and always renders only `RestBar`. The approved L03 state is
therefore unreachable, including when the completed row has scrolled away. The reference
prototype's `Screens/Live/LiveBottomDock.swift` supplies this band through `LiveBestBand`.

Implement the approved moment using the real record scope, with its Reduce Motion treatment,
or explicitly record a decision to omit this part of the approved screen. Ticket 03 currently
records neither an implementation nor an exception.

## Low

### 5. Bar and Rest sheets inherit the live Paper treatment (Spec)

**Location:** `WorkoutTracker/Features/ActiveWorkout/ExerciseEntryCard.swift:107`–`:117`.

These sheets are presented inside `ActiveWorkoutView.swift:214`'s `screenLook` environment.
Unlike the sheets owned by `ActiveWorkoutView`, they inherit `Look.live`; neither resets it.
Opening Bar and entering a custom bar therefore renders “Use this bar” with the Paper primary
button treatment, while sheet grounds use the live tokens. `lookGroupedList()` consumes the
inherited look; it does not select plain Floodlight. This contradicts ticket 03's explicit
“every sheet over the cover stay plain Floodlight”. Reset the look at these presentation
boundaries while preserving the selected light/dark appearance.

### 6. The new unit suffix does not have a 44 pt hit region (Standards)

**Location:** `WorkoutTracker/Features/ActiveWorkout/LiveSetRow.swift:276`–`:295`.

The unit button's label is caption-sized “lb”/“kg”, with only 6 pt trailing padding and 12 pt
vertical padding. Its width is well below 44 pt. The enclosing HStack's minimum height does
not enlarge this button's width, and tapping the surrounding weight well focuses the field.
Thus a tap beside the tiny suffix edits weight instead of toggling units. Give the suffix an
actual 44 × 44 target without overlapping the weight editor. This violates the iOS-design
skill's control minimum; the circular marker and check do explicitly provide 44 pt regions.

## Verification and review limits

- Inspected the supplied four actual captures and all eight approved light/dark L01,
  L01-end, L03 and L06 captures, plus source and the read-only prototype. Default live
  composition follows the approved Paper structure and Floodlight palettes. Native sheets
  are an explicitly listed design exception; finding 5 concerns their tokens.
- The rest slab uses `safeAreaInset`, not an unconstrained overlay. The passing
  `RedesignScreenshotUITests.test02_activeWorkoutLargeText` explicitly scrolls and asserts
  Add Exercise is hittable **above** the Rest label (`:180`–`:186`). There is no confirmed
  last-row/add-block obstruction from the supplied top-of-screen AXL capture. That capture
  alone does not show all rows, the footer or the sheets in both schemes.
- Row commit, dirty-draft, prefill-context, bar-context, unit-toggle, keyboard-Done and delete
  handlers otherwise retain their old paths. Completion validates the visible text and commits
  it before toggling; no automatic row creation was introduced. One unlisted beneficial change:
  non-bar field reconstruction now uses `WeightMath.displayNumber` instead of `Format.weight`
  (`LiveSetRow.swift:86`), retaining two decimals instead of one. Record that in ticket 03.
- Next-set selection follows the most recently completed set and contiguous superset runs;
  warmups are excluded from working-set numbering. Volume uses `RecordsMath` eligibility and
  normalized total load, excluding warmups and non-weighted load types, with the displayed
  unit conversion applied once. First-workout badge math suppresses “New best”. Set count and
  ring use the same completed/total inputs.
- Finish, rename, minimise/resume, explicit planned-cardio Start, activity focus, add paths,
  menu actions and freeze services retain their action paths. D46 scheduling and D48 rest
  gating are unchanged. PREVIOUS's spoken label retains the full value/unit, and the marker,
  check and stickers have explicit accessibility semantics. Stamp/ripple, rest-ring animation
  and fresh-heart motion follow their Reduce Motion/freshness gates; this is source inspection,
  not a new runtime VoiceOver or Reduce Motion pass. The stale-source “Not reporting” behavior
  is unchanged from `HeartRateBar`.
- Read `/tmp/wt-floodlight/results/live-ui-1.log` and its actual result bundle with
  `xcresulttool`: **45 tests, 40 passed, 5 failed, 0 skipped**; specifically **33 UI tests
  (28 passed / 5 failed) plus 12 passing domain tests**. The log records **EXIT 65**. Ticket 03's
  “31 UI” parenthetical is incorrect. `base-5.log` and `base-5.xcresult` confirm the same five
  test/assertion failures on the baseline run. The baseline result is Failed, 0 passed / 5
  failed / 0 skipped; its log does not record a numeric shell exit.
- `build-live.log` ends in `BUILD SUCCEEDED`; ticket 03 claims exit 0, but that log does not
  retain the numeric exit. No fresh build was run. The Core Loop and Heart Rate edits only
  replace cleanup with `discardActiveWorkout()`; the helper still opens and confirms discard,
  and their functional assertions remain intact.
- No `xcodebuild` or `simctl` commands were run. Only this report was written. Existing
  untracked `opencode.json` was left untouched; STATE is stale and was not treated as evidence
  of this branch's implementation or verification.

**Axis totals:** Standards — 2 findings, worst medium; Spec — 4 findings, worst medium.
