# N9 — Body weight logging and Apple Health

Type: feature
Status: **N9a done — Codex clear (round 2), merged** (2026-11-10); **N9b (Apple Health) built** on `ericlee4992/c1-n9b` (2026-11-10), verification + Codex review pending together with C1; was: next, grouped with C1 (the user, 2026-11-10: build C1 and N9b, then test and Codex-review them together as one task); split by Claude overnight: **N9a** body weight logging, **N9b** Apple Health — usage strings **approved** (below)
Blocked by: N2
Implementer: Claude; Reviewer: Codex (visible Orca terminal), to "clear".
Branch (when built): `ericlee4992/nutrition-09-weight-health` off `main`.
Spec: [nutrition](../spec.md). Decisions: D74, D71.

## Goal

Log body weight in the app, and share weight, food and burned calories with Apple Health as the user chose.

## Scope

- **Log weight:** a sheet with the figure and ± steps in the user's unit (prototype); edit/delete entries.
- **Apple Health** (permission asked when the user first turns it on; each part works when the others are denied):
  - **Read body weight** → shown with the app's own entries (deduplicated: the app's own writes are recognised by
    their Health sample id).
  - **Write body weight** → each app entry, updated/deleted with it.
  - **Write food totals** → each food entry writes dietary energy, protein, carbs and fat (a correlation per entry with
    a sync id), replaced on edit and deleted on delete.
  - **Read calories burned** → the day's active energy shown as Burned on Today (D71: shown, never added).
- Profile → Apple Health: on/off per part, and what is shared.
- Usage strings (`NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription`) updated — **approved by the user
  (2026-11-10 morning; recorded from that session's transcript in the evening):**
  - Share (reading): "Your heart rate, active and resting energy, and distance are shown during and after a workout;
    your body weight appears with the weights you log, and the day's active energy is shown as Burned on Today.
    Stacked does not upload them; they leave your iPhone only in an export or feedback you send."
  - Update (saving): "Workouts you log are saved to Health, and if you turn them on, your body weight and the calories,
    protein, carbs and fat of the food you log."
  (Today's values are in `project.pbxproj` `INFOPLIST_KEY_NSHealth…`, both configurations.)
- Goals (N3): offer Recalculate when the weight changes by more than about 2 kg since the goal.

## Acceptance

1. Unit tests: dedupe, unit handling, sync ids, delete propagation (HealthKit behind a protocol, faked).
2. Simulator: permission prompts, denied paths; real check on the phone at R.
3. Captures; Codex clear.

## Code map

- `Domain/HealthKitHeartRateProvider.swift` (current HealthKit read set `:64`), `Domain/WorkoutVitals.swift`; new
  `Domain/HealthNutritionSync.swift`; Profile (S2).

## Progress

**Split (Claude, 2026-11-10 night, the user's overnight permission):** **N9a** — body weight logging and the
Recalculate offer; **N9b** — Apple Health (read/write weight, write food totals, read active energy as Burned, the
Profile → Apple Health page, usage strings for the user's approval). Reason: N9b needs the user's wording, and Codex's
weekly budget was at 23 %, so a smaller reviewable unit first.

**N9a built (branch `ericlee4992/nutrition-09-weight-health`):** `Domain/BodyWeightLog.swift` (log / update / delete,
entered `(value, unit)` + `normalizedKg` in step; steps 0.1 kg / 0.2 lb; ranges as Personal details;
`goalNeedsRecalculating` past 2 kg from the goal's weight); `Features/Nutrition/BodyWeightView.swift` — Profile →
Goals & tracking → **Body weight** (row value = latest, or Not set): latest weight as the hero with its date, a
"Your nutrition goals use 80 kg. / Recalculate goals" card when > 2 kg away (runs N3's `NutritionGoalStore.update`),
History rows (tap to edit), **Log weight** primary; **Log weight** sheet (prototype): the figure as a field, − / +
steps, Time, Cancel / Save, Delete Weight when editing. New entries use the latest entry's unit, else the unit system.
- **Own decisions:** logging a weight does not move the goal by itself (the offer does); a past time is allowed, not a
  future one; "Apple Health" subtitle reserved for Health-read entries (N9b).
- **Open for the user:** N3's goals page refresh already recalculates from the latest weight when visited — so the goal
  still follows the weight on a visit to Nutrition goals. Keep that, or have the goal follow only Recalculate?
- **New strings:** "Body weight", "No weight yet" / "Log your weight to follow it over time.", "History", "Log weight",
  "Edit weight", "Time", "Delete Weight", "Your nutrition goals use X kg.", "Recalculate goals", VoiceOver "Less" /
  "More".
- **Evidence:** build exit 0; `BodyWeightLogTests` 3 × 10 = 30/30 (`n9u.xcresult`); `BodyWeightUITests` 3/3 (captures
  2/2 in `n9ui.xcresult`; the flow test failed once — its edit typed before the old figure — fixed to tap the field's
  end, 1/1 in `n9ui2.xcresult`); captures looked at (`n9att/N9.png`). After rebasing on `main` `d38cf18`: Unit plan **1,225 executions, 0 failed**
  (`n9unit.xcresult`); warm-up + BodyWeight + FloodlightProfile + NutritionGoals **23/23** (`n9reg.xcresult`, 2 workers).
  Verified: the above. Not verified: runtime Reduce Motion, VoiceOver by a person, the full UI suite.

**N9b built (Claude, 2026-11-10, branch `ericlee4992/c1-n9b`, with C1).**
- **Code:** `Domain/HealthNutritionSync.swift` — `HealthType` / `HealthPart` (the four switches, each asking Health only
  for its own types), `HealthStoring` (HealthKit behind a protocol), `HealthSyncPlan` (pure: desired samples, diff,
  readings, mirror), `HealthSync` (the observable engine); `Domain/HealthKitNutritionStore.swift` — the real store, the
  `FakeHealthStore` (unit tests + UI tests) and `HealthFixture` (`-uiTestHealthSample`, `-uiTestHealthOn`,
  `-uiTestHealthRefused`); `Features/Nutrition/AppleHealthView.swift`; Profile row **Apple Health** (On / Off) at the
  end of Goals & tracking; Body weight shows Health's weights read-only; Today's Burned; app root injects and starts the
  sync (never in the tour's sample world; UI tests get the fake and throwaway switches). No schema change: N2's
  `healthSampleID` fields carry the Health ids.
- **How it syncs (Claude's design):** a reconcile, not a hook per write path — food is logged from many places (Log
  food, Undo, Restore, scans, editors). Each pass (at launch, ~1 s after any save, when the app becomes active, when a
  part is turned on) compares the app's entries with the samples this app wrote, found by sync identifiers
  (`stacked.weight.<id>`, `stacked.food.<id>.<type>`); it saves what differs (Health's sync versioning replaces the old
  sample, so an edit never duplicates) and deletes samples whose entry is gone. A repeated pass writes nothing.
- **Own decisions (Claude; for the user to confirm):**
  1. Food goes to Health as four plain samples per entry (calories always; protein, carbs, fat when above zero), each
     named with the food, **not a food correlation** as this ticket first said: Health cannot be asked to share the
     correlation type, so the app could not reliably replace or delete one.
  2. Turning a save part **off** stops changes; what is in Health stays. Turning it on again brings Health back in line
     with the app — every entry written, ones deleted meanwhile removed.
  3. Health's weights: the **last 365 days**, in the app's unit system, **read-only** in the app (no chevron; change
     them in Health); turning reading off removes them from the app (Health keeps them). The Log weight sheet's unit
     follows the latest weight the user logged, not a Health one.
  4. **Burned** = the larger of Health's active energy for the day and the app's own workouts (Health's figure already
     counts the app's workouts saved there; the max keeps a workout not yet in Health). Today only; the week's rings
     are unchanged.
  5. A refused save is said under its switch; a refused read cannot be detected (Health shows it as no data).
- **New strings:** page "Apple Health"; groups "Read from Health" / "Save to Health"; rows "Body weight" — "Shown with
  the weights you log", "Calories burned" — "Active energy, shown as Burned on Today", "Body weight" — "Each weight you
  log", "Food" — "Calories, protein, carbs and fat of each entry"; footnote "Stacked doesn't upload your Health data.
  Turning a switch off stops new changes; what's already in Health stays there."; refused "Health hasn't allowed saving
  body weight. / …saving all of your food's numbers. Allow it in the Health app: Profile → Apps → Stacked."; failures
  "Couldn't ask Health for permission. Try again." / "Couldn't update Apple Health. It will try again."; unavailable
  "Health isn't available" / "This device doesn't have Apple Health."; Profile row "Apple Health" On / Off. Usage
  strings as approved above (apostrophe typeset ’ like the file's other strings), iPhone app Debug and Release.
- **Design (ios-design):** *In the default state this screen exists so the user can turn a part on in one tap; the eye
  lands on the first group, Read from Health* (runner-up: Save to Health, same weight, second). Wireframe:
  ```
  Apple Health                 (nav title, large)
  READ FROM HEALTH             (section header)
  [ Body weight            (o) ]  equal rows
  [ Calories burned        (o) ]
  SAVE TO HEALTH
  [ Body weight            (o) ]
  [ Food                   (o) ]
  ! refused note (only when)
  footnote (secondary)
  ```
  A standard settings list: no mock round (no new structure; Preferences' look). Tells: accent fill — absent (switches
  are state); card around a sentence — absent (the footnote is plain text); second hero — absent.

**Verification (one pass for C1 + N9b, 2026-11-10; scope per DEVELOPMENT — a new feature: its tests plus adjacent flows;
C1: the flows whose text changed).** Build-for-testing exit 0. `HealthNutritionSyncTests` 15 × 10 = 150/150
(`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/20f5b25b-92e7-448e-a00d-dbd68fee92a9/scratchpad/c1n9b-health10.xcresult`); Unit plan 1,247/1,247 (`c1n9b-unit`); `AppleHealthUITests` + warm-up 5/5
(`c1n9b-ui1`, captures looked at: `att1/`); BodyWeight, TodayFood, FloodlightProfile, FloodlightScan,
FloodlightAIRoutine, NutritionGoals + warm-up 65/65, 2 workers (`c1n9b-ui2`). AskAIUITests not run: no test there reads a
changed string; the changed error lines are unit-tested.

```
Verified: HealthNutritionSyncTests 150/150, Unit plan 1,247/1,247, AppleHealthUITests 5/5, affected UI classes 65/65 — exit 0 each
Not verified: the real HealthKit store (permission sheets, sync-version replacement, deletes) — the Simulator/phone check at R; AskAIUITests; VoiceOver by a person
Known flaky: none seen
```

## Comments

**Round 1 (`codex-review-n9a.md`): not clear — 2 P2, 1 P3.** Fixed: (1) the Log weight sheet keeps the stored figure
exactly when its text is unchanged (`EditableNumber`; a time-only edit no longer rounds 176.456 to 176.46); (2)
**Recalculate goals** is N3's explicit Recalculate — `BodyWeightLog.recalculateGoal` clears typed-over numbers and
recalculates with the latest weight, and incomplete Personal details show "Add your personal details first." instead
of doing nothing; (3) README "Body weight" item. Tests: `anUnchangedFigureKeepsItsStoredPrecision`,
`recalculateClearsTypedNumbersAndUsesTheLatestWeight` (overridden goal; incomplete details throw); the UI flow now taps
Recalculate and sees the offer go, then come back after deleting. `BodyWeightLogTests` 5 × 10 = 50/50 (`n9u2.xcresult`);
`BodyWeightUITests` 3/3 (`n9ui3.xcresult`).

**Round 2 (`codex-review-n9a-b.md`): clear** — reviewer's Unit 1,211 / 1,227 executions, BodyWeightUITests 3/3 +
warm-up. N9a merged into `main` by the user's standing permission. **N9b** (Apple Health) is next, held for the
morning: its usage strings need the user's wording, and Codex's weekly limit was at 18 %.

