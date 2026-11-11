# Nutrition — Phase 2 (food, goals, body weight)

Status: **tickets approved 2026-11-07** — not started (after Phase 1). Built after Phase 1
([soft-redesign](../soft-redesign/spec.md)); both phases ship to testers together (D76).
Decisions: D69–D76 in [DECISIONS](../../docs/DECISIONS.md#november-7--soft-redesign-and-nutrition).
Design source: [ui-evolution spec](../ui-evolution/spec.md) Direction B rounds 2–5; the user's reference screens
(selected food, quick add, barcode / label / photo scanner) are local files and are never committed or sent to a model
(one contains personal photos).

## What and why

The user wants the app to be all-in-one: training and food in one place. Food logging, calculated goals and body
weight join the training log; Today shows both.

## The user's decisions (2026-11-07)

- **Scope (D69):** everything in the first release — AI meal photo, barcode, food label, plus manual entry, recent and
  saved foods. Recent/saved foods log with one tap + Undo; every AI result goes through a review screen before Log.
- **Goals (D70):** calculated from body weight, height, age, sex, activity and goal (lose / maintain / gain), protein
  set for lifting; every number editable.
- **Burned calories (D71):** shown beside the budget; the goal stays fixed (not "eat back" exercise).
- **Barcodes (D72):** Open Food Facts first, USDA FoodData Central as the fallback, through the server with a cache;
  not found → offer the label scan.
- **Labels (D73):** the AI reads a photo cropped to the label.
- **Apple Health (D74):** read and write body weight, write food totals (calories, protein, carbs, fat), read calories
  burned.
- **Limits (D75):** food-photo 30, food-label 30, food-describe 60 per person per day.
- **No "Estimated" mark (D78, 2026-11-09):** AI results stay editable, shown as plain numbers.
- **Model (D79, 2026-11-09):** every server AI flow moves to GPT-6.1 Terra, in N6.

## Data rules (apply to every ticket)

- New SwiftData models stay CloudKit-compatible (UUID ids, optional relationships, no `@Attribute(.unique)`).
- **A logged food is history:** each entry stores its own nutrition snapshot (name, serving, calories, macros, other
  facts), so editing or deleting a saved food never changes past days. Links from an entry to a saved food are
  `.nullify`; owned rows (a saved meal's items) are `.cascade`.
- Weights and serving amounts keep the entered `(value, unit)`; body weight also stores `normalizedKg` (the app's
  weight rule). Displays are plain numbers (D52).
- AI estimates are **not** marked "Estimated" (D78, the user 2026-11-09); they stay editable, and the entry keeps its
  `source` (photo / label / describe).
- Export/import (D28) carries all new data; the automatic safety copy (N1) runs before the first launch of the new
  stored format.
- Diet data, sex and age stay on the phone (and in the user's own export / iCloud backup); only the photo, label or
  description of one scan goes to the server, and it is not kept (`store: false`, as today's flows).

## Tickets

| # | Ticket | Blocked by |
|---|---|---|
| [N1](issues/01-safety-copy.md) | Automatic safety copy before a stored-format change (public-beta ticket 11) | S4 |
| [N2](issues/02-nutrition-data.md) | Nutrition data model, migration, export/import | N1 |
| [N3](issues/03-goals.md) | Goals: calculation, onboarding step, Profile → Nutrition goals | N2 |
| [N4](issues/04-manual-logging.md) | Log Food: search, recent, saved, quick add, selected food, one-tap + with Undo | N2 |
| [N5](issues/05-today-food.md) | Today's food parts: day rings in macro colours, fuel card, today's log, Log food pill | N3, N4 |
| [N6](issues/06-server-food-ai.md) | Server: food-photo, food-label, food-describe flows, limits, privacy text | N2 |
| [N7](issues/07-scan-food.md) | Scan Food camera: meal photo and food label, review screen, failure states | N4, N6 |
| [N8](issues/08-barcode-and-search.md) | Barcode and online food search through the server (Open Food Facts + USDA) | N7 |
| [N9](issues/09-body-weight-health.md) | Body weight logging and Apple Health | N2 |
| [N10](issues/10-progress-history-nutrition.md) | Progress body/nutrition metrics, History food line | N5, N9 |
| [R](issues/11-combined-release.md) | The combined release (Phase 1 + 2) to testers | all |
| [N12](issues/12-korean-food-database.md) | Korean food database (식품영양성분DB): Korean search, "Is this it?" for Korean barcodes — after R (the user, 2026-11-11) | R |

Order of work: S5 ([Today's up next](../soft-redesign/issues/05-today-up-next.md), before N1) → N1 → N2 → S6 ([Profile like the prototype](../soft-redesign/issues/06-profile-layout.md), the user 2026-11-08) → N3 → N4 → N5 → N6 → N7 → N8 → N9 → N10 → R (one ticket at a time, in this workspace), then N12 as an update after R.
