# 02 — Load type: editable after creation, and a catalog audit

Status: resolved
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

**2. State the consequence at the point of change — and the FIRST DRAFT OF THIS TICKET GOT IT
WRONG.** It claimed the change re-ranks every past set. It does not. `ExerciseEntry.
effectiveLoadType` returns `snapshotLoadType` once the entry is frozen (D19/D23), so **history
keeps the type it was logged under**. Only entries logged *after* the change use the new type.

That is the correct behaviour and it must be what the sheet says. It also means fixing the
exercise does NOT repair sets already logged wrong — that needs ticket 03. Say so, and point
there, rather than letting the user believe their back catalogue just got fixed.

**3. The edit must SURVIVE CATALOG RECONCILIATION.** `CatalogSeeder.reconcileExercises` runs
`setIfChanged(&row.loadType, seed.loadType)` on every seeded row at each catalog version bump
(D24). Editing a seeded exercise in place therefore works until the next bump and then silently
reverts, flipping the user's records back with no error. Add `loadTypeUserOverridden` to
`Exercise` and have the seeder skip `loadType` when it is set. Without this the feature is a
time-bomb, not a fix.

**4. Catalog audit.** Add plain `bodyweight` where it is the honest tag (push-up, air squat, plank
and similar), and re-check anything supported/assisted. Catalog identity is `D24`-versioned — do
**not** change a UUID; changing a `loadType` in place is a data fix, adding an entry is a new
identity. Ten duplicate identities were caught by a past review; this is that same hazard.

## Acceptance criteria

- An existing exercise's load type can be changed, and the change survives a relaunch.
- The sheet says plainly that history keeps the type it was logged under, and points at history
  editing for repairing past sets.
- Entries logged AFTER the change use the new type; frozen entries do not (assert both in a test).
- A seeded exercise's corrected load type SURVIVES a catalog reconciliation (assert with a test
  that runs the seeder afterwards).
- No `SetRecord` field is mutated by the change (assert this explicitly in a test).
- A plain-`bodyweight` exercise can be logged with reps alone, no weight field demanded.
- `0` is accepted and logged for `assisted` / `bodyweightPlus`, and a `0` weighted set logs but is
  not PR-eligible (existing `RecordsMath.isEligible` behaviour — pin it with a test).
- `LegacyStoreMigrationTests` still opens the fixture store.
- Unit + UI suites green.

## Notes

The user's phone holds the only copy of their history. If this ticket ends up touching stored
rows after all, an export comes first (STATE's standing rule).


## Resolution (2026-08-25)

`Exercise.loadTypeUserOverridden` (optional Bool, lightweight migration) + a guard in
`CatalogSeeder.reconcileExercises`, so a hand-corrected type survives a catalog version bump.
`EditExerciseLoadTypeSheet`, reachable by long-press on any exercise in the Exercises tab —
**including seeded ones**. D24 reserves catalog *naming*; a wrong load type is not a naming
preference, it ranks records backwards, and the only other escape splits history.

Six tests in `LoadTypeOverrideTests`. 485 unit tests green, `LegacyStoreMigrationTests` included,
so the new field migrates the fixture store.

**The catalog audit was deliberately NOT done as a mass retag.** The candidates found — `Lunge`,
`Back Extension`, `Reverse Hyperextension` tagged `weighted` — are judgement calls about how the
user trains, not clear errors, and no specific one was reported. Plain-bodyweight staples
(push-up, plank, air squat) are absent from the catalog entirely, so "fixing" them means adding new
catalog identities, which is the hazard that once produced ten duplicates splitting the user's
history. Retagging seeded rows on a guess would also change what future sets are judged as, for
every one of them at once.

Left to real gym use, which is what STATE says should drive this. The load-type editor makes it a
two-tap fix when the user hits one, and creating a custom exercise already offers all four types.
