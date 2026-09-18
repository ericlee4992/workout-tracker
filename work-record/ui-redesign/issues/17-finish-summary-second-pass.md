# 17 — Finish summary: pair related workout metrics

Status: resolved — source `4d70d7d`; all verification/review clear; installed and launched on phone 2026-09-17

## User decision and acceptance

2026-09-17: after comparing three native proposals and the shipped screen, the user chose:
“I actually like this the most. but just in workout details, move total volume next to workout
time, and have calories on the same row, and also the hr on third row.” “This” refers to the
Current / Shipped app column added immediately before that reply.

Keep the shipped screen. Only reorder Workout details:

1. Workout time / Total volume
2. Active calories / Total calories
3. Avg. heart rate / Max heart rate

Accessibility sizes keep one column in that reading order. Missing values continue to omit
rather than invent tiles (D44); the existing grid compacts, so exact pairs describe the
all-metrics state. Values, units, labels, identifiers, colors, card sizes, actions, chart and
zones are unchanged. No persistence/schema/phone installation changes.

Reopen the SPEC's milestone-9 ordering for this explicit user choice. D54 records the reason;
D44's captured-data contract and D52's plain values stay unchanged.

## Branches and previous design evidence

Implementation: `ericlee4992/finish-summary-order`, based on `c7ef99b`, isolated worktree
`/Users/ericlee06/orca/workspaces/Health App/finish-summary-order`.

The rejected alternatives, native preview sources and 36 captures remain on the exploratory
branch `ericlee4992/finish-summary-second-pass`, tip `5a4c1b2` (initial design `6c3bd5c`). They do
not enter the product branch. [Exploration record](https://github.com/ericlee4992/workout-tracker/blob/5a4c1b2/work-record/ui-redesign/issues/17-finish-summary-second-pass.md).
The comparison was displayed in Orca's embedded browser because local image links were not
visible to the user in chat.

## Job, state and composition (chosen design)

- Saved, with or without sensor: this screen exists so the user can review what was saved and
  open the workout in History in one tap; the eye lands on View in History. The saved ring is
  completion state; the metric tiles are supporting stat figures. Missing sensor fields omit.
- Template saved: the existing template confirmation replaces its button; emphasis stays on
  View in History.
- Empty/discarded: this screen exists so the user can understand that nothing was saved and
  leave in one tap; Nothing to save leads, with Done in the toolbar and no result metrics.

```text
Nice work                                      Done       native chrome
┌ completed ring · Workout saved                  ┐       unchanged status group
│ exercise / set / gym metadata                   │
└─────────────────────────────────────────────────┘
[             View in History — amber             ]       one primary command
[                 Save as Template                ]       secondary command
Workout details
┌ Workout time          ┐ ┌ Total volume          ┐       equal stat tiles
└───────────────────────┘ └───────────────────────┘
┌ Active calories       ┐ ┌ Total calories        ┐
└───────────────────────┘ └───────────────────────┘
┌ Avg. heart rate       ┐ ┌ Max heart rate        ┐
└───────────────────────┘ └───────────────────────┘
Time in zones (if recorded), heart-rate chart (if recorded), Exercises below
```

The only changed block is the tile order. The user explicitly chose the current layout; no
new structural mockup is needed. Same fixture at default and AccessibilityL will be captured
from the actual app. At AccessibilityL time → volume → active → total → average → max stack.

Tells, relative to the selected shipped composition:

- Containers: deliberate — existing status group and structured stat tiles; no new containers.
- Chips: absent in the changed block.
- All-caps headings: absent; existing CAL/BPM units remain.
- Middle-dot metadata: deliberate — existing frozen exercise/set/gym metadata.
- Accent density: deliberate — preserve the user's chosen screen; primary History action,
  completion state, existing stat symbols and exercise best-set styling remain.
- Equal-weight blocks: deliberate — the user requested equal metric pairs in the current grid.
- Phone-sized website / content above fold: deliberate retained receipt composition, explicitly
  preferred over compact alternatives; change is grouping the six metrics, not moving actions.
- Picker as primary: absent — no picker in this block.
- Default-size-only: absent by intended one-column accessibility layout; verify in native captures.

## Implementation and caller audit

`WorkoutFinishedSheet.statsSection` moves the existing Total volume conditional directly after
Workout time. The existing unit conversion, positive-volume gate, all sensor gates, styles,
strings and IDs are identical. Summary construction and callers are untouched.
`RedesignScreenshotUITests` had assumed volume was the last tile; update that capture flow to
record successive viewports through max HR and the exercise summary. The default and AXL
flows keep the same one-exercise / one-completed-set / scripted-sensor fixture. Live elapsed
and sensor aggregates may differ with UI-test timing; this is not fixed-number snapshot testing.
No new test methods or domain tests are added for this low-impact reorder.

## Verification plan and running process

Detached runner PID **9680**. Base `c7ef99b` plus this ticket's implementation diff (source
unchanged while verification runs). Runner script and outputs are under
`work-record/ui-redesign/results/17/` in the implementation worktree (gitignored):

- `run-verification.sh`, `pid.txt`, `runner.log`, `status.txt`
- `build.log` — Debug simulator build
- `focused.log`, `focused.xcresult` — WorkoutSummaryTests and the two finish captures
- `full-ui.log`, `full-ui.xcresult` — full UI suite, serial on WT-iPhone, runs after focused success

Derived data: `/tmp/wt-ticket17-derived`. Inspect real exit statuses and xcresult summaries.
Full suite has 72 declared UI methods, including HeartRateSummary 3, HeartRate 5, CoreLoop 9,
HistoryTemplate 3 (including finish save-as-template), and the changed screenshot flows.
Independent Claude review receives this ticket, diff, relevant decisions, ios-design/REVIEW.md,
captures and actual evidence. Fix and re-review any findings before merge.

## Completion

The selected reorder is complete. All implementation, local verification and independent review
are clear. This closure record lands with the fast-forward of `ericlee4992/finish-summary-order`
to main; its landing commit is discoverable with `git log -- work-record/ui-redesign/issues/17-finish-summary-second-pass.md`.
Initial closure did not include installation; the later authorized phone installation is recorded below.

## Verification checkpoint — source `4d70d7d`

Debug build passed, exit 0. Focused run: WorkoutSummaryTests **8/8**, default finish capture
**1/1**. AccessibilityL failed in the unchanged active-workout setup while typing reps
(`setRow.reps`: no keyboard focus), before the receipt opened; focused exit 65. No product
change made for a single harness failure. Per DEVELOPMENT, rerun the failed method alone.

Original PID 9680 exited. New detached runner PID **15547**, script `run-after-retry.sh`,
`retry-pid.txt`, `retry-runner.log`, `axl-retry.log` / `axl-retry.xcresult`, then
`full-ui.log` / `full-ui.xcresult`; same results directory. The full suite starts only if the
retry passes. Current code is committed/pushed as `4d70d7d`; subsequent edits are evidence/docs.

Independent Claude reviewer is working in separate checkout
`/Users/ericlee06/orca/workspaces/Health App/review-finish-summary-order` at `4d70d7d`.

AccessibilityL isolated retry passed **1/1**, exit 0; xcresult confirms 0 failed/skipped.
No source change was necessary; the first attempt's keyboard-focus failure remains recorded.
Full UI suite started automatically on source `4d70d7d`, same runner PID 15547.
Exported and opened five actual app PNGs in `screenshots/17/selected/`: default top+scroll,
AXL top+two scrolls. All six metric labels/values are whole across the AXL captures; default
rows match the user's requested pairs. Chart and exercise section are recorded too; this
fixture has no configured zones. Before/after gallery opened in Orca's embedded browser.

Claude independently cleared code, default/AccessibilityL visuals and combined focused
evidence on source `4d70d7d`; [follow-up report](../claude-review-17-final.md), with the
[initial report](../claude-review-17-initial.md) preserved. No source findings remain. Merge
clearance is conditional on the still-running full UI suite. All five captures are listed
with hashes in the follow-up. The original focus failure is resolved by one unchanged retry,
not erased. No further product or test edits after the verified source.

## Full local UI suite — verified result

Source `4d70d7d`; later `2633b1d` changes documentation/captures only. Finished 2026-09-17
18:48:35 EDT: **72 passed, 0 failed, 0 skipped**, actual exit **0**, log
`** TEST EXECUTE SUCCEEDED **`. Independently read `full-ui.xcresult` via
`xcrun xcresulttool get test-results summary`, and compared the 72 declared UI methods against
the 72 distinct passed method names in `full-ui.log`: no missing or unexpected tests. The AXL
finish capture passed in the full suite too; the original setup failure did not recur.

[Raw result summary](../full-ui-summary-17.json). Bundle contains **22 non-failing runtime
warnings**, all “Invalid frame dimension (negative or non-finite).” This is the same warning
type/count recorded for ticket 16; origin remains uninvestigated, not attributed to this change.
Runner PID 15547 completed; no verification process remains active. Detailed scripts, logs and
result paths are preserved above. No further app or test change was made after the tested source.

Verification scope: Debug simulator build; WorkoutSummaryTests 8/8; two real finish capture
methods green using the original pass + one unchanged isolated retry; full local UI suite72/72;
independent Claude code and default/AXL visual review. Phone was not built/installed/launched.

## Independent gate clearance

Claude read the actual statuses, log, xcresult summary, source diff and binary timestamps, and
reconciled all 72 declared methods with the passed log entries. [Gate addendum](../claude-review-17-gates.md):
**CLEAR to merge source `4d70d7d`; no open findings.** Final record changes are docs/captures
only. App/test source remains exactly the reviewed and tested source. No install claimed.

## Phone installation — 2026-09-17, authorized after visual approval

User: “looks good. install on phone.” Build from clean main `39b4c8d`; product source is
`4d70d7d`. No app/test/schema change since the 72/72 run and Claude clearance.

- Fresh generic-iOS build under `/tmp/wt-ticket17-device`, exit **0**, BUILD SUCCEEDED.
  Compile log names the current WorkoutFinishedSheet source; app dylib timestamp 21:42:12 EDT
  and symbols verified. Matching bundle `com.ericlee4992.workouttracker`, team `X68M8SR6NA`.
- Read both built provisioning profiles: app expires 2026-09-24 07:16:18 UTC, widget expires
  07:16:20 UTC. Both were created September 17; no renewal or longer expiry is claimed.
- Before install, phone app was not running (only its widget processes). Copied its complete
  data container via `devicectl device copy from` to
  `/Users/ericlee06/WorkoutTracker-Backups/2026-09-17-before-ticket17` outside Git: 24 files,
  24,245,971 bytes. SQLite `quick_check` passed on `Library/Application Support/default.store`
  and HTTP storage; SHA-256 manifest beside backup. Directory access restricted to the user.
  This is a fresh raw device backup, not a new portable CSV/JSON export or a tested restore.
  No schema/history migration is part of this layout-only installation.
- Installed at 21:43 EDT with same bundle identity (preserves the data container): device tool
  exit **0**, JSON outcome **success**, new app installation UUID
  `043B11E1-78BA-4185-8A2C-5F1AF0B61686`.
- Launched at 21:44 EDT: device tool exit **0**, JSON outcome **success**, process **15231**.
  No launch arguments or test fixture flags used. A follow-up process query confirmed PID 15231
  still running. This is actual OS-reported launch evidence.

Build/install/launch logs and JSON live in the main checkout at
`/Users/ericlee06/orca/projects/Health App/work-record/ui-redesign/results/17-install/`
(gitignored). The raw backup stays outside the repository. No phone data was committed.

The user's separate “queued follow-up inputs” question was checked against the visible Codex
CLI: it shows one pending question. That is the earlier asynchronous finish-summary preference
question; the user already answered in normal chat by choosing the current screen. No further
answer is required and it did not block installation.
