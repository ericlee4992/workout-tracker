# Ticket 03 — independent review, round 2 (T6)

**Not clear: one medium finding.** No critical, high or low findings.
Reviewed `b1e0128..e6faceaa5bfe374b6120cee80698302e1d973fce` on
`ericlee4992/redesign-floodlight-live`, in `/tmp/wt-floodlight/live`. Product fixes are
`1a04857` and `57d20cc`; `e6facea` adds the review prompt. Claude implemented; Codex reviewed.

## Medium — the new completion band can announce a revoked best (Spec)

**Location:** `WorkoutTracker/Features/ActiveWorkout/ActiveWorkoutView.swift:534`–`:545`,
with the captured value created at `:522`–`:529`.

`refreshBadges()` updates the row stickers but never reconciles `freshBest`. Complete a new
best, then immediately change that completed row to Warmup: the row sticker disappears, but
the slab continues announcing “New best” for an excluded set until the four-second timeout.
Deleting the set has the same effect. Correcting its weight during the window leaves the old
value in the band, even if the correction removes the record. Deleting its entire exercise
also leaves a band whose previous-performance tap can no longer resolve an entry.

Reconcile the active band against the recalculated outcome whenever its inputs change:
remove it when its set/entry is gone or no longer qualifies, and refresh its value/incumbent
when it still qualifies. Preserve the original expiry rather than starting another celebration
on an edit. Add a focused regression that changes a newly celebrated set to Warmup or deletes
it and checks **both** the row sticker and `liveNewBest`. The current warmup test starts with
fixture badges and never creates a fresh band, so it does not cover this case.

## Round-1 findings

| Finding | Round-2 disposition |
|---|---|
| 1. Completed rows locked | Resolved. Weight/reps and non-bar units are editable. Field commits retain `completedAt`, clear `prefilledAt`, and do not invoke the completion/rest callback. Bar input still commits the computed total and locks the unit. |
| 2. Stale row marks | Original repros resolved: type, completion, values and deletion change `badgeInputs`; affected stickers recompute. See the dependency audit below and the new band finding above. |
| 3. Preset coverage missing | Resolved. Both original preset tests now reach and pass the live chips, inherited-value clearing and frozen-entry split assertions. |
| 4. L03 band absent | Implemented, including the user's AX replacement choice. Not fully clear because its captured result can become stale, as above. |
| 5. Bar/Rest sheet tokens | Resolved. Both entry-owned presentation boundaries call `floodlightSheet(from:)`, restoring plain Floodlight tokens in the inherited light/dark scheme. |
| 6. Unit target too small | Resolved. The unit button's own label now has a 44 × 44 minimum frame and content shape. |

## Dependency and behavior audit

- **`badgeInputs` is not an exhaustive representation of the calculation's inputs.** It
  includes live machine/tag/preset and effective load type, plus set identity, type, completion,
  reps and normalized load. It omits live exercise identity and the snapshot identity/fallback
  fields used by `Scope` (`snapshotExerciseID`, `snapshotMachineID`, `snapshotFreeWeightTag`,
  `snapshotPresetID` and snapshot-capture state). It also omits `weightValue` presence,
  `weightUnit`, workout start time and finished-history inputs. Effective load type does read
  the frozen load type, but that does not cover the other snapshot fields. The comments and
  ticket's “everything the marks read” claim should be narrowed or the dependency representation
  made complete. I found no additional ordinary local UI repro: inspected scope mutations
  also change a hashed value/split the entry, normal load commits update normalized load,
  and editing history through minimise/resume refreshes on appearance. No speculative
  snapshot-mutation defect is counted as a finding.
- **No refresh loop found.** The signature is calculated during body evaluation, but history
  is fetched only on appearance or a changed signature. `refreshBadges()` writes view state
  only when the resulting dictionary differs; those writes do not alter the signature. Timer
  and heart-rate updates do not themselves change it.
- **L03 calculation and lifecycle:** outcome selection uses the same equipment/variation/load
  scope as badges and returns the incumbent actually beaten, including earlier sets in the
  current workout. First-workout suppression remains. A newer best replaces the band and
  cancels the old task; explicit uncompletion clears it. The cancellable task uses a four-second
  duration. With no rest, the band renders alone. At accessibility sizes with rest, it replaces
  the Rest/time block, preserving the ring and controls; the slab caps its contents at AX1.
  Reduce Motion suppresses the triggered landing/highlighter motion and moving transitions.
  The full spoken label includes units and incumbent; the tap resolves previous performance;
  success feedback is wired. These paths were traced in source, not exercised in a new run.
- **Completed PREVIOUS is safe.** `reference(for:)` extracts the same historical selection
  formerly used by `prefill(for:)`. It does not mutate a set. `prefill` retains its completed-row
  guard, and `applyPrefill` independently refuses completed or dirty rows and rows with another
  completed peer. Calling `reference` from `LiveSetRow` therefore cannot overwrite a completed
  set. The D36 context-change clearing and dirty-text guards remain intact. Retaining the
  reference matches approved L01/L03 and breaks no reviewed product rule.

## Tests, captures and scope

- Independently read actual exit files, logs and `xcresulttool` summaries. Builds
  `live-build-2` and `live-build-4`: **exit 0**. `live-ui-3`: **exit 65**, **54 passed / 1 failed /
  0 skipped** (33 UI passes, one UI failure, 21 domain passes). Its sole failure is the already
  documented Gyms model-picker submenu assertion. `live-ui-4`: **exit 0**, **9 passed / 0 failed /
  0 skipped**. Artifacts are under `/tmp/wt-floodlight/results/`.
- `revealedSearchField()` reveals the native drawer with a gesture, retains the existence
  assertion, and returns the real search field. It does not bypass the preset assertions.
  `FloodlightLiveUITests` now checks exact replacement text and exact achieved/incumbent band
  values. The edit, warmup and band tests would fail against their corresponding missing fixes
  by source inspection; no reverse-patch run was performed. The edit test proves editability
  and continued completion, while timestamp/rest preservation is established by tracing the
  commit handlers. The band test proves appearance and eventual disappearance within its
  timeout, not precise four-second timing. The AX test checks replacement and restoration.
- Opened all five new captures: light/dark default, light AXL, default L03 and AX L03. The
  captured AX band follows the user's choice; it does not stack above the Rest/time text.
- The targeted round-2 scope is appropriate under DEVELOPMENT. Add the focused regression
  for the remaining band invalidation issue and rerun affected tests after fixing it; a full
  UI-suite rerun is not required by this finding. Minor ticket correction: “CoreLoop 9 others”
  should be **8 CoreLoop passes and 1 failure** in `live-ui-3`.

No `xcodebuild` or `simctl` commands were run. Only this report was written; existing
`opencode.json` was untouched. Standards axis: clear. Spec axis: one medium finding.
