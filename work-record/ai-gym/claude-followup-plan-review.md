# Claude plan review — ticket 07 (template visibility and scanning)

Reviewer: Claude (independent, AGENTS T6). Date: 2026-09-22. Stage: **plan only**; the
implementation is not ready and nothing was run. Final code/evidence review follows later.

Reviewed against: [ticket 07](issues/07-template-visibility-and-scanning.md) as it stands in the
implementation checkout (`ericlee4992/ai-template-followup`, uncommitted, base `5a894da`),
D56–D58, SPEC line 64, the AI spec (`spec.md` lines 16–34, 45–46), ios-design `SKILL.md`,
`REFERENCE.md` (Sheets, Captures) and `REVIEW.md`, and DEVELOPMENT — Verification scope.
Review checkout: `ericlee4992/ai-template-followup-review` at `5a894da`, clean. Also read:
`AIRoutineSheet.swift`, `AIRoutine.swift` (save), `StartWorkoutView.swift`,
`IdentifyEquipmentSheet.swift`, `GymsView.swift` (`MachineEditorSheet`),
`EquipmentLifecycle.swift` (`activeMachines`), `AskAIUITests.swift` including the new
uncommitted regression test.

User-approved scope taken as given: additive **Scan Machine** in the routine equipment section,
one camera flow for label or whole machine with editable confirmation, and the **Ask AI for
Templates** rename.

## Verdict

Not yet clear to implement as written. Four items need to be settled in the ticket first (P1),
because different answers lead to materially different code and tests. The remaining items are
acceptance gaps the final review will check; they do not need a user decision.

## P1 — settle before implementation

### 1. The "exact" baseline regression is not exact, and existing evidence predicts it passes

The existing `routine(large:edit:)` helper already saves a fixture week and waits for the Day 1
tile without a restart (`WorkoutTrackerUITests/AskAIUITests.swift:104-106`); those cases are part
of the passing UI evidence in ticket 05. The new
`testAllThreeGeneratedTemplatesAppearWithoutRestart` adds days 2–3 and a duplicate count, but
otherwise runs the same path. It differs from the phone report in every way that plausibly
matters:

- no selected gym (`gym == nil`, so `generatedForGymID` is nil and options come from extras only);
- no pre-existing templates (`-uiTestTemplate` is not passed), so the grid grows from zero
  instead of from an already-laid-out row;
- fixture Terra answers in 200 ms with no real photo, network or key.

If the run at PID 43060 is green, the ticket must record "baseline does not reproduce" rather
than treating it as the regression, and the plan needs a second variant before any product edit:
`-uiTestTemplate` (existing "Whole Body" tile), a gym created and selected in the Workout gym
picker, three days, default and AccessibilityL. Add one diagnostic that separates the two
candidate causes, because the fix is different for each:

- **@Query did not refresh.** The week is saved in an isolated `ModelContext`
  (`WorkoutTracker/Domain/AIRoutine.swift:147-173`, D58 atomic save), while the grid reads a
  main-context `@Query` (`StartWorkoutView.swift:8`). Compare, after Save, the `@Query` count
  against a fresh `FetchDescriptor<WorkoutTemplate>` count on the main context.
- **Refreshed but not rendered.** The tiles are a `LazyVGrid` inside one `List` row
  (`StartWorkoutView.swift:58-96`). A row whose content grows after first layout can keep its
  cached height; the name sort puts "Day n" tiles first, which matches "top two absent". This
  grid-in-row structure already produced one attribution bug (codex-review-15 note at
  `StartWorkoutView.swift:74-79`). Compare the rendered tile count against the `@Query` count.

Whichever it is, the fix must keep D58: one atomic save with rollback and the duplicate-submit
guard (`AIRoutineSheet.save()`, `saved` flag). Moving the save onto the main context or adding a
manual refresh both need a line in the ticket and, if D58's wording changes, a DECISIONS entry.

### 2. Which screen owns the confirmation and the Add

The ticket says "retain editable confirmation" and "Add commits a machine to the gym", but the
code has no entry point that does that from outside `MachineEditorSheet`:

- `IdentifyEquipmentSheet` saves nothing; it hands an `EquipmentIdentification` to `onIdentify`.
- `MachineEditorSheet` receives it only through its own private scanner state
  (`GymsView.swift:617-628`) and does the resolution and save at `GymsView.swift:704-741`,
  including catalog match, user-space model creation, generic/ambiguous fallback and
  edited-name preservation (D56, D3).

The plan must pick one of these and say so:

- (a) Scan Machine presents `MachineEditorSheet(gym:)` and the user taps its own
  "Scan equipment…" — two taps, the button is not called Scan Machine, and the catalog/offline
  rows are exposed; this does not meet "a single camera flow".
- (b) Add an initial-identification parameter to `MachineEditorSheet` so Scan Machine can
  present `IdentifyEquipmentSheet` and then the editor prefilled; the existing `save()` is reused
  unchanged.
- (c) Re-implement the resolution and save inside the routine sheet — **do not**; it forks
  the identity logic that keeps physical-machine history from splitting.

Recommendation: (b). Whatever is chosen, the acceptance for repeat scans (item 6) and for
"no unconfirmed machine on cancel" must be written against that screen.

### 3. Gym selection inside the sheet

`AIRoutineSheet` takes `var gym: Gym?` fixed by the caller (`StartWorkoutView.swift:136`).
"Without a selected gym, provide a reachable gym selection/add path" means the gym becomes sheet
state, and three consequences need decisions in the ticket:

- Does an in-sheet pick change the Workout tab's remembered gym? D1 says every pick is
  remembered, and `restoreSelectedGym` reads the stored pick once per screen lifetime
  (`StartWorkoutView.swift:226-233`), so the tab will not follow unless the sheet reports back.
  Either answer is defensible; it must be stated and tested.
- `generatedForGymID` (save) and `RoutineAvailability.exercises(... machines: gym.activeMachines)`
  (options) must both follow the in-sheet gym; archived gyms stay excluded.
- The add-gym editor is `private struct GymEditorSheet` (`GymsView.swift:396`). Sending the
  user to the Gyms tab tears down the full-screen cover and loses the preferences, which the
  ticket forbids. Say whether the editor is made reusable or the no-gym path only selects among
  existing gyms with a message.

### 4. Copy changes are wider than the ticket lists

The user approved three strings. The ticket should list every visible string that changes and
where, because the copy policy and REVIEW item 11 require it:

- "Ask AI" button on Workout → "Ask AI for Templates" (`StartWorkoutView.swift:97`);
  identifier `askAIRoutine` stays.
- The routine sheet's title is "Ask AI" (`AIRoutineSheet.swift:49`). Say whether it changes to
  match; at inline width "Ask AI for Templates" may truncate at AccessibilityL.
- "Scan a machine or its label" replaces "Frame one machine or its label" in
  `IdentifyEquipmentSheet` (capture view). That screen is shared with the Gyms flow, so the
  change is global; record it as such or keep the existing string.
- The Settings label "Ask AI" (`AskAISettingsSheet.swift:21,58`) names the key/consent screen,
  not the template flow; leave it.

## P2 — acceptance gaps to close in the ticket (no user decision needed)

5. **Equipment refresh after Add.** `MachineEditorSheet` saves on the environment context, and
   `Gym.activeMachines` is computed over the relationship (`EquipmentLifecycle.swift:25-30`), so
   the "N saved machines" line and `options` should update if the sheet's `Gym` is the
   main-context instance. If the implementer copies D58's isolated-context pattern for the
   machine save, the count will not refresh — the same class of bug as item 1. Acceptance test:
   with no extras and no cardio, Generate is disabled (`AIRoutineSheet.swift:100`); after Scan
   Machine → Use → Add, without leaving the sheet, the count reads 1 and Generate is enabled.
   That is a cleaner check than inspecting the generated week.

6. **Repeat scans.** The fixture always answers "Chest press", so the second scan produces a
   same-label machine. Assert two machines at the gym and the count text "2 saved machines";
   labels are not unique, so a count of tiles or rows is the only honest check.

7. **Cancel and error paths.** Assert after each of: photo-consent declined, no key
   (`scannerAISettings` reachable from inside the nested presentation), `-uiTestTerraOffline`
   error, Cancel on the proposal, Cancel on the editor: goals text, steppers, extras and cardio
   toggles are unchanged and the machine count is unchanged. `AIRoutineSheet` runs `cancel()`
   in `onDisappear` (`AIRoutineSheet.swift:61`); a `.fullScreenCover` on top fires that on the
   covered view, a `.sheet` does not. Use `.sheet` and note it. Presentation depth will be
   cover → editor sheet → identify sheet → settings sheet; each Cancel must dismiss only its own
   level, and the routine sheet must still be on screen with its state.

8. **Machine saved only at the selected gym.** No machine may be created when the gym is nil;
   the Scan Machine row should be hidden or disabled in that state with the selection path
   offered instead. Test the nil-gym state explicitly.

9. **Photo consent is separate from routine consent.** Scanning from routine setup goes through
   `TerraAccess.photoConsentKey` inside `IdentifyEquipmentSheet`, not the routine toggle. The
   first-scan capture from this entry should show that consent screen so the record proves it
   is reachable here (AGENTS: gated settings must be reached, not just tested at the gate).

10. **Design record per SKILL steps 1, 4 and 6.** The ticket's design section has the wireframe
    and a tells list, but not one job/state sentence per state that changes composition
    (preferences with gym, preferences without gym, capture, confirmation) and not one line per
    tell. Skipping the mock is justified as a one-row addition; write that down. Name the
    capture pairs: Workout tab with the renamed row; Equipment section with the count and Scan
    Machine row; the no-gym state; proposal and editor from this entry. Same fixture and state
    at default and AccessibilityL (REFERENCE — Captures: touching a screen completes its pair).
    Scan Machine must stay a plain Form row so Generate remains the only prominent command
    (REVIEW item 7).

11. **Verification scope is a category list, not a named list.** DEVELOPMENT's row for shared
    navigation/persistence applies (a shared editor entry and a persistence-presentation fix).
    Name the tests before running: all of `AskAIUITests`; the gym/machine editor and scanner
    UI cases that use `addMachine`/`saveMachine`; the Start/template tile tests from tickets
    10/11/15 if `StartWorkoutView` changes; `RedesignScreenshotUITests` Start pair; domain
    `AIGymTests` plus the atomic-save and preservation suites if the save path changes; a clean
    `xcodebuild build`. Record actual exit codes and the xcresult summary line, not a summary
    from another agent. If the fix ends up in the shared `List`/grid, state why a full UI run
    is or is not warranted.

12. **No schema change** is claimed; confirm no new stored property is introduced (in-sheet gym
    selection and scan state must be transient). Export schema stays 11.

## What the final review will check

Root cause recorded with the diagnostic from item 1; the chosen path from item 2 with
`MachineEditorSheet.save()` reused; gym-selection decision from item 3 implemented and tested;
the string list from item 4 matched against the UI tests' queries; items 5–9 as named tests
with actual results; captures opened and looked at; D56–D58 unchanged or explicitly reopened.
No merge or push is authorized by this review.
