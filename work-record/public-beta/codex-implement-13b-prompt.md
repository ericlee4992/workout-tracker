Ticket 13 — CHANGE OF DIRECTION from the user (2026-10-17). Stop the focus-scroll / inset experiments.

The user's words: "i dont know why this is getting complicated. Just keep the next button at bottom at all times, and
just have "done" button appear on keyboard."

New design for AIGoalsStep (replaces decision items 1, 3 and 5 of the ticket; item 2, Return ends editing, stays):

1. **Next is pinned to the bottom of the screen, always shown** (no `focus == nil` condition). It does NOT ride above
   the keyboard: while the keyboard is up it sits behind it, like any bottom content; when the keyboard closes it is
   there immediately. The ScrollView keeps its normal keyboard avoidance, so a focused field (goal, height, weight)
   stays visible above the keyboard as the system does on its own.
2. **Our own "Done" button on top of the keyboard**, shown only while one of this step's fields is focused: a compact
   trailing button directly above the keyboard (follow the Look tokens and the ios-design skill; keep identifier
   `dismissRoutineKeyboard`; tap → `focus = nil`). Drawn by the app, not by `ToolbarItemGroup(placement: .keyboard)`,
   because that toolbar did not appear on the user's iPhone (iOS 27). Remove this step's keyboard-toolbar Done so the
   simulator does not show two.
3. Keep the goal field's Return → end editing (newline stripped, `.submitLabel(.done)`) as you already built it.
4. **Revert** everything else that was added for the old design: the tap-outside handlers and `focus = nil` additions
   on chips/tiles/day picker/minutes/save switch, the ScrollViewReader/keyboard notifications/`.id` anchoring, the
   `safeAreaInset` reservation, and the TrainingProfileEditor and README changes. Smallest diff from `2dd305c` that
   delivers 1–3. If the other screens may share the missing-toolbar problem, note it in the ticket as a follow-up;
   do not change them now.
5. Tests: update the ticket-13 UI tests to the new behaviour (Next exists and is hittable once the keyboard closes; our
   Done appears with the software keyboard and dismisses it; Return dismisses with no newline; the focused height and
   weight fields are hittable and above our Done). Drop tests that only served the reverted parts. Run on WT-iPhone27
   with the **software keyboard** (ConnectHardwareKeyboard false): build, the ticket-13 tests, then AskAIUITests,
   FloodlightAIRoutineUITests, FloodlightProfileUITests. Read the `** TEST …` lines yourself.
6. Captures with the software keyboard visible: Goals with the goal focused and with weight focused, Default and
   AccessibilityL, light and dark; plus one with the keyboard closed showing Next. Look at them. Replace the old
   captures in work-record/public-beta/captures/13/.
7. Afterwards delete the Simulator `ConnectHardwareKeyboard` key (it was originally unset). Update the ticket's
   decision and Progress (say the user changed the design), fix STATE's "main =" line to the real `main` (`df6f0bc`).
   Commit and push the branch. If one honest attempt at item 1 or 2 fails, stop and write the blocker instead of
   iterating.
8. Write work-record/public-beta/codex-implement-13.md: what changed, commands, results, capture paths, final commit,
   last line exactly "Status: ready for review" or "Status: blocked — <reason>".
