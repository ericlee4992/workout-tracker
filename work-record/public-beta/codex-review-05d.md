# Ticket 05 — Ask AI prefill and save-switch review

Reviewed 2026-10-14 on `ericlee4992/beta-05-askai-prefill`, HEAD
`7fbea81a2211842afb024598171721c77fe749e2`, using
`git diff 507c1dd..HEAD -- WorkoutTracker WorkoutTrackerTests WorkoutTrackerUITests docs/DECISIONS.md`.
Ticket 10's documentation is excluded. Read ticket 05's Design, Units and wiring sections, the profile spec,
D52/D58/D60, the server's training-profile implementation/README, affected callers and recorded artifacts.
Standards and Spec were reviewed separately. No builds, simulators, devices or deployed requests were run.
Only this report was written.

## Standards

### S1 — P3: Assert the prefilled day selection rather than existence of its option

`WorkoutTrackerUITests/FloodlightProfileUITests.swift:168` uses `isSelected || exists`. All seven day options
exist, so this passes even when day 4 was never prefilled. The test subsequently taps day 3, which is also the
model's default; its save assertion can pass with broken day prefill. Assert that day 4 is selected or that the
displayed figure says four days before editing.

The domain tests meaningfully verify unchanged stored measurements, integer edits in both app unit systems,
clearing weight and creating a profile. They set canonical model values directly, however, and do not exercise
actual field edits, late-profile provenance, or the cases below. The two UI tests genuinely exercise save-on and
save-off through the sample account's in-memory save path; they do not verify network failure or concurrent saves.
Targeted verification is appropriate under DEVELOPMENT; these gaps need focused coverage, not a full UI suite.

## Spec

### F1 — P2: Bind and order the profile writes started by generation

`WorkoutTracker/Features/Templates/AIRoutineSheet.swift:213` starts an untracked save task for every generation.
Generate with form A, cancel/close, then generate with edited form B while A's PUT is delayed: B can save first,
then A overwrites the newer training profile. `AccountStore.swift:204–212` accepts both same-session responses;
its token check does not order requests. Even when server writes happen in order, reversed responses can restore
the older profile in memory.

The initiating session is also not captured at the enqueue boundary: the signed-in check occurs at `:210`, but
`AccountStore.save` selects its token only when the task executes. A replacement before execution can send the
old draft under the replacement session. Once a save has started, the existing store correctly rejects late
responses/401s belonging to a different token; that does not cover this earlier window.

Bind each queued save to its initiating session and enforce write ordering across routine-sheet lifetimes.
Ignoring stale responses alone does not prevent an older request overwriting the server. Add controlled tests
for overlapping writes and session replacement before a queued save begins. D58's enabled switch should leave
the profile reflecting the latest requested form.

### F2 — P2: Profile-save failure is silently discarded

`WorkoutTracker/Features/Templates/AIRoutineSheet.swift:213` discards `saveTraining`'s Boolean result. If the
profile PUT fails but AI generation succeeds, the tester sees a generated week with their save switch enabled,
although the edits were not saved. Reopening Ask AI restores the old inputs without any explanation.

The ticket permits generation to continue after a failed save; continuing need not hide the failure. Surface
the profile-save failure without blocking the week, using an appropriate approved error message. The normal
profile editor already handles a false result (`ProfileSample.swift:69`). Cover a failing profile PUT alongside
a successful AI response; the synchronous sample-store tests cannot exercise this case.

### F3 — P2: Measurement equality is being used as a substitute for edit provenance

`WorkoutTracker/Domain/TrainingProfile.swift:31` treats differences smaller than `0.001` as unchanged and returns
the original stored pair. For example, a server-valid stored **80.0005 kg** measurement explicitly replaced with
**80** is saved as **80.0005 kg**, contrary to D58's requirement that a changed measurement be saved as typed.
The server accepts finite fractional values without this precision restriction.

There is a second provenance problem at `AIRoutineSheet.swift:211`: `prefilledFrom ?? account.profile?.training`
uses a late-loaded profile as the preservation baseline even when prefill was skipped because the tester had
already typed. A typed 80 kg can then preserve a late profile's approximately equivalent pound value/unit that
never prefilled this form. Preserve original pairs only for measurements actually prefilled and left untouched;
track field edits rather than infer them from approximate numeric equality. Test explicit replacement of a
near-integer stored fraction and a profile arriving after measurement entry.

### F4 — P2: Late prefill can overwrite a form the tester already edited

`WorkoutTracker/Features/Templates/AIRoutineSheet.swift:198–204` equates “untouched” with “currently equal to
defaults.” If the profile is still loading and the tester types then clears the goal, or changes a choice and
returns it to its default, the later profile response passes this guard and replaces their deliberate edits.
This contradicts the promised “never over anything typed.” Record whether the tester has edited the form and
allow late prefill only before that first edit. Add a delayed-profile case where the tester edits and clears
before the response arrives.

### Confirmed behavior

- Initial prefill reads `account.profile.training`; later training-profile changes retry prefill only on the
  Goals step and while no prefill baseline has been recorded. Nondefault current input is protected. Signed-out
  account state has no profile to prefill, and the save switch is hidden.
- The switch defaults on and remains sheet state across steps. The exact approved strings are used:
  “Save to my training profile” and “Filled in from your training profile.” The latter appears only after
  prefill. `routineSaveToProfile` matches the UI tests.
- Generation invokes the save path; switch-off, signed-out, unchanged and invalid profiles skip saving.
  `TrainingProfile.isValid` matches the server's relevant goal/experience/day/minute and converted-measurement
  bounds. Goals are trimmed. `AccountClient.update` encodes the profile under `training`; omitted optional
  measurements are accepted by `cleanTraining` as cleared values.
- Outside F3's cases, untouched measurements retain their original value/unit exactly, changed integer values
  are saved in the app's units, and nil removes a measurement. Existing request-side cm/kg conversion remains.
- The sample now uses the same account-driven prefill path. Its flags remain reset-only, and its save path is
  in-memory. The old `-uiTestProfilePrefill` path was removed. No schema or server behavior changed.

### Evidence inspected

Artifacts under `/tmp/wt-floodlight/results/05/` were read directly:

- `build1.log` and `build2.log`: **TEST BUILD SUCCEEDED**.
- `unit1.xcresult`: **995 passed, 0 failed, 0 skipped**.
- `ui1.xcresult`: **2 passed, 0 failed, 0 skipped**, the new prefill/save-switch UI tests.
- `ui2.log` names FloodlightProfile, FloodlightAIRoutine and FloodlightAIAccess, using `dd-05` and three
  workers. At **2026-10-14 05:17 EDT**, `ui2.status` was absent and no completed summary was available.
  The regression run remains **pending**, not passed.

Standards: **1 P3 finding**. Spec: **4 P2 findings**. No installation or live-server verification is claimed.

Verdict: not clear
