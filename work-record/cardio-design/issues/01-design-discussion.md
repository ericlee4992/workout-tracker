# 01 — Cardio design discussion

Type: prototype
Status: claimed — direction B selected; indoor device policy and feature specification pending

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

## Independent review checkpoint

[Claude review](../claude-review-01.md) cleared the docs-only `c5449c9` checkpoint and ring
closure. The first prototype review found three required design-record/palette/control
issues (R1–R3); corrections and fresh captures are in progress on the prototype branch.
No production cardio code will merge as part of this checkpoint.

## Final reviewed designs

Reviewed source **48608fb** on the same prototype branch. [Claude follow-up](../claude-review-02.md)
is **CLEAR**: R1–R3 resolved, no required findings. Final capture/build exits 0, capture drivers
**2/2**, no failures/skips/runtime warnings. The gallery shows 29 distinct views from 37 PNGs.
Updated gallery/ticket disclose A’s scrolling trade-off at both default and AccessibilityL.
The existing app’s real tab order/icons remain the implementation baseline (A10 is illustrative
prototype chrome, not a request to change navigation).

[Reviewed prototype record](https://github.com/ericlee4992/workout-tracker/blob/48608fb/work-record/cardio-design/issues/01-design-discussion.md).
Gallery stays at the same local path and is open in main’s Orca browser. All test/build jobs
finished. Next action is **the user’s design choice**, then a proper feature spec; no cardio
implementation has started. The phone and production app source remain unchanged.

## User decision — 2026-09-18

“Regarding design direction, lets go with B.” **B is selected:** focus on the current
activity while keeping one workout with separate lifting and cardio sections. Start Lifting
and Start Cardio determine the first activity; either kind can be added mid-workout. The
throwaway view remains a design source, not production implementation. The previous “user
choice pending” checkpoints above are historical and superseded by this decision.

The user also wants indoor activity choices aligned with Apple Fitness and asks whether to
require a connected AirPods/Watch device, wondering whether it is needed for distance.
**A device gate has not been selected.** Proposed policy: keep the activity list available;
show automatic metrics only when a supported source supplies them; allow a timer and manual
machine-distance entry without a wearable. Label source/estimated values, omit unavailable
HR/calories, and preserve the session if a sensor disconnects. This is a recommendation
awaiting discussion, not an approved acceptance criterion.

### Verified Apple behavior and limits

- Apple's iPhone Fitness guide lists phone-only outdoor walk/run, hiking, wheelchair push
  walking/running pace and outdoor cycle. Connected Apple Watch, AirPods Pro 3, Powerbeats
  Pro 2 or compatible Bluetooth HR monitors enable additional workout types. This refers to
  compatible HR hardware, not every AirPods generation or arbitrary Bluetooth connection.
  Apple documents the capability difference but does not state that distance alone motivates
  the restriction. [iPhone guide](https://support.apple.com/en-gb/guide/iphone/iph8475d8510/ios).
- AirPods Pro 3 supply heart-rate AND motion data to iPhone for metrics including calories,
  steps and distance. Do not describe them as HR-only or claim they can never contribute to
  indoor walking/running distance. Availability through this app's public APIs and the iOS 26
  deployment floor still needs verification before promising automatic distance.
  [AirPods guide](https://support.apple.com/guide/airpods/track-heart-rate-workouts-airpods-pro-3-dev1b40fb47d/web).
- Apple Watch calibration learns stride length at different speeds and improves distance
  when GPS is limited/unavailable. A wearable-derived distance is an estimate, not the
  treadmill's own measurement. [Calibration](https://support.apple.com/en-us/105048).
- Compatible gym equipment can pair with Apple Watch for synchronized workout data. This
  does not establish general machine connectivity in this app or that a generic HR monitor
  supplies bike/rowing/elliptical distance.
  [Gym equipment](https://support.apple.com/guide/watch/use-gym-equipment-apd15b0268fd/watchos).

No app/test/schema changes, build, phone installation or new device integration in this
checkpoint. Direction B is accepted; sensor policy is the next discussion.
