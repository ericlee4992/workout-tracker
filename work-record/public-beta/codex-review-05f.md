# Ticket 05 — Ask AI prefill and save-switch review, round 3

Reviewed 2026-10-14 on `ericlee4992/beta-05-askai-prefill`, HEAD
`90bba39496b691288f6bc7ce3962ce71b4f96790`, using `git diff a1c1977..HEAD`,
`codex-review-05e.md`, and the ticket's **Codex review 05e — response (round 2)**.
The working tree was clean before this report. Standards and Spec were reviewed separately,
including the current callers. No builds, tests, simulators, devices or deployed requests were
run by this review. Only this report was written in the repository.

## Standards

**No P1–P3 findings.**

The queue captures its predecessor before replacing its tail, awaits that predecessor without
blocking the main actor, and retains the captured-session check. No production training-write
caller bypasses the queue: `AccountStore.saveTraining` is called only from
`WorkoutTracker/Features/Account/AccountStore.swift:222`. Current-source searches verified this;
the Graft caller map did not enumerate the UI references.

The editor's callback and the Ask AI completion path were checked against their consumers,
as AGENTS.md requires. No changes violate the domain/UI boundary, entered-unit rules,
CloudKit-compatible storage conventions or runtime-dependency restriction. No actionable
code smells were found in this diff.

The four added tests exercise the relevant ordering and feedback states. The editor-ordering
test calls the queue with a removal, rather than driving the editor; the identity test calls
the model, rather than generating two weeks through the sheet. Their coverage is supported
by the caller inspection below, not treated as UI integration evidence. Targeted verification
fits DEVELOPMENT's verification-scope policy.

## Spec

**E1–E3 closed; no new P1–P3 findings in this diff.**

- **E1 closed — unchanged is checked inside the ordered operation.**
  `WorkoutTracker/Features/Account/AccountStore.swift:219` awaits the preceding save before
  comparing the current profile at `:221`; equality also requires the same session.
  `WorkoutTracker/Features/Templates/AIRoutineSheet.swift:205` no longer compares the form
  against the last completed profile before enqueueing. A held three-day write followed by
  a request to restore four days therefore sends the restoration after the earlier write.
  `aFormChangedAndChangedBackIsSavedInOrder` and
  `aSaveEqualToTheSettledProfileSendsNothing` cover reversion and the no-op case
  (`WorkoutTrackerTests/AIServerClientTests.swift:351`, `:369`). The reversion test uses
  different goal strings as its equality-changing values; it exercises the same full-profile
  comparison as the reported day-count sequence.

- **E2 closed — the real editor enters the same queue and keeps its failure reporting.**
  `WorkoutTracker/Features/Account/TrainingProfileEditor.swift:80` validates the staged form,
  trims its goals and invokes `onSave` before dismissing. That callback in
  `WorkoutTracker/Features/Account/ProfileSample.swift:70` captures the session and enqueues
  synchronously at `:73`. Both a missing session and a false task result set the existing
  `AccountDisplayCopy.saveFailed` message; the alert at `:95` still presents it.
  `anEditorSaveQueuesBehindAnAskAISave` (`WorkoutTrackerTests/AIServerClientTests.swift:379`)
  confirms a later queued write wins after a held Ask AI write, including optional removal.

- **E3 closed — completion feedback belongs to the latest request.**
  `WorkoutTracker/Features/Templates/AIRoutine/AIRoutineFlowModel.swift:48` creates a new
  identity and clears the previous failure; `:55` accepts only that identity's completion
  and sets the flag from the actual outcome. The sheet establishes the identity before
  enqueueing and passes it back after awaiting the task
  (`WorkoutTracker/Features/Templates/AIRoutineSheet.swift:212`). Its no-save path at `:208`
  invalidates earlier completions too. Both Generate and Retry reach this wrapper via
  `generate()` at `:218`. The preview still reads this state and renders the specific
  training-profile failure line at
  `WorkoutTracker/Features/Templates/AIRoutine/AIWeekPreview.swift:53`.
  `onlyTheLatestRequestsSaveIsReported` (`WorkoutTrackerTests/AIServerClientTests.swift:395`)
  covers an older failure, newer success, current failure and no-save reset.

The switch remains on by default and signed-in-only; enqueueing does not delay AI generation.
The earlier fixes for edit history, late-prefill rejection, exact preservation of untouched
measurements and session-bound writes remain intact. No regression was found in those paths
or in the changed callers. This matches ticket 05 and D52/D58/D60.

### Evidence inspected

Read directly under `/tmp/wt-floodlight/results/05/`:

- `build4.log`: **TEST BUILD SUCCEEDED**, with derived data `dd-05c`.
- `unit3.xcresult`: **1004 passed, 0 failed, 0 skipped**; `unit3.status`: **exit 0**.
  Its invocation uses `dd-05c`.
- `ui4.xcresult`: **28 passed, 0 failed, 0 skipped**; `ui4.status`: **exit 0**.
  Its invocation uses `dd-05b`: this is the round-1 build's broader regression result,
  not a completed UI result for the round-2 fixes.
- At **2026-10-14 11:43 EDT**, `ui5.status` and the completed bundle's `Info.plist` were
  absent. `ui5.log` uses `dd-05c`; it records the failure-line and prefill/save tests
  passing. **The current-build UI run is pending, not passed.**
  Its final result must be inspected before recording completed verification for delivery.
- `git diff --check a1c1977..HEAD`: exit 0.

Standards: **0 findings**. Spec: **0 findings**. This clears the scoped code re-review;
the outstanding UI result remains a verification follow-up, not an assumed pass.

Verdict: clear
