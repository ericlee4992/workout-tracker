# Decision Log

Decisions made during product discovery (2026-08-08 interview). Each entry: decision, and why. Locked decisions are reopened deliberately, not drifted away from — an agent that finds one inconvenient should surface the conflict, not silently work around it.

## Product

| # | Decision | Why |
|---|---|---|
| D1 | Layered history fallback: this machine → same model elsewhere → exercise, labeled | Strict machine-only starts every new machine cold; exercise-first reduces the differentiator to a tag. Fallback keeps honesty *and* usefulness. |
| D2 | Machine/gym optional; remembered per gym per exercise. (Refined by D19: equipment context lives on the entry, not per set) | Free weights, home workouts, and lazy logging must work; friction kills fast logging. |
| D3 | Seed equipment models only; gyms/machines always user-created | A worldwide gym database is impossible offline and its machine inventories are unknowable. Creating a gym takes 10 seconds, once. |
| D4 | Catalog depth: major brands, popular lines (~hundreds of models) | Covers most commercial gyms; long tail via user entry; exhaustive curation is weeks of work for two people. |
| D5 | Audience: the developer alone (v1) | Cuts onboarding/dedup/polish scope. Stable IDs + export keep public release open. (Amended 2026-08-08: project is solo, not two-person.) |
| D6 | Templates are generic; resolved to last-used machine per gym at workout start | One "Push Day" works at every gym; gym-pinned templates break when traveling. |
| D7 | Models map to exercises; free weights are equipment tags, not machines | Machine pick auto-fills exercise (speed); multi-exercise stations prompt; barbells aren't machines. |
| D8 | PRs: per-rep-count bests + est. 1RM at machine/model/exercise layers | Heaviest-set-only is meaningless for machine training; mirrors the fallback layers. |
| D9 | Mixed units display as entered + marked convert toggle | Converting silently (90.7 kg for a 200 lb entry) is exactly the falseness the app rejects. |
| D10 | Log-time context snapshots; archive instead of delete; model corrections prompt past-vs-future | History must survive renames, re-modeling, and deletions without silently changing meaning. |
| D11 | Prefill from same-machine history only | Prefilling another machine's numbers would assert cross-machine comparability we reject. |
| D12 | Set types: warmup/working/failure; warmups excluded from PRs/volume | The minimal set that keeps records honest. Drop sets/RPE/supersets deferred. |
| D13 | Rest timer: auto-start on completion, per-exercise durations (warmup vs. working split), notification | Strong-standard behavior; the split is a verified Strong nicety worth matching. |
| D14 | Load types: weighted / bodyweight / bodyweightPlus / assisted, direction-aware | Assisted machines invert "better" (less assistance wins); naive weight×reps produces wrong PRs. |
| D15 | Strength-only v1 (no duration/distance sets) | Single set shape is the biggest scope containment available. |
| D16 | v1 extras all in scope but sequenced: export → charts → Strong import → plate calc | Everything ships in v1, but a gym-usable build exists early (dogfooding from milestone 2). |
| D17 | e1RM: Brzycki, 12-rep record cap | Strong parity (verified from their docs); estimates degrade past 12 reps. |
| D18 | Adopt Strong's template-drift prompt (update/values-only/both/keep) | Elegant, proven solution to template drift. |
| D19 | Equipment context lives on ExerciseEntry and freezes once the entry's first set completes — permanently, even if that completion is later undone. Switching equipment starts a new entry; uncompleted draft rows move to it, completed sets stay | Prevents completed sets being silently relabeled; keeps snapshots, prefill, and machine PRs historically honest (2026-08-08 Codex cross-review, finding 2). |
| D20 | e1RM is computed for `weighted` exercises only. Assisted records = least assistance per rep count; bodyweight+added = most added weight per rep count (athlete bodyweight intentionally ignored); plain bodyweight = most reps, uncapped. The D17 12-rep cap applies only to weight-keyed rep-count tables | Brzycki is mathematically invalid on inverted (assisted) or offset (bodyweight) loads (review finding 5). |
| D21 | Volume = Σ(normalizedKg × reps) over completed working+failure sets of `weighted` exercises. Dumbbells are logged as labeled (per hand) and never auto-doubled. Assisted/bodyweight excluded from volume in v1 | One consistent honest rule; resolves the deferred dumbbell question; avoids Strong's per-platform divergence (finding 14). |
| D22 | Rest-duration precedence: per-exercise override → global defaults (2:00 working / 1:00 warmup). Failure sets use the working duration. TemplateItem carries no rest duration in v1 | Single storage owner; documents the warmup default explicitly (finding 16). |
| D23 | Context snapshots store stable UUIDs (exercise, machine, model, gym), the exercise's **loadType**, and the **freeWeightTag**, alongside display strings; historical queries (prefill, layers, records) group by snapshot values, never live relationships | A "future-only" model correction or a catalog loadType edit must not reinterpret old sets (findings 3; pass-2 criticals 2–3). |
| D24 | Catalog seeding is versioned, idempotent reconciliation keyed by fixed catalog UUIDs. Mutable seeded fields are allowlisted (name, exercise links, metadata); seeded rows are not user-editable — only user-created models/exercises can be renamed | First-launch-only seeding would strand installs; unrestricted edits would fight reconciliation (finding 9; pass-2 important 8). |
| D25 | Unit conversion uses exactly 1 lb = 0.45359237 kg; `normalizedKg` recomputes atomically on any value/unit edit; storage keeps full precision. Display: up to 2 decimals, trailing zeros trimmed, half-up rounding, locale-independent decimal point in storage; converted values prefixed ≈ | Executable contract so normalized values can never drift from as-entered values (finding 12). |

## Technical

| # | Decision | Why |
|---|---|---|
| T1 | SwiftData | First-party, SwiftUI-native, fits no-dependency rule. Weak migrations mitigated by simple models + denormalized snapshots. |
| T2 | CloudKit-compatible schema; ship single-device | UUIDs/optional relationships/no unique constraints cost little now; retrofitting sync later is a painful migration. |
| T3 | UI-first build order | User requirement: see and approve the screens (sample data) before logic/persistence is wired. |
| T4 | Xcode buildable folders (synchronized groups) | Adding files doesn't touch project.pbxproj — no merge hazard, and agents can add source files without editing project config. |
| T5 | Repo is the source of truth for spec/context | Any agent session (Claude Code or Codex, either dev) loads identical context from docs/. |
| T6 | Cross-review over double-build | Work is reviewed by a **different agent than the one that wrote it** (Claude ↔ Codex), against the tickets and this decision log. Solo development means this is the only independent check that exists — it is not optional ceremony. Proven 2026-08-08: a Codex review of Codex-written code plus a Claude review of it caught 9 real defects, 3 of which broke the product's historical-honesty thesis. Codex may also independently author adversarial tests for the pure-logic core against the spec. |
| T7 | Unit-default precedence: machine → gym → app preference | Most specific context wins. |

## Deferred / open

- Assisted-machine UX details beyond records direction (belt weight entry? bodyweight input?) — milestone 2
- Export column layout / JSON schema versioning — milestone 3
- Notification permission timing (on first completed set, not launch) — milestone 2
- Seeded catalog curation workflow — parallel content task
- Post-v1: iCloud sync, duration sets/cardio, drop sets/RPE/supersets, catalog dedup, Watch/HealthKit

## Reviews

- 2026-08-08 — Independent Codex cross-review of SPEC + milestone-2 tickets: `.scratch/milestone-2-core-loop/codex-review.md`. Produced D19–D25 and the milestone-2 ticket rewrite.
- 2026-08-08 — Codex pass 2 (`codex-review-2.md`): 12/24 resolved, 12 partial; 3 new criticals (snapshot loadType + free-weight tag) folded into D19–D25 amendments and ticket edits. Known accepted risk: tickets 02/07/15 are deliberately larger than one session (executed with WIP commits) to avoid renumbering churn.
