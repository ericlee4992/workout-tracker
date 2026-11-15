# 02 — Add a gym from the Train screen

Status: implemented, in review (Claude implements, Codex reviews — T6); branch `ericlee4992/add-gym-from-train`
Type: task

## The user's request (2026-11-14)

> For adding new gym, they also said it would be more convenient if we can just easily add gym from the train screen
> (instead of having to navigate to gyms tab). Maybe with just like a button.

## Today

- Train → Templates (`WorkoutTracker/Features/Start/StartWorkoutView.swift`) shows the gym picker
  (`gymPicker`, `:392-422`): a system `Menu` listing "No gym" and each gym (name · city), with a checkmark on the
  current one. The pick is remembered (D1, `select(_:)` → `GymSelection.remember`, `:384-388`).
- A gym is added only from Train's **Gyms** switch (`GymsView` → `GymEditorSheet()`) or inside Ask AI for Templates
  (`AIRoutineSheet.swift:129-131`: `GymEditorSheet(onSave: { created in select(created) })`).

## Change

Add a way to create a gym right from Train → Templates, using the existing `GymEditorSheet` (add mode). On save the
new gym becomes the selected, remembered gym (as Ask AI for Templates does); Cancel creates nothing and keeps the
current selection.

UI-first — show the user real default and AccessibilityL captures of the options before wiring, and let them pick:
- **A.** A "New Gym…" item at the bottom of the gym menu (with a plus icon, after a divider).
- **B.** A small "+" / "Add Gym" button beside the gym picker.
- **C.** A and, when there are no gyms yet, a visible "Add your gym" button in place of the empty "No gym" picker.
Match the app's current screens (AGENTS.md design rule), not the ios-design skill.

## Acceptance

- From Train → Templates, a gym can be added without visiting Gyms; after Save it is selected and remembered (it is
  still selected after relaunch); after Cancel nothing changes.
- VoiceOver names the control; AccessibilityL stacks without truncation; Reduce Motion respected.
- The guided tour (`tour.gymPicker` anchor) and its sample data are unaffected; an archived gym still never appears.
- A UI test covers create-from-Train (Save selects it; Cancel keeps the old pick); existing gym picker tests pass.
- README mentions it if the Train/gym description there changes.

## Progress

### The user's choice (2026-11-14)

Real Default/AccessibilityL captures of A, B and C (a temporary `-protoGymAdd` launch switch, removed;
`build/captures/tf02/tf02-options-sheet.png`) → the user asked how C looks with gyms (identical to A: the menu item) →
**C**. Recorded as D89.

### What changed (`5510b9fe`)

- `StartWorkoutView`: `gymRow` — no gyms: `TrainMakeRow` "Add Your Gym…" (id `trainAddGym`) in place of the "No gym"
  picker; with gyms: the picker, whose menu ends with a divider and "Add Gym…" (plus icon, id `trainAddGym`), copying
  Ask AI's gym menu. Both open `GymEditorSheet()`; `onSave` → `select(created)` (selected + `GymSelection.remember`,
  D1). Cancel never calls `onSave`, so nothing is created and the pick stays. The `tour.gymPicker` anchor stays on the
  row; the tour's sample world has a gym, so its step shows the picker as before. Archived gyms stay out (the `gyms`
  query filters them).
- Tests: `TrainAddGymUITests` (new, TodayTrain plan): menu Add Gym… → Save selects it and Gyms marks it "Current"
  (remembered in the store, D1); Cancel keeps Iron Temple and creates nothing; the first gym from "Add Your Gym…" at
  Default and AccessibilityL (frame and height checks); captures light/dark × Default/AccessibilityL.
  `FloodlightTourUITests.assertBackOnTheUsersEmptyStore` now checks the empty store's "Add Your Gym…" row (its "No gym"
  picker no longer exists there).
- Docs: D89; README's gyms bullet (and its stale "read its name plate on the phone" from before ticket 01).
- "Still selected after relaunch": the selection is `AppPreferences.selectedGymID`, read at launch by
  `restoreSelectedGym`; a UI test cannot relaunch onto the same store (`-uiTestReset` wipes it, by design), so the tests
  check the stored value through Gyms' "Current" badge, which reads it. `GymSelection` is unit-tested (`GymSelectionTests`).

### Verification (author)

- `build-for-testing` exit 0. `TrainAddGymUITests` **8/8** (`build/results/tf02-new.xcresult`; captures
  `build/captures/tf02-final/`).
- Unit plan + `FloodlightTourUITests`, `FloodlightWorkoutTabUITests`, `GymsFlowsUITests`, `TemplateMachinesUITests`,
  `AskAIUITests/testRoutineGymPickerRemembersExistingGymAndNoGym` (2 workers; `build/tf02-ui.sh`, logs
  `build/logs/tf02-{unit,ui}.log`, results `build/results/tf02-{unit,ui}.xcresult`): Unit **1291/1291**; UI **22/27**
  — four `FloodlightTourUITests` failed because `startTourFromSettings` read the gym picker's frame on the user's empty
  store, where the row is now "Add Your Gym…" (fixed: it reads that row's slot; the tour's sample, with a gym, still
  shows the picker there), and `AskAIUITests/testRoutineGymPickerRemembersExistingGymAndNoGym` failed in `typeGoals`
  (the goal text not fully entered within 5 s under parallel load — unrelated to the gym row).
- Serial rerun after the fix (`build/results/tf02-rerun.xcresult`): `FloodlightTourUITests` **10/10** +
  `testRoutineGymPickerRemembersExistingGymAndNoGym` **1/1**, exit 0.

**Verified:** build; Unit 1291/1291; TrainAddGymUITests 8/8; FloodlightWorkoutTabUITests, GymsFlowsUITests,
TemplateMachinesUITests (in the 22 passed); the tour class and the Ask AI gym test serially. **Not verified:** on a
phone. **Known flaky:** `AskAIUITests` goal typing under parallel load (passed serially).

### Review round 1 (Codex, `codex-review-02.md`): changes requested → fixed

Both findings were in older code the new entry point now uses (`GymEditorSheet`'s add path, `select` → `remember`).
- **1 (P2)** a failed Add left the inserted gym pending in the screen's context (Cancel could later save it; a retry
  made a second). **2 (P2)** the screen showed the new gym selected even if remembering it failed (a second save,
  its error swallowed in Release).
- Fix: `Domain/GymCreation.create` writes the gym and, with `selecting`, the remembered selection in **one save on an
  isolated context**, rolling it back and rethrowing on failure (the `AIRoutinePersistence` pattern, so the user's other
  unsaved edits are untouched). `GymEditorSheet` add mode uses it (`selectsCreated`); Train passes `selectsCreated: true`
  and only sets its local `selectedGym` after the save succeeded; Ask AI's Add Gym… also passes `selectsCreated: true`.
  Gyms' Add Gym… is unchanged in behaviour (no selection).
- `GymCreationTests` (new): one save for gym + selection; not selecting keeps the pick; **failed save → nothing pending,
  the next screen save makes no gym, the stored pick unchanged, a retry makes exactly one**; a failed save spares the
  screen's unsaved edits. D89 notes the one-save rule.
- Round 2 verification (author): build-for-testing exit 0; `GymCreationTests` + `GymSelectionTests` 7/7; Unit plan
  **1295/1295** (`build/results/tf02-r2-unitplan.xcresult`); `TrainAddGymUITests` 8/8 + `TemplateMachinesUITests` 2/2 +
  `AskAIUITests/testRoutineGymPickerRemembersExistingGymAndNoGym` 1/1, serial, exit 0 (`build/results/tf02-r2-ui.xcresult`).
  Not verified: Ask AI's Add Gym… in a UI test (none exists; the same sheet path is covered by Train's tests).

### Review round 2 (Codex): changes requested → fixed

- **R2-1 (P2)** after a successful save, a failed fetch of the new gym (`try?`) skipped `onSave` and still closed the
  sheet, so Train kept showing the old gym while the new one was stored as the pick. Fix: `GymAddAttempt` creates at
  most once and then hands the gym back through `GymCreation.resolve`, which **throws** (`Missing`) rather than
  answering nil. A failed hand-back keeps the sheet open: "<name> was saved but could not be opened here (…). Tap Add
  to try again." The fields lock once saved, and Add resolves the SAME gym. Cancel after such a save tries the
  hand-back once; if that fails too, the gym and its remembered selection are saved and show from the next launch.
  That is the one accepted residual, after an explicit Cancel.
- Tests: `GymCreationTests.aFailedHandBackRetriesTheSameGym` (save ok, hand-back fails, retry: one create, one gym,
  stored pick = the gym shown), `resolvingAGymThatIsNotThereThrows`.
- Round 3 verification (author): build-for-testing exit 0; Unit plan **1297/1297** (`build/results/tf02-r3-unit.xcresult`);
  `TrainAddGymUITests` 8/8 + `TemplateMachinesUITests` 2/2, serial, exit 0 (`build/results/tf02-r3-ui.xcresult`).
