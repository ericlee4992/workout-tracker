# Claude independent review — ticket 17, visual and gate follow-up

Reviewer: Claude (T6; Codex implemented). Date: 2026-09-17. Source under review: `4d70d7d`,
unchanged since the initial report (`claude-review-17.md`, preserved as written; this file
follows it up and does not replace it). Implementation worktree verified at HEAD `4d70d7d` with no
diff under `WorkoutTracker/`, `WorkoutTrackerUITests/` or `WorkoutTrackerTests/`.
I ran no simulator tests, altered no product source, and did not install, merge or push.

## Verdict

| Gate | State |
|---|---|
| Code / contract review of `4d70d7d` | **CLEAR** (initial report; no source change since) |
| Visual review, default size | **CLEAR** |
| Visual review, AccessibilityL | **CLEAR** |
| Focused gate | **CLEAR as combined evidence** — original run red on one setup step (`FOCUSED 65`, kept), isolated retry of that one method green (`AXL_RETRY 0`); details below |
| Full UI suite (72) | **STILL RUNNING when this was written — no result, not cleared** |
| Merge clearance | **Conditional only:** my review has no open finding against `4d70d7d`. Merging still requires the full suite's real exit status and its own log/xcresult summary to be green (AGENTS: full local UI suite before merging screen changes). This file does not assert that. |

## Visual review — five captures

Inspected in `finish-summary-order/work-record/ui-redesign/screenshots/17/selected/`. The three AXL
files are byte-identical (SHA-256) to the attachments I exported myself, read-only, from
`axl-retry.xcresult`, so the exported images are the run's images:

| File | SHA-256 (first 12) |
|---|---|
| `redesign-03-finish-summary.png` | `6d56e4fb4593` |
| `redesign-03-finish-summary-scroll-1.png` | `e33fe05ba374` |
| `redesign-03-finish-summary-axl.png` | `e5d63b4a1f18` |
| `redesign-03-finish-summary-axl-scroll-1.png` | `df8206a1a459` |
| `redesign-03-finish-summary-axl-scroll-2.png` | `805843495a1f` |

Default size:

- Rows read **Workout time | Total volume**, **Active calories | Total calories**,
  **Avg. heart rate | Max heart rate** — exactly the user's requested pairs.
- Compared against the shipped capture `screenshots/16/03-finish-summary.png`: nav title and Done,
  the saved ring/status group, amber View in History, Save as Template, the "Workout details"
  header, tile size/spacing/corner radius, and the Heart rate card all sit at the same positions.
  Only the tile contents changed places. Per-tile symbols, tints, labels and units are unchanged
  (timer amber, scale neutral, flames pink, hearts red; CAL/BPM).
- `…-scroll-1` holds all six tiles again plus the whole chart and the Exercises card, fully in view.

AccessibilityL (same fixture and state: Seated Chest Press, 1 set, 600 lb, Iron Temple, scripted
sensor):

- One column, in order time → volume (`…-axl`), active → total → avg → max (`…-axl-scroll-1`), then
  chart and Exercises (`…-axl-scroll-2`). Hierarchy order unchanged.
- No truncation of any value or unit: "0:16", "600 lb", "5 CAL", "7 CAL", "123 BPM", "151 BPM". The
  "126 B…" regression from codex-review-03b is absent. Status text wraps rather than clips.

REVIEW.md items touched by this change: 1 (single amber action — View in History only; tile
symbols are existing meaning colours) pass; 2 placement pass; 3/4 grouping and stat figures
unchanged, pass; 9 Dynamic Type pass; 11 copy/identifiers pass (by diff, initial report); 12 record —
the ticket must list the five captures and the gate counts once the suite finishes. Items 5–8 and
10 are not touched by a reorder.

Live values differ slightly between runs (0:15/0:16, 6/7 CAL, 125/123 BPM); the ticket already
states this is live fixture timing, not snapshot testing. The fixture records no zone time, so no
Time in zones card appears — same as the shipped capture; not a finding.

## Findings — status

- **F0 (Medium, focused gate red) — resolved as required, original evidence kept.**
  `status.txt`: `BUILD 0`, `FOCUSED 65`, `AXL_RETRY 0`. Original focused run: 8/8
  WorkoutSummaryTests and `test02_activeWorkoutAndFinish` passed; `test03_finishSummaryLargeText`
  failed at `RedesignScreenshotUITests.swift:495` (`logSet`, reps field did not take keyboard
  focus) before the finish sheet opened. Retry (`run-after-retry.sh`: `test-without-building`, same
  derived data, new result path, only that method): `axl-retry.log:267` passed (66.6 s), 1 executed
  0 failures, `:281` `** TEST EXECUTE SUCCEEDED **`. Same binary, same source, no test edit — so
  the failure is a non-reproduced setup focus flake in code `4d70d7d` does not touch, and nothing
  was retried-until-green beyond one isolated re-run. I accept passing-originals + one passing retry
  as the focused evidence; rerunning the unaffected cases was not needed. The ticket should record
  both runs, and the flake as a known intermittent (one occurrence) rather than dropping it. The
  full suite runs test03 again, which will be a third sample.
- **F1 (Low, capture completeness not asserted) — visual concern closed.** Every one of the six
  tiles is fully legible in at least one capture at each size, and chart and Exercises are on
  record at both. The optional hardening (assert all six ids seen) remains optional; not required.
- **F2 (Info, attachment names) — closed.** Export used the new `…-scroll-N` names.
- **A1 (advisory) — stands, no action.** Pairs hold only when all six metrics exist; with a
  missing fact the grid compacts and pairs shift. User-approved shipped behaviour (D44); worth one
  sentence to the user.
- **A2 (advisory) — stands, out of scope.** History detail's tile order is untouched.
- **A3 (advisory, new, pre-existing, out of scope).** The status metadata wraps with a trailing
  "·" at default size ("1 exercise · 1 set ·" / "Iron Temple"), and the AXL chart shows one x-axis
  time label where default shows three. Both are present in shipped captures/behaviour and are not
  caused by this ticket. No action requested here.

## Still required before merge (not covered by this clearance)

1. Full UI suite finishes: `status.txt` gains `FULL_UI 0`, and `full-ui.log`'s own TEST line plus
   the `full-ui.xcresult` summary show all 72 declared methods executed, 0 failed — including
   `test03_finishSummaryLargeText`, `HeartRateSummaryUITests`, `HeartRateUITests` and the
   HistoryTemplate finish flow. When I last looked the log showed 2 passed, 0 failed, run in
   progress. If any test fails, that result needs its own reading before merge; it is not
   pre-cleared here.
2. Any source or test change after `4d70d7d` voids this clearance for the changed lines until
   re-reviewed.
3. Ticket/STATE updated with the real counts, both focused runs, and the five capture names.
