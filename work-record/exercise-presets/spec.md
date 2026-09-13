# Exercise presets — grips, stances, and single/double

Written 2026-08-12 from gym feedback, with three design questions answered by the user the same
day. Sits alongside the numbered v1 milestones; it changes the taxonomy, so read this before
touching records or history.

## The ask, in the user's words

> for exercises that can switch between grips, single/double, there should be option to select
> them before adding the machine/exercise. For example, instead of having to add leg press
> separately twice, i should be able to choose betwen single/double leg press. Same for cable
> seated rows. I should be able to choose wide-grip, narrow-grip, etc. Basically I'm saying i
> should be able to make presets.

## What a preset is

A **named variation of a movement** that the user defines: `single leg` / `double leg`,
`wide grip` / `narrow grip` / `neutral grip`, `high pulley` / `low pulley`.

It is a fifth thing in the taxonomy, and the first one that is *not* about hardware:

| Level | Example | Created by |
|---|---|---|
| Exercise | Seated Cable Row | Seeded + user |
| **Preset** | **Wide grip** | **User, per exercise** |
| Equipment model | Life Fitness Insignia Row | Seeded catalog + user |
| Machine instance | "Cable Row #2" | User, per gym |
| Gym | Gold's Gym Gangnam | User |

## The three decisions (user, 2026-08-12) → D36–D38

- **D36 — A preset splits records.** PRs, e1RM, "previous performance" and prefill all key on the
  preset alongside the equipment layers. A narrow-grip row PR is not a wide-grip row PR. **Volume
  is not split**: it is a whole-workout total (D21), and a total that dropped the sets performed
  under another grip would simply be wrong.
  This is the same rule that keeps two machines apart (D1/D8/D23), applied to the axis the user
  actually varies; pooling them would let one variation set a "record" the other can never beat.
- **D37 — Presets belong to the exercise, not the machine.** "Seated Cable Row" offers its grips at
  every gym and on every machine — defined once, travels with you, which is exactly D6's argument
  for gym-independent templates. A machine may nominate *which* of them it usually is.
- **D38 — The preset is chosen at log time, with the machine's usual one preselected.** Grips vary
  session to session on the same machine, so freezing the choice at machine-creation would mean
  editing the machine to change grip. Adding a machine sets its usual preset; logging preselects
  that and switches in one tap.

## Consequences that follow, not choices

- **A preset is part of the entry's context snapshot (D23).** It is captured with the rest when the
  entry's first set completes, and history reads the snapshot forever after. Renaming
  "wide grip" later must not retitle last month's sets.
- **Switching preset on a frozen entry starts a new entry (D19).** Identical reasoning to switching
  equipment: completed sets must never be silently relabelled into a variation they were not
  performed in. Uncompleted draft rows move across; completed sets stay.
- **The export carries it (D30).** `presetID`/`presetName` appended as CSV columns 28–29 (appended,
  so a reader of the first 27 is unaffected) and added to every JSON entry; `schemaVersion` → 2.
- **`GymExerciseMemory` is untouched.** It remembers the machine for a (gym, exercise); the
  machine's usual preset lives on the machine.
- **Nothing is seeded.** Presets are user-created (D3's reasoning: a worldwide list of grips per
  machine is unknowable). The add sheet *suggests* common names — it does not ship a catalog.

## What it looks like

```
Exercises → Seated Cable Row → Presets
    Wide grip          ⇅
    Narrow grip        ⇅
    Neutral grip       ⇅
    + Add preset…      (suggestions: wide grip, narrow grip, neutral grip,
                        single arm, single leg, high pulley, …)

Add Machine → Cable Row #2 → Usually: [ Wide grip ▾ ]     (only when the model serves one exercise)

Active workout → Seated Cable Row
    [ Wide grip ✓ ] [ Narrow grip ] [ Neutral grip ]
    SET  PREVIOUS          WEIGHT  REPS
     1   70 kg × 8 (wide)  [ 70 ]  [ 8 ]  ○
```

History and the previous-performance sheet name the preset wherever they already name the machine.

## Out of scope

- Seeding a preset catalog.
- Presets on free-weight (machineless) entries — the same mechanism will serve them, but the ask
  was about machines; wiring the picker into free-weight entries follows the same entry field.
- Per-preset rest durations, per-preset templates.
- Migrating existing history: sets already logged have no preset and keep none. They group as
  "no preset", which is honest — nobody recorded which grip they were.

## Tickets

```
01 preset-schema-and-core   — model, snapshot fields, records/prefill grouping, migration-safe
└── 02 preset-management-ui — presets per exercise, machine's usual preset
    └── 03 log-time-picker  — chips in the entry card, entry split on change, history display
        └── 04 export-and-verification — CSV/JSON, docs, full suite, cross-review
```
