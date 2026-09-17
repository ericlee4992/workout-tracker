# Claude independent review — ticket 17 (finish-summary metric order)

Reviewer: Claude (T6; Codex implemented). Date: 2026-09-17.
Range: `c7ef99b..4d70d7d` ("Pair related metrics in the finish summary"), reviewed in an isolated
checkout at `4d70d7d`. No product source altered, no simulator run, no install/merge/push by me.

Inputs read: AGENTS.md, the ticket (`issues/17-finish-summary-second-pass.md`), SPEC finish-summary
paragraph, DECISIONS D44/D52/D54, `ios-design/SKILL.md` + `REVIEW.md`, the full diff, every
UI-test caller of the summary identifiers, and the runner artifacts in the implementation worktree
(read-only).

## Verdict

| Gate | State |
|---|---|
| Code / contract review of `4d70d7d` | **Clear** — no blocking findings |
| Visual review (default + AccessibilityL captures) | **PENDING** — no images inspected yet |
| Focused run | **FAILED** — `status.txt` `FOCUSED 65`, `focused.log:1916` `** TEST FAILED **` (F0 below) |
| Full UI suite (72) | **DID NOT RUN** — the runner exits on a non-zero focused result; PID 9680 has exited |
| Overall merge clearance | **NOT GIVEN** — focused gate is red, no AXL captures exist, full suite has no result |

Scope respected: the user chose the shipped screen and asked only for the tile order. I do not
require anything from the rejected alternatives.

## What I verified in the code

`WorkoutTracker/Features/ActiveWorkout/WorkoutFinishedSheet.swift`

- :209–216 — the `Total volume` block is moved verbatim (gate `summary.totalVolumeKg > 0`, the
  `volumeLabel` conversion, label, symbol, tint `Theme.text`, id `summaryVolume`, and its D52
  comment) from after Max HR to directly after Workout time. `git diff` shows the removed and
  added hunks are byte-identical apart from position.
- Resulting order :207–233 is time → volume → active → total → avg → max, which is the ticket's
  1/2/3 pairing in the two-column state and the required reading order in one column.
- Column rule :205 (`dynamicTypeSize.isAccessibilitySize ? 1 : 2`) untouched — accessibility
  sizes stay one column.
- Missing-data gates untouched: `activeEnergyKilocalories`, `totalEnergyKilocalories`,
  `averageHeartRate`, `maxHeartRate` are still `if let`; volume still `> 0`. Nothing is zeroed or
  invented (D44). No placeholder tiles were added to force pairs — correct per the ticket.
- No change to strings, units (CAL/BPM), symbols, tints, identifiers, `tile(...)`,
  `accessibilityText`, `WorkoutSummaryBuilder`, `WeightMath`, models, schema or persistence. D52
  plain numbers unchanged. REVIEW item 11 (copy/identifiers): pass by diff.
- Only comment added: :201–202, accurate.

Callers of the identifiers (all UI tests; no app code depends on tile position):

- `HeartRateSummaryUITests.swift:39–44` — existence checks only (`summaryTotalCalories`,
  `summaryAvgHR`, `summaryMaxHR`, `summaryVolume`), order-independent. The grid is one List row,
  so all six tiles materialise together; row count is unchanged (3 rows / 6 stacked), so nothing
  that existed before is pushed out of the hierarchy.
- `HeartRateUITests.swift:113,124` — waits for `summaryAvgHR`, one `swipeUp`, then
  `summaryExercise`. Section height is unchanged by a reorder, so the scroll distance assumption
  holds. To be confirmed by the full suite, not by me.
- `RedesignScreenshotUITests.swift` — the one caller that assumed **volume is last** (old
  :116–121 scrolled to `summaryVolume` and asserted it hittable). That assumption is removed and
  replaced by `captureFinishSummaryRemainder` (:409–424) keyed on `summaryMaxHR` (the new last
  tile) plus `summaryExercise`. I found no other volume-last assumption in Swift, scripts or
  DEVELOPMENT.

Docs: SPEC finish-summary bullet and the D54 amendment state the new order, the one-column rule,
omission, and that D44/D52 are not reopened; the reopening of the milestone-9 order is explicit
with the user's words in the ticket (AGENTS "reopen a locked decision explicitly"). STATE is
current-only and links the ticket. Consistent with the code.

## Findings

### F0 — Medium (verification gate red; not shown to be a product defect) — `WorkoutTrackerUITests/RedesignScreenshotUITests.swift:495`

`test03_finishSummaryLargeText` failed after 61.1 s (`focused.log:1857`, `:1899`):
`Failed to synthesize event: Neither element nor any descendant has keyboard focus` on
`repsField.typeText(reps)` inside `logSet` (:488–497). The log's hierarchy at that moment shows
`setRow.weight` with value 60 still **Keyboard Focused** and `setRow.reps` empty — the tap on the
reps field at AccessibilityL did not move focus. This is in fixture setup on the active-workout
screen, **before** `finishWorkout` is tapped: the finish sheet, the reordered grid and the new
`captureFinishSummaryRemainder` helper were never reached, and `logSet` is not touched by
`4d70d7d` (last changed before this ticket).

- What it means: nothing here implicates the reorder, but it equally proves nothing about it —
  there is **no AccessibilityL evidence at all** for ticket 17 (no `…-axl` attachments were
  produced), and because `run-verification.sh` exits on a non-zero focused result, the full UI
  suite never started. `status.txt` is `BUILD 0` / `FOCUSED 65`, no `FULL_UI` line.
- Not established by me (I was told not to run the simulator): whether this is a one-off focus
  flake or reproducible at AXL on this source. Ticket 16 changed the active-workout layout at
  accessibility sizes and its AXL capture flow passed in the 72/72 run on `0b6515f`, which argues
  for a flake, but that is inference, not evidence.
- Required: re-run test03 on unchanged `4d70d7d`. If it passes, record both runs in the ticket
  (the failure is evidence too — do not overwrite `focused.log`/`focused.xcresult`; use a new
  result path). If it fails again the same way, it needs diagnosis as its own item (a
  `waitForExistence`/focus check on the reps field in `logSet` is a test-only change and would
  need re-review; it must not be papered over by retry-until-green). Then run the full suite.

### F1 — Low (test/evidence robustness, non-blocking for source) — `WorkoutTrackerUITests/RedesignScreenshotUITests.swift:409–424`

The helper's doc comment says recording each viewport means the run "cannot skip the middle
tiles", but nothing enforces that: only `summaryMaxHR` (seen hittable at some stop) and
`summaryExercise` (fully in view) are asserted, and `swipeUp()` carries momentum, so consecutive
captures are not guaranteed to overlap. Evidence this matters: in the focused run, `test02` went
from the top of the sheet to "exercise fully in view" in **one** swipe (`focused.log:1444–1465`:
attachments `redesign-03-finish-summary` and `…-scroll-1` only). So the default-size record is two
images, and whether calories/HR rows, Time in zones and the chart all appear in one of them can
only be settled by looking at the images.

- Consequence: not a product defect and it fails closed for max HR; the risk is an incomplete
  review record that still passes.
- Required for clearance: the visual check below must confirm every one of the six tiles is
  legible in at least one capture at each size.
- Optional hardening (author's call, not required): track "seen hittable" for all six ids in the
  loop and assert them, mirroring the old message "all six tiles reachable".

### F2 — Info — attachment names changed

`redesign-03-finish-summary-axl-2` no longer exists; captures are now `…-scroll-N` for both
sizes. No script or doc procedure references the old name (only historical records in
`issues/03-finish-summary.md` and `codex-review-03c.md`, which should stay as written). The
export step for `screenshots/17/selected/` must use the new names.

### A1 — Advisory (judgement, no action requested) — pairs hold only in the all-metrics state

Because tiles omit and the grid compacts (kept deliberately, D44), partial data shifts pairs:
e.g. no basal energy → time/volume, active/avg, max alone; bodyweight-only volume 0 with a
sensor → time/active, total/avg, max alone. The ticket states this ("exact pairs describe the
all-metrics state") and the shipped screen compacted the same way before, so this is the
user-approved behaviour, not a finding. Worth one sentence to the user so a split pair on the
phone is not read as a bug.

### A2 — Advisory (judgement, out of scope) — History detail

`WorkoutDetailView.swift:187–203` orders its heart-rate tiles avg/max then active/total and has
no time/volume tile in that block. The user said "just in workout details" (the finish sheet's
section), so leaving History untouched is correct for this ticket.

## Runner evidence as I saw it (read-only, 2026-09-17 ~18:06 EDT)

Implementation worktree HEAD `4d70d7d`, working tree clean. Runner PID 9680 has exited.

- `status.txt`: `BUILD 0` only. `build.log:1655` `** BUILD SUCCEEDED **`. — Build: confirmed.
- `focused.log`: WorkoutSummaryTests 8/8 passed (Swift Testing; the "Executed 0 tests" XCTest
  lines at :1180–1182 are the empty XCTest shell of that bundle, not a skipped run).
  `test02_activeWorkoutAndFinish` passed (65.4 s; attachments `redesign-02-active-workout`,
  `redesign-03-finish-summary`, `…-scroll-1`). `test03_finishSummaryLargeText` **failed**
  (61.1 s, F0). `status.txt` `FOCUSED 65`; `focused.log:1916` `** TEST FAILED **`.
  — Focused: **red**.
- `full-ui.log` / `full-ui.xcresult`: do not exist; the runner exited. — Full suite: **not run**.
- `screenshots/17/selected/`: contained only `comparison.html`; no ticket-17 captures yet.

## Pending before I can give full clearance

0. F0 resolved as described (re-run on a new result path, both runs recorded).
1. A run whose `status.txt` shows `FOCUSED 0` and `FULL_UI 0`; the full log's own TEST line / xcresult summary
   shows 72 executed, 0 failed (not a summary from another agent).
2. Default-size captures (`redesign-03-finish-summary`, `…-scroll-N`): rows read exactly
   time | volume, active | total, avg | max; tiles equal size; nothing else on the screen moved
   relative to the shipped capture (status group, View in History as the single amber primary,
   Save as Template, zones, chart, Exercises).
3. AccessibilityL captures (`…-axl`, `…-axl-scroll-N`), same fixture/state: one column in the order
   time → volume → active → total → avg → max; no truncation of any value or unit (REVIEW
   item 9; the "126 B…" regression from codex-review-03b must not return); every one of the six
   tiles visible in at least one image (closes F1).
4. If any source change is made in response (e.g. the optional F1 hardening), I re-review that
   diff; clearance applies to a named commit only.
