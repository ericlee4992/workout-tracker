# N9 — Body weight logging and Apple Health

Type: feature
Status: **N9a in progress** (2026-11-10) — in the user's plan (N3 … N10 → R); split by Claude overnight: **N9a** body weight logging (now), **N9b** Apple Health (next — its usage strings need the user's wording approval)
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
- Usage strings (`NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription`) updated; wording to approve.
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

## Comments
