# 04 — Restore the original Start capsule buttons

Type: task
Status: resolved — merged, installed and launch-verified

User correction 2026-09-19: disliked ticket 03's changed Start Lifting appearance; restore
its previous design and give Start Cardio the same design, including its activity logo.
User then explicitly chose **stacked** after seeing the side-by-side wrap tradeoff;
this supersedes the earlier adjacent-button request. This explicitly supersedes ticket 03's compact
text-only idle buttons and amends D54: the idle choice pair uses two matching amber capsules,
an intentional exception to one accented command. The user selected the existing design;
no alternative mock or extra approval is needed for this restoration.

## Acceptance / composition

- Reuse the original HeroCapsuleLabel: amber capsule, ink icon disc, body-bold title and
  arrow. Lifting uses figure.strengthtraining.traditional; Cardio uses figure.run.
- Matching peer capsules stacked at every text size, original single-line titles and
  content-hugging width, aligned leading. Both full labels and glyphs readable; no font shrinking.
- Resume and template detail retain existing treatment and actions. Keep start identifiers
  and cardio picker/start flow. Ticket 03's map/label behavior remains.

In idle Start the screen exists so the user can choose Lifting or Cardio in one tap;
the eye lands on the matching activity capsule pair below the gym selector, above Templates.
The user explicitly wants equal visual prominence for those peer choices.
In live Start the eye lands on the existing single Resume capsule.

```
[ Gym selector                                      ]
[ (lifting icon) Start Lifting ↗ ]
[ (running icon) Start Cardio ↗ ]
[ Templates grid                                    ]
Default and large text: same stacked reading order and original capsule geometry.
```

Tells: uniform containers absent; caption chips absent; extra all-caps absent; middle-dot
metadata deliberate (unchanged resume/template metadata); two amber commands deliberate
(user expressly requests same original design); equal peer weight deliberate (activity
choice); website hero absent; excess above-fold content absent; disguised commands absent;
default-only layout absent (larger text stacks). Existing visible copy and identifiers stay.

## Verification

Build; paired default/AccessibilityL Start captures using RedesignScreenshotUITests (2);
inspect real images and show user; full local UI suite (81 expected) before merge; independent
Claude code/visual review. No model, schema, recording, export or migration change.

Base main **62f9469**, branch `ericlee4992/restore-start-capsules`. Implementation pending.

## Progress

Build/focused runner PID **25797**, implementation worktree
`/Users/ericlee06/orca/workspaces/Health App/restore-start-capsules`; artifacts under
`work-record/ui-redesign/results/start-capsules/`: `run-focused.sh`, `build.log`,
`build-exit.txt`, `focused.log`, `focused-exit.txt`, `focused.xcresult`.

Build exit 0; focused **2/2 passed, 0 failed/skipped, exit 0**, actual xcresult summary read.
Product **5c51f69**; default and AccessibilityL captures exported under
`../screenshots/start-capsules/`, opened as images and linked to user. Default titles wrap
at word boundaries to retain the original icon/arrow design beside each other; AXL stacks
with whole labels. Resume/template use the unchanged default sizing.

Full UI runner PID **29355**, `run-full-ui.sh`, `full-ui.log`, `full-ui-exit.txt`,
`full-ui.xcresult` in the same artifacts directory. Independent Claude reviewer in
`review-start-capsules`, terminal `term_607a4c83-d519-4dc0-8bc1-c01abbe954e4`.

## Review follow-up

Claude F1: default screenshot wraps titles to two lines to retain adjacent original icons
and arrows. User was explicitly offered side-by-side wrapped titles versus stacked original
single-line capsules; preference pending. F3 (stacked content centering) is low/advisory;
shared Resume/template retain original hugging geometry.
F2: stack from `.xLarge` instead of `.xxLarge` to avoid narrow-phone word squeezing.
Full UI run of 5c51f69 deliberately interrupted (xcodebuild PID 29384) after review identified
this needed threshold change; it is not a passing gate and will be replaced on final code.

User answered **stacked**. F1 resolved by explicit choice: both original single-line
capsules now stack at every size. Removed fillsWidth and fixedSize changes entirely;
HeroCapsuleLabel is byte-identical to pre-task 62f9469, so F2/F3 no longer apply.
The only product edit is the idle Start choice block. Capture assertions now check
stacked geometry, equal heights and leading alignment rather than equal widths.

Original partial full-suite exit 75 (intentional interruption). Stacked build/focused
runner PID **31057**: `run-stacked.sh`, `stacked-build` and `stacked-focused`
logs/exits, `stacked-focused.xcresult`. Full suite will run on the final stacked code.

Final stacked product/tests **95a82dd**: build exit 0, focused **2 passed**, no
failed/skipped tests or runtime warnings, exit 0. Fresh `*-stacked.png` default/AXL
captures opened and links shown user. Prior un-suffixed PNGs are the superseded side-by-side
proposal. Final full UI runner PID **32074**, `run-stacked-full-ui.sh`,
`stacked-full-ui.log`, `stacked-full-ui-exit.txt`, `stacked-full-ui.xcresult`.

## Final verification — 2026-09-19

Tested product/tests **95a82dd**, records/captures **98d72fd**. Debug stacked-build exit 0;
stacked-focused **2/2 passed**, 0 failed/skipped/warnings, exit 0. Final stacked-full-ui
**81/81 passed**, 0 failed/skipped, exit 0; actual log and xcresult summary inspected.
Finished 01:36 EDT, 2916 seconds. 24 known invalid-frame warnings, same count/class as
prior run; origin uninvestigated. Runner 32074 finished. No code changes after 95a82dd.

Parent and Claude opened the final default/AccessibilityL stacked captures. Shared
HeroCapsuleLabel is unchanged from pre-task; user chose stacked explicitly. Earlier
side-by-side captures and interrupted exit-75 run are retained as superseded evidence,
not current acceptance. Unit suite not repeated: no domain/schema/sensor change.

Relative links, exact archive preservation and unchanged tested code checked. Independent
final artifact clearance requested. Current installed build remains a7d3d41 until delivery.

Claude independently verified the final artifacts and issued **CLEAR TO MERGE** in
[review](../claude-start-capsules-review.md), authored at f679e4c. Branch
`ericlee4992/restore-start-capsules`, product/tests95a82dd, evidence98d72fd; remaining
checkpoint changes are documentation only. Fast-forward main and push with this checkpoint,
then update the installed app as continuation of the authorized device-feedback correction.

## Installation and final delivery

Merged/pushed main **be5a3f0**, remote tip verified. Continued the previously authorized
installation workflow for the user's correction to the installed buttons. Fresh generic-iOS
build from clean main be5a3f0 (product/tests **95a82dd**) at
`/tmp/wt-start-capsules-device-20260919`, build exit 0. Only StartWorkoutView differs from
prior installed product; no schema/history migration and no new backup claimed.

Verified fresh dylib timestamp, both new idle HeroCapsuleLabel closure symbols, matching
app/widget bundle IDs and signatures, team X68M8SR6NA. Profiles expire September24
07:16:18 /07:16:20 UTC (app/widget). Phone initially reported locked; user prompted to
unlock. Install **2026-09-19 01:41 EDT**, **exit 0 / success**, installation UUID
`8CF16E2A-6EA5-445C-82E3-F8EB5BF6658C`. Launch **exit 0 / success**; PID **3586**
independently confirmed running in a subsequent device process list. No reset/uninstall.

Artifacts in main `work-record/ui-redesign/results/start-capsules-install/`: build script,
log/exit; binary-verification.json; install/launch JSON, logs and exits; processes.json.
Build runner 45140 finished. Physical cardio acceptance remains ticket02; existing-history
content was not inspected. Product/test code unchanged after 95a82dd.
