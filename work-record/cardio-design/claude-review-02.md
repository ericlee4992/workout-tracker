# Claude review 02 — follow-up on R1–R3 (design-only)

Reviewed: commit `48608fb` on `ericlee4992/cardio-design-prototype`, diffed against `4f004be`.
Reviewer checkout: `review-cardio-design`, unchanged and still at `4f004be`; the follow-up commit
was fetched and read from Git, and its PNGs were extracted from the commit object into the
reviewer scratchpad. Nothing in this checkout was modified except this file. Reviewer: Claude,
independent of the author. Date: 2026-09-17.

Scope: only the fixes to R1–R3 from [review 01](claude-review-01.md) plus the touched Start and
summary visuals. Not a fresh exhaustive pass. No simulator runs, no code edits.

## Verdict

**CLEAR.** R1, R2 and R3 are resolved in both the record and the render. The touched Start and
summary screens are consistent with the shipped app's chrome and components. Two advisory notes
below are judgement only and do not block.

## Evidence checked

| Item | Result |
|---|---|
| Source diff `4f004be..48608fb` | Only `CardioDesignPrototype.swift` and `CardioPrototypeCaptureUITests.swift` changed under source; `WorkoutTrackerApp.swift` is untouched, so the DEBUG + `-uiTestReset` + `CARDIO_SCREEN` gate from review 01 still holds and the prototype file is still wrapped in `#if DEBUG`. |
| Build / recapture 3 | `build-3-exit.txt` = 0, `captures-3-exit.txt` = 0. `captures-3.log` shows 2 tests executed, 0 failures. `capture-summary-3.json`: result Passed, 2 passed, 0 failed, 0 skipped, empty `runtimeWarnings`. The only warnings in the log are pre-existing compiler warnings in production files, not from the prototype. |
| Prototype checkout | `cardio-design-prototype` is at `48608fb` with a clean tree, so its `screenshots/` folder equals the commit's PNGs. |
| PNG set | 37 files. Eight byte-identical pairs remain (seven AXL `scroll2` = `scroll1`, plus `mixed-C-default-scroll1` = `mixed-C-default` because C fits in one default viewport). The gallery's `captureSets` table omits exactly those eight, giving the 29 distinct views the ticket claims. |

## R1 — A's above-fold claim (resolved)

- Ticket tell now reads per variant: A keeps lifting first and at AccessibilityL the timer and
  controls need a scroll past completed lifting; B leads with the live activity; C keeps
  chronology and may also need a scroll; the expanded gym/outdoor views pin the controls. The
  job sentence no longer promises one tap in the collapsed mixed state. The gallery card for A
  says the same in plain words while keeping "Suggested starting point" as a familiarity
  recommendation. That is an honest description the user can choose against.
- C's fixture now matches A/B (lifting then run; the extra sample walk is gone), so the three
  directions differ in structure only, as the skill asks.
- Captures confirm: `cardio-mixed-A-axl.png` first viewport still ends at the card title (as
  disclosed); `cardio-mixed-A-axl-scroll1.png` shows timer, metrics, distance and both controls.

## R2 — Zone colours (resolved)

- `CardioDesignPrototype.swift` now uses `HeartRateZone.two.color` (gym) and
  `HeartRateZone.three.color` (outdoor). `cardio-gym-A-default.png` shows "Zone 2" in the
  shared teal and `cardio-outdoor-A-default.png` shows "Zone 3" in the shared green; no unit or
  warmup colour remains on a zone label.

## R3 — Primary control in A/B/C (resolved)

- New `mixedControls`: Pause `.primary`, End Cardio `.secondary`, both `maxWidth: .infinity`,
  side by side in an `HStackLayout` at default and a `VStackLayout` at accessibility sizes.
- Captures: `cardio-mixed-A-default-scroll1.png`, `cardio-mixed-B-default.png` and
  `cardio-mixed-C-default.png` each show one amber Pause and one neutral End Cardio of equal
  width; `cardio-mixed-A-axl-scroll1.png`, `cardio-mixed-B-axl-scroll1.png` and
  `cardio-mixed-C-axl-scroll1.png` show them stacked full-width. The timer remains the only
  `hero`, so each mixed screen has one bold figure and one primary control, matching the ticket.
- The capture driver now takes a default-size scroll for every mixed variant, so End Cardio is
  on record at default for A and B; for C it is already in the first viewport.

## Touched Start and summary visuals

- **Start.** The painted stand-in bar is gone; the screen runs inside a real `TabView`, so
  `cardio-start-A-default.png` shows the native floating bar and `cardio-start-A-axl.png` no
  longer hyphenates labels. The template card's accent "Start" pill is replaced by a neutral
  chevron, leaving Start Lifting as the single accent call to action. The Templates "+" and the
  A-card expand button now carry 44 pt minimum frames.
- **Summary.** The six combined metrics reuse the shipped `StatTile` in a two-column grid that
  collapses to one column at AccessibilityL (`cardio-summary-A-axl.png`, `-scroll1.png`), and
  View in History is full width. Pairs and order match ticket 17's accepted finish summary.

## Advisory (judgement, not blocking)

- **A10 — Tab order and symbols differ from `RootView`.** The prototype's tabs run Workout,
  History, Exercises, Gyms, Settings with `clock` and `dumbbell`; production runs Workout,
  History, Gyms, Exercises with `clock.arrow.circlepath` and `list.bullet.rectangle`. Harmless
  for the Start decision, but if a Start capture is ever shown beside a real one the bar will
  not match. Copy the `RootView` tab items if the prototype is recaptured again.
- **A11 — A's controls at default sit under the pinned bar in the first viewport.**
  `cardio-mixed-A-default.png` clips the top of Pause/End Cardio behind the Add bar. This is the
  same fold trade-off R1 now discloses for AccessibilityL, but the gallery text only mentions
  larger text. One clause ("at default the controls sit just below the first screen") would make
  the A card fully accurate.

Earlier advisory items A1–A9 from review 01 were addressed where the author chose to (A1, A2,
A4, A8) or remain judgement (A3, A5, A6, A7, A9); none is required.
