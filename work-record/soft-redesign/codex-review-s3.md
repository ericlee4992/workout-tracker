# S3 independent review — workout refinements

Reviewed 2026-11-07 by Codex; implementation by Claude.

## Scope

Requested diff: `git diff a1ec954..4e6e887`, S3 only, stacked on the cleared S2 tip. Branch
`ericlee4992/soft-03-workout`; checkout HEAD `3d059d8017baff60c0ec2fe354c742502d760ec6`. The commit after
`4e6e887` changes only the review prompt and ticket, so tested product/test code matches the requested tip.
Read AGENTS, STATE, the full review brief, S3 ticket, Direction A, D44/D52/D64/D67, relevant development and
SwiftUI/SwiftData/design guidance, and the specified approved prototype files. Soft's approved design supersedes
the older Floodlight palette in the design skill. Glanced at `scripts/test-progress.sh` as requested; it is a
progress display, not a test-result gate.

Only this report was written in the repository. No implementation files were changed, committed, or pushed.

## Spec

No actionable source findings.

- **Train and Today:** `TemplateStats.dueNext` selects never-run first, then oldest last run, with name/UUID ties.
  Both screens use it against finished-workout statistics. Train suppresses the lead while a workout runs and
  offers Resume. The lead is excluded from `otherTemplates`, so its `templateTile.<name>` identifier does not
  duplicate another rendering of that template. Existing tile queries open the template rather than depending
  on tile-only content. The sole-template card receives `tour.templates`; start and Ask AI anchors remain.
- **Finish:** the List orders bests → receipt → actions after the existing saved-status header. Receipt values,
  units, missing-fact omission rules, identifiers, and spoken meanings come from unchanged
  `FinishTile.summaryTiles`; exercise/set counts use completed entries/sets. Best speech retains the exercise,
  equipment, value and previous best. The comparison gate includes exactly a 25% drop, excludes larger drops and
  zero-volume runs, and leaves History unchanged. No record, volume, energy, or D64 time calculation changed.
- **Cardio:** Pause and End have equal widths and a gap, with shorter visible End text and an activity-specific
  spoken label. The Finish Workout slot requires cardio focus, no unfinished segment, an existing segment, and
  a nondeleted workout. It does not appear in lifting focus in a mixed workout. It invokes the same
  `finishTapped()` path as toolbar Finish, preserving drift resolution and empty-workout handling; End still
  ends only the segment.
- **Template detail:** the More menu retains the deletion confirmation and existing handler and is disabled
  when the template is gone. Case/diacritic-insensitive equality suppresses the repeated machine name, while
  distinct equipment labels remain.
- **Rest slab:** one-row and fallback layouts match the approved prototype. The container's spoken label still
  includes Next. `axTimeReplacement` is preserved; its actual caller supplies `LiveBestCompact` during a fresh
  best at AX size, not heart-rate content. The fallback keeps ring, lead and Skip together, moving +15s below.

## Standards

No actionable source findings. Domain changes remain free of UI imports; there is no persistence/schema change.
The test edits retain deletion/cancel assertions and accommodate the finish actions' new position. Receipt
figures keep their individual identifiers rather than inheriting a panel identifier. Separate standards and
spec checks found no unrelated modernization or file split worth adding to this review.

## Independent verification

Xcode 27.2 (27B52), iOS 27.0 simulator WT-iPhone27 `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`.
Artifacts: `/tmp/codex-s3/`; derived data: `/tmp/codex-s3/DerivedData`.

- Build for testing: **exit 0**, result `succeeded`, **0 errors, 31 warnings**; `build.log`, `build.xcresult`,
  `build-summary.json`.
- Unit tests: **exit 0**, **7 passed, 0 failed, 0 skipped** — `TemplateDueNextTests` 4 and
  `FinishComparisonRuleTests` 3; `unit.log`, `unit.xcresult`.
- Requested serial UI run: **in progress**; exec session `35402`, `ui.log`, `ui.xcresult`. Selection begins with
  `CardioUITests/testSavedDistanceEditorKeepsEnteredUnitsAndUntouchedMeasurements`, followed by
  `FloodlightFinishUITests` and `TemplateDetailUITests` in XCTest's class order. Final counts and capture
  inspection will replace this checkpoint before delivery.
- `git diff --check a1ec954..4e6e887`: **exit 0**.

The full combined Phase 1 capture/core-flow run remains deferred. This review does not claim device installation,
real sensor/GPS testing, or a person's VoiceOver traversal. Source inspection of spoken labels and ordering is
distinct from those checks.

Standards: **0 source findings**. Spec: **0 source findings**. Runtime/visual verification is pending.

Verdict: not clear
