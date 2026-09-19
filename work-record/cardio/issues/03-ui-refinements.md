# 03 — Cardio presentation refinements

Type: task
Status: resolved — merged, installed and launch-verified

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

Build passed (exit 0). Implementation committed/pushed as **3020180**; code under test is
identical to that commit. Full UI runner PID **1758**, `run-full-ui.sh`, queued after
focused success on the same simulator; `full-ui.log`, `full-ui-exit.txt`, `full-ui.xcresult`.
Claude reviewing in `review-cardio-ui-refinements`, terminal
`term_25860acb-53b5-4121-bb08-e6bcc224a6c0`; code/visual clearance pending.

Initial Claude review: code paths clear; T1 test could assert caption absence before data
arrived. Moved the assertion after measured-data wait and added automatic-distance checks
in ended segment, receipt and History. L1 equal-height improvement applied. L2: deliberately
use compact text-only standard buttons for idle Start so both full labels fit side by side;
Resume and template detail retain their capsule. This implements the user's selected side-by-side
composition using existing tokens; default/AXL captures will be shown. Full-UI queued runner
1758 was stopped before it started tests; final focused verification will precede the full suite.

Final sequential runner PID **4631**, `run-final.sh`: waits for original focus to release simulator,
then `final-build`, `final-focused` (9), `full-ui` (81), each with `.log`, `-exit.txt` and test
`.xcresult` under the same artifact directory.

Initial focused result: 7 passed / 2 failed, exit 65. Both outdoor tests passed absence
before Finish and map presence after Finish, then failed reaching the receipt's History
link. A single-test `outdoor-repro` (runner PID 5229, test-without-building, same bundle)
reproduced it. Logs show ten upward swipes after scrolling below the link; exported Summary
capture contains the expected route. Hypotheses: (1) wrong scroll direction for lazy link,
(2) link removed by finish behavior, (3) sheet overlay intercepting. Evidence favors (1):
the link existed before scrolling; Summary is still presented. Fixed only the test helper
to scroll down toward the top for this known-above action. Skipped broader instrumentation/
bisection because the failing command, exact scroll trace and capture isolate a test-navigation
error, not a product defect. Final focused run is the regression check.

Reproduction exit 65 confirmed. Final sequential runner restarted as PID **6068** after
repro completion; prior queued PID 4631 stopped before testing. `final-build-exit.txt` = 0.
Final focused tests running, followed automatically by full UI if successful.

Final focused: **9 passed, 0 failed/skipped, exit 0**, xcresult inspected. Product/test input
**269498b** (the working diff was committed during the run, contents unchanged). Two known
invalid-frame warnings; same class as prior cardio, origin not investigated. Full UI running.
[Native capture gallery](../ui-refinements-gallery.html): 15 PNGs exported under
`../screenshots/ui-refinements/`; paired Start, automatic distance, live/ended outdoor,
Summary and History. Parent inspected them as images. Start labels whole and equal-size;
caption removed; active/ended maps absent; saved maps present. AXL Summary capture includes
only upper part of the map; full History route is captured. Claude visual review pending.

Claude code/visual review clear on 269498b; final suite clearance remains pending.
V2: supplementary AXL receipt map screenshot not required by reviewer (viewport clipping,
same component fully captured in History); no new test run. V3: exported mixed History
shot showing automatic Distance edit action, bringing the selected record to 16 PNGs.
N3: STATE now names 269498b. Start default/AXL capture links shown to the user.

## Final verification — 2026-09-19

- Tested product/tests: **269498b**; subsequent **9c7d1b7** is documentation/captures only.
- Debug `final-build`: **exit 0**. Focused: **9 passed**, 0 failed/skipped, **exit 0**.
- Full UI: **81 passed**, 0 failed/skipped, **exit 0**; log `TEST SUCCEEDED`, actual xcresult
  summary inspected. Completed September 19 00:11 EDT, 2902 seconds of test execution.
- Full suite reports 24 known invalid-frame warnings, same class/count as pre-change cardio;
  origin remains uninvestigated. No domain/schema/sensor changes, so no unit-suite rerun.
- No build/test job remains from this ticket; artifacts and scripts preserved in the
  implementation worktree. Runner 6068 completed.
- 16 committed PNGs plus gallery, default/AccessibilityL pairs inspected; code and visual
  Claude review clear. Independent final artifact clearance requested.
- Relative links checked; archived STATE is byte-identical to 21ef98f; product/test/config
  tree unchanged after 269498b. No device installation performed for ticket 03.

## Clearance and delivery

Claude independently read final build/focused/full artifacts and issued **CLEAR TO MERGE**
in [review](../claude-ui-refinements-review.md). Required T1 resolved and re-reviewed;
L1/L2/V3/N3 addressed. Start default/AXL and automatic-distance capture links shown to user.
Final branch is `ericlee4992/cardio-ui-refinements`; reviewed code **269498b**, evidence
checkpoint **9c7d1b7**. Further commits are records only. Main is fast-forwarded with this
checkpoint; no PR required. At merge, installation was pending; the authorized installation below supersedes that state.
Remaining physical device acceptance stays in ticket 02.

## Authorized installation — 2026-09-19

User requested “install.” Built from clean main **a7d3d41**, reviewed product/tests **269498b**,
with Xcode 27.0 at `/tmp/wt-cardio-ui-device-20260919`; build exit 0 / BUILD SUCCEEDED.
Only the two UI files differ from the prior installed c847ef3 product; no schema/history
migration. Existing September 18 private backup retained; no new backup or restore claimed.

Verified fresh debug dylib timestamp plus `distanceSourceCaption` / `showsRoute` symbols,
app/widget signatures and same bundle IDs/team. Profiles remain valid: app expires
2026-09-24 07:16:18 UTC, widget 07:16:20 UTC. Initial device connection failed; one retry
connected and confirmed unlocked. Installed **2026-09-19 00:34 EDT**, devicectl **exit 0 / success**,
installation UUID `EA8B303F-42B0-4A9D-BCC4-D35483E42D5F`. Launch **exit 0 / success**,
app PID **3283**, then independently found still running via device process list. Widget
process PID 3275 also appeared; this does not establish visual widget acceptance.

Logs/JSON/scripts: main `work-record/ui-redesign/results/cardio-ui-install/`, including
`build-exit.txt`, `binary-verification.json`, `install.json`, `install-exit.txt`,
`launch.json`, `launch-exit.txt`, `processes.json`. Build runner 22662 finished.
No reset/uninstall performed; same bundle ID preserves the container. Existing-history
content was not inspected. Hardware acceptance remains separately tracked in ticket 02.
