# Independent review — live-workout-fixes 01

Reviewed `git diff 70e8499..HEAD` on `ericlee4992/live-01-weight-unit`, HEAD
`ecc82a7227236a59b98a138e76fb0cc898fa8ea1` (implementation `dfc86f4`). Claude authored;
Codex reviewed against the ticket, SPEC's per-set units/durability boundary, D9/D25/D40/D59,
DEVELOPMENT's verification scope, and the iOS design skill/checklist. No product files changed.

## Standards findings

1. **P3 — Correct the test breakdown.**
   `work-record/live-workout-fixes/issues/01-weight-unit-tap.md:67` reports 14
   `FloodlightLiveUITests`. The source and actual run contain **13**; the overall **17** is
   correct (13 Floodlight + 2 Barbell + 2 CoreLoop). A reviewer reconciling the listed suites
   otherwise gets 18 and cannot tell whether a test was omitted. Change 14 to 13. This is an
   evidence-record error, not a failed or skipped test.

2. **P3 — Preserve and link the reviewed captures.**
   `work-record/live-workout-fixes/issues/01-weight-unit-tap.md:68` names screenshots but
   neither links preserved PNGs nor gives the result/log location. The three new captures
   are currently only in the temporary evidence directory below. Once it is cleaned, the
   ticket loses its inspectable default/AccessibilityL design evidence. The iOS design
   `REFERENCE.md` “Captures” section requires exported captures kept in the repository.
   Preserve the three new PNGs under an appropriate `work-record/` capture directory, link
   them from the ticket, and record the result/log/status paths and tested code revision.

## Spec and implementation assessment

No demonstrated product defect or scope creep found. `LiveSetRow.swift:265–295` has no
remaining in-box unit button: the static label and surrounding rectangle route taps to
weight focus. The new toolbar is gated by this row's focus, with the picker additionally
gated on weight (`:130–139`). The model-backed selection comparison (`:324–326`) prevents
an already-selected segment from toggling again. The unchanged toggle synchronously commits
visible text before changing/saving the unit (`:438–444`), preserving as-entered values and
normalization. It does not clear focus. Toggle and end-editing commits guard deleted sets;
rows retain set identity through `ForEach(orderedSets)`.

The weight field's named accessibility action provides the alternate switching route;
bar mode omits it and disables the keyboard picker. The disabled picker retains the bar
explanation. New strings match the ticket: “Unit”, “Switch to kg”, “Switch to lb”. All
executable `setRow.unit` test queries now use static text; no old button query remains.

The default light/dark and AccessibilityL captures were opened and inspected. Removing
the leading padding centers number plus unit; the accessibility layout remains two lines.
Both segments and Done fit without clipping. Captures establish visual layout, not exact
native hit regions or VoiceOver/Switch Control behavior.

## Verification and limits

Directly inspected the implementer's `r1.status` (**exit 0**), `r1.log`
(**TEST SUCCEEDED**, 13 Floodlight / 17 total), and `xcresulttool get test-results summary`
(**Passed, 17 passed, 0 failed, 0 skipped**). Evidence root:

`/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-public-beta/0dc39eb1-054d-49da-bf79-784fabae4a4e/scratchpad/live01/`

Result: `r1.xcresult`; exported screenshots and name mapping: `att/manifest.json`.
The build succeeded within that test action. `git diff --check 70e8499..HEAD` also passed.
No new build/test run, simulator interaction, desktop control, phone/account/backup access,
or deployment was performed during this review.

Targeted scope is proportionate under DEVELOPMENT; unchanged domain logic does not require
a new domain/full-UI run. The tests demonstrate label-tap focus without switching, keyboard
switching and persisted units, and bar-mode disabling. They do **not** directly establish
weight → reps → another row's weight toolbar teardown/retargeting, deletion of a focused
row, switching with uncommitted typing, continued typing after switching, or assistive
technology action discovery. Source supports the intended behavior, but these runtime
properties remain unverified; a focused regression covering them would strengthen the
evidence. No stale/multiple picker or lost-keystroke failure was reproduced or inferred as
a proven bug.

Standards: two P3 documentation findings. Spec: no demonstrated violation. Clearance is
pending the two record corrections above, not a broader test suite.

Verdict: not clear
