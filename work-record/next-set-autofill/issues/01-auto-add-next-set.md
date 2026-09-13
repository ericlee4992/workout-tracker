# 01 — The next set is already there when you finish this one

Status: wontfix — **built, tried on the phone, removed the same day (2026-08-22)**
Blocked by: —

> **Reverted at the user's request after using it.** The behaviour was built, shipped to the
> phone, and rejected on contact: "Whenever I complete a set, it automatically adds next set.
> Delete this." Every set row is now created deliberately, by Add Set, exactly as before.
>
> **What survives, and is what the user actually wanted:** `addSet`'s carry-forward (B1, ticket
> 17) — a row added by hand still arrives holding the last completed set's weight, unit, reps and
> bar, so a repeat set is one tap once the row exists. The half worth having was already built in
> ticket 17; this ticket only removed the tap that asks for the row, and that tap turned out to be
> the part the user wanted to keep.
>
> **Don't rebuild this without new evidence.** The reasoning below is intact and still sounds
> convincing, which is exactly why it is left here: it did not survive one session of real use.
> A future agent reading "four taps spent asking for a row whose contents the app already knows"
> should know that the user, holding the app, disagreed.

Requested by the user 2026-08-22: *"when user records a set, the next set should either be able to
autocomplete with same weight and rep (if user just marks it as complete), or just manually
enter."*

## What already exists, and what does not

`WorkoutSession.addSet` has seeded new rows from the entry's last **completed** set since ticket
17 (B1) — weight, unit, reps. So the "autocomplete with the same weight and reps" half is built
and shipped, and confirming a carried-forward row is already one tap.

What is missing is that the row does not exist until the user taps **Add Set**. On a 4-set
exercise that is four taps spent asking for a row whose contents the app already knows.

## What to build

In `WorkoutSession.toggleCompletion`, after a completion succeeds: if the entry now has **no
uncompleted set left**, append one via the existing `addSet` path, so it arrives carrying the
weight, unit, reps and bar of the set just completed.

**The guard is deliberate.** Appending on every completion regardless would grow a row per
completion on an entry whose rows already exist — a template that pre-built four sets would end
the exercise with four abandoned drafts, and completing set 1 of 4 would insert a row between
nothing and set 2. The user asked for "the next set is ready"; the guard is how that reads when
rows already exist below.

Nothing new is persisted at Finish: `finishInPlace` already deletes uncompleted draft rows and
zero-completed-set entries, so an unused trailing row never reaches history.

Un-completing must not spam rows: after un-completing, an uncompleted row exists, so the next
completion appends nothing.

## Acceptance criteria

- [ ] Completing the only set of an entry appends exactly one uncompleted row carrying the same
      weight value, unit, reps (and bar, once `barbell-bar-weight/02` lands), with `prefilledAt`
      set — it is inherited, not typed (D36).
- [ ] Completing set 1 of a 4-row entry appends **nothing**; completing set 4 appends one row.
- [ ] Complete → un-complete → complete appends exactly one row in total.
- [ ] Completing a **warmup** row appends a row of the same type, consistent with `addSet` today.
- [ ] The appended row is persisted (reopen the store and it is there) — completion is already a
      durability boundary (SPEC "Recording experience").
- [ ] Finish still deletes the trailing draft: a workout of one completed set finishes with one
      set in history, not two.
- [ ] The rest timer still starts from the completed set, not the appended one, and D26 still
      suppresses it for drop sets.
- [x] XCUITest: complete a set and assert a second row appears prefilled, then complete it with a
      single tap and assert both land in history.

## Resolution (2026-08-22) — landed, then reverted hours later

`WorkoutSession.appendNextSetIfNeeded`, called from `toggleCompletion` after the save.
**Both are now deleted**, along with `NextSetAutofillTests.swift`; the six existing tests listed
below were restored to their original expectations with `git checkout`, since every one of their
changes existed only to absorb the appended row. `toggleCompletion` is byte-identical to its
pre-ticket shape.
Tests: `WorkoutTrackerTests/NextSetAutofillTests.swift` (6), and the second half of
`WorkoutTrackerUITests/BarbellUITests.swift` — which also proves the waiting row carries the
*plates*, not the total, when the entry is in bar mode.

**Six existing tests changed expectations, none changed meaning.** They asserted set counts and
`order` values that an appended row necessarily shifts (`WorkoutSessionTests`, `SetLoggingTests`,
`ExercisePresetTests`). Where a test's next step was "add a row and check what it inherited", it
now uses the row completion already left waiting — which is a truer test of the flow than adding a
row by hand. Two are worth naming because their *subject* moved slightly:

- `deletingTheOnlySetLeavesTheEntryIntactAndUsable` — deleting an entry's only completed set no
  longer empties the entry; the waiting row remains, uncompleted, renumbered to 0.
- `carryForwardSurvivesCrossWorkoutPrefill` — the cross-workout candidate is now matched against
  the waiting row's ordinal. Adding a *third* row by hand made prefill correctly return nil (the
  past workout had only two sets), which is the ordinal rule working, not a regression.
