# Ticket 11 — independent Codex review

**Not clear.** Reviewed `ericlee4992/redesign-floodlight-ai-routine..HEAD`, from
`0fa681458afc68a9b2bd7997f61780d56d9b8b63` through
`18ce42127c076cba5308ebe245c17f251ca0e2ec`, on
`ericlee4992/redesign-floodlight-system` in `/tmp/wt-floodlight/system`.
Claude implemented; Codex reviewed. Findings are ordered by severity.

## High

### 1. Cold commands change the store without restoring their runtime side effects

**`WorkoutTracker/Features/ActiveWorkout/WorkoutActivityCommands.swift:72–87`**

The handler is installed in app initialization, but its coordinator is supplied only by
`RootView.onAppear` (`RootView.swift:66–68`); the monitor/recorder is attached later by the
live screen. When an intent launches the app before those views exist, `+15s` skips
`broadcastRest`, and Resume falls through to `CardioSession.resume`. The card's clock starts,
but neither the recorder's sensors nor the Watch provider is started; an extended rest gets
a notification but no newly scheduled audible alarm or Watch mirror. The fallback controller
restores only the card. This violates decision 1's explicit cold-background requirement.

Give commands an initialized workout runtime independent of view appearance, and wait for
the required work before returning. The command tests inject no coordinator and therefore
exercise this incomplete path without asserting alarm, Watch, or recorder behavior.

## Medium

### 2. Grouping or breaking a superset leaves the cached next set wrong

**`WorkoutTracker/Features/ActiveWorkout/ActiveWorkoutView.swift:708–718`**

The cache includes `badgeInputs`, but that hash omits `supersetGroupID`
(`ActiveWorkoutView.swift:511–535`). Complete A1 while A and B are ungrouped, let the card
cache A2, then choose **Superset with next**. That action changes group IDs without changing
the cache's inputs (`ExerciseEntryCard.swift:228–250`). The live next-set rule now selects
B1, while the card retains A2, its old marker and PREVIOUS. Breaking the group has the
inverse problem. Include grouping in the cache inputs and test both transitions after
populating the cache.

### 3. A card command forgets that a heart-rate rest already fell back to the timer

**`WorkoutTracker/Features/ActiveWorkout/WorkoutActivityCommands.swift:98–105`**

The command's final push calls `WorkoutActivityContent.make` without
`degradedRestSetID`. That builder defaults to nil and resolves the exercise's configured
heart-rate rule, so a rest that already degraded is relabeled `.heartRate` instead of
`.fallback`. Reproduce by letting a heart-rate rest degrade without readings, minimising
the workout, and pressing +15s on its card. No live-screen tick corrects this push; at
expiry `shownResult` reports a heart-rate cap instead of “No heart rate reading” and the
fallback timer. With the screen present, the command can also overwrite the correct state
pushed by `didApply` until the next tick. Keep the actual rest mode with the workout runtime
and supply the same mode to every state producer.

### 4. Foregrounding after expiry erases the rest result before the next set

**`WorkoutTracker/Features/ActiveWorkout/ActiveWorkoutView.swift:902–912`**

`refreshRest` calls `RestTimerService.currentState`, which clears expired rest dates and
the initiating set ID. The appearance/foreground handlers (`360–364`) call this without
first retaining `shownResult`; only the slab's expiry callback (`214–217`) does that.
Background until a timer expires: the stale card correctly infers the timer result, but
returning to the app clears its source fields and pushes a ready card with no result.
Resuming a minimised workout has the same issue. Ticket 11 requires the result to remain
until the next set is completed. Capture it before every expiry-clearing path, and retain
it across live-screen dismissal.

### 5. The xLarge cap does not keep the card within its 160-point budget

**`WorkoutTrackerWidget/Shared/WorkoutActivityViews.swift:731–734`**

The footer stacks at larger sizes while the header, instrument, 20 points of inter-row
spacing and 25 points of vertical padding remain. The committed
`captures/11/Z01-resting-dark-axl.png` is 1290×2796 (@3x); its card spans approximately
y400–897, or **166 points**. The best-state card is approximately 167 points. Both exceed
the specified 160-point system budget despite the claimed cap. The gallery's unconstrained
plate (`ActivityGalleryView.swift:106–111`) expands to accommodate them, so these captures
do not demonstrate that the real card fits. Reduce the composition's height and verify it
under the actual height constraint, including wrapped headers. This is measured gallery
overflow; real-system AccessibilityL clipping was not exercised in the supplied evidence.

### 6. VoiceOver loses the next set's number or type

**`WorkoutTrackerWidget/Shared/WorkoutActivityViews.swift:329`**

`ActivityNextMarker` is accessibility-hidden whenever there is no superset letter. In the
ready card and expanded island, neither the value nor the footer repeats its identity.
For the warmup fixture, the user hears “Next” and “45 lb × 12” but cannot hear that it is a
warmup; ordinary set numbers and drop/failure markers are also omitted. Expose a descriptive
marker label, or include the set number/type in the next-set announcement. The countdown
and clock labels now include their system timer text; this finding concerns the marker.

## Low

### 7. The required design reference still mandates D54's dark-only appearance

**`.claude/skills/ios-design/REFERENCE.md:69–84`**

The reference still says the app ships Any-only assets, forces `.dark`, and must reopen
D54 before adding light variants. It also retains the old Theme contrast table immediately
before the new Look tokens. A reviewer following this required guide would reject approved
light behavior or assess contrast against obsolete colors. Replace that section with D59
and the current palette's contrast evidence.

### 8. D59 claims ticket 11 already has independent clearance

**`docs/DECISIONS.md:164`**

“Codex reviewed each to clear (tickets 02–11)” includes this still-open review. That claim
is false at the reviewed commit and could be used as release clearance. Limit it to the
tickets actually cleared and record ticket 11 as pending. The requested area decisions are
otherwise represented; the receipt decisions under the “tickets 01–03” heading belong to
ticket 04.

## Verification and scope

- Read the requested tickets/decisions, design guidance, prototype System source and captures,
  actual captures, old widget, changed code and affected callers. The checkout was clean at
  the start. Only this report was written; no `xcodebuild` or `simctl` commands were run.
- Independently read actual exit files and existing xcresult summaries: `sys-build-7` exit 0;
  `sys-ui-11` exit 65, 954 passed / 1 failed / 0 skipped (Seeding timing);
  `sys-ui-12` exit 65, 42 passed / 1 failed / 0 skipped (fresh-best timeout);
  `sys-ui-14` exit 0, 10 passed / 0 failed / 0 skipped. These support the ticket's account of
  the failures and focused follow-ups, rather than an uninterrupted green run.
- The selected live, heart-rate, cardio, finish, machine-sheet/core-loop and workout-tab
  neighbours are reasonable under DEVELOPMENT. Add focused coverage for the findings above;
  a blanket full UI rerun is not needed to establish these defects. Existing command tests
  do not verify runtime side effects. `skipOnTheCardEndsTheRest` also checks
  `presenter.lastState?.restEndsAt == nil`, which passes if no state was pushed at all.
- The real-card test measures elapsed time from its initial reading correctly. Its lower
  bound detects a missing extension in the normal run, but cannot reject an excessive
  extension. Skip's absence assertion can pass through natural expiry if the flow runs long;
  bound the remaining-time window. Gallery tests assert containers/buttons, not result text,
  next-set identity, accessibility content, or height.
- On the two-second tick, history work is cached, but the cache hash still walks the workout's
  sets. Running cardio also changes `elapsedSeconds` every tick, guaranteeing state updates
  even with unchanged sensor data. This is a cost observation, not a measured performance
  failure. Gallery gating/static rings, the three icon appearances, and Theme/Legacy removal
  produced no additional concrete findings.

**Summary: 1 high, 5 medium, 2 low. Independent clearance remains pending.**
