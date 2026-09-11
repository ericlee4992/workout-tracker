# Design review checklist

For the cross-reviewer (Codex) and for self-critique. The author supplies, in the ticket: the
screen's job and state sentences, the wireframe with relative sizes, the tells answered, the
gate tests with counts, and the captures at the default size and AccessibilityL. Grade the
render against THAT record and the rules in `SKILL.md`; report by severity with file:line, or
say "clear". Items 1–12 have a checkable answer; anything else is advisory and is labelled as a
judgement.

1. **Bold element.** The one the ticket names is the only call to action or figure with an
   accent fill or the largest content type in the capture. Not counted: the navigation title,
   and amber as a state (selected tab, selected chip, completed set). A second one is a finding.
2. **Placement.** The bold element sits where the ticket said (eye or thumb), and the first
   viewport holds every block the wireframe put there, in that order.
3. **Grouping.** Every card in the capture contains a group or a structured item; no card
   around a single line; no card in a card; sets of more than three like items are lists.
4. **Figures.** Every figure the ticket calls glanceable is `stat` or `hero`; at most one
   `hero`; every label is smaller than its figure.
5. **Type.** System text styles only (grep for `.system(size:`); no Light weights; one family.
6. **Colour.** Amber only on the bold element and on states (selection, completion); red,
   yellow, `Drop`, unit and muscle colours only for their meanings. Every text/background pair
   meets 4.5:1: the pairs in `REFERENCE.md`'s table by lookup, any other pair (a unit chip, a
   muscle tile) by measuring its composited colours; `TextTertiary` carries no essential text on
   `SurfaceElevated` or `SurfaceFill`.
7. **Controls.** ≤ 2 prominent buttons; 44 pt minimum hit regions; equal options equal size;
   no destructive primary; custom buttons have a press state; a collapsed selection control
   shows value + disclosure and is not in the primary style (segmented pickers and command
   menus keep their native look).
8. **Lists, sheets, tab bar.** Rows keep swipe and context menus; each sheet keeps its existing
   dismiss/commit buttons; tabs only navigate.
9. **Dynamic Type.** The AccessibilityL capture uses the same fixture and state as the default
   one; nothing the wireframe names is truncated; trailing accessories stacked; chips wrapped;
   icons scaled; hierarchy order unchanged.
10. **Motion.** Only in answer to the user plus the live pulse; under Reduce Motion every
    animation on the screen is suppressed or replaced (follow `accessibilityReduceMotion` to
    the modifier it gates — a read with no effect is a finding).
11. **Copy.** Every visible string and accessibility identifier the tests read is unchanged
    (diff the UI tests' queries against the tree); no new string without the user's decision
    recorded.
12. **Record.** The ticket has the job/state sentences, the wireframe, each tell answered with
    a functional reason or accepted composition, the gate tests with counts, and both captures.

Advisory (label as judgement): whether the composition is the best of the alternatives, whether
spacing feels right, whether the accent could mark something better.
