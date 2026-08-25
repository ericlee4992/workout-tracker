# Milestone 8 — correct history, then see it

Six asks from the user, 2026-08-25, after several weeks of real gym use.

## What was asked, verbatim

1. Progress charts
2. "For supported weight exercises/machines (like supported dips, pull-ups, etc), make sure the
   weight user enters isn't counting as +weight (it should be minus?, idk)"
3. Edit workout history — delete workouts, edit specific workouts
4. Super/compound sets
5. Workout progress on the phone lock screen (HR, rest timer)
6. Bodyweight exercises: be able to enter 0 for weight

## What investigation found before any ticket was written

**Asks 2 and 6 are the same bug, and it is NOT the one the user thinks.**

The assisted maths is already correct. `RecordsMath` treats `assisted` as *lower is better*,
excludes it from e1RM, and `WorkoutSession.isLoggable` already accepts `0` for `assisted` and
`bodyweightPlus` ("zero assistance and zero added weight are both meaningful"). The seeded catalog
tags them properly too: `Assisted Pull-Up` and `Assisted Dip` are `assisted`; `Pull-Up` and `Dip`
are `bodyweightPlus`.

The real gap: **`loadType` can only be set when an exercise is CREATED** (`NewExerciseSheet`).
There is no way to change it afterwards. So if the user logged against `Dip` when they meant
`Assisted Dip`, or against a machine-derived exercise the catalog tagged `weighted`, they are
stuck — and picking a different exercise **splits their history** (D23, D36). Ask 2 and ask 6 are
both "the load type is wrong and I cannot fix it".

Corroborating: the catalog has **zero** exercises tagged plain `bodyweight` (66 `weighted`,
8 `bodyweightPlus`, 2 `assisted`), so a genuinely bodyweight-only movement has no correct tag to
be given.

**Ask 3 (edit history) collides with D23** — history reads frozen snapshots precisely so the past
cannot be rewritten by later edits. Editing history is legitimate (correcting a typo is not
falsifying) but the rules need stating rather than assuming, hence its own ticket.

**Ask 4 (supersets)** reopens SPEC's post-v1 deferral of "RPE/supersets".

**Ask 5 (lock screen)** is ActivityKit + a widget-extension target. D46 applies directly: state is
pushed to the system, which owns the rendering — nothing runs at a deadline.

## Order, and why

1. **02 — load type editable + catalog audit.** Correctness, and it is small. Everything logged
   from now on is only as good as the load type; and ticket 03 needs a way to fix what is already
   logged wrong.
2. **03 — edit history.** Lets the user repair sets already logged under the wrong type. Must
   settle the D23 question first.
3. **01 — progress charts.** Reads history. Worth doing after history is correct and repairable,
   or the first charts will faithfully draw wrong data.
4. **04 — supersets.** Schema change; larger; nothing above depends on it.
5. **05 — lock screen.** New target, self-contained, and the least reversible if rushed.

Charts were asked for first and are ranked third deliberately: a chart of mis-typed loads is a
confident picture of the wrong thing, and D9/D25's honesty rule is the reason this project exists.

## Codex review points (T6)

- After **02 + 03** — the data-correctness pair. This is the highest-risk surface in the milestone:
  it can silently rewrite the user's real training history.
- After **04** — schema change, and supersets touch the set-ordering invariants.
- After **05** — a new target with its own lifecycle, the shape that hid the watch bug.

Charts (01) can ride along with the 02+03 review unless they grow their own domain logic.
