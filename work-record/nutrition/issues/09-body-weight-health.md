# N9 — Body weight logging and Apple Health

Type: feature
Status: **proposed** (2026-11-07) — awaiting the user's approval
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

Not started.

## Comments
