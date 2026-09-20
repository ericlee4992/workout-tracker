# Claude final independent review — AI gym recognition and weekly routines

Reviewed: feature tip **2daaa2b** (`ericlee4992/ai-gym-and-routines`; product code through
**e35f80e**) on new review branch `ericlee4992/review-ai-gym-final`. Earlier reports and branches
are preserved ([spec](claude-spec-review.md), [round 1](claude-code-review.md),
[round 2](claude-code-review-round2.md)). I read STATE, ticket 05, D56–D58, the product/test delta
since my code-clear at 3f75187, the evidence directory in the feature checkout, and all 51 PNGs
under `screenshots/`. I ran **no build, simulator or test job** and changed no source; I did read
exit files, log TEST lines and `xcresulttool` summaries directly.

## Verdict

| Area | Verdict |
|---|---|
| Code (delta 3f75187 → e35f80e) | **CLEAR** — no blocking finding |
| Test/build evidence | **CLEAR** — every claimed count matches the artifacts; one scope note (E1) |
| UI captures | **CLEAR for private trial** — required states present at Default and AccessibilityL; named polish items U1–U5 and capture gaps G1–G2 are non-blocking |
| **Private-trial merge to `main`** | **CLEARED** (ff-only, per AGENTS). Recommended, not required, first: U1, U2, C1 |
| Phone install | **NOT cleared** — outside this review until the user confirms the installed build opens with history intact and a fresh backup exists; signing expires 2026-09-24 07:16 UTC |
| Recognition accuracy / public release | **Not claimed, not cleared** — g010 whole-machine miss stays a documented private-trial limitation; a backend is still a prerequisite for any other user |

## Code delta since 3f75187 — checked

- **Movement-only titles** (`EquipmentIdentification.swift:62-91`): guard runs inside the shared
  resolver, so proposal display and Add agree; digits bypass it, branded series survive (tests for
  "Insignia Series Chest Press", "Hack Squat RPL-5356", "Plate Loaded Chest Press"). Errs only
  toward model-less, which is the history-safe direction. See C2.
- **AI template start at its original gym** (`WorkoutTemplates.swift:160-170`): remembered machine
  if compatible, else the sole compatible active machine, else none; two candidates → unassigned.
  Test covers unique / ambiguous / remembered. Other templates and other gyms keep D6 unchanged.
  See C1.
- **Hand-edited label provenance**: `labelWasEdited` is excluded from `CodingKeys` (a model reply
  cannot set it; test asserts both directions) and clears `modelDerivedLabel` so D3's catalog
  default cannot overwrite it (`GymsView.swift:622-626`). Red repro `edited-label-red2` (exit 65)
  and green `label-ui` both exist.
- **Wrapping fields + keyboard Done**, camera-teardown guard, unknown cardio rows keep positions
  (`PlannedCardio.swift:37-48`, test), Add keeps confirmed links when the chosen user-space model
  has no links (`GymsView.swift:730`, consistent with `supportedExerciseIDs`). Fixture-only
  additions are gated by `TerraAccess.fixture` (requires `-uiTestReset`). No new behaviour beyond
  the listed fixes; no schema change in the delta.

### Code notes (non-blocking)

- **C1 (Low–Medium, recommend before merge, one line).** At the original gym a remembered machine
  that is *not* link-compatible (e.g. a model-less machine the user logged this exercise on through
  the full picker) is discarded, and a different sole-compatible machine is assigned instead.
  D58's wording permits it, but it overrides the user's actual last-used machine (D6) with an
  inference. Safer order: `remembered ?? soleCompatible`. The machine is visible on the entry card
  and prefill stays machine-scoped, so no history is corrupted — hence not a blocker.
- **C2 (Low, document).** By my offline replica of the guard, **38 of 1877** seeded models have
  movement-only names (e.g. Life Fitness "Plate Loaded Row", "Back Extension"); the AI path can no
  longer resolve these to the catalog and saves them model-less. They remain reachable through
  "Read label on device" and manual selection. Add one sentence to D56.
- **C3 (Low).** Round-2 lows L2–L5 remain accepted in ticket 05; no change.

## Evidence — read from artifacts, not from the summary

| Run | Exit file | Log TEST line | xcresult summary |
|---|---|---|---|
| `final-domain` | 0 | 773 tests / 83 suites passed, TEST SUCCEEDED | 773 / 773 / 0 failed / 0 skipped |
| `final-targeted` (AIGymTests + WorkoutTemplateTests) | 0 | 29 passed | 29 / 29 / 0 / 0 |
| `label-units` | 0 | 23 passed | 23 / 23 / 0 / 0 |
| `preservation-units` | 0 | 23 passed | 23 / 23 / 0 / 0 |
| `integration-ui-v2` | 65 | 24 run, 1 failure | 23 / 24; failure = ambiguous "Cancel" selector in `testManualModelSuggestions…` (test-only) |
| `ai-final` | 65 | 20 run, 2 failures | 18 / 20; `testAmbiguousIdentityAccessibility`, `testNewModelIdentityAccessibility` |
| `ai-corrected2` | 0 | 4 run, 0 failures | 4 / 4 |
| `label-ui` | 0 | 5 run, 0 failures | 5 / 5 |
| `review-captures` | 0 | 4 run, 0 failures | 4 / 4 |
| `device-build`, `device-final` | 0, 0 | BUILD SUCCEEDED | — |

`ui-coverage.json` lists 36 distinct passing cases; the three earlier failures each have a later
passing run (manual-consent case in `ai-final`; the two AXL identity cases in `ai-corrected2`), and
both failures were test-harness causes, not product defects. `device-verification.json`: signature
verified, binary fresh, both profiles expire 2026-09-24, `installed: false`. `GymsView.swift` mtime
equals the `device-final` log start and the log compiles it, so the e35f80e line is in that build.
No key-shaped string in the reviewed diff.

- **E1 (scope note, accepted).** The full 773-test domain run predates four later product commits
  (8235781, affa748, 14b8c5f, e35f80e). Those were covered by targeted runs of the suites that own
  the changed code, which fits DEVELOPMENT's verification-scope policy; e35f80e (one View line on
  Add) has compile evidence only — no test can reach it without a user-space link-less model
  fixture. CI will run the full unit suite after merge; treat a red CI as a merge regression.

## UI — all 51 PNGs inspected

Present at Default **and** AccessibilityL: Start screen with secondary Ask AI below Templates
(amber starts unchanged); photo consent (top and action); proposal generic / catalog match /
new model / ambiguous (top and action) / uncertain; Settings overview, three permissions, key;
routine goals, equipment, cardio; week preview; day editor (strength and cardio); template detail
with rest caption and planned cardio; template editor (generated rest, existing-template rest
default, cardio targets); active workout planned-cardio Start row with generated "Target:" caption;
existing-template logging **without** a Target caption. Long model text wraps at AXL with no
truncation; resolution footers state the outcome plainly; disabled "Use this equipment" in the
uncertain state; consent copy names people/screens in frame and the exercise catalog.

Non-blocking findings:
- **U1 (Low–Medium).** Proposal fields show bare values ("Chest press / Life Fitness / Insignia
  Series Chest Press") with no visible labels once filled — name, manufacturer and model are
  indistinguishable, and these fields decide whether a catalog model is created. Use labelled rows.
- **U2 (Low).** Week preview reads "1 exercises" — pluralise.
- **U3 (Low).** Active-workout "Planned cardio" renders as a full-width flat band above the
  heart-rate banner with a plain-text "Start", unlike the surrounding rounded cards and buttons.
- **U4 (Low).** "Allow photos and continue" has the same weight as the policy link beside it; the
  consenting action deserves the button treatment "Use this equipment" already has.
- **U5 (Low, largely pre-existing).** Default-size template editor rows are tightly stacked; at
  AXL the pinned Start pill sits directly against "Delete Template…".

Named capture/evidence gaps (exact states, no blanket rerun needed):
- **G1.** Template detail at a *different* gym: "Created for another gym…" notice and the per-item
  "No matching machine at this gym" caption — no capture and no UI/unit assertion.
- **G2.** "Some cardio targets are unavailable in this version" (detail, editor with Save disabled,
  active workout) — unit-tested storage only; no capture.
Both are rarely reached and fail safe (notice text only), so they do not hold the trial merge;
record them in ticket 05 or deferred-work.

## Conditions carried with the clearance

Merge with `git merge --ff-only`, push, confirm the remote tip, and watch post-merge CI (E1).
Record C2 in D56 and G1–G2/U1–U5 in ticket 05 or `deferred-work.md`. Do not install on the phone
until history confirmation and a fresh backup are done per DEVELOPMENT; re-sign if past Sep 24.
If C1/U1/U2 are fixed before merging, a targeted re-review of those lines is sufficient.
