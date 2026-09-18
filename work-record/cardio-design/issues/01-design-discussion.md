# 01 — Cardio design discussion

Type: prototype
Status: claimed — native designs under review; user choice pending

## Accepted scope and workflow

The user wants live gym cardio (timer, heart rate, calories and distance) and outdoor runs/
rides with GPS routes. Mixed workouts save as **one workout with separate lifting and cardio
sections**. The user explicitly requested design screens before feature implementation.
D15 is reopened for design; no cardio feature or schema change is shipped.

## Current design artifact

Throwaway branch `ericlee4992/cardio-design-prototype`, source `4f004be`, based on main
`e51695b`. Checkout `/Users/ericlee06/orca/workspaces/Health App/cardio-design-prototype`.
The design ticket, source, screenshots and gallery are preserved on that branch:

- [Full design record](https://github.com/ericlee4992/workout-tracker/blob/4f004be/work-record/cardio-design/issues/01-design-discussion.md)
- Gallery: `work-record/cardio-design/gallery.html` in the prototype checkout (open in main's
  Orca browser). It compares A inline sections, B activity focus, C timeline, and five shared
  flow screens. Toggle default/AccessibilityL; click captures to enlarge.
- `WorkoutTracker/Features/Prototypes/CardioDesignPrototype.swift` contains sample UI only,
  gated behind DEBUG + disposable UI-test store + explicit environment variable. Never merge
  that throwaway source into main or install it on the phone.

## Evidence and next action

Debug build exit 0; two native capture drivers **2/2**, exit 0, no failures/skips/runtime
warnings. 34 real simulator PNGs. These are rendering evidence, not functional cardio tests.
Raw script/log/result/exit files remain at `work-record/ui-redesign/results/cardio-prototype/`
in that checkout; runner PID 91563 completed. Independent Claude visual/design review is
running in separate checkout `review-cardio-design`; report expected at
`work-record/cardio-design/claude-review-01.md`. No source clearance claimed yet.

Next: resolve required review findings, show the gallery and get the user's choice. Then
write the implementation spec before touching persistence/HealthKit/GPS. Open design details:
manual versus connected gym distance, pause and transition semantics, cardio goals,
background GPS handling, HealthKit representation and export. Apple documents limited mixed
activity support in HKWorkoutActivity; one in-app History entry need not equal one HealthKit
workout. Do not promise arbitrary mixed HealthKit activity types or duplicate calorie totals.

Sources: [Apple workout types](https://support.apple.com/en-us/105089),
[HealthKit activities](https://developer.apple.com/documentation/healthkit/dividing-a-healthkit-workout-into-activities).

Separate ring ticket 18 is closed because the user checked it and confirmed it actually works.
