# 17 — Finish summary: pair related workout metrics

Status: claimed — selected design implemented; verification and independent review running

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

## Next action

Inspect build/focused results, export/open the real captures, show the selected screen in
Orca's browser, and obtain Claude's independent clearance while the full UI suite runs.
Then commit/push, fast-forward/push main only after all gates are clear. Phone installation
is not part of this request; live build remains `0b6515f`.
