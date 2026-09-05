# Scanner accuracy

User, 2026-09-05, after the finish-graph work: "for scanning machine it sometimes feels slow and
inaccurate … It sometimes captures symbols or logos as a text and misreads the machine brand/name.
How can we make this very accurate."

## What the scanner is today (read from the code, 2026-09-05)

Live: a 1080p frame to Vision (`.accurate`, whole frame, no region of interest, no custom
vocabulary, no confidence floor) about three times a second; every reading ranked against all
1877 catalog rows on the main thread; "settled" when two consecutive readings share the same
top-ranked row, whatever its score. The still path (`MachineLabelOCR.read`) survives only behind
"Choose a photo instead". Every threshold in `CatalogMatcher` was tuned on rendered text; **the
scanner has never been measured on a photograph** (STATE has said so since milestone 3), and the
live loop was never cross-reviewed.

## Why the user sees logos-as-text and misread brands

- Nothing filters Vision's output: a logo comes back as a low-confidence token and is fed to the
  matcher like a word.
- No vocabulary: "Insignia" half-read as "lnsigna" stays that way.
- The settle rule keys on the top row regardless of score, so two half-reads while the camera is
  still moving can agree and settle.
- Many plates carry the brand only as a logo, which OCR cannot read, and D33 then (correctly)
  refuses to preselect.

## The plan, agreed with the user

1. **Corpus + harness first** (ticket 01). Photos of real name plates — online (dealer and resale
   listings, worn plates, odd angles; NOT marketing shots) for breadth across brands, and the
   user's own gym for the exam. Photos are gitignored; `manifest.json` (source URL + ground-truth
   label) and the reports are committed. The harness runs the app's own OCR and matcher over every
   photo and reports per photo: what was read, the top candidate, whether it would preselect, and
   whether that is right. **That number gates every later change.**
2. Capture-first (ticket 02): keep the live preview and torch for framing, add a one-tap shutter,
   read one still at full photo resolution inside a framing box (region of interest), once, off
   the main thread; drop the live reading loop. Retake is one tap.
3. Read quality (ticket 03): confidence floor, symbol/junk token filtering, minimum text height,
   catalog vocabulary as Vision custom words, burst voting across a few frames on the shutter tap.
4. Brand as a logo (ticket 04): a prior for manufacturers already at this gym, and a brand chip row
   on the results screen so a plate that names no brand is one tap from preselection.

"Very accurate" means: the right machine is top of the list nearly always, preselected most of the
time, and a wrong machine is never preselected. The confirm tap stays as the safety net.
