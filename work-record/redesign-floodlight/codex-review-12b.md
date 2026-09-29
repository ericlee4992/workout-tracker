# Ticket 12 — Codex review, round 2

**Not clear: two medium findings and one low finding.** Reviewed
`0fddd52..3d58a981984844473be83c2815f8c2342739c2dc` on
`ericlee4992/redesign-floodlight-cardio` in `/tmp/wt-floodlight/cardio`, following
`codex-review-12b-prompt.md`. The checkout was clean before this report.

## Medium

### 1. The typing cap still changes numbers before validating them

**`WorkoutTracker/Features/Cardio/CardioDistanceSheet.swift:97–102`.**

Round-1 finding 2 is only partly resolved. Initialization now preserves the stored value, but
focused input is still replaced with its first seven characters. Paste `1.23e-06` into a blank
Distance field: it becomes `1.23e-0`, which the parser accepts as **1.23**, a millionfold increase.
Paste invalid `1.23456x`: it becomes valid `1.23456`, so the promised whole-entry validation never
sees the invalid character. These are source-traced cases, not new simulator runs.

Preserve the complete input and validate length separately, or refuse an overlength edit without
accepting a numeric prefix. The added parser tests bypass this callback and cannot catch either
case. Add a focused-field paste/edit regression covering valid exponent notation and an invalid
suffix, while retaining the unchanged-open test for saved precision.

### 2. The AccessibilityL ring hierarchy is still reversed

**`WorkoutTracker/Features/Cardio/CardioLive.swift:79`, `:110`, `:211`, `:412`.**

Round-1 finding 6 remains. Changing the table and heart plate to `statNumber` reduces their size,
but their Dynamic Type font still overtakes the ring centre, whose size remains tied to the
fixed 190-point ring and may shrink further to fit its centre. In the retaken
[`C02-p2-dark-axl.png`](captures/12/C02-p2-dark-axl.png) and
[`C02-p2-light-axl.png`](captures/12/C02-p2-light-axl.png), the table and heart numerals remain
taller than the ring's `13:28` / `13:31`. The Default capture has the intended hierarchy.

Size the ring centre and its supporting figures together so the ring figure actually remains
larger at AccessibilityL, including a multi-digit elapsed time. Verify the rendered result and
retake both appearances. The current comment that the centre “stays the largest figure at every
size” does not match these captures. REVIEW items 1, 4 and 9 are still unmet.

## Low

### 3. The second-segment check does not verify the full AX card or exclude duplication

**`WorkoutTrackerUITests/FloodlightCardioUITests.swift:231–235`.**

`reach(cycle)` stops when the header becomes hittable. In both retaken
[`H04-second-segment-dark-axl.png`](captures/12/H04-second-segment-dark-axl.png) and
[`H04-second-segment-light-axl.png`](captures/12/H04-second-segment-light-axl.png), the cycle title
is partly behind the tab bar and its figures/labels are below the viewport. The capture therefore
does not verify the second card's AccessibilityL layout or the changed label wrapping.

The adjacent `count <= 1` assertion also permits a duplicate run card: once the hero is recycled,
one erroneous run card would satisfy it. Zero matches passes too. The production ID filter is
correct by inspection, but this assertion cannot protect it. Reach and assert the cycle's actual
figures before capturing; verify the identities in the card section independently of the lazy
hero's current existence. This is a verification defect, not a claim that the current app
duplicates the run.

## Disposition of the eight original findings

| Round-1 finding | Result |
|---|---|
| 1 — unbounded splits/markers and ring conversion | Resolved: finite/200-unit split bound, corresponding marker bound for the History caller, and a bound before the ring's `Int` conversion. Stored values are retained. |
| 2 — rewritten distance input | Partly resolved; loaded values survive, but focused input still changes as described above. |
| 3 — missing distance metric identifier | Resolved: metric and separate edit button coexist on figure/ring; the new exact-count assertions are meaningful. |
| 4 — zero shown as missing | Resolved: zero formats as `0.00`; nil remains unavailable. |
| 5 — incorrect snapshot reuse | Resolved: cache and task use projection/size/appearance; canceled render results are discarded. |
| 6 — ring hierarchy at AccessibilityL | Still open, as above. |
| 7 — discarded tail time | Resolved: elapsed time is folded into the final emitted split; the new test checks the total and final duration. |
| 8 — spoken cycling pace instead of speed | Resolved: spoken cycling figures use the displayed speed and per-hour unit. |

## Verification reviewed

The second fixture segment is isolated to the UI-test store and is ended after the run. History
keeps it as a separate card. The two-line finished figure labels and conditional Workout details
section are correctly implemented; Default captures show the complete “Entered distance” label
and no empty heading. The new picker Start, zone-setup and receipt-edit action checks exercise
their destinations, rather than only checking that controls exist.

Read the existing build/test exit files and logs, plus xcresult summaries for `cardio-ui-8` and
`cardio-ui-11`: build 3 exited 0; UI 8 had 30/30 domain tests, 9/9 Cardio tests and 6/8 Floodlight
tests, with both failures being the documented AX count assertion. Focused runs 9 and 10 passed
2/2 each; run 11 passed 5/5, exit 0, zero skipped tests and no recorded runtime warnings. Run 8
retains the invalid-frame warnings. Targeted scope remains appropriate; address the specific
input and capture/assertion gaps above rather than requiring a blanket full suite.

No `xcodebuild` or `simctl` command was run. Only this report was written; product, test,
ticket, STATE, prototype and capture files were left unchanged.
