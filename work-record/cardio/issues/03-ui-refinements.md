# 03 — Cardio presentation refinements

Type: task
Status: claimed

User request 2026-09-18: indoor distance works with AirPods Pro 3; remove the HealthKit
estimate label, show routes only in workout Summary/History, and put Start Cardio beside
Start Lifting. This explicitly amends D15/D54's accepted cardio composition and copy.
The requested composition is selected; no alternative-design approval is needed.

## Acceptance and composition

- No visible HealthKit estimate caption in live, completed-segment, receipt or History views.
  Preserve measured distance, provenance, manual editing and other source labels.
- No map anywhere in an unfinished workout, including ended cardio segments. Recording
  continues; finished Summary and History retain the route.
- Start buttons share a row and equal width at ordinary sizes. Accessibility sizes stack.
  Existing start/resume behavior and identifiers remain.

In the idle Start state this screen exists so the user can start either activity in one tap;
the eye lands on the amber Start Lifting button, with Start Cardio a secondary peer.
In the resumed Start state the eye lands on the unchanged Resume capsule.
In active cardio the screen exists so the user can read metrics and pause in one tap;
the eye lands on the timer, with metrics subordinate and Pause the sole amber command.
Completed cardio within a live workout shows metrics; routes belong to the finished screens.

```
Start:   [ gym selector                          ]
         [ Start Lifting (amber) ][ Start Cardio ]  equal widths
         Templates grid below
AXL:     same reading order; start buttons stack
Cardio:  header / focus switch / activity
         TIMER (largest) / metrics / distance edit
         Pause / End Cardio (pinned)
Finish:  existing summary / cardio metrics / route
History: existing details / cardio metrics / route
```

Tells: same container everywhere absent; caption chips absent; extra all-caps labels absent;
middle-dot metadata deliberate in unchanged resume/template details; accent proliferation
absent; stacked equal-weight blocks absent (AXL buttons differ in prominence); website hero
absent; unnecessary above-fold content removed (map); disguised commands absent; default-only
layout absent (AXL stacks). No new visible copy beyond reuse of Distance for the edit action.

## Verification plan

Debug build; focused CardioUITests (7) plus paired Start captures in
RedesignScreenshotUITests (2); full local UI suite (81 expected). Inspect actual xcresult
summaries and default/AccessibilityL captures. Claude independently reviews code and visuals.
No domain math, sensor collection, persistence or schema change is intended.

## Progress

Base main 21ef98f; branch ericlee4992/cardio-ui-refinements. UI implementation complete; verification running. No schema/sensor changes.

Detached runner PID **97931**, worktree
`/Users/ericlee06/orca/workspaces/Health App/cardio-ui-refinements`.
Artifacts: `work-record/ui-redesign/results/cardio-refinements/` in that worktree;
`run-focused.sh`, `build.log`, `build-exit.txt`, `focused.log`, `focused-exit.txt`,
`focused.xcresult`. Working diff against 21ef98f is the tested input (commit after build succeeds).
