# Ticket 04 — independent Codex review

**Not clear: four medium findings, one low. No critical or high findings.**

Reviewed 2026-09-27 in `/tmp/wt-floodlight/finish`, branch
`ericlee4992/redesign-floodlight-finish`, range
`0ca7868c4a2b7edfb3c4d91303ac87cbb656a01d..743f609c308d7d551314a2846f43f5fa4c822f7e`
(`ericlee4992/redesign-floodlight-live..HEAD`). Claude implemented; Codex reviewed.
Only this report was written. No `xcodebuild` or `simctl` commands were run.

## Medium

### 1. Completed sets without a muscle family disappear from the ring

**Location:** `WorkoutTracker/Domain/FinishReceipt.swift:62–65`.

Ticket 04 requires “one segment per completed set … so it agrees with the set count.”
`MuscleFamily` has no mapping for Core, Neck, Full Body or an unclassified exercise. Those
sets are skipped here. Three chest sets plus two crunch sets therefore produce **5 sets**
in the header but three ring segments; the ring's VoiceOver label also says **3 sets**.
A core-only workout gets an empty ring despite its completed sets. Keep unmapped sets in
the ring, using a neutral representation. Add mixed-family/unmapped and unmapped-only cases.
The aggregation also merges nonadjacent families: chest → back → chest becomes chest → chest
→ back, contrary to the stated workout-order rule; keep ring order separate from family totals.

### 2. Localized count-up parsing can reduce the displayed volume by 1,000×

**Location:** `WorkoutTracker/Features/ActiveWorkout/FinishPieces.swift:138–140`;
supporting path: `Features/Design/Look/Stats.swift:128–131` and
`Features/ActiveWorkout/WorkoutFinishedSheet.swift:236–237` (under `WorkoutTracker/`).

The new tile enables `countsUp` on an already localized string. With German region formatting,
1,880 kg becomes `1.880`; `CountUpFormat.parse` removes commas only and parses this as the
Double **1.88**. At animation completion the tile displays **1,88 kg**, while its accessibility
label and comparison still represent 1,880 kg. Reduce Motion uses the same parsed value.
The parser predates this branch, but the new receipt caller exposes it here. Pass a numeric
value with its formatter, or parse with the same locale; verify the final rendered value in
a locale using a period for grouping.

### 3. Volume now loses the established decimal precision

**Location:** `WorkoutTracker/Features/ActiveWorkout/WorkoutFinishedSheet.swift:237`.

The old tile used `WeightMath.displayLabel` (up to two decimals, D25). `LookFormat.grouped`
rounds to a whole number. One working set of **2.5 kg × 3** now shows **8 kg**, previously
**7.5 kg**; **0.25 kg × 1** shows **0 kg** despite a positive volume. This contradicts ticket
04's “same values and conditions as before” and creates disagreement with History. The new
comparison labels use the same whole-number formatter. Retain grouping with the established
decimal precision in both places. This is separate from finding 2's locale parsing error.

### 4. VoiceOver omits the scope of each new best

**Location:** `WorkoutTracker/Features/ActiveWorkout/FinishPieces.swift:201–204`
(children are ignored at lines 185–186).

The visible row includes `best.equipment`, which contains the machine/tag and preset, but
the replacement accessibility label omits it. Set records for the same chest-press exercise
on two machines in one workout: VoiceOver reads the exercise and values twice without saying
which machine each record belongs to. Different presets likewise become indistinguishable.
Ticket 04 explicitly keeps these as separate record scopes. Include the existing equipment/
preset string in the spoken label and verify two same-name records with distinct scopes.

## Low

### 5. Bar-mode rows lose their bar annotation

**Location:** `WorkoutTracker/Features/ActiveWorkout/FinishPieces.swift:219–223`;
`WorkoutTracker/Domain/SetValue.swift:14–16`.

The old exercise summary appended the bar, for example **60 kg × 5 (20 kg bar)**
(`Domain/WorkoutSummary.swift:169–175`). The new value renderer ignores `SetValue.bar`, so
the exercise row loses that information. New-best rows omit it too, and the historical-best
conversion cannot retain it because `RecordSetInput` carries no bar. Preserve the bar
annotation through the receipt's display data, including the historical incumbent. This
removal is not listed as a product change in ticket 04. **The load itself remains correct:**
`commitPerSide` stores the total, so the receipt does not omit or double-add the bar weight.

## Other checks and verification limits

- Record selection uses the pre-workout incumbent, strict completion-time cutoff, shared
  scope across split entries, and normalized-load ranking. Assisted lower-is-better,
  bodyweight reps, warmup exclusion/fallback, first-time suppression and as-entered set
  units are preserved. Family lookup deliberately uses the live muscle group as documented.
- Comparison selects the latest earlier-started finished run of the same template. It uses
  existing weighted-only, non-warmup volume; assisted/bodyweight/bodyweight-plus add none.
  If either volume is zero it hides the comparison, without skipping back to an older
  positive-volume run.
- Template drift still precedes the receipt. Empty finish, Done, View in History, Save as
  Template, chart/zone gates, cardio cards, “Lifting”/“Exercises” and the requested identifiers
  remain. History's default `.listSection` keeps its previous content and modifiers.
- Reviewed both approved F01 images, the prototype Finish source and all 12 supplied actual
  captures. The captured light/dark Default/AccessibilityL layouts retain the main hierarchy
  and readable content. Primary/secondary actions retain targets above 44 pt; Done is native.
  Ring/key and comparison labels are present. Motion paths honor Reduce Motion in source;
  no interactive VoiceOver or Reduce Motion run was performed. Findings 3 and 5 are unlisted
  display changes; the listed new receipt strings are present.
- Caching avoids rebuilding on ordinary renders. Save as Template creates a separate template
  and does not change the workout, so it does not stale the receipt. Same-ID external model
  changes would not invalidate this cache while presented. Each entry still fetches all
  finished workouts and traverses their entries, including repeated scopes: cost grows with
  receipt entries × historical entries, on the UI path. No large-history timing evidence
  establishes a latency regression or proves scalability; a single shared history pass would
  bound repeated work better.
- Targeted verification is appropriate for this ticket under DEVELOPMENT. Independently read
  `/tmp/wt-floodlight/results/finish-build-5.{log,exit}` (successful build-for-testing, exit 0),
  `finish-unit-1.exit` (0), and `finish-ui-4.{log,exit}` plus its xcresult summary via
  `xcresulttool`: **14 unit tests passed; UI 17/18 passed; exit 65; zero skipped**. The failure
  at `HeartRateSummaryUITests.swift:66` is also present in `base-5.log:576`; it is not a new
  receipt regression. The result also retains invalid-frame warnings. Existing fixtures do
  not cover the five cases above. Add focused regression coverage and recapture changed
  layouts after fixes; this review does not request a full UI suite for ticket 04 alone.
