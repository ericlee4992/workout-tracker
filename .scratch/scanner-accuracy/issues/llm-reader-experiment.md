# LLM-as-plate-reader experiment — result (2026-09-06)

Question (user, 2026-09-05): would attaching Claude to the scanner help — read logos, reason about
the machine? Agreed answer: measure before building. `tools/llm_reader.py` sent every corpus
photo to `claude-sonnet-5` (structured output, effort low, 1568 px, "transcribe only what
identifies the machine; do not guess a model that is not printed") and the harness ran those
transcriptions through the app's own `CatalogMatcher.rank` under `TEST_RUNNER_SCANNER_LLM=1`.
Same 41 photos, same matcher, same catalog — only the reader differs.

Reports: `reports/llm-sonnet-2026-09-06.md` (LLM) vs `reports/after-ticket-02c-2026-09-05.md`
(Vision, tickets 01–02 applied; ticket 03 does not change the still path the harness measures).

## Totals

| Metric | Vision (02c) | Claude Sonnet 5 |
|---|---|---|
| Top-1 right (of 12 in catalog) | 8 | **10** |
| Preselected right (of 12) | 5 | **6** |
| Wrong preselections | 0 | **0** |
| Create-new suggested when the row is absent (of 29) | 28 | 24 |
| Nothing read | 1 | 1 |

Cost: 119,473 input + 2,873 output tokens = **≈ $0.27 for 41 photos (≈ 0.7¢ per plate)** at
Sonnet 5 list price ($2 / $10 per MTok). ~2,900 input tokens per photo at 1568 px. Wall clock
~2–3 s per call.

## Per-row: what changed

**Gained (in catalog).**
- `h072` Wide Pulldown, placard at 45° with rotated text: Vision lost WIDE → top-1 *Iso-Lateral
  Row* 67% (wrong, not preselected). Claude read it whole → 100%, preselected.
- `q1_13` Precor Vitality Leg Extension, support-page photo with red annotations: Vision top-1
  *Life Fitness Insignia Leg Extension* 40% (wrong). Claude: right row at 58%.
- `h044` 93% → 100%; `h107` Hoist 43% → 70% (still not preselected: the plate says HACK SQUAT
  and the row is "Hack Squat/Dead Lift/Shrug RPL-5356").

**Still wrong in both, and honestly so.**
- `g094` Swedish placard BENSPARK: Claude transcribed BENSPARK, did not translate. Expected miss.
- `h108` ROC-IT sub-brand sticker: Claude gave brand "ROC-IT" — the sticker carries no HOIST text.
  Top-1 *Hammer Strength Plate Loaded Hack Squat* 70% (Vision: Nautilus 61%). Not preselected in
  either; a catalog alias (ROC-IT → Hoist) fixes this on either reader.

**Brand on the logo-only rows — the user's actual complaint.** Vision: `SCYBEX`, `OLУBЕN`,
`OCYBEX`, `LAMMED STRENGTH`, `WUH STRENCTH`, `YAMMER RENGTH`, `LiTTes / EC`, `HOS / HOIST`,
`FITNESS / EQUIPMENT / EMPIRE …` (dealer signage instead of the logo). Claude: every one of the
11 logo/badge-only rows came back as the clean brand (CYBEX ×5, HAMMER STRENGTH ×4, HOIST, Life
Fitness). Zero junk lines anywhere: no warning text, no serial prose, no URLs, no "Start 7 lbs".

**Invented model names: none.** `q1_16` stayed "TIBIA" (not expanded to Dorsi-Flexion); `q1_12`
"PLSM"; `g018`/`g035` model numbers only; `h107` listed `RPL-5356` as a line. Confidence was
`low` only on the whole-machine shot that has no readable plate, `medium` on the two blurry ones.
The `brand_from_logo_only` flag was **false on every row** — the model treats a wordmark logo as
printed text — so that flag is not a usable signal; drop it or rephrase.

**Create-new fell 28 → 24 — the matcher's doing, not the reader's.** Cleaner text scores higher
against sibling rows: `q1_03` Triceps Press → *Insignia Series Triceps Press* 66%, `q1_05` Seated
Leg Press → *Insignia Series Seated Leg Press* 69%, `h132` Dual Pulley Row → *Dual Adjustable
Pulley* 73%, `q1_15` (one word, STRENGTH) → *Technogym Pure Strength Row* 44%. The first three are
the row the manifest itself calls "nearest"; none preselects (D33's brand + margin rule holds).
The last one is the only ugly suggestion, and it is a matcher threshold question (one generic
word should not reach 44%), independent of who read the plate.

## Verdict

The reader is not the bottleneck any more once Claude reads: brand is right on every plate that
shows one, the text is clean, nothing is invented, and a wrong preselection never appears. The
remaining misses are catalog (aliases, a Swedish plate) and matcher thresholds. On identical
photos it beats Vision on every count that matters and costs under a cent a plate.

What it does NOT settle: latency and feel at the gym (a network round trip vs on-device), the key
problem (an API key cannot ship inside the app — a proxy is a prerequisite for anyone but the
developer), and D34 (recognition stays on the phone; a photo of the gym would leave it). Those are
product decisions — see ticket 05.

## Re-read with the production contract (2026-09-06, after codex-review-05)

`llm_reader.py` now mirrors `PlateTranscriptionAPI.prompt` / `.schema` exactly (no
`brand_from_logo_only`). Re-run with `SCANNER_LLM_REDO=1`: `reports/llm-sonnet-2026-09-06b.md` —
**identical totals** (top-1 10, preselected 6, wrong 0, create-new 24, nothing-read 1); the only
row differences are capitalisation and line order in the transcriptions (e.g. `HAMMER STRENGTH /
GROUND BASE COMBO INCLINE`), which the matcher normalises. 116,316 input / 2,341 output tokens,
≈ $0.26. This is the baseline any future prompt or schema change must hold.

## Environment note

`llm_reader.py` sends `Accept-Encoding: identity`: anaconda's `brotli` 1.0.9 lacks the
`output_buffer_limit` keyword the SDK's bundled `httpx2` passes, so a brotli-compressed response
died with "process() takes no keyword arguments" wrapped in `APIConnectionError`.
