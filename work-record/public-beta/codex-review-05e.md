# Ticket 05 — Ask AI prefill and save-switch review, round 2

Reviewed 2026-10-14 on `ericlee4992/beta-05-askai-prefill`, HEAD
`a1c1977ce24db9f757266059f2c175c64086ac65`, using `git diff 7fbea81..HEAD`, the round-2 prompt,
round-1 report and ticket response. Standards and Spec were reviewed separately. No builds, simulators,
devices or deployed requests were run. Only this report was written.

## Standards

**S1 closed; no new Standards findings.**

`WorkoutTrackerUITests/FloodlightProfileUITests.swift:168` now asserts the day picker's actual accessibility
value is `"4"` before editing. This matches `AIDayCountPicker`'s value at `AIGoalsStep.swift:321`.

The `didSet` audit found no app-initiated write that incorrectly records a user edit. Outside prefill, writes
to the six tracked fields come from text bindings, goal chips, experience/day selection, or measurement/time
controls. In particular, `AIMinutesControl` writes only from button, accessibility, tap and horizontal-drag
actions; it does not normalize the binding on appearance. Navigation, generation and discard do not rewrite
these fields. Prefill wraps its assignments in `prefilling`, suppressing edit recording.

The new tests meaningfully cover edit history, near-equal measurement replacement, late-prefill rejection,
the ordering of two queued saves, replacement-session rejection, and failure visibility. Their queue tests
hold the first request, release it explicitly, and await completion before checking outcomes. The coverage
does not include the three cases below. Targeted verification remains appropriate.

## Spec

### E1 — P2: An unchanged comparison outside the queue can skip the latest edit

`WorkoutTracker/Features/Templates/AIRoutineSheet.swift:209` compares the requested form only with the last
completed `account.profile.training`, ignoring pending writes. Start with a four-day profile, change it to
three days and generate while that profile PUT is delayed. Return to preferences, explicitly change back to
four days, and generate again before the first PUT finishes. Four equals the last completed profile, so the
second save is skipped. The pending three-day write then wins, despite the newer four-day request.

F1 is therefore only partly closed. Evaluate whether a write is unnecessary within the ordered operation,
after earlier writes settle, or against an accurately maintained queued target. Test the delayed
four → three → four case; testing only distinct A/B values that both enqueue misses it.

### E2 — P2: The profile editor still bypasses training-save ordering

`WorkoutTracker/Features/Account/ProfileSample.swift:71` calls `account.saveTraining` directly, bypassing
`AccountStore.queueTrainingSave` (`AccountStore.swift:214–222`). An older Ask AI write can remain pending after
the routine sheet closes. A newer explicit edit on the profile page can then save first, followed by the old
Ask AI write, restoring stale training data on the server and phone.

Put every training-profile write through the same ordering boundary, including the editor. Preserve the
existing explicit-save failure reporting. Add a held Ask AI write followed by an editor save and verify the
newer editor data wins. The current queue is ordered only among callers that opt into it.

### E3 — P3: An older failure can mark a successfully saved newer week as failed

`WorkoutTracker/Features/Templates/AIRoutineSheet.swift:212` sets a shared `profileSaveFailed` Boolean without
a generation/save identity check. Generate A while its profile save remains pending, change preferences and
generate B: B clears the flag at `:206`, then A fails and sets it to true. When B saves successfully, its
completion does not clear the flag. B's week consequently says “Couldn't save to your training profile.” even
though B was saved.

Associate completion feedback with the corresponding generation/save and ignore superseded results. Test an
older failed save followed by a successful newer save. F2's ordinary failure path is now visible, but its
asynchronous feedback is not yet reliable across repeated generation.

### Findings closed and other checks

- **F3 closed:** `AIRoutineFlowModel.trainingProfile` preserves an original measurement only when it was
  actually prefilled and its edit flag remains false. `TrainingProfile.fromAskAI` no longer uses a numeric
  tolerance or a late-loaded profile as a substitute baseline. The original value/unit survives unrelated
  edits; explicitly changed or cleared values follow the form. The near-integer test covers the reported case.
- **F4 closed:** edit history persists after typing then clearing and after changing a choice back. Prefill is
  allowed once, on Goals, before the first recorded edit. Tests cover both reverted-input cases and late loading.
- **F1 session binding closed:** the sheet captures the token before enqueueing; the queued operation passes it
  into `saveTraining`, and `save(session:)` checks it before sending. The existing response/401 token checks
  protect replacement sessions. The queue captures its predecessor before assigning its own task, producing
  an acyclic chain. Awaiting the predecessor suspends the main actor; no self-wait or deadlock was found.
  E1/E2 concern which writes enter that chain, not reordering within the chain itself.
- **F2 copy and ordinary path:** the new line identifies the training-profile save specifically, fits above
  Save templates, and does not imply AI generation failed. Its identifier is `routineProfileSaveFailed`, as
  tested. The sample failure flag is reset-only. The ticket flags the new string for the user's decision;
  this review judges fit and does not supply that approval.

### Evidence inspected

Read directly under `/tmp/wt-floodlight/results/05/`:

- `build3.log`: **TEST BUILD SUCCEEDED**, using `dd-05b`.
- `unit2.xcresult`: **1000 passed, 0 failed, 0 skipped**.
- `ui3.xcresult`: **3 passed, 0 failed, 0 skipped**, the focused ticket-05 UI tests.
- At **2026-10-14 05:37 EDT**, pre-fix `ui2.status` was absent and `ui2.log` ended with
  **BUILD INTERRUPTED**. The broader FloodlightProfile/FloodlightAIRoutine/FloodlightAIAccess run is
  **incomplete**, not passed; it provides no completed regression result for these fixes.

Standards: **0 findings**. Spec: **2 P2 findings and 1 P3 finding**. S1, F3, F4 and F1's session binding are
closed; save ordering and repeated-generation failure feedback still need correction.

Verdict: not clear
