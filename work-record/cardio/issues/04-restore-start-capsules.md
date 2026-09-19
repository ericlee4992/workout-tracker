# 04 — Restore the original Start capsule buttons

Type: task
Status: claimed

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
