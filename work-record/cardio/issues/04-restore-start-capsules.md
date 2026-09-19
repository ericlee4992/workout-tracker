# 04 — Restore the original Start capsule buttons

Type: task
Status: claimed

User correction 2026-09-19: disliked ticket 03's changed Start Lifting appearance; restore
its previous design and give Start Cardio the same design, including its activity logo.
The earlier adjacent-button request remains. This explicitly supersedes ticket 03's compact
text-only idle buttons and amends D54: the idle choice pair uses two matching amber capsules,
an intentional exception to one accented command. The user selected the existing design;
no alternative mock or extra approval is needed for this restoration.

## Acceptance / composition

- Reuse the original HeroCapsuleLabel: amber capsule, ink icon disc, body-bold title and
  arrow. Lifting uses figure.strengthtraining.traditional; Cardio uses figure.run.
- Matching equal-size peer choices beside each other at default size, stacked at larger
  text sizes when necessary. Both full labels and glyphs readable; no font shrinking.
- Resume and template detail retain existing treatment and actions. Keep start identifiers
  and cardio picker/start flow. Ticket 03's map/label behavior remains.

In idle Start the screen exists so the user can choose Lifting or Cardio in one tap;
the eye lands on the matching activity capsule pair below the gym selector, above Templates.
The user explicitly wants equal visual prominence for those peer choices.
In live Start the eye lands on the existing single Resume capsule.

```
[ Gym selector                                      ]
[ (lifting icon) Start Lifting ↗ ][ (run) Start Cardio ↗ ]
[ Templates grid                                    ]
Large text: same reading order, capsule choices stack.
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
