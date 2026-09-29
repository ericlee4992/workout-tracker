# Ticket 11 — independent Codex review, round 2

**Not clear: 1 high, 2 medium findings.** Reviewed `18ce421..ede5583`
(`ede558308a5c81d4857139fa2fa378dd6b01c264`) on
`ericlee4992/redesign-floodlight-system`, in `/tmp/wt-floodlight/system`, following
`codex-review-11b-prompt.md`. Claude implemented; Codex reviewed.

## High

### 1. Cold runtime attachment still drops the Watch rest update

**`WorkoutTracker/Features/ActiveWorkout/WorkoutActivityCommands.swift:84–101`**

`attachRuntime` calls `coordinator.monitor` synchronously, but that method schedules
`fresh.start()` in an unawaited task (`WorkoutHeartRateCoordinator.swift:114–120`).
Before that task can run, the command calls `broadcastRest`. The new monitor's
`WorkoutActivityProvider.current` is still nil, so its `sendRest` silently drops the
message (`WorkoutActivityProvider.swift:135`). The Watch provider subsequently starts
with `restEndsAt: nil` (`WatchHeartRateProvider.swift:63–64`), and nothing replays the
new deadline.

Concrete case: +15s launches the app in the background during an existing rest, with no
live screen. The store, notification, audible alarm and card move, but the Watch never
receives the extended rest. H1 is therefore only partly resolved. `handle` also waits
only for the card, not provider startup or the recorder's asynchronous configuration;
that does not establish completion of the sensor work before the intent returns.

Await runtime readiness/configuration, or retain and replay the desired rest state once
the provider is ready. Test a delayed provider startup and the actual outgoing rest
message. The new test helper replaces attachment with an ID collector
(`WorkoutActivityContentTests.swift:184–196`), leaving the monitor and recorder
unattached; its pause/resume test still takes the direct `CardioSession` fallback.
It proves the alarm call and store changes, not cold Watch or sensor behavior.

## Medium

### 2. Unrelated set changes remove an ongoing rest's fallback status

**`WorkoutTracker/Features/ActiveWorkout/ActiveWorkoutView.swift:860–863`**

`updateRest` now clears `degradedRestSetID` on every completion/uncompletion. Some of
those changes deliberately leave the current rest running: completing a drop set or
uncompleting a set other than the one that started the rest
(`RestTimer.swift:131–141`). Thus this is not necessarily a new rest.

Concrete case: a heart-rate rest degrades to the timer, the user adds 15 seconds, then
unchecks an earlier unrelated set. The fallback marker is cleared even though its
rest remains. The next evaluation can degrade again and reset the deadline to
`start + standardDuration`, losing the extension; a late low reading can instead
finish it as recovered. This regresses the D43 safeguard and D26's preservation of
an existing timer. Clear the marker only when its rest actually ends or is replaced,
and cover both unrelated uncompletion and drop completion.

### 3. Rest results survive into the next workout

**`WorkoutTracker/Domain/WorkoutHeartRateCoordinator.swift:52–56`**

Moving `lastRestResult` and `degradedRestSetID` to the shared coordinator makes them
survive screen dismissal, but neither `end`, `endAny`, `releaseAlarm` nor attachment
to another workout clears them (`releaseAlarm`, lines 274–278, clears only the older
alarm fields and callback).

Concrete case: finish workout A after a timer or recovered result, then start workout
B in the same app process. Before B logs its first set, its ready card receives A's
result and displays that rest duration/recovery reading. A recovered result can also
light B's next-set marker. Reset the workout-specific rest state on teardown and
workout identity changes, preserving it only when minimising/resuming the same workout.
Add a two-workout regression case.

## Fixes and verification checked

- **M2:** the cache now includes superset IDs. The added test checks the uncached builder,
  so it would also pass before the cache fix; it does not exercise cache invalidation.
- **M3/M4:** commands now receive the shared fallback/result, and foreground expiry
  records its result before clearing the persisted dates. The ownership/reset cases
  above remain. Skip on an already expired rest preserves its result.
- **M5/M6:** the card uses the Large cap, tighter spacing/padding and a single-line
  header. Refreshed captures and the executed height assertions support the fix.
  Set numbers/types now have descriptive accessibility labels, including superset
  identity.
- **L7/L8:** the obsolete dark-only guidance/contrast table and premature ticket-11
  clearance claim are corrected.
- Skip's unit assertion now requires a pushed state. The real-card test checks both
  bounds of the extension and a remaining-time margin before Skip. The stable cardio
  clock origin and `activeSeconds(at:)` preserve the pause/resume arithmetic.
- `CardioControlStyle` restores the prior 52/44-point control metrics in Look colors;
  no additional concrete defect found in that fix.
- Read the actual exit files and existing xcresult summaries: `sys-build-8` exit 0;
  `sys-ui-17` exit 65, 37 passed / 1 failed / 0 skipped; `sys-ui-18` exit 65,
  1 passed / 1 failed / 0 skipped; both failed the outdoor AccessibilityL cardio case.
  After the control fix, `sys-ui-19` exit 0, 9 passed / 0 failed / 0 skipped.
  `sys-ui-15.log` records 902 unit tests passing, but its interrupted result bundle
  lacks `Info.plist`; it is not evidence of a completed successful combined run.
- The neighbour coverage is reasonable under DEVELOPMENT. The remaining findings
  need focused runtime and lifecycle tests, especially provider startup, outgoing
  Watch messages, an attached recorder, and rest ownership transitions.

No `xcodebuild` or `simctl` commands were run. The checkout was clean at the start;
only this report was written. **Independent clearance remains pending.**
