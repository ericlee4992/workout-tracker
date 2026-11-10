# N4 — Log Food: search, recent, saved, quick add, selected food, one-tap + with Undo

Type: feature
Status: **approved** (the user, 2026-11-09: "S6 → N3 → N4 → N5", recorded in STATE); My meals included (N2)
Blocked by: N2
Implementer: Claude; Reviewer: Codex (visible Orca terminal), to "clear".
Branch (when built): `ericlee4992/nutrition-04-log-food` off `main`.
Spec: [nutrition](../spec.md). Decisions: D69.

## Goal

Log food by hand quickly: from recent and saved foods with one tap, or by entering a food once and reusing it.

## Scope

- **Log Food sheet:** meal chips (Breakfast / Lunch / Dinner / Snacks, defaulting by time of day); a search field over
  the user's own recent and saved foods (online search joins in N8; "Describe what you ate" joins in N7 through the
  food-describe flow); tabs All / My foods / My meals / Saved; recently logged with a **+** that logs one serving to
  the chosen day and meal, with an **Undo** toast; Scan (N7) and Manual Add entry points.
- **Selected food:** servings and measurement, calories, protein / carbs / fat, other nutrition facts (collapsed),
  Save to My foods, Log.
- **Manual Add:** name, serving, calories and macros (macros optional; the calories–macros mismatch is shown, not
  blocked). **Quick add:** calories (and optional macros) without a name.
- **Entries:** edit (servings, meal, numbers) and delete, with Undo; Today/History show the result (N5/N10).
- **My meals:** save a group of entries as a meal and log it in one tap — only if confirmed in N2.
- Not in scope: Voice Log (in the prototype, not chosen).

## Acceptance

1. One-tap + logs exactly one serving and Undo removes it (UI test); totals update.
2. Manual Add / Quick add / Selected food log the numbers entered, in the entered units (unit tests for scaling).
3. Editing a saved food leaves past entries unchanged (N2 rule; test).
4. Captures at default and AccessibilityL, light and dark; Codex clear.

## Code map

- New `Features/Food/` (Log Food, Selected food, Manual Add); `Domain/` food helpers (N2).
- Prototype: `Screens/Soft/SoftProfileAndAdd.swift` (Log food), `SoftModel.swift` (sample shapes only).

## Progress

**Structure (the user, 2026-11-10, D81):** tabs All / My foods / My meals / Saved foods; **My foods** = created by
the user via **Add food** at the bottom of that tab (two-step form like the user's reference: brand (optional),
description, serving size, servings per container (optional) → Next → calories, protein, carbs, total fat, saturated
fat, … → Save food); **Saved foods** = bookmarks from anywhere (incl. My foods); **Manual Add** (All tab) logs a
one-off entry, creates no food, name optional — **Quick Add merged into it**. Meals kept (preset by time). Wording of
the first mock approved. Data: `SavedFood` + "made by the user" + optional servings per container (additive, pre-R).

**The user (2026-11-10):** N4 adds Today's **"Log food" pill** now (N5 builds Today's food area around it); the Log
Food screens are **mocked with sample data and shown first**, then wired.

**Handoff (2026-11-10):** mock v1 at `5f36999` (pill, Log food with chips/tabs/search/recent +/Undo/My meals,
Selected food, Manual Add, Quick Add; `LogFoodUITests`; captures in the old session's scratchpad — re-run the test to
regenerate). Rework to D81 next (see STATE → Next), then show the user, then wire.

## Comments
