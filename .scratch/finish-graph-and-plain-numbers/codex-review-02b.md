# Codex review 02b

## Standards

- **Medium — `docs/STATE.md:44-46` still contradicts the new head and the repository's current state.** The head correctly says that `finish-graph-and-plain-numbers` is active, pushed, unmerged, and uninstalled, and that the milestone 7/8/9 branches were deleted locally and remotely. The older numbered section still calls `milestone-9-history-and-summary` a branch that is merely safe to delete and then says “Nothing is in flight.” Because `docs/STATE.md` is the required current source of truth, the round-1 stale-STATE finding is not fully closed. Delete or rewrite those stale statements so the document has one answer about current work and branch cleanup.

- **Low — `docs/STATE.md:29-30` records a transient terminal as live when it is not currently verifiable as live.** The head says the live Codex terminal is “Codex review — finish graph,” but the read-only Orca status reports the app/runtime as not running and terminal enumeration fails with `runtime_unavailable`. Remove the live-state assertion or phrase it as the last-known terminal name rather than a current fact.

## Spec

Clear within the requested code and decision-record scope. The metric picker now says `1RM`; the WeightMath header, D45, D52, and CLAUDE index are corrected; all three former display sites call `WeightMath.displayLabel(kilograms:in:locale:)`; the kg path remains exact and has focused coverage; and the app/widget/watch grep found no remaining on-screen `≈`, `estimat`, or `est.` copy. The focused `WeightMathTests` passed (13/13), the full unit suite passed (655/655), and `git diff --check 2262b0f..d198352` passed. The branch/base, unmerged/uninstalled status, pushed commit, deleted stale branches, phone build, and reported test counts in the new STATE head otherwise check out.
