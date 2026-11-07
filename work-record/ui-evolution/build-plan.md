# Build plan — Soft redesign + nutrition (agreed 2026-11-07, tickets not yet written)

Status: **tickets written 2026-11-07** — [soft-redesign](../soft-redesign/spec.md) S1–S4, [nutrition](../nutrition/spec.md) N1–N9 + release R; decisions D67–D76. The original plan below is kept.

Original status: **planning.** The user approved the design ("I like the current design now, and would like to start
building") and asked to plan tickets first. **No app code yet.** Next session: turn this into ticket files
(`work-record/soft-redesign/` and `work-record/nutrition/`, one spec + `issues/NN-*.md` each, per
`docs/agents/issue-tracker.md`), record the decisions in DECISIONS (new D-numbers), then build in order.

## The approved design

The prototype at `DesignPrototype/` (branch `ericlee4992/UI_design` only — record, not in `main`; tag `design/soft-approved-2026-11-07`), look **SOFT**,
layout **A**. Its spec, round by round: `work-record/ui-evolution/spec.md` (Direction B, rounds 2–5). Launch:
`-look soft -softLayout profileTab`. Saved alternatives: tags `design/floodlight-mono-2026-11-07`,
`design/soft-2026-11-07`; Blend (`-look blend`) is in the prototype too.

## The user's answers (2026-11-07)

| Question | Answer |
|---|---|
| Tab layout | **A: Today · Train · History · Progress · Profile.** Train has Templates \| Gyms \| Exercises; settings move to Profile; the Log food pill shows on Today only; no floating + |
| First nutrition release | **Everything at once:** AI meal photo, barcode, food label (plus manual, recent, saved) |
| Goals | **Calculated, editable:** from body weight, height, age, sex, activity, goal (lose / maintain / gain), protein set for lifting; every number overridable |
| Burned calories | **Show, don't add:** shown beside the budget, the goal stays fixed |
| Recent / saved food | One-tap + with Undo (earlier answer); AI scans always go through a review screen before Log |
| Barcode database | **Open Food Facts first, USDA FoodData Central as the fallback** (US products), through the server with a cache; not found → offer the label scan |
| Food labels | **AI reads a photo cropped to the label** (a daily-limited flow; needs sign-in and internet) |
| Apple Health | **All four:** read body weight, write body weight, write food totals (calories, protein, carbs, fat), read calories burned (shown, not added) |
| Daily AI limits | **food-photo 30, food-label 30, food-describe 60** per person per day (re-measure the real cost before release) |
| Parallel workspaces | **No:** one workspace, Phase 1 then Phase 2 (asked and decided 2026-11-07) |
| Release | **Phases 1 and 2 ship to testers together** — no interim tester build, and no Developer-only phone build after Phase 1 |
| Merging | **Each ticket merges into `main`** when clear (the usual flow), so `main` carries unreleased work until the release; an urgent tester fix branches from build 9's commit `5ab7a16` |
| Prototype | **Record only:** `DesignPrototype/` never merges to `main`; ticket work starts on branches off `main` |
| Today before nutrition | Moot (one release): Today's training parts are built in Phase 1, its food parts in Phase 2 |

## Facts that constrain the order

- Nutrition adds SwiftData models (food entries, saved foods, goals, body weight) → the first **stored-format change**
  since ticket 11 was deferred: the **automatic safety copy (public-beta ticket 11)** ships with or before it.
  Follow DEVELOPMENT's migration, backup and Gate S rules; CloudKit-compatible models (UUIDs, optional
  relationships, no unique); export/import (D28) must include the new data.
- The AI path exists: the Worker (`server/src/ai.ts`, model `gpt-5.6-terra`, `store: false`) with sign-in, daily
  limits per flow (`DAILY_LIMITS`: scan-machine 60, routine-week 10, model-exercises 60), images sent inline and not
  kept. Food photo / label / describe become new flows with their own limits.
- Privacy (D61): the policy at `/privacy` and the App Store privacy answers need updating for food photos and diet
  data before testers get the release (the user approves wording, as in ticket 08).
- New screens follow the approved Soft look; the live set table keeps its layout (skin only).

## Proposed tickets and order (to confirm and write up next session)

**Phase 1 — look and navigation (no stored-data change; can ship as its own build)**
1. Soft look app-wide (tokens: SF Pro, Soft colours, white cards + soft shadow in light / graphite + hairline in
   dark, Mono action, flat buttons); live set table skinned only.
2. Tabs (layout A): Today · Train · History · Progress · Profile; Train's Templates | Gyms | Exercises; History as a
   tab; settings into Profile. (Today ships its training parts here, nutrition parts in Phase 2 — or Today waits for
   Phase 2: decide.)
3. Workout refinements from the Mono round: next template leads Train, finish screen (new bests first + receipt
   summary), cardio Pause | End, Delete Template in "…", template machine line de-duplicated.
4. History journal + Progress with pin-anything (training metrics first; food / weight metrics join in Phase 2).

**Phase 2 — nutrition (everything at once, per the user)**
5. Safety copy (ticket 11) + nutrition data model + migration + export/import.
6. Goals setup (calculated, editable) — onboarding step and Profile → Nutrition goals.
7. Manual logging: Log Food (search/describe field, recent, saved, meals), "Selected food" (servings, measurement,
   calories, P/C/F, other nutrition facts), one-tap + with Undo, edit/delete entries.
8. Today: week day rings (calories in macro colours, workout mark), fuel card, Today's log, Log food pill.
9. Server flows: `food-photo` (items with name, portion, grams, calories, P/C/F, confidence), `food-label`
   (nutrition-facts reading), `food-describe` (text → items); limits; privacy policy + App Privacy update.
10. Scan Food in the app: camera with Scan food | Barcode | Food label modes, photo consent, review screen (edit
    items/portions, "Estimated"), failure states (no camera, not recognized, limit, offline).
11. Barcode: on-device barcode reading (VisionKit / AVFoundation) + food database lookup via the server (cache).
12. Body weight logging + Apple Health (read/write weight; maybe write dietary energy/macros) + Progress charts
    (weight, trend, calories, protein, macros) + History food line.

## Open questions for the next session — answered 2026-11-07 (see the table above; kept for the reasoning)

- **Food database for barcodes:** Open Food Facts (free, crowd-sourced, ODbL attribution, international incl.
  Korea, variable quality) vs USDA FoodData Central branded foods (free, public domain, US only) vs a paid API
  (Nutritionix / Edamam / FatSecret: keys on the server, cost). Recommendation to discuss: Open Food Facts through
  the server with a cache; not found → offer the label scan.
- **Food label reading:** send the label photo to AI (robust, multilingual, costs a scan) vs on-device text
  recognition + a parser (free, offline, weaker on unusual labels). Recommendation: AI, cropped to the label, like
  D53's label crop.
- **Today in Phase 1:** ship Today with training only first, or keep the Workout tab as home until nutrition lands.
- **Apple Health:** write food (dietary energy, protein, carbs, fat) to Health? Read body weight?
- **Daily limits** for food photo / label / describe and the per-scan cost check (as ticket 10 measured for Sol).
- **Per-day macros on past days** (the prototype fakes a split): the model stores per-entry macros, so rings are real.
- Whether the prototype branch stays a record (like `redesign-prototype`) or merges to `main` (it is a separate
  Xcode project under `DesignPrototype/`; the app is untouched).

## Reference screenshots

The user's references (calorie tracker): `~/Downloads/IMG_5745…5756.PNG` and `IMG_5759…5763.PNG` (selected food,
quick add, barcode / label / photo scanner). **IMG_5751 contains the user's personal photos — never send it to a
model or commit it.** The brief for the design proposals: scratchpad (not kept); proposals in `proposals/`.
