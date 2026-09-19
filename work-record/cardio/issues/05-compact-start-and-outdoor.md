# 05 — Arrowless Start row and simpler outdoor cardio

Type: task
Status: claimed

User request 2026-09-19: put the original icon capsules on one row by removing arrows;
remove the outdoor cardio GPS section. Reopens ticket04/D54 stacked layout explicitly.
D15 presentation changes only; no assertion that GPS measurements are always available.

## Acceptance / composition

- Keep amber capsule, dark activity-icon disc and body-bold label. Remove arrows from the
  two idle Start choices; place side by side when full labels fit. Responsive vertical
  fallback for larger text/narrow widths; no font shrinking or mid-word breaks.
- Resume and template Start keep their existing arrows and original padding/behavior.
- Outdoor live cardio removes the duplicate GPS/distance edit row, retaining the main
  Distance metric, pace/speed, location failure/status messages and continuous recording.
  Indoor distance edit/fallback remains. Finished Summary/History correction remains.
- Maps still appear only after Finish. No model/schema/source/route/permission changes.

In idle Start the screen exists to choose Lifting or Cardio in one tap; the eye lands on
matching amber icon capsules below Gym. Two prominent peer choices remain user-authorized.
In live outdoor cardio the screen exists to read progress and pause in one tap; timer is
hero, main Distance/pace metrics subordinate, Pause the sole amber command. Removing the
redundant GPS editor does not remove the primary distance readout.

```
[ Gym selector                                    ]
[ (lifting) Start Lifting ][ (running) Start Cardio ]
[ Templates                                       ]
Large text / narrow fit: choices stack, full words retained.
Outdoor: header / focus / activity / TIMER / Distance + pace / HR + calories
         optional location status / Add actions / pinned Pause + End
```

User selected this composition directly; no alternatives approval is needed. Tells:
uniform containers absent; chips absent; all-caps proliferation absent; middle-dot metadata
deliberate in existing details; two amber commands deliberate (equal activity choice);
stacked equal weight deliberate only when responsive fit requires it; website hero absent;
excess above-fold content removed (duplicate GPS row); disguised commands absent; default-only
layout absent (fit-driven stack). New UI strings: none.

## Verification

Debug build; 2 Start and 2 outdoor default/AccessibilityL focused capture tests, plus existing
indoor edit regression; inspect/show captures, independent Claude code/visual review and full
local UI suite (81 expected). Only UI/test files; no domain suite or migration change.

Base main **0e16a8c**, branch `ericlee4992/compact-start-outdoor`. Implementation pending.

## Progress

Implementation in `/Users/ericlee06/orca/workspaces/Health App/compact-start-outdoor`.
Detached build/focused runner PID **49847**; artifacts under
`work-record/ui-redesign/results/compact-start-outdoor/`: `run-focused.sh`, `build.log`,
`build-exit.txt`, `focused.log`, `focused-exit.txt`, `focused.xcresult` (5 tests).
