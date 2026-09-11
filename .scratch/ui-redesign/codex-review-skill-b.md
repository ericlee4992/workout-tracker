# T6 — ios-design skill, round 2

Reviewed `2636dfa..06fef42` on `ios-design-skill`. **Not clear: seven original findings closed, five partially closed; remaining issues below.** Inspection only; no `xcodebuild` or `simctl`, and no reviewed files modified.

Round-1 closure, one line per finding:

1. **Partial:** matching captures and AXL-not-maximum are explicit, but the coverage inventory still incorrectly claims a matched active-workout pair (`REFERENCE.md:122`).
2. **Partial:** semantic colours are retained in prose, but the exclusive accent-fill test still rejects selected chips (`SKILL.md:61`, `REVIEW.md:10`).
3. **Closed:** `hero` Black/Rounded is allowed, repeated `stat` figures are allowed, and at most one `hero` is required (`SKILL.md:69`, `REVIEW.md:16`).
4. **Partial:** read-only dismissal and commit verbs are fixed, but immediate-save editors still incorrectly require Cancel + commit (`SKILL.md:89`).
5. **Closed:** D54 is explicitly the recorded exception, and adding light variants requires reopening it (`REFERENCE.md:69`).
6. **Partial:** minimum/target and both sampled cells are correct—Primary/Background **17.5580 → 17.6:1**, OnAccent/accent **10.6922 → 10.7:1**—but the checklist makes the incomplete table exclusive (`REVIEW.md:20`).
7. **Closed:** the ticket supplies the composition record, placement is compared with that record, and aesthetic alternatives are labelled advisory (`REVIEW.md:3`, `:12`, `:39`).
8. **Partial:** button-like selection controls are allowed and primary styling is distinguished, but the replacement rule overgeneralizes to segmented pickers and action menus (`SKILL.md:85`, `REVIEW.md:24`).
9. **Closed:** step 5 ends on green build/named gates; step 7 requires reviewer clear after fixes and renewed captures for visual changes (`SKILL.md:47`, `:55`).
10. **Closed:** initial viewport/scrolling continuation, structured single items, and shared peer radii are explicitly supported (`SKILL.md:35`, `:65`).
11. **Closed:** Hairline includes filled-card borders, unit values and Drop are present, and Theme is the full inventory (`REFERENCE.md:97`, `:101`, `:111`).
12. **Closed:** Fitness ring states are qualified, Strong's grid remains unverified, and the shared design lesson is identified as an inference (`SKILL.md:20`).

Remaining findings, ordered by severity (paths below are under `.claude/skills/ios-design/`):

- **P2 — `REVIEW.md:10`, `SKILL.md:61`: The dominance check still contradicts the state exceptions.** The checklist declares a second accent-filled element a finding; the rule likewise rejects a second filled amber control. Yet the required `Chip` fills selected states with `Theme.accent` (`WorkoutTracker/Features/Design/Chip.swift:14`). A primary action plus a selected chip therefore fails despite the explicit selection exception. Exclude semantic state fills from the dominance count. Also compare the ticket's chosen dominant treatment: an accent-filled primary action and a separate Large Title should not automatically fail merely because one supplies the fill and the other the largest text.

- **P2 — `SKILL.md:89`: Editing does not always imply staged changes.** The rule requires Cancel and a commit verb for every editing sheet, contradicting `REVIEW.md:26`'s preservation of existing semantics. `ExercisePresetsSheet.swift:54` deletes immediately, `:57` reorders, `:68` adds, and `:96` supplies a dismiss-only Done. Adding Cancel would imply rollback that does not exist or require a behaviour change. Distinguish staged edits from immediate-save editors; preserve the latter's dismissal semantics.

- **P2 — `SKILL.md:85`, `REVIEW.md:24`: The replacement picker rule rejects native controls.** The segmented Rest picker (`ExerciseRestSettingsSheet.swift:50`) exposes its options directly and has no disclosure destination. The exercise ellipsis menu (`ExerciseEntryCard.swift:297`) offers commands, not a current selection. Require current value plus disclosure only for collapsed selection controls; allow selected segments and command menus their appropriate affordances.

- **P2 — `REVIEW.md:20`: The contrast table is not a complete allowlist.** Requiring all text/background pairs to come from that table excludes the semantic colours that the preceding sentence permits. For example, `UnitChip` uses unit-coloured text on a translucent unit-coloured fill (`Chip.swift:13`, `:22`), which is absent from the table. Permit other semantic pairs after measuring their actual composited colours against the stated minimum. The two sampled table calculations themselves are correct, using the asset RGB components and WCAG sRGB relative luminance.

- **P2 — `REFERENCE.md:122`: Active-workout coverage is still overstated.** `RedesignScreenshotUITests` has only a default active-workout capture (`:53`). The AXL capture in `CodexScreenshotUITests:65` has no selected gym, entered sets or rest state, unlike that class's default captures (`:30`); it is not a matching pair. Mark that gap explicitly. Conversely, History/detail belong in the matched category: both use `-uiTestChartHistory`, although `REFERENCE.md:123` places them under DIFFERENT before saying “same.” The corrected process can close coverage when a screen is touched; the inventory must accurately identify what remains missing.

- **P3 — `REVIEW.md:31`: Reading Reduce Motion is not verifying its effect.** This new check accepts code that reads `accessibilityReduceMotion` but never uses it, and checks only repeating animations. `SKILL.md:97` requires Reduce Motion to be honoured generally. Check that the value suppresses or substitutes the relevant motion, including custom interaction animations; allow a shared component to implement that behaviour. Otherwise this purportedly checkable item can pass a noncompliant implementation.
