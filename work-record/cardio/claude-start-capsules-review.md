# Claude review — cardio ticket 04, restore Start capsules (code + visual pass)

Independent review per T6. Reviewer: Claude. Author/merger: parent session. Review only —
no product edits, no simulator runs by the reviewer.

- Range: `62f9469..5c51f69` (branch `ericlee4992/restore-start-capsules`)
- Inputs: [ticket 04](issues/04-restore-start-capsules.md), D54 amendment (2026-09-19),
  `work-record/cardio/spec.md` correction, ios-design skill, the pre-ticket-03 source
  (`3020180^`) as the definition of "original".
- Evidence read directly (not from a summary): `build-exit.txt` = 0; `focused-exit.txt` = 0;
  `focused.log` shows `Executed 2 tests, with 0 failures` and `** TEST SUCCEEDED **`
  (`testCardioStartChoicesDefault`, `testCardioStartChoicesAccessibility`). I also opened the
  two resulting PNGs in the implementation worktree
  (`work-record/cardio/screenshots/start-capsules/`) first to check a width calculation, then as the
  parent-delivered paired captures for the visual verdict below.

## Verdict: code CLEAR; visual CLEAR conditional on F1; merge NOT yet cleared

No correctness, behaviour or sibling regressions. Finding F1 is not a code defect but it is a
visible departure from "the original design", so it should be shown to the user explicitly
rather than passed silently. Full UI suite (81) is still pending and remains a merge gate.

## What was verified

1. **Restoration is faithful in code.** The Lifting call is identical to `3020180^`
   (title, `figure.strengthtraining.traditional`, `arrow.up.right`, `live: false`, `.plain`
   style, `.sensoryFeedback(.workoutStart…)`, identifier `startEmptyWorkout`) plus
   `fillsWidth: true`. Cardio is the same call with `figure.run`; identifier `startCardio`
   and `showingCardioPicker` → `CardioActivityPicker` → `WorkoutStartRequest(cardioActivity:)`
   are untouched. No model, schema, recording or export change in the range.
2. **Resume and template detail are unaffected.** `HeroCapsuleLabel` has exactly four
   callers; Resume (`StartWorkoutView.swift:149`) and template Start
   (`TemplateDetailView.swift:84`) do not pass `fillsWidth`. With the default `false`:
   `.fixedSize(horizontal: false, vertical: false)` is a no-op and
   `.frame(maxWidth: nil, minHeight: 56)` equals the old `.frame(minHeight: 56)`. They still
   hug their content. The live dot, Reduce Motion handling and `.combine` accessibility
   element are unchanged.
3. **Accessibility label/identifiers.** `.accessibilityElement(children: .combine)` still
   yields "Start Lifting" / "Start Cardio"; no visible string or identifier changed (D54
   copy rule holds). No font shrinking (`minimumScaleFactor` absent) — matches the ticket.
4. **D54/spec/STATE.** The amendment records the user's rejection, the two-amber exception
   and that it supersedes ticket 03's primary/secondary pair; spec and ticket agree. STATE
   was shortened with the prior handoff archived and indexed
   (`docs/archive/STATE-2026-09-19-before-start-capsules.md`, `docs/archive/README.md`);
   unresolved ticket-02 device items are carried forward. STATE correctly says the change is
   not installed.
5. **ios-design tells.** Two amber commands and equal peer weight are deliberate and
   user-requested; I do not raise them. Live state still has the single Resume capsule.

## Visual verdict (captures of product 5c51f69, opened by the reviewer)

`redesign-cardio-start-default.png` and `redesign-cardio-start-axl.png`, both 1206×2622.
- Default: two equal amber capsules side by side under the gym card and above Templates;
  ink disc with amber barbell / running figure, bold ink title, ↗ arrow. Titles wrap at the
  word boundary ("Start / Lifting", "Start / Cardio"); nothing truncated or clipped; equal
  height and width; reading order gym → choices → templates. Matches the ticket composition.
- AccessibilityL: stacked full-width single-line capsules, glyphs and arrows scaled, full
  labels readable, no shrinking. The clipped helper line under the tab bar is the List's
  scrolled tail, pre-existing and scrollable, not part of this change.
- The components are the original capsule's; the only visible departures are F1 (two-line
  title at default) and F3 (centred content when stacked).

**Visual: CLEAR against the ticket, conditional on the user accepting F1** — they have the
capture links; the wrap must be named to them, since "original design" was single-line.

## Findings

### F1 — At default size the titles wrap to two lines; the original was one line (show user)

Predicted from the numbers, then confirmed in `redesign-cardio-start-default.png`. On the
402 pt simulator each column is ≈178 pt; disc 40 + paddings 28 + spacings 24 + arrow ≈17
leaves ≈70 pt for a ≈105 pt title, so it renders "Start / Lifting" and "Start / Cardio" on
two lines (that is what `fixedSize(vertical: true)` is there to permit). Nothing is
truncated and both glyphs are readable, so the ticket's literal acceptance is met. But the
ticket also says adjacent "where labels fit", and the user asked for the *original* capsule,
which was a single-line hugging capsule. Two-line capsules ≈64 pt tall are a different
silhouette. This is the user's call, not the reviewer's: present the default capture and
name the trade-off — side by side with wrapped titles, or stacked single-line capsules at
every size (the AXL capture shows what that looks like). Do not describe the default capture
as "labels fit" in the ticket without that note.

### F2 — The side-by-side range has no margin at `.xLarge` and is not captured (should fix or capture)

The threshold moved from `isAccessibilitySize` to `>= .xxLarge`, so `.xLarge` is the
largest side-by-side size, and only default and AccessibilityL are captured. At `.xLarge`
on 402 pt the text column is ≈63 pt against a ≈58 pt "Lifting" — about 5 pt spare. On a
375 pt-wide iPhone (still supported by the deployment target) it is ≈50 pt, and the word
would break mid-word or truncate, violating "both full labels readable". Either add an
`.xLarge` capture on the user's actual phone width and record it, or stack from `.xLarge`.
If the user's device is 393/402 pt only, a recorded capture is enough; state the device in
the ticket.

### F3 — Stacked capsules centre their content (observation)

`.frame(maxWidth: .infinity)` uses centre alignment, so in the stacked AXL layout the disc
sits ≈23 pt from the leading edge instead of the original 8 pt, with matching slack on the
right. It reads fine in the AXL capture and the two rows align with each other. Mention it
when showing the user; change only if they object.

### F4 — Pre-existing, not from this diff

At AXL the ink disc is as tall as the capsule (no vertical padding; `minHeight: 56` is
exceeded by the scaled disc), so the disc touches the capsule's top and bottom edge. The
original Resume/template capsule has the same geometry at AXL; out of scope here, noted so
it is not attributed to ticket 04.

### F5 — Test assertions (minor)

The focused tests assert equal size and side-by-side/stacked geometry but nothing about the
title's line count or truncation, so F1/F2 can only be caught by looking at images. Fine for
this ticket given the captures are the review record; no change required.

## Remaining before merge

- User sees default + AccessibilityL captures with F1 (and F3) stated plainly and chooses.
- F2 resolved by capture or threshold.
- Full local UI suite, 81 expected — read the log's `Executed`/`TEST` line and exit file.
- Reviewer's final merge clearance after the full-suite result. This report does not clear
  the merge.

---

## Re-review — stacked revision `95a82dd` (2026-09-19)

Range re-read: `62f9469..95a82dd`; remote branch tip confirmed at `95a82dd`
(`git ls-remote`). The user answered **stacked** to F1's trade-off; the sections above
describe the superseded side-by-side build `5c51f69` and are kept as history.

**Verdict: code CLEAR, visual CLEAR. F1–F3 resolved. Merge not yet cleared — full UI suite
on `95a82dd` outstanding.**

Evidence read directly: `stacked-build-exit.txt` = 0, `stacked-focused-exit.txt` = 0,
`stacked-focused.log`: `Executed 2 tests, with 0 failures`, `** TEST SUCCEEDED **`. The only
`warning:` lines are the toolchain's `appintentsmetadataprocessor … no AppIntents.framework`
notes, not compiler warnings from this change. Captures (mtime 00:47:10, after the focused
exit at 00:46:45) opened by the reviewer:
`redesign-cardio-start-default-stacked.png`, `redesign-cardio-start-axl-stacked.png`.

### Code
- The whole product diff against main is the idle branch of `heroCapsule` plus its doc
  comment. `HeroCapsuleLabel` has no hunk at all — byte-identical to `62f9469` — so Resume
  and template detail cannot be affected; `fillsWidth`/`fixedSize` are gone.
- `VStack(alignment: .leading, spacing: 12)` with two calls identical to the pre-ticket-03
  Lifting capsule (Cardio: `figure.run`). `.plain` style, `.sensoryFeedback`, identifiers
  `startEmptyWorkout`/`startCardio`, and picker → `WorkoutStartRequest(cardioActivity:)` are
  unchanged. `dynamicTypeSize` is still used by the template grid and gym picker (no unused
  environment value).
- Tests now assert equal height, equal `minX`, stacked order at both sizes; dropping the
  equal-width assertion is right for hugging capsules.
- D15, D54, spec and ticket now say stacked at every size by the user's explicit choice,
  superseding the adjacent request. Consistent with each other.

### Visual
- Default: two single-line hugging amber capsules, leading-aligned under the gym card, disc
  8 pt from the leading edge, ↗ arrow — the original silhouette, twice. Widths differ by
  under 1 pt ("Lifting" vs "Cardio"), so the pair reads as matched, not ragged. Templates
  follow directly; nothing pushed below the fold.
- AccessibilityL: same composition scaled; full labels on one line, no truncation or
  shrinking; ≈7 px width difference, not noticeable. Both fit a 402 pt screen with room; the
  hugging capsule at AXL is ≈270 pt wide, so narrower phones also fit.

### Findings status
- **F1 resolved** — user chose stacked; titles are single-line at every size.
- **F2 resolved** — no side-by-side range remains, so no `.xLarge` squeeze.
- **F3 resolved** — capsules hug and lead-align; no centred content.
- **F4 stands, pre-existing** — disc meets the capsule's top/bottom edge at AXL, identical to
  the shipped Resume/template capsule. Out of scope.
- **F5 closed** — assertions match the new layout.

### Housekeeping before merge (docs, not blocking code clearance)
- The two `*-stacked.png` captures are untracked and the ticket has an uncommitted edit in
  the implementation worktree; commit them so the review record is in Git.
- The committed `redesign-cardio-start-{default,axl}.png` show the rejected side-by-side
  build; keep as history only if the ticket labels them superseded, otherwise remove.
- STATE should name `95a82dd`, the stacked decision and the pending full suite.

### Remaining gate
Full local UI suite on `95a82dd`, 81 expected. Reviewer will read `stacked-full-ui.log`'s
`Executed`/`TEST` line and its exit file before giving final merge clearance.

---

## Final merge clearance — 2026-09-19

**CLEAR TO MERGE** `ericlee4992/restore-start-capsules` at **`98d72fd`** (tested product/tests
`95a82dd`). Code, visual and full-suite gates are all met. Parent owns merge and install;
this clearance does not cover installation.

Read by the reviewer in the implementation worktree, not taken from a summary:
- `stacked-full-ui-exit.txt` = `0`, written Sep 19 01:36:44. `run-stacked-full-ui.sh` writes
  xcodebuild's own `$?` (no pipeline), so the exit is the test run's.
- `stacked-full-ui.log`: `Executed 81 tests, with 0 failures (0 unexpected) in 2915.998 s`,
  `** TEST SUCCEEDED **`; 81 `Test Case … passed` lines, no `failed`, no `error:`.
- `xcresulttool get test-results summary` on `stacked-full-ui.xcresult`: result Passed,
  81 total / 81 passed / 0 failed / 0 skipped / 0 expected failures.
- The suite ran `xcodebuild test` (builds before testing) from that worktree;
  `95a82dd..98d72fd` touches only STATE, ticket 04 and the two stacked PNGs — no product or
  test file — and the worktree is clean, so the tested binary corresponds to the tip's code.
- Remote branch tip is `98d72fd`; `main` (`62f9469`) is its ancestor, so
  `git merge --ff-only` applies.

Housekeeping from the re-review is done: stacked captures and ticket edits are committed,
STATE names the stacked decision. F1–F3 resolved, F5 closed; F4 (disc flush with capsule
edge at AXL) is pre-existing in the shared capsule and remains a possible future ticket.

After merge the parent should confirm the remote `main` contains the resulting tip and
update STATE's merged/installed facts separately — merged is not installed.
