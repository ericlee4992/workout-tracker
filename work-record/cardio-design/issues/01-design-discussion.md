# 01 — Cardio design directions

Type: prototype
Status: claimed — native mockups reviewed CLEAR; awaiting user choice; no production cardio implementation

## User decisions

- Live gym cardio: timer, heart rate, calories and distance.
- Outdoor runs and rides, including GPS routes.
- One saved workout in this app's History, with separate lifting and cardio sections.
- Show design screens before building the feature.

D15 (strength-only v1) is reopened for this feature discussion at the user's request.
The implementation specification and persistence schema are not changed yet.

## Prototype

Branch `ericlee4992/cardio-design-prototype`, base `e51695b`.
Native SwiftUI mockups using existing Theme and buttons, gated behind DEBUG + `-uiTestReset`
+ `CARDIO_SCREEN`. Only sample data; no cardio persistence, sensors, route recording or
HealthKit changes. This throwaway branch must not be merged into main. Preview views live
under `WorkoutTracker/Features/Prototypes/CardioDesignPrototype.swift`.

The design canvas is unavailable, so the ios-design fallback is real simulator captures of
native preview screens. Prototype/UI.md's URL-variant concept is adapted to launch environment
`CARDIO_VARIANT=A|B|C` and the in-preview switcher. It is hidden for captures.

## Screen jobs and states

- Start, idle: start the intended activity in one tap; Start Lifting remains the primary
  action and Start Cardio is secondary. Templates are below both.
- Activity picker: choose the cardio kind in one tap; a grouped list leads, Gym and Outdoors
  are distinct sections. Search is illustrative in this mockup.
- Mixed, cardio live: control the current cardio segment once its controls are visible; the timer is the bold
  figure and Pause is its primary control. Completed lifting steps down.
- Cardio, paused: resume in one tap; the elapsed value stops and the primary action is Resume.
- Outdoor, live: glance at time/distance/pace and route; timer leads, map supports orientation.
- Summary: inspect one saved workout and open History in one tap; View in History stays
  primary, lifting and cardio have their own detail sections under combined session metrics.

## Three compositions

A — Add cardio in place (most familiar)
```
Workout title                                      Finish
Gym / session clock
Lifting                         closed ring 18/18 sets
[collapsed lifting summary]
Cardio                                      In progress
[Indoor Run    expand]
[          segment timer                      ]
[HR / active calories                        ]
[machine distance field                      ]
[Pause / End Cardio                           ]
Add Exercise / Add Cardio                     pinned
```

B — Focus on the current activity
```
Workout title                                      Finish
Gym / session clock
[ Lifting done | Cardio selected ]
Indoor Run
                segment timer                      largest
HR / active calories
Machine distance field
Pause / End Cardio
Lifting completed — 6 exercises / 18 sets            compact
Add Exercise / Add Cardio                     pinned
```

C — Session timeline
```
Workout title                                      Finish
Gym / session clock
✓ 20:00 Lifting — 6 exercises / 18 sets
│
● 21:09 Indoor Run — live
│             segment timer                         largest
│ HR / active calories
│ Machine distance
│ Pause / End Cardio
Add Exercise / Add Cardio                     pinned
```

Shared screens: Start, cardio picker, expanded gym-cardio view, outdoor GPS view, combined
summary. Keep the existing dark/amber visual language. These are new proposed strings,
explicitly up for user approval in this design round; existing production strings do not change.

## Tells

- Containers deliberate: exercise/summary groups keep existing cards; live focus and timeline
  directions use unboxed primary numbers. Machine distance is an editable field.
- Chips absent beyond the two-option activity selector in B; it is navigation, not a CTA.
- All-caps headings absent.
- Middle-dot metadata deliberate: existing compact contextual style for sensor/source and counts.
- Accent density deliberate: live/selected state, one primary live control; other actions neutral.
- Equal-weight blocks deliberate: related metric pairs; AccessibilityL stacks them.
- Phone-sized website absent: native SwiftUI navigation, controls, symbols and type.
- Content above fold deliberate per variant: A preserves lifting first, so at AccessibilityL
  the cardio timer and controls require scrolling past completed lifting. B brings live cardio
  forward. C prioritizes chronological context; live controls may also require scrolling.
  The expanded gym/outdoor views pin the live controls. This is a trade-off to choose explicitly.
- Picker as primary absent: picker opens from a command, then uses equal list rows.
- Default-size-only absent: same sample states captured at default and AccessibilityL.

## Open decisions / limits

- Recommendation: common Gym and Outdoor types first, rather than every Apple sports category.
- Gym distance comes from manual entry unless supported equipment/sensors provide it. Mock value
  `2.40 km` is entered machine distance, not a claim of automatic treadmill measurement.
- Outdoor map uses illustrative Central Park coordinates, unrelated to the user's location;
  no actual GPS recording or pace calculation runs in this mockup.
- Pause/resume, transitions and finish semantics still need specification. Mock buttons only
  navigate or change local preview state; they are not acceptance evidence for functionality.
- Apple Health mapping must be deliberate: Apple's documented workout-activity model allows
  swim/bike/run multisport and same-type intervals, not arbitrary lifting/cardio mixtures.
  Keep one History entry here; decide HealthKit representation separately without double-counting.
- Combined calorie numbers and per-segment values are illustrative, not queried sensor results.
- Watch-independent outdoor phone tracking is in scope for discussion; watch companion work is
  not implicitly authorized or required by these mockups.

Sources: [Apple activity types](https://support.apple.com/en-us/105089),
[HealthKit activities](https://developer.apple.com/documentation/healthkit/dividing-a-healthkit-workout-into-activities).

## Capture job

Detached PID **91563**. Script/log/exit/result under
`work-record/ui-redesign/results/cardio-prototype/`: `capture.sh`, `runner.log`,
`captures.log`, `captures-exit.txt`, `captures.xcresult`.
Derived data `/tmp/wt-cardio-design-derived`. Two capture-driver methods visit eight screen
states each (A/B/C mixed, Start, picker, gym, outdoor, summary), at default and AccessibilityL.
These are rendering captures only, not feature tests or release verification.

## First capture results

Both capture drivers passed, actual exit **0**, **2/2**, no failures/skips/runtime warnings
in the result summary. Exported 34 real simulator PNGs into `screenshots/`. Reviewed them
as images. These establish that the sample screens render, not that cardio works.
The sets-ring report is separately closed: user confirmed it actually works, no app change.

## Review corrections — recapture 3

Initial independent review at `4f004be`: R1 inaccurate above-fold claim, R2 zone colours,
R3 primary-control mismatch. Report preserved at `claude-review-01.md`.

- R1: ticket and gallery now explicitly say A requires scrolling past completed lifting at
  AccessibilityL. Familiarity is the recommendation, not superior one-tap access; B leads with
  the live activity. C now uses the same lifting→run fixture as A/B (removed extra sample walk).
- R2: gym/outdoor now use the real `HeartRateZone.two/three.color` palette.
- R3: Pause is primary and End Cardio secondary in A/B/C, equal-width at default and stacked
  at AccessibilityL. All mixed variants now get a default scroll capture too.
- Advisory corrections: Start uses real native TabView chrome; removed its extra template Start
  pill; expand/+ buttons have 44 pt minimum frames; summary reuses existing StatTile pairs;
  gallery suppresses identical scroll images. Samples/stub navigation remain deliberate.

Intermediate recapture 2 passed 2/2, exit 0. Final recapture 3 PID **3000** uses `capture-3.sh`, `runner-3.log`, `captures-3.log`,
`captures-3.xcresult`, `captures-3-exit.txt`, same derived data. Result pending.

Final recapture 3: **2/2 passed**, actual exit **0**, no failures/skips/runtime warnings.
Fresh Debug build `build-3.log` / `build-3-exit.txt` also passed (0). Exported 37 screenshots;
the gallery shows 29 distinct views after byte-hash deduplication. Source is unchanged since
this capture build. Opened and inspected the new Start AXL, mixed controls, zone colours and
summary tiles as images. Independent follow-up review pending.

## Design delivery checkpoint

Source **48608fb** independently **CLEAR** in [Claude follow-up](../claude-review-02.md).
R1–R3 resolved. Advisory A11 also reflected in gallery: A controls require a short scroll at
default, and its timer also falls below completed lifting at AccessibilityL. A10 (prototype
tab order/icons differ from RootView) is illustrative chrome, not a proposed production change;
retain the real app’s tab order/icons during implementation. Other advisory choices await the
user’s preferred composition. No production feature code, schema change or phone install.

The gallery is open in main’s Orca browser. **Next action: user chooses A/B/C or a combination.**
Do not infer permission to implement from completion of this design prototype. All jobs are
finished; logs/results remain under the recorded paths. Main’s docs-only checkpoint records
the scope and the closed ring report separately; never merge this throwaway UI branch.
