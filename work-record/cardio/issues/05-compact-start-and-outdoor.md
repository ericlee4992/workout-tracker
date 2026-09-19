# 05 — Arrowless Start row and simpler outdoor cardio

Type: task
Status: resolved — merged, installed and launch-verified

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

## Initial verification and review

Initial build/focused product **b0d29fa**: build exit0, 5 focused tests passed (exit0).
Claude F1: removed live editor made the denied-location instruction obsolete. Resolve by
deleting “You can enter distance manually.” from that status, reusing existing “Location
unavailable.” copy; no new wording or sensor behavior. This follows the user's removal of
the live affordance and is explicitly recorded under D54. Saved correction remains reachable.
F3: shared capsule comment now says optional trailing symbol.
F2: review inferred iPhone15 Pro/393pt, but devicectl identifies **iPhone15 Pro Max, iPhone16,2**.
Will additionally capture the actual matching simulator model before install.

Final sequential runner PID **56510**, `run-final-focused.sh`: final-build, existing
CardioRecorderTests (`recorder`), final-focused(5), phone-size(1) on WT-iPhone15ProMax.
Each uses matching `.log`, `-exit.txt` and `.xcresult` names in the same result directory.
Denied/restricted status copy is checked directly in production branch and re-reviewed;
no permission-injection seam or copy-mirroring test added for a deleted sentence.

Final product/tests **7825140**: final-build exit0; existing recorder7/7, final-focused5/5,
phone-size1/1 all passed, no failed/skipped, exit0 (actual xcresults inspected).
Phone-size ran iPhone15ProMax/iPhone16,2, matching actual phone; first boot took3minutes,
then capture passed. Row fits with full labels; phone-specific screenshot shown to user.
11 selected final PNGs under `../screenshots/compact-start-outdoor/`; parent opened Start
default/AXL and outdoor details pairs and matching-phone capture.
Full UI runner PID **61459**, `run-full-ui.sh`, `full-ui.log`, `full-ui-exit.txt`,
`full-ui.xcresult`. Code unchanged after7825140; artifacts remain in this worktree.

## Final verification — 2026-09-19

Product/tests **7825140**, records/capture tip **0ffafd9**. Build exit0; recorder **7/7**,
focused UI **5/5**, matching-phone layout **1/1**, full UI **81/81** passed. All actual
exit files are0; xcresult summaries inspected, no failures/skips. Full UI finished02:58 EDT,
2901 seconds, TEST SUCCEEDED. 24 known non-failing invalid-frame warnings, same count/class
as prior suites; origin uninvestigated. Full runner61459 completed.

Code/visual review clear; F1/F2/F3 resolved, F4/F5 informational. Location denied copy
verified directly in production branch; existing recorder suite passed, no special denied
UI fixture/injection seam added for deleted wording. No domain math/schema/sensor algorithm
change. Product/test/config tree unchanged after7825140. Relative links and exact archive
preservation checked. Final independent artifact clearance requested before merge/install.

Independent [Claude final review](../claude-compact-start-outdoor-review.md), authored
at e0d2bd2, is **MERGE CLEARED** after reading actual artifacts. Product/tests7825140,
evidence0ffafd9; subsequent changes documentation only. Main fast-forward/push with this
checkpoint, then signed device build/install as continuation of authorized UI feedback.

## Installation and delivery

Merged/pushed main **c127832**, remote tip verified. Continued the authorized device-feedback
update workflow. Built from clean main c127832 (product/tests **7825140**) at
`/tmp/wt-compact-start-outdoor-device-20260919`, build exit 0. Fresh dylib timestamp and
new compiled `startChoices` symbol verified, app/widget signatures and same bundle IDs/team
verified. Profiles remain September 24 07:16:18 /07:16:20 UTC (app/widget).

Installed **2026-09-19 03:02 EDT**, devicectl **exit 0 / success**, installation UUID
`8B8F2BC1-5823-48B3-97CB-2CB262F1F216`. Launch **exit 0 / success**, PID **3758**,
then independently confirmed running via device process list. No reset/uninstall. No schema
or history migration; prior private backup retained, no new backup or restore claimed.

Artifacts: main `work-record/ui-redesign/results/compact-start-outdoor-install/`, build
script/log/exit, binary-verification.json, install/launch logs/JSON/exits and processes.json.
Runner 69990 completed. New matching-phone simulator WT-iPhone15ProMax is retained for
future width verification. Existing-history content not inspected; physical acceptance
remains ticket 02. Product/test code unchanged after7825140.
