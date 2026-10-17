# Ticket 13 — Goals keyboard captures (user's design: fixed Next, app-drawn Done)

Full-screen captures (`XCUIScreen.main.screenshot()`, so the keyboard window is included) from
`FloodlightAIRoutineUITests/testCaptureGoalsKeyboard*` on WT-iPhone27 (iOS 27.0, software keyboard), 2026-10-17,
code `915b84e` plus Claude's test fixes; halved in size. Taken by Claude after Codex's report.

**Caution:** the iOS 27 simulator's full-screen capture is not reliable for the keyboard: some frames show no keyboard
while the field is focused (e.g. `goals-keyboard-light-default`, `goals-keyboard-light-axl`), and at AccessibilityL the
weight field renders behind the number pad (`weight-keyboard-dark-axl`) while accessibility geometry puts it above
Done. The original build-5 screen behaves the same way in the same probe. The user's phone decides (ticket 13).

- `beta-13-goals-keyboard-{light,dark}-{default,axl}.png` — goal focused, Done above the keyboard
- `beta-13-weight-keyboard-{light,dark}-{default,axl}.png` — weight focused (number pad)
- `beta-13-goals-keyboard-closed.png` — after Done: Next at the bottom
