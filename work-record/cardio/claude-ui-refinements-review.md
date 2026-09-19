# Claude independent review — cardio UI refinements (ticket 03)

Reviewer: Claude (T6 independent review; Codex/parent implemented and retains merge).
Scope: `21ef98f..3020180` on `ericlee4992/cardio-ui-refinements`. Review only; no product,
test or doc file changed by this review. Read: STATE, [ticket 03](issues/03-ui-refinements.md),
D15/D54/T6, cardio spec, `ios-design` SKILL/REFERENCE/REVIEW, the full diff and its callers.

## Status

| Part | Verdict |
|---|---|
| Initial code/spec/test review (2026-09-18) | **Clear to continue verification; no blocking defect.** One test finding (T1) should be fixed before merge; L1/L2 are decided from the captures |
| Visual review of default/AccessibilityL captures | **Pending** — focused run still in progress when this was written (`focused-exit.txt` empty; one CardioUITests case passed in `focused.log`). Not a merge clearance yet |

Evidence I verified myself: implementation worktree is at `3020180` with only the ticket file
modified; `build-exit.txt` = `0`. I did not run builds or tests (WT-iPhone is in use by the
parent's focused/full runs). Focused/full UI results are **not yet verified by me**.

## Requirements against the code

1. **HealthKit estimate caption removed — met in code.** The only UI readers of
   `CardioSegment.distanceLabel` are the live distance button and `CardioSummaryCard`'s edit
   row (`CardioViews.swift:139`, `:234`); both now go through `distanceSourceCaption`
   (`:317-322`), which returns nil only for an automatic HealthKit distance. `CardioSummaryCard`
   is the single component used by the in-workout completed list, the finish receipt
   (`WorkoutFinishedSheet.swift:129`) and History (`WorkoutDetailView.swift:178`), so all four
   surfaces in the acceptance list are covered. "Entered distance", "Phone motion estimate",
   "GPS", "Mixed distance sources" and "No distance source" still show. The domain label
   (`Cardio.swift:37`), `distanceSourceRawValue` and the export fields
   (`ExportCollector.swift:300`, `ExportCSV.swift:92`) are untouched: provenance is kept.
   No other screen, widget or Live Activity renders the string.
2. **Maps only in finished Summary and History — met in code.** `CardioRouteMap` has exactly
   one remaining call site (`CardioViews.swift:231`), gated by `showsRoute`. The live view's map
   is deleted; the in-workout completed list passes `showsRoute: false` (`:74`); the two
   default-`true` callers are reachable only for finished workouts (the receipt renders
   `savedWorkout`; History's query is `finishedAt != nil`). Route recording, storage and
   `recorder.locationMessage` are unchanged.
3. **Start Cardio beside Start Lifting — met in code.** One row, `AnyLayout` HStack/VStack on
   `dynamicTypeSize.isAccessibilitySize`, both labels `maxWidth: .infinity`; identifiers
   `startEmptyWorkout` / `startCardio` kept (all 40-odd test lookups are by identifier; no test
   reads the removed symbol or arrow). Custom button styles mean the two buttons in one List
   row take their own taps. Resume state and the start/cardio-picker flow are unchanged.

Docs: D15 amendment names D54 explicitly (AGENTS "reopen explicitly" satisfied); SPEC, cardio
spec and ticket 02 are consistent with the code. No schema, sensor or domain change — confirmed.

## Findings

**T1 — Medium (test): the "no HealthKit estimate" assertion can pass vacuously.**
`CardioUITests.swift:78-79` asserts absence immediately after reaching the button. The old test
had to *wait up to 10 s* for that caption, because the fixture delivers the measurement
asynchronously; before it arrives the caption is "No distance source" under old and new code
alike. So the assertion does not prove the removal. Move/repeat it after the `Measured:` wait
and sheet Cancel (`:81-82`), when the source is known to be HealthKit. Related gap: the test
then enters a manual distance, so no test covers a HealthKit-sourced segment in the completed
card, receipt or History (acceptance line 1). Risk is low because all surfaces share
`distanceSourceCaption`, but a check that the summary edit button's label is "Distance"
(it is a button label, not a `staticText`) in one HealthKit-sourced flow would close it.

**L1 — Low (design rule 7, confirm in captures): unequal heights in the peer row.**
`.primary` is `minHeight 52`, `.secondary` is `minHeight 44` (`ButtonStyles.swift:10,25`), so
side by side Start Cardio is 8 pt shorter than Start Lifting. The ticket calls them peers with
"equal width"; SKILL says "Equal options get equal size", and the new test asserts only width
and midY. `CardioControls` has the same pairing and was accepted, so this may be fine; decide
from the default capture. Fix if wanted: `minHeight: 52` on the Start Cardio label.

**L2 — Low (record/user decision): Start Lifting lost its ticket-10 capsule treatment.**
The request was placement. The implementation also drops `HeroCapsuleLabel` for the idle
state: no figure disc, no arrow, capsule → 16 pt rounded rectangle, body-bold → subheadline-bold.
Resume and the template detail's Start still wear the capsule, so the button changes shape
between idle and live, and the deleted comment was the record of the user's 2026-09-11
"same capsule, same place" choice. Two equal-width capsules with discs would not fit, so the
change is defensible, but the ticket presents the hero as otherwise unchanged. Record it in
ticket 03 as deliberate and make sure the user sees the default/AXL Start captures
(AGENTS: real captures for UI decisions). `HeroCapsuleLabel`'s doc comment is still accurate
(Resume + template detail).

**L3 — Info: "Distance" as the summary edit row's label.** Reused string, recorded in the
ticket; VoiceOver now reads a button named "Distance" next to a metric labelled "Distance".
Acceptable under the copy policy; no action requested.

**Pre-existing, out of scope:** `.sensoryFeedback(.workoutStart, trigger: activeWorkouts.count)`
sits in the branch that is removed in the same update that changes the count, before and
after this diff. Whether the haptic fires on the phone is unverified. Not introduced here.

## Visual follow-up checklist (when captures land)

`redesign-cardio-start-{default,axl}`: bold element = amber Start Lifting only; L1 height;
AXL stacked, nothing truncated. `cardio-built-outdoor-details-*` and `cardio-built-ended-outdoor-*`:
no map, no leftover gap, controls pinned. `cardio-built-finish-route-*`, `-history-route-*`:
map present and whole. `cardio-built-live/controls-*`: distance button reads cleanly with no
caption. Then exit codes and xcresult summaries for focused (9) and full UI (81).

## Re-review of fixes — `3020180..269498b` (2026-09-18)

Code re-review only; `269498b` fetched from origin and diffed by me. Product change is one
line (`StartWorkoutView.swift:167`); the rest is tests and records. I ran nothing;
`final-focused` / `full-ui` results and captures are still **pending and unverified**.

| Finding | State |
|---|---|
| T1 | **Resolved in code.** The absence assertion now follows the `Measured:` wait and sheet Cancel, in the mixed test and in both capture tests. The mixed flow no longer enters a manual distance, so the automatic source survives into the ended-segment card, receipt and History, each asserted via the **button label** `cardioSummaryEditDistance == "Distance"` (the right element type; not vacuous — the old code would give "HealthKit estimate"). Manual entry stays covered by the manual-distance test and `capture()` |
| L1 | **Resolved in code.** Start Cardio label `minHeight: 52`; the style's own `minHeight 44` is then inert, and the test asserts equal height at both sizes. Confirm in the Start captures |
| L2 | **Resolved as a record.** Ticket 03 states the compact text-only idle buttons are deliberate and that Resume/template keep the capsule. The user still needs to see the default/AXL Start captures |
| L3 | No action, as before |

New observations:

- **N1 — Info (test, the final run decides):** the exact-equality label assertion assumes the
  pencil `Image` adds nothing to the button's accessibility label. If SwiftUI appends the
  symbol's description the three assertions fail loudly rather than pass wrongly, so this is
  safe; if it happens, mark the pencil `accessibilityHidden` or compare with `hasPrefix`.
- **N2 — Info (test helper):** `openFinishedHistory` swipes down until the link is hittable. It
  stops at the first hittable frame, so it should not over-pull the receipt sheet; the diagnosis
  in the ticket (generic `reach` swipes up for an absent lazy element that lives above) matches
  the helper's code, and the fix is test-only. Accepted.
- **N3 — Low (docs, fix at merge):** STATE's header still names `3020180` as the current
  implementation; it should name the final tip when results are recorded. The new archive file
  is byte-identical to STATE at `21ef98f` (checked with `diff`), and the archive index links it.

**Code verdict: clear.** No open code finding. Merge clearance still requires, verified from
the artifacts: `final-focused` exit 0 (9 tests), `full-ui` exit 0 (81 tests), and the visual
checklist above against the default/AccessibilityL captures, plus
`cardio-built-automatic-{default,axl}` showing the distance button without a caption.

## Visual verdict and focused evidence — product `269498b` (2026-09-18)

**Focused evidence, verified by me from the artifacts (read-only; I ran no simulator work):**
`final-build-exit.txt` = 0; `final-focused-exit.txt` = 0; `final-focused.log` shows all 7
`CardioUITests` and both `RedesignScreenshotUITests` start-choice cases passed, "Executed 9
tests, with 0 failures", `** TEST SUCCEEDED **`; `xcresulttool … summary` on
`final-focused.xcresult`: result Passed, 9 total / 9 passed / 0 failed / 0 skipped.
Implementation worktree HEAD is `269498b` (only the ticket, the screenshots folder and a
gallery file are uncommitted). N1 is closed: the `label == "Distance"` assertions passed.

**Captures:** I opened 13 of the 15 PNGs in
`cardio-ui-refinements/work-record/cardio/screenshots/ui-refinements/` as pictures (all but
`cardio-built-outdoor-default` and nothing else skipped of substance; the outdoor top pair is
the unchanged first viewport and the AXL one was checked).

| Check (REVIEW.md) | Result |
|---|---|
| 1 Bold element | Start: amber Start Lifting is the only accent-filled command; Start Cardio is fill-grey. Live cardio: timer is the hero, Pause the only amber command. Pass |
| 2 Placement | Start row sits directly under the gym card at both sizes, Templates below; matches the wireframe. Pass |
| 7 Controls | Start buttons equal width **and height** side by side (L1 confirmed fixed); AXL stacks primary over secondary, full labels, no truncation. Pass |
| 9 Dynamic Type | Same fixture/state in each pair; hierarchy order kept; nothing the wireframe names is truncated. Pass |
| Maps absent while unfinished | `outdoor-details-{default,axl}` and `ended-outdoor-{default,axl}`: no map, no leftover gap; metrics flow straight to the distance row / card footer; controls pinned. Pass |
| Maps present when finished | `finish-route-default`, `history-route-{default,axl}`: whole map with amber route inside the cardio card. `finish-route-axl`: map only partly in frame (see V2). Pass |
| Caption removed | `automatic-{default,axl}` and `automatic-distance`: distance row reads "0.02 mi ✎" with no "HealthKit estimate"; GPS fixture still shows "GPS". Pass |
| 11 Copy | No new string seen; identifiers unchanged. Pass |

**Visual verdict: clear.** No visual finding blocks merge. Notes:

- **V1 — judgement, no action:** with the caption gone, the live distance row for a HealthKit
  distance is an unlabelled "0.02 mi ✎" directly under the identical Distance metric. It is
  exactly what was requested and the row remains the edit affordance; worth the user seeing
  `cardio-built-automatic-default.png` alongside the Start pair.
- **V2 — advice on the AXL Summary route capture:** a supplementary capture is **not required
  for clearance**. The cut is the viewport edge (the helper stops once the map is hittable),
  not truncation; the test asserts the route exists on the receipt; and the identical
  `CardioSummaryCard` is whole at AXL in History. Do not spend a simulator run on it alone. If
  the test file is touched again for any reason, one extra `app.swipeUp()` before that `shot`
  completes the record.
- **V3 — Low (record):** no exported PNG shows the one re-placed string — the "Distance ✎"
  footer of a HealthKit-sourced completed card. `cardio-built-mixed-history` in
  `final-focused.xcresult` should show it; export it into the screenshots folder (an export,
  not a test run).
- Pre-existing, not this ticket: at AXL the Start screen's template caption runs under the
  floating tab bar at rest (scrollable content), and the nav title truncates to "Outdoo…".

## Clearance state

| Gate | State |
|---|---|
| Code review `21ef98f..269498b` | **Clear** |
| Focused UI (9) | **Verified passed** |
| Visual review | **Clear** (V3 export and N3 STATE tip are housekeeping) |
| Full UI suite (81) on `269498b` | **Pending — not verified.** Merge clearance is withheld until I read `full-ui-exit.txt` and the xcresult summary |

## Final merge clearance — 2026-09-19

**Full UI suite, read by me from the implementation worktree's artifacts (read-only; I ran
nothing):** `full-ui-exit.txt` = `0` (written 2026-09-19 00:11 EDT, same minute as the log's
end); `full-ui.log`: 81 `Test Case … passed` lines, 0 `failed`, "Executed 81 tests, with 0
failures (0 unexpected) in 2902 s", `** TEST SUCCEEDED **`; `xcresulttool … summary` on
`full-ui.xcresult`: Passed, 81 total / 81 passed / 0 failed / 0 skipped / 0 expected failures.
The log carries 24 invalid-frame warning lines — the same count and known non-failing class
STATE already lists (ticket 17; origin uninvestigated). 81 = prior 79 + the 2 new start-choice
captures, as the ticket predicted.

**Tested input vs branch tip:** product and tests were last changed in `269498b`. The pushed
tip `9c7d1b7` differs from it only under `docs/` and `work-record/` (STATE, ticket 03, 16 PNGs,
gallery) — checked with `git diff --name-only 269498b origin/ericlee4992/cardio-ui-refinements`;
no path outside those two folders. The 81-test result therefore covers the code that would merge.

**Housekeeping closed:** V3 — `cardio-built-mixed-history.png` opened: the HealthKit-sourced
History card footer reads "Distance ✎", no "HealthKit estimate". N3 — STATE at `9c7d1b7`
names `269498b`.

| Gate | State |
|---|---|
| Code review `21ef98f..269498b` | Clear |
| Build | exit 0 (verified) |
| Focused UI | 9/9 passed (verified) |
| Full local UI | 81/81 passed, exit 0 (verified) |
| Visual review, default + AccessibilityL | Clear |
| Commits above tested tip | Docs/captures only (verified at `9c7d1b7`) |

**CLEAR TO MERGE** (T6 independent clearance, Claude reviewing Codex/parent-authored work):
fast-forward `main` to the branch tip, provided any further commits before merge stay within
`docs/` and `work-record/`; a product or test change after `269498b` voids this clearance and
needs re-review and re-run. The parent owns merge and push; I did not merge or install.

Not covered by this clearance, and still open: unit tests were not re-run for this ticket
(no domain/schema/sensor file changed — verified by diff — so acceptable, but it is an
unexercised gate, not a passed one); nothing here is installed or seen on the phone, and
ticket 02's physical checks remain; V2's AXL receipt capture is optional; the pre-existing
`.workoutStart` haptic placement is unverified on device.

**Correction, 2026-09-19 (L2/V1):** the parent reports that it showed the user the default/AXL
Start capture links after the focused run, and the automatic-distance capture link afterwards,
in its own conversation. My tools cannot see that conversation, so this is recorded as the
parent's report, not something I verified; the earlier "not yet shown" wording is withdrawn.
The clearance is unchanged.
