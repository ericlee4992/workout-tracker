# Codex cross-review — scanner accuracy ticket 02, round 2

Boundary: `5ffa3cc..bf77d4d` (one commit, `bf77d4d`).

Verdict: **not clear**. The rebuild closes the exact prose, singleton-furniture, listed-compound, and code-line constructions from round 1, but the name-line heuristic still permits a wrong D33 preselection, and several narrower repair defects remain.

## Standards

### Medium

1. **The new provenance calculation adds repeated allocation to the existing main-actor live-ranking hot path.** `WorkoutTracker/Domain/CatalogMatcher.swift:227,398-401`; `.scratch/scanner-accuracy/spec.md:9-12`.

   Every live reading ranks all 1,877 entries. For every entry and every OCR line, `score` now reconstructs `Set(entry.tokens)` inside the `filter` closure, even though `entry.tokens` never changes. On a six-line plate that is roughly 11,000 new set constructions per rank, about three ranks per second, on the main actor. Precompute the entry token set/provenance in the index, or compute name-line provenance only for the top candidates before preselection. The ticket is about accuracy, but this change lands directly in the scanner path the parent spec already identifies as slow.

### Low

2. **The rewrite introduced dead stored state.** `WorkoutTracker/Domain/MachineLabelRepair.swift:37-42,69-74`.

   `brandTokens` is initialized from every manufacturer and never read. It should be removed unless it is part of a concrete rule.

No documented `CLAUDE.md` convention violation was found, and `git diff --check 5ffa3cc..bf77d4d` passes.

## Spec

### High

1. **Two furniture words still forge a “name line” and disable D33's ambiguity margin; the same rule also blocks an exact longer name when its distinguishing word is alone.** `WorkoutTracker/Domain/CatalogMatcher.swift:253-286,395-401`; `WorkoutTrackerTests/CatalogMatcherAdversarialTests.swift:381-397`; response at `.scratch/scanner-accuracy/issues/02-brand-repair.md:131-135,149-152`; `docs/DECISIONS.md:41`.

   The three exact round-1 constructions are closed only because their furniture line has one token. The implementation does not establish provenance; it accepts any line containing at least two tokens from the candidate row. These shipped sibling constructions still preselect the wrong longer row:

   - Nautilus `Impact Lat Pull Down` plus a separate `FIXED PULL` line makes `Impact Fixed Lat Pull Down` top at 1.000 versus 0.932 and permits the exception.
   - Life Fitness `Insignia Series Leg Curl` plus `SEATED LEG` makes `Insignia Series Seated Leg Curl` top at 1.000 versus 0.956 and permits it.
   - Eleiko `Prestera Half Rack` plus `FITNESS RACK` makes `Prestera Fitness Half Rack` top at 1.000 versus 0.972 and permits it.

   Conversely, the exact shipped longer Life Fitness name laid out as `LIFE FITNESS / INSIGNIA SERIES / SEATED / LEG CURL` is blocked: `SEATED` is the distinguishing word but is excluded from `nameLineTokens` solely because its line contains one name token. The best and runner-up remain within 0.08, so preselection returns nil. Layout segmentation is not semantic provenance. The response's claim that the shorter-plate-plus-stray-word exposure is closed is therefore false.

### Medium

2. **Every shipped 4–6-character brand token remains manufacturable from a catalog-unknown, dictionary-rejected one-edit token on an otherwise bare line.** `WorkoutTracker/Domain/MachineLabelRepair.swift:153-195,203-209`; `WorkoutTracker/Features/Gyms/MachineLabelDictionary.swift:16-21`; `docs/DECISIONS.md:41`.

   Re-enumeration gives: `body ← B0DY`, `cybex ← CYB3X`, `eleiko ← E1EIKO`, `gym80 ← GYN80`, `hammer ← HAMNER`, `hoist ← HOISI`, `legend ← LEGEMD`, `life ← L1FE`, `matrix ← MATR1X`, `precor ← PREC0R`, `prime ← PR1ME`, `rogue ← R0GUE`, `solid ← SOL1D`, `star ← ST4R`, `titan ← T1TAN`, `trac ← TRAE`, and `watson ← WAT5ON`. Digit-bearing tokens automatically fail the dictionary test. Leading-prefix stripping supplies another dictionary-free path.

   As an OCR of a large logo, these are highly plausible intended repairs (`HOISI` is in the corpus). As unrelated prose, the new whole-line gate makes them unlikely. As a short model/serial code printed alone on a plate, however, a false collision is moderately plausible; the corpus itself contains code-only lines. Single-token makers immediately become named. A multi-word maker additionally needs its exact companion on the same line or the next unchanged line, so its false-positive risk is lower. The two-line pass can therefore join unrelated lines into a brand, but only in that exact, unique-brand shape. This is much narrower than round 1, not a proof that the plate named the maker.

3. **The rebuild deliberately drops explicit ticket behavior without amending the ticket.** `.scratch/scanner-accuracy/issues/02-brand-repair.md:18-28,37-45,128-130,136-138`; `WorkoutTracker/Domain/MachineLabelRepair.swift:198-209,231-248`; `WorkoutTrackerTests/MachineLabelRepairTests.swift:35-45,65-76,106-123`.

   The ticket requires leading *and trailing* stray-character stripping, `LAMMED → HAMMER`, `YAMMER → HAMMER`, and separatorless `DIPCHIN → dip chin`. The new tests instead assert that `LAMMED`, `YAMMER`, `CYBEXS`, and `DIPCHIN` remain unchanged. The response calls part of this cost “accepted,” but the acceptance criteria were not amended and two named corpus badges now retain a noncanonical create-new brand. The safety tradeoff may be reasonable, but the built result does not match its governing ticket.

4. **The tighter split rule still corrupts ordinary unknown names.** `WorkoutTracker/Domain/MachineLabelRepair.swift:231-248`; `WorkoutTracker/Domain/CatalogMatcher.swift:149-160`; `WorkoutTrackerTests/MachineLabelRepairTests.swift:106-127`; `docs/DECISIONS.md:43`.

   Re-enumerating ordinary dictionary words against the current shipped same-row pair set leaves two false splits: `MIDLAND → mid and` and `ROWLAND → row and`. Both pairs occur in Body-Solid's `S2LATX Series 2 Lat and Mid-Row`. The dictionary refusal is not applied to `split`, so a genuine user-space manufacturer/model name can still be altered in D35's create-new prefill. The 13 round-1 compound examples are fixed, but the class is not closed.

5. **The new consecutive-line brand pass reintroduces the punctuation/spacing loss fixed for the single-line pass.** `WorkoutTracker/Domain/MachineLabelRepair.swift:82-105`; response at `.scratch/scanner-accuracy/issues/02-brand-repair.md:141-147`.

   `repairedText` correctly splices alphanumeric runs into the original string, but the pair pass reconstructs both complete lines with `joined(separator: " ")`. For example, `HAMMER-` / `(STRENCTH)` becomes `HAMMER` / `STRENGTH`; punctuation and spacing disappear. That contradicts the response's “copies every other character through verbatim” claim and can degrade the create-new prefill.

### Low

6. **The repair commit contains unrelated next-ticket planning.** `.scratch/scanner-accuracy/issues/03-capture-first.md:1-44`; `.scratch/scanner-accuracy/spec.md:32-43`.

   Adding the complete ticket-03 draft and renumbering the roadmap is outside a round-1 repair boundary. It does not change the product, but it makes this review commit less atomic.

### Verified closures, paths, and claims

- Direct reconstruction and the focused repair/adversarial suites confirm that `MOIST CHEST PRESS RS-2301`, `PRICE FITNESS`, `START TRACK`, `RECORD`, `METRIC`, the original three one-word furniture cases, the 13 listed compound cases, and `HOISI-RS-2403` no longer trigger their round-1 failures. The vocabulary hook and its environment-name mismatch are gone.
- `MachineLabelDictionary.closure` is safe for every current caller despite erasing the actor annotation: `MachineLabelRepairTests` and `ScannerCorpusHarness` are `@MainActor`; the sheet is main-actor isolated; live OCR dispatches its callback to main at `WorkoutTracker/Features/Gyms/LiveLabelScannerView.swift:191-193`; and the still-photo `Task` inherits the sheet actor before ranking at `WorkoutTracker/Features/Gyms/ScanMachineLabelSheet.swift:362-376`. The stored plain closure remains easy for a future off-actor caller to misuse, but no current path does.
- Building the same-row name-pair set is correct and cheap for the shipped catalog: 14,273 qualifying insert attempts collapse to 8,394 unique unordered pairs during one index build. Single-token model names correctly contribute no pair because no two halves can co-occur in such a name.
- Source count is exactly 674 `@Test` declarations, including 15 `MachineLabelRepairTests`; the prefix-sibling section contains three tests. I independently ran the full `WorkoutTrackerTests` target and both `ScanMachineLabelUITests`; both `xcodebuild test` commands exited 0. The focused repair/adversarial run also passed all 35 tests.
- The fresh harness run reproduced the committed report's 41-photo totals: top-1 8/12, preselected-right 6/12, wrong preselections 0, create-new 28/29. The issue response and commit message are accurate on those measurements and test claims, subject to the behavioral overclaims above.

Summary: Standards has 2 findings; worst is Medium repeated allocation in the main-actor ranking hot path. Spec has 6 findings; worst is High because two-token plate furniture can still cause a wrong sibling preselection.
