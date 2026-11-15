# 02 — Add a gym from the Train screen

Status: ready (Claude implements, Codex reviews — T6); after 01
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

(none yet)
