# 16 — Template drift prompt

**What to build:** Finishing a templated workout that drifted offers four options (D18). Definitions: **structure** = the ordered exercise list and per-exercise set counts; **values** = target reps. (Weights are not template data in v1, so "values" ≅ reps.) Drift = any structural **or** values difference between the finished workout's completed entries and the template (a reps-only change triggers the prompt too). Matching: entries map to template items by exercise, duplicates matched in order; entries with zero completed sets are ignored. Options and exact write sets: **Update template** = replace structure, keep existing targets where exercises survive; **Update values only** = keep structure; for each surviving matched exercise, target reps per slot = that slot's completed reps (extra completed sets beyond the template's count are ignored; missing slots keep old targets); **Update both** = replace structure and targets from the workout; **Keep original** = write nothing. A persisted settings toggle suppresses the prompt; suppressed = Keep original.

**Blocked by:** 15.

**Status:** resolved

- [x] Drift detection tests: added exercise, removed exercise, reordered exercises, changed set count, reps-only change → prompt; identical workout → no prompt
- [x] One state-transition test per option asserting the template's exact post-state
- [x] Suppression toggle: no prompt, template unchanged
- [x] Uncompleted (empty) entries don't count as drift

**Review fix (2026-08-08).** "Update values only" wrote reps onto the wrong exercise.
`TemplateDriftService.apply` zipped `orderedItems(of: template)` with the resolved values, but
those values are positionally aligned to `templateSnapshot`, which `compactMap`s away items
whose `exercise` is nil (nullify delete rule). A single orphaned item shifted every later
item's targets by one. Snapshot construction and write targets now come from one filtered
source — `snapshotRows(_:)` returns each surviving `TemplateItem` together with its
`TemplateDriftItem`, and `templateSnapshot` is just its `.snapshot` projection — with an
exercise-id equality guard before each write, so identity matching (duplicates in order, per
this ticket) can no longer diverge from the comparison. Orphaned items keep their own values.

Test: `updateValuesOnlySkipsOrphanedItemsInsteadOfShiftingTargets` — three-item template whose
MIDDLE item's exercise is deleted, workout completes the first and third; asserts each item
keeps its own reps.

**Judgement call — the drift prompt on "Finish It & Start New" is correct behavior, not scope
creep.** This ticket scopes the prompt to "finishing a templated workout"; `StartWorkoutView`'s
"Finish It & Start New" *does* finish a templated workout, just from a different button. The
alternative — suppressing the prompt there — would mean the D18 decision silently loses the
user's drift whenever they finish from the Start screen instead of the workout screen, which is
the behavior D18 exists to prevent. Kept deliberately; the wording of the ticket describes the
event, not the button.
