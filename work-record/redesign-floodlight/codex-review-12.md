# Ticket 12 — independent Codex review

**Not clear.** Reviewed `af30f66..0fddd52ef8d84b03344218599108810565c1cf35` on
`ericlee4992/redesign-floodlight-cardio`, in `/tmp/wt-floodlight/cardio`.
Claude authored the implementation. The checkout was clean before this report.
Findings below are source-traced unless a capture is named; no new app execution is claimed.

## High

### 1. Bound split generation before deriving views from entered distance

**`WorkoutTracker/Domain/CardioReadout.swift:115`**, also
`WorkoutTracker/Features/Cardio/CardioCards.swift:38`, `:306`, `:444`.

For a saved outdoor segment with a route, enter `999999` km in Distance. This is six characters,
passes the new sheet's validation and `CardioSession.enterDistance`, and immediately makes the
receipt/History derive **999,999 splits**. Each crossing scans the cumulative route from the
beginning, and the view then constructs a row for every split. The History map independently
creates nearly a million markers. This work runs synchronously in view evaluation and can make
the saved workout unusable through excessive main-thread work and memory use. The previous cards
formatted this value without expanding it into rows. Bound the derived output/work and handle
out-of-range data without changing the stored entered value. Add a targeted oversized-distance
case. There is a related unchecked conversion at `CardioReadout.swift:47`: an existing finite
manual value of `1e19` km, accepted by the old editor/domain, traps at `Int(whole)` when its live
distance ring is rendered.

## Medium

### 2. Opening Distance can rewrite the existing value before the user edits it

**`WorkoutTracker/Features/Cardio/CardioDistanceSheet.swift:99`**, initialization at `:67`,
and `WorkoutTracker/Features/Cardio/CardioSupport.swift:48`.

The `onChange` sanitizer also processes the value loaded by `onAppear`. A previously stored
`12.34567` becomes `12.345`; `0.000001` loads as `1e-06` and becomes **`106`**. `initialText`
retains the original, so opening the sheet enables Save without an edit; Save overwrites the
distance and stamps the finished workout edited. The old editor retained both values. The same
filter silently changes pasted `-1` to `1` and `1e3` to `13`, bypassing the invalid-entry state.
Preserve the initialized value and validate complete input instead of removing meaningful
characters. Cover existing precision, scientific notation, invalid paste, and unchanged Save.
This violates the preserved entered-value semantics and the ticket's valid-change Save rule.

### 3. Editable indoor states lose `cardioDistanceMetric`

**`WorkoutTracker/Features/Cardio/CardioLive.swift:165` and `:291`.**

Start an indoor segment without measured distance: the Distance figure has only
`cardioEditDistance`. Enter a positive distance without a planned target: the resulting distance
ring also has only `cardioEditDistance`. Neither state contains `cardioDistanceMetric`.
The old screen exposed both handles, and ticket 12 explicitly preserves the metric identifier
as it moves between ring and figures. Keep an independently queryable metric as well as its edit
action, with exactly one timer and one distance metric in every ring/editability combination.
The current tests check the metric only in measured states and miss this regression.

### 4. A recorded zero distance is displayed and announced as missing

**`WorkoutTracker/Features/Cardio/CardioSupport.swift:28`**, consumed by live figures,
ended cards, receipt, History and the Measured row.

Enter and save `0` for an indoor segment. The domain deliberately accepts zero and distinguishes
it from clearing the field, but the new formatter returns `—` for both zero and nil. In the live
table VoiceOver consequently says “Entered distance no reading”; the receipt says “none”.
The old view showed `0.00`. Keep zero as `0.00` with its unit; only unavailable distance should
use the missing-value treatment. Pace may correctly remain unavailable for zero distance.

### 5. The snapshot cache can put a route over the wrong map

**`WorkoutTracker/Features/Cardio/CardioCards.swift:511`**, task identity at `:374`.

Two routes with the same first coordinate and point count, but different later coordinates/bounds,
produce the same cache key at a given size/appearance. Opening the second after the first reuses
the first map image, while `routeLayer` projects the second route using its own bounds. For
example, equal-length point arrays starting at the same trailhead and heading north versus east
display different geographic extents but share the image. The task identity omits coordinates
entirely, so replacing an equal-count route in an existing view also cannot refresh it. Key both
the image and task by the actual snapshot projection, size and appearance, and discard canceled
render results. A failed render already correctly leaves the grid.

### 6. The live figures overtake the ring at AccessibilityL

**`WorkoutTracker/Features/Cardio/CardioLive.swift:79`, `:107`, `:193`**, and
`WorkoutTracker/Features/Cardio/CardioSupport.swift:355`.

The AccessibilityL ring centre is fixed to approximately 40 pt (`190 * 0.212`), while the table
defaults to the Dynamic-Type-scaled `bigNumber`. In
[`C02-p2-light-axl.png`](captures/12/C02-p2-light-axl.png), the `2.44`, `6:59`, calories and heart
figure are larger than the ring's `13:27`; the initial dark/light AccessibilityL captures show the
same reversal. Ticket 12 calls the ring centre the bold element and explicitly demotes the table
to smaller stat numbers. Keeping the approved compact ring requires scaling/demoting its
runner-up figures accordingly. This fails REVIEW items 1, 4 and 9; retake the affected captures.

## Low

### 7. Omitting a sub-metre split tail also omits its elapsed time

**`WorkoutTracker/Domain/CardioReadout.swift:115–120`.**

Consider 2,000.5 m with unit crossings at 300 and 600 active seconds, followed by the final half
metre and Finish at 660 seconds. The loop emits two 300-second splits and exits because less
than one metre remains. The last 60 seconds disappear from the split accounting. Omitting a
rounding-sized distance row is reasonable, but its time should be folded into the final emitted
split. Test this alongside exact-unit totals and ordinary partial tails.

### 8. Cycling split accessibility labels announce pace instead of the displayed speed

**`WorkoutTracker/Features/Cardio/CardioCards.swift:333–335`.**

A cycling split displayed as `18.0 km/h` is announced as `3:20 per km`; partial-tail labels have
the same mismatch. The visible value branches on `usesSpeed`, but its accessibility label does
not. Use the same value and unit for the visible and spoken figures, and test cycling splits as
well as running splits.

## Verification and design assessment

- Read AGENTS, STATE, tickets 01/12, the relevant SPEC/DECISIONS, DEVELOPMENT verification scope,
  ios-design SKILL/REFERENCE/REVIEW, the old cardio views, the requested prototype sources, the
  changed source/tests and their recorder/host callers. Reviewed both-appearance Default and
  AccessibilityL comparison sheets and inspected current individual captures for the live
  figures, picker, GPS plate, ended card, Distance, receipt and History. Some older intermediate
  contact sheets still show defects fixed before HEAD; those were not treated as current findings.
- REVIEW 1–12: the hierarchy failure is item 6 above; the identifier failure affects item 11.
  Grouping, placement, appearance tokens, controls, staged sheet commits and the scrolling tray
  were checked against the ticket. The current AX Distance readout and split pace wrapping fixes
  are present. Motion was traced through pulse, blink, signal bars, ring, press feedback,
  BeatingHeart and celebration: Reduce Motion gates their movement; the map uses an opacity fade.
  This is source/capture review, not runtime Reduce Motion or human VoiceOver acceptance.
- Explicit picker Start, Home's chosen activity, planned Start through `startPlannedCardio`,
  replacement protection, Pause/Resume/End through the recorder, and no map before Finish are
  preserved. The live manual editor uses the indoor/no-measurement-or-typed rule. Ended and saved
  corrections remain available as before, including the explicitly retained receipt edit.
  Blank clears the manual pair; unit selection relabels; the domain marks History only when
  the stored manual pair actually changes.
- Pause/recovery, target precedence, ordinary route scaling/portion separation, last-done
  filtering, positive-window heart buckets, stale heart-rate gating and location-message mapping
  were traced. No new defect was established in those paths. The heart source caption removal
  is declared in the ticket; zones still have the plate action when a reading exists and the
  existing Settings route. Additional cardio-only History segments remain as cards. Fixture
  arguments require `-uiTestReset` and use the isolated test store.
- Read actual `.exit` files/logs and existing xcresult summaries. `cardio-build-2`: exit 0;
  `cardio-ui-2`: 45 passed/2 failed (27 domain, 18/20 UI); `cardio-ui-4`: 18/19 passed;
  focused recovery runs `cardio-ui-3` and `-6`: 2/2 each; `cardio-ui-7`: 5/5, exit 0,
  zero failures/skips. Earlier result bundles contain the documented invalid-frame warnings;
  the inspected `-6`/`-7` summaries contain none. These are existing results, not new test runs.
- The selected neighbouring classes are proportionate under DEVELOPMENT; a blanket full suite
  is not required for these fixes. Add focused coverage for the findings. The negative
  `exists` checks in lazy lists do not alone prove absence offscreen, and
  `FloodlightCardioUITests.swift:129` should assert the Start button exists before testing that
  it is disabled. The new class also never commits the preselected picker target, taps the
  receipt's distance editor, or opens zone setup; add those action assertions. The migrated
  positive value/unit checks remain meaningful, but do not cover editable metric identifiers.
  The captures/tests do not establish the zone-coloured heart trace, invalid Distance state,
  or several-segment cardio-only History layout; cover those specific states when verifying fixes.

Only this report was written. No `xcodebuild` or `simctl` command was run, and no product,
test, ticket, STATE, prototype or capture file was changed.
