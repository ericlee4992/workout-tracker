# Codex cross-review — scanner accuracy ticket 02

Boundary: `419a04a...5ffa3cc` (`197ba91`, `5ffa3cc`).

Verdict: **not clear**. The corpus improved, but this change opens two unmeasured paths to D33's forbidden outcome: inventing a manufacturer from ordinary plate text, and preselecting a longer sibling because an unrelated line happens to contain its distinguishing word.

## Spec

### Critical

1. **Brand repair manufactures manufacturers from ordinary plate words, then the matcher trusts them as exact.** `WorkoutTracker/Domain/MachineLabelRepair.swift:103-106,114-134`; `WorkoutTracker/Domain/CatalogMatcher.swift:190,206,345-369`; `docs/DECISIONS.md:41`.

   D33 requires that the plate name the row's manufacturer. This code changes an unknown word into a manufacturer token before `manufacturersNamed` and `manufacturerMatched`, with no indication that the token was inferred. The shipped 4–6-character manufacturer tokens are:

   - `body` — one edit from plausible `bony`;
   - `cybex` — no plausible one-edit English collision found;
   - `eleiko` — none found;
   - `gym80` — none found;
   - `hammer` — `hamper`, `hummer` (`jammer` is catalog-known and therefore refused);
   - `hoist` — `moist`, `joist`, `host`;
   - `legend` — none plausible at one edit;
   - `life` — `line`, `live`, `like`, `wife` (`lift` is catalog-known and refused);
   - `matrix` — none plausible at one edit, but six-character tokens allow two: `metric -> matrix`;
   - `precor` — none plausible at one edit, but `record` and `precut` are allowed at distance two;
   - `prime` — `price`, `pride`, `crime`, `grime`, `prize`;
   - `rogue` — `vogue` (`rouge` is distance two and correctly falls outside this five-character token's limit);
   - `solid` — `sold`, `slid`;
   - `star` — `start`, `stay`, `stair`;
   - `titan` — none plausible at one edit;
   - `trac` — `track`, `trace`, `tract`, `tram` (`trap` is catalog-known and refused);
   - `watson` — none plausible at one edit.

   All listed collision inputs are absent from the shipped catalog vocabulary, so the `isKnown` refusal does not protect them. The special strip is worse than the edit band for legitimate extensions: `START -> star`, `HAMMERS -> hammer`, and `HOISTS -> hoist`. Ordinary `START TRACK` becomes the complete **Star Trac** manufacturer; `PRICE FITNESS` becomes **PRIME Fitness**; `FITNESS LINE` can name **Life Fitness** because token order is ignored; and single words `MOIST`, `METRIC`, and `RECORD` become **Hoist**, **Matrix**, and **Precor**. A repaired `MOIST CHEST PRESS RS-2301`, for example, scores the real Hoist row 1.00 with its runner-up at 0.635, so it is preselected even though the plate never said Hoist.

   `WorkoutTrackerTests/MachineLabelRepairTests.swift:95-108` is strong only for the seeded vocabulary: every seeded token short-circuits at `isKnown`. It proves no catalog token changes; it proves nothing about plate prose, model codes, or genuine user-space names, which are the dangerous population. Add adversarial common-word/plate-furniture tests before treating repaired brand tokens as manufacturer evidence. The ticket's claim at `work-record/scanner-accuracy/issues/02-brand-repair.md:100-102` that what remains "is not a brand problem" is false.

### High

2. **The prefix-sibling exception lets plate furniture disable D33's 0.08 margin.** `WorkoutTracker/Domain/CatalogMatcher.swift:195-206,232-263,314-369`; representative rows at `WorkoutTracker/Resources/SeedCatalog.json:119-120,460-461,617-618,1388-1390`.

   `exactlyCovered` means only that every unique name token occurs somewhere in `allTokens`. It does not require the token to come from the model-name line, to be contiguous with the other name tokens, or even to survive the junk-line filter. Therefore a plate for the shorter row can acquire the longer row's distinguishing token from an instruction, feature badge, URL, or neighboring text; the longer row becomes top, `exactlyCovered` becomes true, and `isPrefixSibling` suppresses the ambiguity margin.

   Concrete wrong-preselection constructions from shipped rows:

   - Nautilus `Impact Lat Pull Down` plus furniture word `FIXED` ranks `Impact Fixed Lat Pull Down` 1.000 vs 0.932 and preselects the wrong UUID.
   - Life Fitness `Insignia Series Leg Curl` plus an instruction containing `SEATED` ranks `Insignia Series Seated Leg Curl` 1.000 vs 0.956 and preselects it.
   - Eleiko `Prestera Half Rack` plus generic `FITNESS` ranks `Prestera Fitness Half Rack` 1.000 vs 0.972 and preselects it.
   - The same exposure exists for distinguishing tokens such as `pro`, `prone`, `standing`, `high`, `low`, `linear`, `double`, `twin`, `lite`, `animal`, `combo`, and `mts`.

   Full SeedCatalog enumeration found 142 directed same-maker strict-subset relationships. Of those, 130 pass the implementation's `>= 3` structural rule: Life Fitness 28, Hammer Strength 25, Watson 36, Nautilus 11, Technogym 9, Rogue Fitness 9, Eleiko 4, PRIME Fitness 4, Precor 2, and Sorinex 2. With an exact reading of each longer row, 62 actually put that subset sibling second inside 0.08 and execute this exception. This is not a narrow Low Row carve-out.

   Exact accounting itself is otherwise as advertised: the exact pass runs before fuzzy matching, each unique entry token is consumed once, and fuzzy contributions do not increment `exactNameTokens`. Same-manufacturer display-string equality is conservative. The missing condition is provenance: a distinguishing token must be established as part of the model name, not merely present anywhere on the plate.

3. **Separatorless glue repair corrupts hundreds of legitimate whole words and therefore D35's create-new prefill.** `WorkoutTracker/Domain/MachineLabelRepair.swift:103-107,159-177`; `WorkoutTracker/Features/Gyms/ScanMachineLabelSheet.swift:383-396`; `docs/DECISIONS.md:43`.

   `split` does enumerate every cut and requires exactly one candidate; it is not first-found. That ambiguity rule is still far too weak. Against the shipped vocabulary, 350 ordinary `/usr/share/dict/words` entries that are not catalog tokens have exactly one accepted cut, including `AIRLIFT -> air lift`, `ARMCHAIR -> arm chair`, `BACKGROUND -> back ground`, `COUNTERWEIGHT -> counter weight`, `CROSSBAR -> cross bar`, `FACEPLATE -> face plate`, `HANDGRIP -> hand grip`, `LIGHTWEIGHT -> light weight`, `OVERRIDE -> over ride`, `PROFIT -> pro fit`, `TRIPOD -> tri pod`, and `WITHSTAND -> with stand`. These are especially plausible equipment/model/prose words.

   The real-vocabulary invariant does not cover genuine new model names, and the synthetic test at `WorkoutTrackerTests/MachineLabelRepairTests.swift:69-77` does not exercise compound English words. This repair can alter both ranking evidence and the editable-but-incorrect D35 prefill. Restrict separatorless splitting to measured confusions or preserve the original token as uncertain evidence; catalog membership plus one cut is not a safety condition.

### Medium

4. **The failed vocabulary experiment remains as an unsafe process-global race, and its documented switch does not work.** `WorkoutTracker/Features/Gyms/MachineLabelOCR.swift:60-83`; `WorkoutTrackerTests/ScannerCorpusHarness.swift:80-88`; `work-record/scanner-accuracy/issues/02-brand-repair.md:64-72`.

   The ticket says to keep vocabulary only if the corpus supports it; the corpus showed no gain, but production code retains `nonisolated(unsafe) static var vocabulary`. The harness mutates that variable while OCR reads it inside `Task.detached`; Swift Testing can run other OCR tests concurrently, so those tests can nondeterministically see language correction enabled. `nonisolated(unsafe)` suppresses the compiler's protection without making the access safe. Pass immutable per-call configuration if this experiment must remain, or remove the hook.

   The comment and ticket prescribe `TEST_RUNNER_SCANNER_VOCAB=1`, but the implementation reads `SCANNER_VOCAB` at `ScannerCorpusHarness.swift:83`. The documented command therefore runs the normal path while claiming to run the vocabulary experiment. Grep confirms the app never assigns the hook and its default is nil; that does not cure the test race or the dead experiment flag.

5. **The 5ffa3cc "only repaired words" correction still rewrites punctuation and whitespace outside the repaired token.** `WorkoutTracker/Domain/MachineLabelRepair.swift:74-98`; `WorkoutTrackerTests/MachineLabelRepairTests.swift:81-91`; `work-record/scanner-accuracy/issues/02-brand-repair.md:104-110`.

   `repairedText` splits the entire line on whitespace and rejoins it with single spaces. Thus even a line with no repaired token loses repeated spaces/tabs. If one whitespace-delimited word contains punctuation and any contained token repairs, the entire word is reconstructed from normalized tokens: `HOISI-RS-2403` becomes `HOIST RS 2403`; parentheses, slashes, and hyphens disappear. The added test checks punctuation only in an untouched word (`Iso-Lateral`) and misses the failing case.

   Multi-token expansion does preserve the containing `LabelReading.Line`'s confidence and `heightFraction`, so model-name line selection by height is unchanged. The defect is the false preservation claim and degraded create-new spelling.

### Low

6. **The resolution's final test counts are stale.** `work-record/scanner-accuracy/issues/02-brand-repair.md:94-96`; `WorkoutTrackerTests/MachineLabelRepairTests.swift:24-133`.

   `197ba91` had 11 repair tests and 669 unit `@Test` declarations. `5ffa3cc` added `untouchedWordsKeepTheirCaseAndPunctuation`, so the reviewed tip has 12 repair tests and 670 unit `@Test` declarations. The historical 197ba91 count may be true, but the resolution is not a true tip summary. A focused run passed all 12 repair tests. The first commit's false "UI green" assertion is candidly corrected, and a fresh run of both `ScanMachineLabelUITests` passed with `** TEST SUCCEEDED **`, including `testCreateNewFromAScanPrefillsTheModelSheet`.

### Verified paths and records

- `WorkoutTracker/Features/Gyms/ScanMachineLabelSheet.swift:158-169,322-339,362-399`: live settle, still-photo fallback, and fixture all reach `present`; results retain the raw reading while guesses use the repaired reading. `consider` derives its key from repaired ranking and still gives the stabilizer a raw reading, so the stabilizer contract is unchanged.
- `WorkoutTrackerTests/ScannerCorpusHarness.swift:61-74`: absent photos return before OCR/index setup and do not write a report; the harness does print one informational line, so "silently" is not literal.
- `work-record/scanner-accuracy/reports/baseline-2026-09-05.md:3-11`, `after-repair-2026-09-05.md:3-11`, and `after-ticket-02-2026-09-05.md:3-11` agree with the ticket: top-1 7/12 throughout, preselected-right 3 -> 5 -> 6, wrong preselection 0, create-new 28/29.

## Standards

### Medium

1. **Possible Speculative Generality and an actual concurrency hazard:** the no-gain experiment leaves a mutable test hook in the production binary. `WorkoutTracker/Features/Gyms/MachineLabelOCR.swift:60-83`; `WorkoutTrackerTests/ScannerCorpusHarness.swift:83-88`. This is the same unsafe global described in Spec finding 4. It has no supported product use and is not isolated across parallel tests.

### Low

2. **Dead state obscures the repair model.** `WorkoutTracker/Domain/MachineLabelRepair.swift:26-38,47-59`. `Brand.name` is never read, stored `brands` is never read after initialization, and `Brand: Equatable` is never compared. Remove the field, property, and conformance.

No documented `CLAUDE.md` convention violation was found: pure logic stays in `Domain`, Vision/UIKit stay in `Features/Gyms`, no dependency or project-file edit was made, and `git diff --check 419a04a...5ffa3cc` passes.

Summary: Spec has 6 findings; worst is the D33-violating manufacture of false brands. Standards has 2 findings; worst is the unsafe speculative global vocabulary hook.
