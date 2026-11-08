# 01 — Faster unit-test runs

Type: task
Status: **approved** (the user, 2026-11-08) — after S5, before N1
Implementer: Claude; Reviewer: Codex.

## Why

The user (2026-11-08): "even the unit tests sometimes take long." Measured 2026-11-07: 90 tests ran in ~50 s and 21 in
~42 s — the time is fixed overhead, not the tests: the build, the hosted test bundle (`TEST_HOST`: the simulator boots,
the app installs and launches), the app's launch work (`WorkoutTrackerApp.swift:43–47` reconciles the 1,877-model
seeded catalog on every launch), a few slow suites on a fresh simulator (`EquipmentLifecycleTests` 179 s once), ~1,100
tests run serially, and other runs sharing the Mac.

## Plan

1. One timed full unit run with per-test durations (xcresult) — record the slowest suites and the fixed overhead.
2. Cheap fixes: skip catalog seeding when the app only hosts unit tests (check which tests rely on it first); keep the
   test simulator booted between runs; fix or isolate the slowest suites.
3. Only with the user's OK: move pure Domain tests to run without the host app (a project change).

## Progress

Not started.

## Comments
