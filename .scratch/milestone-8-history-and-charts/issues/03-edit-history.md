# 03 — Edit and delete workout history

Status: resolved
Blocked by: 02 (a wrong load type is one of the things the user will want to repair)
Covers user ask **3**.

## The decision this ticket must settle first

**D23 says history reads frozen snapshots so the past cannot be silently rewritten.** That rule
exists because a later edit to an exercise or machine must not restate what happened in a session
months ago. Editing history deliberately is a different act from history drifting by accident —
but the difference has to be *written down*, not assumed, or this ticket quietly guts D23.

Proposed line, to confirm with the user and record as a decision:

- **Correcting** what you actually did (a typo'd weight, a missed rep, a set logged on the wrong
  exercise) is legitimate. The log should describe reality.
- **Snapshots stay snapshots.** Editing a past set must not re-point it at today's machine name or
  today's exercise definition. What was frozen stays frozen unless the user edits *that field*.
- **Deletion is real deletion**, and it changes PRs and volume. Say so before it happens.

## What to build

- Delete a whole workout from `History`, with confirmation naming what is lost (sets, PRs).
- Edit a past workout: its sets' weight / reps / warmup flag, and delete individual sets.
- Recompute records after any edit — a deleted PR set must stop being the PR.
- An edited workout should be visibly marked as edited, with the timestamp. The app's whole thesis
  is not claiming more certainty than it has; a silently altered history is exactly that.

## Acceptance criteria

- A workout can be deleted; its sets no longer contribute to PRs, volume or charts.
- A past set's weight/reps can be corrected, and records recompute.
- Editing a past set does NOT re-resolve its exercise/machine snapshot (assert with a test that
  renames the exercise afterwards and checks the history row still shows the old name — this is
  the D23 regression that a past review already caught once).
- Deleting the last set of an exercise entry leaves no orphan entry.
- Export (CSV/JSON) reflects edits and deletions.
- An edited workout is marked as edited in the UI.
- `LegacyStoreMigrationTests` green; unit + UI suites green.

## Risk

**Highest-risk ticket in the milestone.** It can destroy the user's only copy of their training
history. Take an export before testing on the device, and make the destructive paths confirm.


## Resolution (2026-08-25)

**D47 recorded** in `DECISIONS.md`, settling the question this ticket opened rather than leaving it
implicit: numbers are editable, snapshots are not, and every edit is marked.

`Domain/HistoryEditing.swift` owns the rules — `apply` re-derives `normalizedKg` with the value and
unit (D25) and refuses an edit that would not be loggable (A1); `deleteSet` + `pruneIfEmpty` avoid
orphan entries; `impact(ofDeleting:)` counts what a deletion destroys so the confirmation names it
instead of asking "are you sure?" about an unknown quantity. `Workout.historyEditedAt` (optional,
lightweight migration) carries the mark.

UI: tap a set in `WorkoutDetailView` to correct it, swipe to delete it, and delete the whole
workout from the toolbar menu behind a confirmation that quotes sets and exercises.

10 unit tests + 2 XCUITests. 495 unit tests green including the migration fixture.

**The test that matters most** is `editingASetDoesNotRestateWhatEquipmentItWasLoggedOn`: it renames
and re-types the exercise, then edits a set, and asserts the frozen snapshot is untouched. Without
that boundary, correcting a weight typo would silently re-label a March set with today's machine
name and today's load type.

**Note on the UI tests**: two rounds of "no matches found" were a STALE TEST BINARY, not wrong
selectors — a hierarchy dump showed both identifiers present all along. Worth remembering before
chasing a selector that is already correct.


## Post-review (2026-08-25)

Codex found five real defects. Every one is fixed with a regression test that failed against the
reviewed implementation:

1. **Invalid weights could be written into finished history.** `apply` asked only whether the value
   was non-nil, bypassing `StoredWeight`/`WeightMath.isValidInput` — a pasted `-50`, `NaN` or `inf`
   was accepted, normalized and stored. The resolution's "refuses an edit that would not be
   loggable" claim was false.
2. **Bar provenance was torn apart.** Editing a bar set's unit relabelled a 45 lb bar as 45 kg while
   exporting its old normalization, and a total could drop below its own bar (D39). An incoherent
   edit now drops the provenance rather than lying about it.
3. **The deletion volume was a second implementation** that counted assisted and bodyweight-plus
   loads as volume. Now `RecordsMath.totalVolumeKg`.
4. **The volume was computed and never shown** — the absence-of-a-caller class again, in a decision
   (D47) that requires the confirmation to name what it destroys.
5. **Swipe-deleting a set did not confirm**, though the ticket's own risk section demanded it.
6. **`historyEditedAt` was missing from the backup**, so a restored history claimed never to have
   been edited.

Also added, closing the review's critical Spec finding: `HistoryEditing.retype`. Correcting an
exercise fixes only future sets, so sets already logged under a wrong type were permanently ranked
backwards — the user's original complaint. One entry, load type only, identity frozen, marked as an
edit.

507 unit tests green.
