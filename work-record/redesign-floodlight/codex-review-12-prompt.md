Independent review (T6) of ticket 12 of the Floodlight redesign: the Cardio area in plain Floodlight — Choose
Cardio, the live cardio focus (ring, figures, heart-rate plate, paused and GPS states, the tray), the Distance
sheet, the ended-segment / receipt / History cardio cards with the route picture and splits, and the cardio-only
History hero — on branch `ericlee4992/redesign-floodlight-cardio`. Range: `af30f66..HEAD` (stacked on ticket 11's
tip `af30f66`). Claude implemented; you review. Run in the checkout `/tmp/wt-floodlight/cardio` and stay in it.

Read first: AGENTS.md; `work-record/redesign-floodlight/issues/01-implement-redesign.md` (user decisions,
including the 2026-09-28 "keep cardio plain floodlight", area order item 3); `issues/12-cardio.md` (scope, the
user's four decisions of 2026-09-28 — select then Start, GPS status only on a problem, the distance ring, the
receipt keeps its distance edit — job/state sentences, wireframe, tells, strings, identifiers, verification);
`.claude/skills/ios-design/REVIEW.md`; DECISIONS D15, D23, D47, D52, D57 and D59 (the September 19 cardio rules
it carries over from D54: no visible distance-source or estimate captions, manual distance for indoor cardio only
when nothing measured it or it was typed, outdoor live has no distance editor, "Location unavailable.", routes
only after Finish). Prototype captures `reference/prototype-cardio/{dark,light}/`; prototype source (read-only)
`/Users/ericlee06/orca/workspaces/Health App/redesign-prototype/RedesignPrototype/Sources/Screens/Cardio/` and
`…/Screens/Finish/FinishCardioCard.swift`, `…/Screens/History/HistoryDetailSections.swift`,
`…/Screens/History/WorkoutDetailScreen.swift` (H04). Actual captures: `captures/12/`. The old views:
`git show af30f66:WorkoutTracker/Features/Cardio/CardioViews.swift`.

Review for:
1. **Behaviour kept** against the old views and the recorder: explicit Start (the picker's Start, planned targets
   through the live screen's `startPlannedCardio` — can the picker start a target that `CardioSession` refuses, or
   end a running segment on one stray tap?); Home's picker still starts a workout with the chosen activity; Pause /
   Resume / End through `CardioRecorder`; the manual-distance rule (indoor only, when nothing measured or typed) in
   every place the distance can be edited (the ring, the Distance figure, the ended card, the receipt, History); no
   map while recording; `enterDistance` semantics (unit relabels, blank clears the manual value, a finished workout
   is marked edited only on a real change); D52 plain numbers.
2. **Derived figures** (`Domain/CardioReadout.swift`, `CardioReadoutTests`): the ring model (target → distance →
   sweep, target met), the pause duration after pause / resume / relaunch (`CardioSession.recover`), splits (active
   time with pauses, portions never joined, scaled to a typed distance, the part-unit tail, a route that starts late
   or has points outside the active intervals), last done (finished workouts only, the newest), the heart trace
   buckets (window edges, samples before the segment), the location status mapping from the recorder's messages.
   Edge cases that crash or divide by zero (empty route, zero distance, zero time, `CardioSplit` with 0 seconds).
3. **The live cardio focus** (`CardioLive.swift`, `ActiveWorkoutView`): the rows inside the live `List`; the vitals
   strip and the "Cardio targets" list hidden in cardio focus — is anything the user needs lost (the heart-rate
   source, the zone set-up path, a target's Start when the focus is Cardio but nothing is recording)? The heart
   plate's stale / missing reading (D44) and zone only with a maximum (D45); the tray's ViewThatFits at
   AccessibilityL covering the figures; the 1-second `TimelineView` cost; Reduce Motion (pulse, blink, flicker,
   ring, celebrate — follow each read of `accessibilityReduceMotion` / `cardioStill` to its effect).
4. **Accessibility identifiers and labels**: `cardioTimer` / `cardioDistanceMetric` move between the ring and the
   figures by ring mode — can a state have neither, or two elements with one id? The figures became single
   accessibility elements; VoiceOver labels say the value and the unit, never a source caption.
5. **The Distance sheet** (`CardioDistanceSheet.swift`): Save enabled only on a valid change; the Measured row;
   invalid entry; the average pace / speed readout; `SheetHeader` commit id.
6. **Cards and History** (`CardioCards.swift`, `WorkoutDetailView`): the receipt keeps the distance edit (decision
   4); the cardio-only hero and Splits; the tiles dropping workout time only for cardio-only; a cardio-only workout
   with several segments (the hero's plus the rest as cards); the route snapshot (projection matches the drawn
   route, a failed snapshot leaves the grid, the cache key, main-thread work).
7. **The capture fixture** (`CardioDesignFixture`, the recorder's location message under UI tests): cannot affect a
   normal launch or a real store.
8. **Design review** per REVIEW.md items 1–12 against the ticket and the captures (both appearances, Default and
   AccessibilityL).
9. **Tests and verification scope** per DEVELOPMENT: `FloodlightCardioUITests` (assertions that could pass
   vacuously), the moved `CardioUITests` / `RedesignScreenshotUITests` assertions (did a check get weaker?), the
   neighbour classes chosen.

Do NOT run xcodebuild or simctl. Do not modify files other than the report. Report findings by severity (critical
/ high / medium / low) with file:line and a concrete failure case, or say "clear" in one paragraph. Write the
report to `work-record/redesign-floodlight/codex-review-12.md`.
