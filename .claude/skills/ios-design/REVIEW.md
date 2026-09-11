# Design review checklist

For the cross-reviewer (Codex) and for self-critique. Grade a screen against these, by
inspection of the source and the captures; report by severity with file:line, or say "clear".
Each line is a question with a checkable answer.

1. **One bold element.** Name it. Is there a second element competing for the accent or the
   largest type? Is the hero where the eye starts or the thumb rests, and not both?
2. **Reading order.** Does the most important thing sit top-leading? Does anything the user
   glances at sit below the fold?
3. **Grouping.** Does every card contain a group? Is any single item boxed? Any card in a card?
   Would a list serve a set of like items better?
4. **Figures and labels.** Every glanceable number in `stat` or `hero` with a small label; no
   label larger than its number.
5. **Type.** System text styles only; no Light weights; one family; a title style used once per
   screen.
6. **Colour.** Amber on the action or the live thing only; red only for heart rate and
   destruction; no decorative colour; every text/background pair ≥ 4.5:1 (7:1 for small text);
   nothing relies on `Hairline` for a shape.
7. **Controls.** ≤ 2 prominent buttons; 44 pt hit regions; equal options equal size; primary
   never destructive; every custom button has a press state.
8. **Lists, sheets, tab bar.** Rows keep swipe and context menus; one sheet at a time with
   Cancel + Done; tabs navigate only.
9. **Dynamic Type.** At AccessibilityL: nothing truncated that the user needs, trailing
   accessories stacked, chips wrapped, icons scaled, hierarchy order kept. Name the capture.
10. **Motion.** Only in answer to the user, plus the live pulse; honours Reduce Motion.
11. **Copy.** Every visible string and accessibility identifier the tests read unchanged; no new
    string without the user's decision.
12. **Tells.** Walk the list in `SKILL.md`; each one "absent" or "deliberate because …".
13. **Verification.** The ticket names the gate tests that ran and their counts; the captures
    exist for the screen at both sizes.
