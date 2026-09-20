# Claude T6 review — cardio ticket 06 (app unit system, automatic indoor metrics)

Reviewer: Claude (independent; Codex/parent implemented). Date 2026-09-19.
Range `e457493..d4de3d8` on `ericlee4992/cardio-units-and-sources`. Read against
[ticket 06](issues/06-unit-system-and-indoor.md), SPEC Units, DECISIONS T7/D9/D15/D52/D54,
and the ios-design skill. **Code review only.** No simulator run, no product edits, by
instruction. Visual review and test-result inspection are still owed (see Pending).

## Verdict

**Code: clear to proceed to captures and the full UI gate, with one recommended one-line fix
(F1) and low notes.** No finding breaks stored data, the new-cardio-only rule, or the schema.
**Not a merge clearance:** captures were not seen and unit/UI results did not exist when this
was written.

## What I verified in the source

- **New cardio only.** `CardioSession.start` (Cardio.swift:266–286) resolves
  `AppPreferences.canonical(in:)` → `AppUnitSystem.resolve(...).distanceUnit` once and writes it
  to `displayUnitRawValue` at creation. Nothing else in the diff reads the preference for
  cardio; live and saved views read only `segment.unit`. A preference switch therefore cannot
  touch an active or saved segment. Both production callers (`CardioRecorder.swift:104`,
  `WorkoutStartFlow.swift:98`) pass no unit, so both get the app preference; both fixtures
  pass `.km` explicitly, so the override path stays exercised.
- **No schema change.** `AppUnitSystem` is a pure enum over the existing
  `AppPreferences.unitPreference: WeightUnit?`; the Settings binding writes
  `newValue.weightUnit`. Export (`ExportCollector.swift:438`) still writes the same kg/lb field.
  Lifting precedence consumers (`UnitPrecedence`, WorkoutSession:908, finish sheet, progress,
  Start) are untouched; `firstLaunchDefault` returns the same values as before (US→lb, else kg).
- **Entered values.** `enterDistance` is unchanged: the typed `(value, unit)` pair is stored
  verbatim and the segment's display unit follows the typed unit — the user's own act, not the
  preference. Covered by `explicitUnitsAndEnteredDistanceSurvivePreferenceChanges`.
- **Hidden rows.** Live editor condition is
  `!isOutdoor && (distanceMeters == nil || manualDistanceValue != nil)` (CardioViews.swift:139):
  no data → "Enter distance"; manual value → editor stays to revise/clear; automatic → hidden.
  `distanceSourceCaption` now returns "Entered distance" for manual, "GPS" for GPS, nil for
  HealthKit / phone motion / mixed / none — so saved indoor cards read "Distance" and saved
  outdoor cards are unchanged. The saved editor button is unconditional, including on an ended
  segment inside a still-running workout, so correction is reachable without finishing.
  Source/spans/readings are not touched by any of this; provenance stays stored and exported.
- **Motion error copy.** "Motion data unavailable." — the removed instruction could otherwise
  point at a hidden editor. When the error leaves distance nil, the editor is directly below.
- **Fixture guard.** `CardioIndoorFixture.isEnabled` goes through
  `WorkoutTrackerStore.fixtureIsEnabled`, which requires `-uiTestReset`; unit-tested both ways.
- Build: `results/cardio-units/build-exit.txt` = 0 (read directly). Units/focused UI had no
  exit file yet.

## Findings

### F1 — Low/Medium: a zero or near-zero automatic reading hides the live manual editor
`CardioSegment.acceptDistance` and `CardioRecorder.acceptPhoneDistance` accept `meters >= 0`.
A first sample of 0 m makes `distanceMeters == 0` (non-nil), so the live screen shows
"0.00" and removes "Enter distance". Same for a few metres of steps before the phone goes on
the treadmill console — the stationary-phone case still open in ticket 02. The user can then
only correct after End Cardio (saved editor). That is consistent with the ticket's words
("once automatic distance arrives") and correction is not lost, so it does not block; but
"0.00 with no way to enter distance" is not what "no-data/manual input stays" intends.
**Recommend:** treat only a positive automatic distance as measured, e.g.
`(segment.distanceMeters ?? 0) <= 0 || segment.manualDistanceValue != nil`, plus a unit/UI
assertion. Record the small-non-zero consequence (live correction requires ending the segment)
in the ticket so it is not rediscovered as a bug during hardware acceptance.

### F2 — Low: "No distance source" caption also disappears
Before, a no-data indoor segment showed the caption "No distance source" above "Enter
distance"; `distanceSourceCaption` now returns nil there. Reasonable under D52/ticket 06
("no technical source captions"), and no test reads the string, but the ticket lists only
automatic captions. Name it in the ticket as deliberate. `distanceLabel`'s fallback is now
unreachable from UI (export unaffected).

### F3 — Low: test coverage that moved or went away
- The "Measured: …" line in the distance sheet is no longer asserted anywhere (it was the
  old arrival signal). The saved-editor test could assert it cheaply.
- `testDistanceEditorDoesNotFreezeAnUntouchedMeasurement…` now runs on an ended segment, where
  the measurement cannot advance; the "does not freeze" half of its name is no longer tested
  in a live state. The remaining live-editor state (manual value present while sensors keep
  reporting) has no test that clearing returns to the moving measured value.
- `cardio-built-editor-{default,axl}` captures are no longer produced, while
  `work-record/cardio/gallery.html:27–28` still links them. Existing files remain valid
  history; regenerate from the manual path or note the gap.
- `waitForAutomaticDistance` matches any `N.NN` static text; "0.00" would satisfy it (ties to F1).

### F4 — Low (docs): D15 trail
The ticket says it reopens D15/D54 presentation; DECISIONS records the change under D52 and
T7 only. The content is recorded and the placement is sensible; add a one-clause pointer in
D15 (or drop the D15/D54 claim from the ticket) so the two agree.

### Notes, no action
- `CardioSegment.init`'s default `.localeDefault` now means "locale, no preference". No
  production caller relies on it (only `start`, which always passes a unit). Harmless.
- `start` now throws before ending the previous segment if the preference fetch fails;
  previous behaviour could not fail there. A fetch failure would fail the later save too.

## Design (from source only; captures owed)
Ticket 06 carries the composition block and tells list the skill requires. The change removes
a duplicate equal-weight block and a caption, adds no container, accent or copy beyond the
user-requested "Metric" / "U.S. customary", and keeps the native menu picker. To check in the
captures: "U.S. customary" beside "App unit preference" at AccessibilityL (wrap, not truncate);
indoor measured live screen ends cleanly at the Add actions with no orphan gap where the
editor was; saved indoor card's "Distance" edit row still reads as a control.

## Pending before merge clearance
1. Units exit/`TEST` line (752 expected) and the 9 focused UI tests — read the logs, not a summary.
2. Default + AccessibilityL captures: Settings (both choices), indoor measured live/details,
   U.S. cardio, saved indoor card.
3. Full local UI suite (85 expected) exit 0.
4. F1 decision (fix or explicitly accept in ticket); F2/F4 wording.

## Follow-up — decisions on findings (2026-09-19, code-only)

Read the implementer's uncommitted follow-up in the implementation worktree (not yet on the
branch; re-check once committed).
- **F1 accepted by decision — closed.** Rationale recorded in ticket 06: a real automatic zero
  is a measurement; the user wants no duplicate row during automatic tracking; nil still
  offers Enter distance, manual overrides stay live-editable, low/zero readings are corrected
  after End. Consistent with the source I read. Carry the stationary-phone consequence into
  ticket 02 hardware acceptance.
- **F2 closed** — removal named deliberate in the ticket.
- **F3 resolved in part** — test renamed `testSavedDistanceEditorKeepsEnteredUnitsAndUntouchedMeasurements`
  and the "Measured:" assertion restored (diff read). Live clear-manual-and-resume UI test
  remains absent; ticket says so and domain clear-override tests exist. Accepted low.
- **F4 closed** — D15 now points to D52/T7/ticket 06 (diff read).
- **Units:** initial full run is **not a pass**: 750/752, the two failures are exactly the
  flakes named in `docs/DEVELOPMENT.md:45–46`; none touch this diff. xcodebuild hung and was
  interrupted. Clearance still needs the rerun's own exit files/TEST lines, focused UI (9),
  captures, and the full UI suite. No merge clearance yet.

## Follow-up 2 — HeartRateMonitor clock injection (uncommitted diff read, code-only)

Scope expansion for testability after the full rerun failed the same two documented liveness
flakes (750/752, exit 65 — not a pass). **Clear; production default is equivalent.**
- `init(..., clock: @escaping () -> Date = { .now })`, stored `@ObservationIgnored`. The default
  closure evaluates `.now` on every call, exactly what `current`, `isStale` and
  `refreshLiveness()` did inline. All wall-clock reads in the monitor class now go through it
  (`grep`: lines 122, 130, 249; the ingest path's `refreshLiveness()` at 229 included). The
  remaining `.now` uses (351–365) are the fixture provider's own sample dates, untouched.
- `refreshLiveness(asOf: Date? = nil)` stays source-compatible: the only production caller
  (`ActiveWorkoutView.swift:362`) passes nothing; tests passing an explicit date still compile
  and behave as before.
- No production call site passes a clock, so nothing in the app can run on a non-wall clock.
- Tests: both flaky cases now use a fixed clock with samples dated at that clock, and still
  assert state produced by real ingest (`samples.count`, `current`, `.live(...)`, `!isStale`)
  with no manual refresh added — the fix removes the wall-clock race, not the check. New
  `advancingInjectedClockMakesAQuietFeedStale` proves the injected clock actually drives
  staleness and `.waitingForSensor`. Added `stop()` calls are hygiene.
- Low note: `CardioRecorder` keeps its own clock; a test that fixes one and not the other
  could disagree. No production effect.

Still owed: build + targeted, full units (753 expected) exit 0, focused UI (9), captures, full
UI (85). Re-check this diff once committed.

## Follow-up 3 — committed tip `dc08ea8` (code-only)

`d4de3d8..dc08ea8` read from the pushed branch: `6a6e7d4` (ticket/D15 wording, renamed saved
editor test + "Measured:" assertion) and `dc08ea8` (monitor clock). The committed
`HeartRateMonitor.swift` diff is byte-for-byte the one cleared in Follow-up 2; test changes
match (two fixed-clock cases asserting real ingest state, one clock-advance regression).
Implementation worktree clean at `dc08ea8`. DEVELOPMENT wording now matches the code.
**Clock change: clear.** F1–F4 dispositions confirmed on the branch.

Evidence read directly from `results/cardio-units/`: `stable-build-exit.txt` 0;
`stable-timing-exit.txt` 0 with "32 tests in 3 suites passed" and `** TEST SUCCEEDED **`.
Earlier `units-exit.txt` 143 (interrupted) and `units-rerun-exit.txt` 65 remain failures of
record, superseded only by a passing stable full run. Owed: stable full units 753 exit 0,
focused UI 9, captures (default + AXL), full UI 85.

## Follow-up 4 — unit gate verified (artifacts read directly, no simulator use)

- `stable-units-exit.txt` 0; log: "Test run with 753 tests in 82 suites passed",
  `** TEST SUCCEEDED **`. `xcresulttool` on `stable-units.xcresult`: Passed, 753/753,
  0 failed, 0 skipped, 0 expected failures; new `AppUnitSystemTests` and
  `advancingInjectedClockMakesAQuietFeedStale` are present in the result.
- `stable-timing.xcresult`: Passed, 32/32, 0 failed/skipped; exit 0.
- Freshness: the stable build/unit run (23:32–23:34 EDT) finished about a minute before
  commit `dc08ea8` (23:33:49), i.e. it ran on the then-uncommitted tree. I had read that
  uncommitted diff and the committed one is identical, and the worktree is clean at
  `dc08ea8`, so the result stands for the tip. The pre-merge build on clean main still applies.

**Unit gate: clear. Clock change: clear (re-reviewed at the committed tip).**
Owed for merge clearance: focused UI 9 exit/result, default + AXL captures (Settings,
indoor measured, U.S. cardio, saved card), full UI 85 exit 0.

## Follow-up 5 — focused UI 8/9 and first captures (artifacts read; no simulator use)

- `focused-exit.txt` 65; `focused.xcresult`: Failed, 9 total / 8 passed / 1 failed —
  `testUnitSystemAccessibility()`, `XCTAssertTrue failed`. **Not a pass.** Implementer's
  diagnosis (full `swipeUp` at AXL overshoots the live metrics onto the ended run) is
  consistent with the old test code (`app.swipeUp()` then wait for "mi/h"); the earlier
  assertions in that test (new km, km retained after switching, new mi) had already passed,
  so the product behaviour under test was observed before the scroll failed.
- Uncommitted test-only fix `revealCardioSpeedUnit()` read: small-step drags until "mi/h" is
  hittable, below y 120 and above the pinned controls, then asserts. It strengthens the
  assertion (visible above controls, not merely existing) and touches no product code. Clear
  as a test change. Low: `minY > 120` still lets the metric *labels* sit under the floating
  header — see capture note.
- Captures seen (`initial-shots/`):
  - `unit-settings-us-default`: row reads "App unit preference — U.S. customary ⌃⌄" on one
    line, native menu affordance, amber value consistent with other tappable values. Pass.
  - `unit-settings-us-axl`: label and value stack on two lines, nothing truncated, steppers
    and toggle intact. Pass.
  - `unit-cardio-us-default`: new Indoor Cycle shows mi and mi/h (also "Current speed … mi/h")
    while the ended Indoor Run card in the same workout stays km and /km — the new-only rule
    is visible on one screen. Saved card ends with a plain "Distance ✎" row, no source
    caption. Pass on behaviour. **Capture quality (low):** the shot is mid-scroll; the
    "Distance"/"Average speed" labels are clipped under the floating header and the timer
    ghosts behind it. Raise the reveal threshold (≈160–180 pt) or scroll to top for the
    record image.
- Not yet seen: metric Settings pair, `indoor-measured-*` and `indoor-measured-details-*`
  (default + AXL), `unit-cardio-us-axl`, saved indoor card at AXL.

Owed: Settings pair rerun result (both exit 0), a clean focused set on the committed tip,
the remaining captures, full UI 85 exit 0.

## Follow-up 6 — visual clearance at `cda7fd4` (artifacts and PNGs read; no simulator use)

Branch `dc08ea8..cda7fd4`: UI-test helper, docs and 21 PNGs only — `git diff` over
`WorkoutTracker/` and `WorkoutTrackerTests/` is empty, so product and the 753-unit result stand.
- **Settings pair:** `settings-verified-exit.txt` 0; `settings-verified.xcresult` Passed 2/2,
  0 failed (queried directly). Helper read: `selectUnitSystem` now skips the menu when already
  selected, waits for the option to disappear and for the row label to contain the choice;
  Back is scoped to the Settings bar and Resume is awaited. All waits are on real UI state,
  none weaken an assertion. `revealCardioSpeedUnit` unchanged from Follow-up 5. Clear.
- **Captures** (`work-record/cardio/screenshots/units-and-indoor/`), judged against ticket 06's
  composition and the ios-design review tells:
  - `indoor-measured-{default,axl}` and `-details-*`: timer is the landing point, Distance
    1.00 km / Average pace beneath, Pause at the thumb. No "Phone motion estimate", no
    duplicate distance/editor row, no leftover gap — the list runs from "Waiting for
    heart-rate data" straight into the Add actions. AXL is one column, nothing truncated in
    the metrics; controls stack. Pass.
  - `unit-settings-*` (from Follow-up 5, re-shot): one line at default, clean two-line wrap at
    AXL. Pass.
  - `unit-cardio-us-default`: now a clean top-of-screen shot — new Indoor Cycle in mi / mi/h
    with the ended Indoor Run card still km and /km. My earlier capture-quality note is
    resolved for default. `unit-cardio-us-axl` is still mid-scroll (header ghosting) but shows
    mi, mi/h and "Current speed … mi/h" unobstructed above the controls. Accepted, low.
  - `cardio-built-summary-axl-2`, `cardio-built-mixed-history`: saved indoor cards end in a
    plain "Distance ✎" row at caption weight, 44 pt row, no source caption, in finish summary
    and History. Pass.
- Observations, no action: header timer and pace tick a second apart (5:22 vs 5:23 — average
  pace is computed at the recorder's measurement time; pre-existing). AXL "Add Cardio" peeks
  beneath the pinned controls; pre-existing scroll-under behaviour. The saved "Distance ✎" row
  repeats the word of the metric above it; this is the pre-existing HealthKit presentation
  now applied to all automatic indoor sources, as the user asked.

**Visual: clear. Code: clear. Units: clear (753/753).** The 9-case focused set passed across
two runs (7 cardio in `focused`, 2 Settings in `settings-verified`), not in one run on the
tip; the full 85-test UI suite on the current tip covers that and is the remaining gate.
**Merge clearance is conditional on full UI exit 0 with `** TEST SUCCEEDED **` on `cda7fd4`
(or a later test/docs-only tip), plus the pre-merge build on clean main.**

## Follow-up 7 — build gate wording corrected

My "pre-merge build on clean main" condition in Follow-ups 4 and 6 was wrong: main
(`e457493`) still holds the old product, so building it verifies nothing about this change.
Withdrawn. Because main is an ancestor of the branch, the fast-forward makes merged main
byte-identical to the verified tip, so the feature-tip evidence is the pre-merge build gate:
`stable-build-exit.txt` 0 on the feature product, and the full `xcodebuild test` run builds
the current tip again. `cda7fd4..a262e77` is records only (STATE + ticket; checked).

**Final gates:** (1) full UI 85 on `cda7fd4` exit 0 with `** TEST SUCCEEDED **` → merge
clearance, provided later commits stay records/test-only and the merge is `--ff-only`.
(2) After merge, per DEVELOPMENT and before installation: fresh signed device build from
clean merged main, with binary-freshness and launch checks — an install gate, not a merge gate.

## FINAL — merge clearance (2026-09-20, artifacts read independently; no simulator use)

**CLEAR TO MERGE** `ericlee4992/cardio-units-and-sources` into `main` with `--ff-only`.
- `full-ui-exit.txt` 0 (written 00:58:36 EDT). `full-ui.log`: "Executed 85 tests, with 0
  failures (0 unexpected)", `** TEST SUCCEEDED **`; no canceled/interrupted markers.
- `full-ui.xcresult` queried directly: Passed, 85/85, 0 failed, 0 skipped, 0 expected
  failures; contains the new unit-system, phone-motion and saved-editor cases.
- Freshness: run started 00:02:38 EDT, after `cda7fd4` (00:01:48) and `a262e77` (00:02:36);
  `cda7fd4..a262e77` is STATE + ticket only, no diff under `WorkoutTracker*`. main is an
  ancestor of the tip.
- Finalisation: the implementer stopped only the optional `simctl diagnose` child after all
  tests had finished; xcodebuild then exited 0 on its own and the result bundle is complete
  (85 executed, none skipped). I accept this as a pass, not an interrupted run.
- Standing: code clear (F1 accepted by decision, F2/F4 closed, F3 partly resolved/accepted
  low), clock change clear, units 753/753, visual clear.

Conditions: commits after `a262e77` before merge must be records-only (the implementation
worktree currently has uncommitted STATE/ticket edits — fine). Not covered by this clearance:
the post-merge fresh signed device build, binary-freshness, backup and launch checks required
before installation (DEVELOPMENT); hardware items in ticket 02, including the
stationary-phone/low-reading consequence of F1.
