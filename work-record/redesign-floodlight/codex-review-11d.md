# Ticket 11 — independent Codex review, round 4

**Not clear: 1 medium finding.** Reviewed `d1a5e50..1ac5f5d`
(`1ac5f5d5218ea83061bd93d9a2db142e2d581825`) on
`ericlee4992/redesign-floodlight-system`, in `/tmp/wt-floodlight/system`, following
`codex-review-11d-prompt.md`. Claude implemented; Codex reviewed.

## Medium

### 1. Replacing an attached workout clears the new rest-facts owner

**`WorkoutTracker/Domain/WorkoutHeartRateCoordinator.swift:110–119`**

`monitor(for: B)` assigns `restFactsWorkoutID = B`, then ends the previously attached
workout A. That calls `releaseAlarm`, which resets the owner to nil at line 327.
Nothing restores B's owner after the teardown. If B subsequently degrades to a timer,
its next `refreshRest → noteRestFacts(B)` clears the fallback marker because the owner
is nil. The same rest can then be evaluated as a heart-rate rest again, ending on a
late low reading or losing a +15s extension when it degrades again.

Restoration before replacement has a related failure: `noteRestFacts(B)` explicitly
names B, but assigning B's inferred result invokes `lastRestResult.didSet` at line 60,
which overwrites the owner with still-attached A. Attaching B then discards the result.

Concrete recovery case: the store contains older active A and newer active B. A cold
card command attaches A before RootView exists; RootView's newest-active recovery
selects B and finishes A in the store (`RootView.swift:101–103`,
`WorkoutSession.swift:88–97`). B's live screen then replaces the still-attached A
runtime. This reaches the problematic replacement path. The ordinary explicit
end-before-start flow avoids it, and first attachment with no old runtime is fixed.

Tear down the previous runtime before establishing B's rest-facts ownership, and
do not overwrite an explicit facts owner using another workout's attached monitor.
Extend the replacement test to restore B's result while A is attached, and to set a
B fallback after replacement then call `noteRestFacts(B)`. The existing test
(`WorkoutActivityContentTests.swift:347–367`) checks only that replacement initially
clears the fields, then writes a nonnil result—which repairs the missing owner through
`didSet` and masks this failure.

## Fixes and verification checked

- The recorder now retains and chains its configuration work; `ready()` awaits both
  initial startup and the recorder's configuration. The generation/shutdown guards
  prevent obsolete queued work from starting. No additional concrete regression
  found in normal start/pause/resume/end or same-workout minimise/resume.
- The held-provider test exercises the actual recorder and configuration path with
  device sensors disabled. The recorded mutation run (`sys-ui-25`, exit 65) fails its
  “intent has not returned” assertion, supporting that it detects the missing wait.
- The deadline alarm records an absolute deadline at scheduling time. Both +15s
  assertions now check that deadline within 0.5 seconds, closing the prior loose bound.
- Rest facts restored before a first attachment survive, and explicit teardown clears
  them. The attached-workout replacement case above remains.
- Independently inspected actual exit files and existing xcresult summaries:
  `sys-ui-24` exit 0, 37/37; `sys-ui-26` exit 65, unit 906/906 and UI 36/38, with the
  documented model-picker and typed-value failures; `sys-ui-27` exit 0, both focused
  cases passing. No skipped tests in these summaries. The selected scope is reasonable;
  add a focused rest-ownership replacement regression for this finding.

No `xcodebuild` or `simctl` commands were run. The checkout was clean at the start;
only this report was written. **Independent clearance remains pending.**
