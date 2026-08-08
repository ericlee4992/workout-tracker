# 16 — Template drift prompt

**What to build:** Finishing a templated workout that drifted offers four options (D18). Definitions: **structure** = the ordered exercise list and per-exercise set counts; **values** = target reps. (Weights are not template data in v1, so "values" ≅ reps.) Drift = any structural **or** values difference between the finished workout's completed entries and the template (a reps-only change triggers the prompt too). Matching: entries map to template items by exercise, duplicates matched in order; entries with zero completed sets are ignored. Options and exact write sets: **Update template** = replace structure, keep existing targets where exercises survive; **Update values only** = keep structure; for each surviving matched exercise, target reps per slot = that slot's completed reps (extra completed sets beyond the template's count are ignored; missing slots keep old targets); **Update both** = replace structure and targets from the workout; **Keep original** = write nothing. A persisted settings toggle suppresses the prompt; suppressed = Keep original.

**Blocked by:** 15.

**Status:** resolved

- [x] Drift detection tests: added exercise, removed exercise, reordered exercises, changed set count, reps-only change → prompt; identical workout → no prompt
- [x] One state-transition test per option asserting the template's exact post-state
- [x] Suppression toggle: no prompt, template unchanged
- [x] Uncompleted (empty) entries don't count as drift
