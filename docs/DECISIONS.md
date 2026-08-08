# Decision Log

Decisions made during product discovery (2026-08-08 interview). Each entry: decision, and why. Reopening a locked decision requires both developers.

## Product

| # | Decision | Why |
|---|---|---|
| D1 | Layered history fallback: this machine → same model elsewhere → exercise, labeled | Strict machine-only starts every new machine cold; exercise-first reduces the differentiator to a tag. Fallback keeps honesty *and* usefulness. |
| D2 | Machine/gym optional on sets; remembered per gym per exercise | Free weights, home workouts, and lazy logging must work; friction kills fast logging. |
| D3 | Seed equipment models only; gyms/machines always user-created | A worldwide gym database is impossible offline and its machine inventories are unknowable. Creating a gym takes 10 seconds, once. |
| D4 | Catalog depth: major brands, popular lines (~hundreds of models) | Covers most commercial gyms; long tail via user entry; exhaustive curation is weeks of work for two people. |
| D5 | Audience: the two developers only (v1) | Cuts onboarding/dedup/polish scope. Stable IDs + export keep public release open. |
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

## Technical

| # | Decision | Why |
|---|---|---|
| T1 | SwiftData | First-party, SwiftUI-native, fits no-dependency rule. Weak migrations mitigated by simple models + denormalized snapshots. |
| T2 | CloudKit-compatible schema; ship single-device | UUIDs/optional relationships/no unique constraints cost little now; retrofitting sync later is a painful migration. |
| T3 | UI-first build order | User requirement: see and approve the screens (sample data) before logic/persistence is wired. |
| T4 | Xcode buildable folders (synchronized groups) | Adding files doesn't touch project.pbxproj — kills the main two-dev merge hazard. |
| T5 | Repo is the source of truth for spec/context | Any agent session (Claude Code or Codex, either dev) loads identical context from docs/. |
| T6 | Cross-review over double-build | Each dev's PRs reviewed by the other's agent; Codex may independently author adversarial tests for the pure-logic core against this spec. |
| T7 | Unit-default precedence: machine → gym → app preference | Most specific context wins. |

## Deferred / open

- Assisted-machine UX details beyond PR direction (belt weight? bodyweight input?) — milestone 2
- Dumbbell volume rule — milestone 2
- Export column layout / JSON schema versioning — milestone 3
- Notification permission timing (on first completed set, not launch) — milestone 2
- Seeded catalog curation workflow — parallel content task
- Post-v1: iCloud sync, duration sets/cardio, drop sets/RPE/supersets, catalog dedup, Watch/HealthKit
