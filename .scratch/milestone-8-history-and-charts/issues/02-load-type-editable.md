# 02 — Load type: editable after creation, and a catalog audit

Status: open
Blocked by: —
Covers user asks **2** (assisted/supported machines) and **6** (bodyweight = 0).

## The finding that reshaped this ticket

The user asked to "make sure the weight isn't counting as +weight" for supported dips/pull-ups.
**That maths is already right.** `RecordsMath` ranks `assisted` lower-is-better and excludes it
from e1RM; `WorkoutSession.isLoggable` already accepts `0` for `assisted` and `bodyweightPlus`.

What is missing is the ability to **fix a wrong load type**. `loadType` is set once, in
`NewExerciseSheet`, and never again. If a movement is tagged `weighted` when it is `assisted`,
every set logged against it is ranked in the wrong direction — heaviest-wins instead of
least-assistance-wins — and the user's only escape is a different exercise, which splits history
(D23, D36).

Also: the catalog has **zero** plain-`bodyweight` exercises. A push-up has no correct tag today.

## What to build

**1. Change the load type of an existing exercise.** An editing surface for a user-created *and*
a catalog exercise. Where it lives is a judgement call — an "Edit" path from `ExercisesView`
is the obvious home.

**2. State the consequence at the point of change.** Changing a load type **re-ranks every past
set of that exercise** — an assisted PR is the *lowest* load, a weighted PR the highest. Say so
in the sheet, with the count of sets affected. This is the D9/D25 honesty rule applied to a
destructive-feeling edit.

**3. Do NOT rewrite history rows.** D23: `SetRecord` keeps what was entered. Only the exercise's
type changes, and records recompute from it. Confirm by reading `RecordsMath` rather than assuming.

**4. Catalog audit.** Add plain `bodyweight` where it is the honest tag (push-up, air squat, plank
and similar), and re-check anything supported/assisted. Catalog identity is `D24`-versioned — do
**not** change a UUID; changing a `loadType` in place is a data fix, adding an entry is a new
identity. Ten duplicate identities were caught by a past review; this is that same hazard.

## Acceptance criteria

- An existing exercise's load type can be changed, and the change survives a relaunch.
- The sheet names the consequence and the number of sets it re-ranks before committing.
- Records for that exercise recompute in the new direction; a previously "best" assisted set is
  the least assistance, not the most.
- No `SetRecord` field is mutated by the change (assert this explicitly in a test).
- A plain-`bodyweight` exercise can be logged with reps alone, no weight field demanded.
- `0` is accepted and logged for `assisted` / `bodyweightPlus`, and a `0` weighted set logs but is
  not PR-eligible (existing `RecordsMath.isEligible` behaviour — pin it with a test).
- `LegacyStoreMigrationTests` still opens the fixture store.
- Unit + UI suites green.

## Notes

The user's phone holds the only copy of their history. If this ticket ends up touching stored
rows after all, an export comes first (STATE's standing rule).
