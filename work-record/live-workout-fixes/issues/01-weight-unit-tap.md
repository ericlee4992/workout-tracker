# 01 — The weight box's unit switch steals taps

Type: task
Status: implemented; targeted UI tests green; Codex review 01 not clear (2 × P3, records) → fixed; round 2 next
Blocked by: —
Implementer: Claude; Reviewer: Codex (visible Orca terminal), to "clear".
Branch: `ericlee4992/live-01-weight-unit` off `main`.
Decisions: reopens part of **D59** (the live set row's in-box unit button); keeps D9/D25 (no conversion) and D40
(a bar fixes the unit).

## Problem (the user, 2026-10-10)

"When I'm trying to enter weights during workout, it overlaps with lb/kg switch so it's difficult to enter weights
(like pressing the weight enter box triggers lb/kg switch)."

Cause: `LiveSetRow.weightInput` put the unit in the weight box as a `Button` with a 44 × 44 pt target of its own
(`frame(minWidth: 44, minHeight: 44)`). In a box roughly 80–90 pt wide that target was about half of it, right
beside the number — a tap aimed at the field often hit the toggle and switched the set's unit instead.

## Decision (the user, 2026-10-10, from three options)

**Keyboard bar.** The whole box edits the weight; the unit stays visible in the box as a plain label; while a weight is
being edited, the keyboard bar carries an `lb | kg` segmented switch beside Done. Rejected: long-press menu (hidden),
the unit as its own control under the box (taller rows).

## Change

- `LiveSetRow.swift`: the unit is a `Text` (identifier `setRow.unit` kept, now a static text); the box's tap focuses
  the field. `keyboardUnitPicker` (identifier `keyboardUnit`, segments `lb` / `kg`) appears in the keyboard toolbar
  only when this row's **weight** field is focused (only the focused row contributes a keyboard bar, as before).
  Choosing the other segment runs the unchanged `toggleUnit()` (commits on-screen text, then re-reads the number in
  the other unit — never converts). Disabled in bar mode with the old hint (D40). VoiceOver: the weight field
  carries a "Switch to kg/lb" action (absent in bar mode), so the switch does not depend on the keyboard bar.
- The box's `padding(.leading, 6)` (it offset the old 44 pt trailing target) is removed so "105 lb" centres.

**New strings:** "Unit" (the picker's accessibility label), "Switch to kg" / "Switch to lb" (VoiceOver action).
Visible copy is unchanged ("lb", "kg", "Done").

## Design (ios-design steps 1–4)

- *In the logging state the row exists so the user can type a set's weight and reps and log it in one tap; the eye
  lands on the weight figure.* The unit is now subordinate (a label); the switch appears only while editing, where the
  number is being decided.
- Wireframe (agreed with the user):
  ```
  ①  100 × 8   [ 105 lb ]  [ 8 ]  ◯          row: whole box = weight field
  ┌───────────────────────────────┐
  │ [ lb | kg ]             Done  │           keyboard bar while the weight is edited
  └───────────────────────────────┘
  ```
- Tells: all absent (no new container, chip, caps label or accent). A segmented control shows its options (Rules →
  Controls); it is not accent-filled.

## Verification scope (DEVELOPMENT → Verification scope: layout within one screen + an interaction change)

Build; `BarbellUITests` (D40 disabled switch, bar-unit changes), `CoreLoopUITests/testCoreLoopFromEmptyStoreToOneTapRepeatSet`
(tap on the unit edits, does not switch; the keyboard switch switches; the unit persists through finish and prefill),
`CoreLoopUITests/testAddSetCarriesForwardTheLastCompletedSet` (unit as entered carries forward),
`FloodlightLiveUITests` (existing live captures and regressions + new weight-keyboard captures, default and
AccessibilityL). No domain logic changed (`toggleUnit`/`WorkoutSession` untouched), so no unit tests are selected.

## Evidence

- **Targeted UI run 2026-10-10** on WT-Floodlight (`9E822EF6…`, iPhone 15 Pro Max, iOS 27.0; `WT-iPhone` is on iOS 26.5
  and no longer matches the scheme's destination — DEVELOPMENT's example name is stale): `xcodebuild test` exit 0,
  `** TEST SUCCEEDED **`, xcresult summary **Passed, 17 passed / 0 failed / 0 skipped** — `BarbellUITests` (2),
  the two `CoreLoopUITests` above, `FloodlightLiveUITests` (13, incl. the 3 new captures). Build part of the same run.
  Tested code `dfc86f4`. Result `…/scratchpad/live01/r1.xcresult`, log `r1.log`, status `r1.status` (session scratchpad,
  ephemeral; the counts above are the record).
- **Captures** ([light default](../captures/01/live-fixes-01-weight-keyboard-light-default.png),
  [dark default](../captures/01/live-fixes-01-weight-keyboard-dark-default.png),
  [light AccessibilityL](../captures/01/live-fixes-01-weight-keyboard-light-axl.png); existing `floodlight-03-live-*`
  regenerated in the same run): looked at. A tap on set 3's "lb" puts the caret in `110|lb`, the unit stays lb, and the
  keyboard bar shows `lb | kg` (lb selected) left and Done right; the box's "110 lb" is centred. At AccessibilityL the
  two-line row is unchanged and the bar fits. The Simulator hides the software keyboard (hardware keyboard), so the
  bar floats at the bottom; on a phone the number pad sits under it.

## Codex review 01 — response (round 1)

Review: [codex-review-01.md](../codex-review-01.md) — not clear, two P3 record findings; no product defect.

1. **P3 test breakdown** — 14 → 13 `FloodlightLiveUITests` (17 total was right). Fixed above.
2. **P3 captures not preserved** — the three PNGs are now in [`captures/01/`](../captures/01/) and linked; the result,
   log, status paths and tested commit are recorded.

The review also listed runtime cases the tests did not cover (not findings). Added
`FloodlightLiveUITests/testTheKeyboardUnitSwitchFollowsTheFocusedWeight`: switching kg mid-typing keeps "12" (no
conversion) and the focus (typing "0" gives "120"); focusing reps removes the switch; focusing another row's weight
shows exactly one switch, with that row's unit (lb) selected, and the switched row keeps kg. Run on WT-Floodlight:
exit 0, `** TEST SUCCEEDED **`, xcresult **Passed 1/0/0** (`…/scratchpad/live01/r2.xcresult`). Not covered by a test:
deleting the focused row (source: the toolbar belongs to the row's view and goes with it; `toggleUnit` and the
commits guard `set.isDeleted`), and VoiceOver/Switch Control discovery by a person.
