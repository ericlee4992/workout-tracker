# Claude review — ticket 05, arrowless Start row and outdoor cardio

Independent review per T6. Reviewer made no product edits and ran no simulator operations.
Range `0e16a8c..b0d29fa` (`ericlee4992/compact-start-outdoor`), reviewed 2026-09-19.
Read: [ticket 05](issues/05-compact-start-and-outdoor.md), D15/D54 amendments, cardio spec,
ios-design SKILL/REFERENCE/REVIEW, the diff, and the callers of everything it touches.

**Verdict: code review NOT yet clear — one medium source-honesty defect (F1) and one
must-verify layout risk on the user's actual phone width (F2). Everything else is sound.**
The user's directly selected composition (arrowless row, fit-driven stack, no outdoor GPS row)
is not questioned here and needs no new approval.

Stage covered: **code review only.** Native default/AccessibilityL captures and the full UI
suite had not finished when this was written; visual clearance and merge clearance are separate
and still owed.

## Findings

### F1 — Medium — outdoor message promises a manual entry that no longer exists live

`WorkoutTracker/Domain/CardioRecorder.swift:275` — when location is denied/restricted, an
outdoor segment shows *"Location unavailable. You can enter distance manually."*
`CardioLiveView` renders that message (`CardioViews.swift:134`) and the diff then hides the only
live manual-entry control for outdoor activities (`CardioViews.swift:139`). The screen now tells
the user to do something it offers no way to do. This is exactly the "mirrored message actually
sent / gated control reachable" class AGENTS.md asks us to check, and the ticket's own
acceptance line ("location failure/status messages … retained", "honest location status")
is only half met: the message is retained, its truth is not.

Manual entry is still reachable after **End cardio** (`cardioSummaryEditDistance` on the ended
card, and in Summary/History), so no data path is lost — the defect is the live copy/affordance
mismatch, in the one state (no GPS) where the main Distance metric reads "—" for the whole run.

Options for the parent (either resolves it; pick per the user's intent):
- (a) Keep the row hidden whenever GPS is measuring, but show the existing "Enter distance"
  row for outdoor when location is denied/restricted (or when an outdoor segment already has a
  manual distance). No new strings; the "redundant GPS section" the user objected to stays gone
  because in that state there is no GPS readout to duplicate.
- (b) Change the outdoor denied copy so it does not promise a live action. This is a new/changed
  visible string and needs the user's decision recorded (D54 "never words").

Whichever is chosen, add an assertion for the denied/unavailable outdoor state; today no unit or
UI test reads that message (`grep` of both test targets: no hits), so the mismatch was invisible
to the focused tests.

### F2 — Must verify before install — the row is borderline at the user's phone width

The side-by-side row only appears if both full capsules fit (`ViewThatFits`,
`StartWorkoutView.swift:156`). Estimated default-size widths: each capsule ≈ 8 + 40 + 12 +
~100–103 (body-bold title) + 12 ≈ 172–177 pt, so the pair with 12 pt spacing ≈ **359–361 pt**.
The test simulator `WT-iPhone` is an **iPhone 17 Pro (402 pt wide)**; with inset-grouped list
margins that leaves ≈ 362–370 pt — it fits by a few points, which is what
`RedesignScreenshotUITests` asserts. The user's phone (UDID `00008130-…`, A17 Pro class,
**393 pt wide**) has ≈ 353–361 pt. By this estimate the row may **not** fit there and
`ViewThatFits` would silently fall back to the stacked layout — i.e. the installed build could
look identical to ticket 04 minus arrows, and the user's actual request would not be delivered
on the only device that matters, while every test and capture stays green.

This is an estimate from source, not a measurement. Required before merge/install: capture the
idle Start screen on a 393 pt-wide simulator (iPhone 15 Pro / 16) at the default size and record
the result in the ticket. If it stacks, there is room to recover without shrinking type or
breaking words (e.g. capsule spacing 12 → 8, title/disc gap, or trailing pad), but that is the
parent's call; show the user the 393 pt capture either way.

### F3 — Low — stale doc comment on `HeroCapsuleLabel`

`StartWorkoutView.swift:292-295` still describes the capsule as having "a trailing symbol";
`trailing` is now optional and two of four callers pass `nil`. AGENTS.md asks that doc comments
match callers before a feature closes. One-line fix.

### F4 — Low — live provenance for an outdoor manual distance is no longer visible

If an outdoor segment carries `manualDistanceValue` (entered on the ended card and then resumed
via recovery, or carried over from the currently installed build, which still had the outdoor
row), the live screen shows the number in the main metric with no "Entered distance" caption.
Storage, export and the ended/Summary/History caption are untouched, so this is display-only and
consistent with D52's direction; recorded so it is not rediscovered as a bug. Option (a) in F1
would also cover it.

### F5 — Low / test — default-size layout is asserted at one width only

`RedesignScreenshotUITests.swift:45-51` hard-codes "default ⇒ row, AXL ⇒ stack" for the 402 pt
simulator. That is fine as a gate for this simulator but it encodes the device, not the rule,
and is the reason F2 cannot be caught by the suite. Acceptable for a one-user app once F2 is
verified by hand; note the device assumption in the ticket.

## Checked and clear

- **Scope of arrow removal.** Only the two idle choices pass `trailing: nil`
  (`StartWorkoutView.swift:168,176`). Resume (`:149`) and template Start
  (`TemplateDetailView.swift:84`) still pass their arrow and keep the 20 pt trailing pad — no
  change in their geometry. Those are the only four `HeroCapsuleLabel` call sites.
- **Fit logic.** `HStack … .fixedSize(horizontal: true)` inside `ViewThatFits(in: .horizontal)`
  measures the un-wrapped titles, so the row is chosen only when full single-line labels fit; no
  `minimumScaleFactor`, no line limit, no mid-word breaks. The `VStack` fallback is ticket 04's
  layout. Shared `startChoices` keeps identifiers (`startEmptyWorkout`, `startCardio`), actions
  and the `.sensoryFeedback` trigger identical in both branches. Only one branch is instantiated,
  so identifiers are not duplicated in the accessibility tree.
- **Capsule geometry.** 12 pt trailing pad against a 28 pt end radius leaves ≈ 9–10 pt between
  the title and the curve at text height — adequate on paper; confirm optically in captures
  (judgement, advisory).
- **Outdoor removal is presentation-only.** No change under `Domain/`; `CardioRecorder`,
  `acceptDistance`, route capture, span/source selection, schema and exports are untouched.
  The main Distance metric, pace/speed, current pace line, HR/zone row and `locationMessage`
  text all still render for outdoor. `CardioDistanceSheet` stays attached; indoor
  `cardioEditDistance` is byte-for-byte the previous row, and the indoor tests that use it
  (`CardioUITests.swift:52,86,187,195`) are unaffected. `CardioSummaryCard`'s
  `cardioSummaryEditDistance` (ended-in-workout, Summary, History) is unchanged and the outdoor
  test still reaches it after End.
- **Test honesty.** `staticTexts["GPS"]` is a real negative: `CardioDistanceSource.gps.label`
  is exactly `"GPS"`, the string the removed caption rendered. `"0.67"` pins the GPS fixture in
  the main metric; `cardioDistanceMetric` is a new identifier, none removed. The in-code comment
  at `CardioViews.swift:137` is accurate for the measuring case (see F1 for the non-measuring one).
- **Docs.** D15 and D54 reopen the stacked decision explicitly with reason and ticket; spec
  gains a dated section; STATE was archived before shortening and the archive index links it.
  Spec line "Restore … with activity icon disc and arrow" (ticket-04 section) is now historical
  and is superseded by the new section directly below it — acceptable.
- **Design record (REVIEW item 12).** Ticket has job/state sentences, wireframe, tells answered,
  two-amber-commands accepted by the user, "New UI strings: none". Captures pending. Item 11
  (copy) holds unless F1 option (b) is taken.

## Evidence seen by the reviewer

- Parent's artifacts in the implementation worktree
  (`work-record/ui-redesign/results/compact-start-outdoor/`): `build-exit.txt` = **0**.
  Focused run (PID 49847) was still in progress at review time: 2 of 5 finished
  (`testDistanceEditorDoesNotFreeze…` and `testOutdoorRouteAccessibilityCapture` passed); no `focused-exit.txt` yet. Reviewer has **not**
  seen a green focused result, captures, or the full UI suite.
- Implementation worktree clean at `b0d29fa`.

## Still owed before merge clearance

1. Resolve F1 (and F3); re-review the fix.
2. F2: 393 pt default-size capture of idle Start, shown to the user and recorded.
3. Focused 5 green with exit code read from the log's TEST line; default + AccessibilityL
   captures reviewed (visual pass); full local UI suite (81 expected) exit 0.

## Addendum — parent's response and reviewer correction (2026-09-19)

- **F2 corrected — reviewer error.** I inferred a 393 pt iPhone 15 Pro from the UDID's `8130`
  chip prefix; A17 Pro also ships in the Pro Max. `devicectl list devices` (read by the reviewer)
  shows the phone is **iPhone 15 Pro Max (iPhone16,2), 430 pt wide**, as milestone-7's spec already
  recorded. That leaves ≈ 390 pt for a ≈ 360 pt row: it is *wider* than the 402 pt test simulator,
  so the row should fit with more margin on the phone than in the captures. F2 is downgraded from
  must-verify to **informational**; the parent's planned 15 Pro Max capture closes it. The
  borderline arithmetic still holds for 393 pt devices, which nobody in this project uses (F5).
- **F1 plan (b) accepted in principle.** Replacing the denied/restricted copy with the existing
  `"Location unavailable."` deletes words and adds none, so D54's copy rule holds provided the
  consequence is recorded in D54/ticket as stated. Not restoring the row is the user's call and
  is respected. To verify on re-review: the indoor pedometer message
  (`CardioRecorder.swift:243`, "Motion data unavailable. You can enter distance manually.") must
  stay — it is still true indoors — and no outdoor path may still emit the manual-entry sentence.
- **No permission-injection seam — agreed.** `startLocationIfAuthorized` reads
  `CLLocationManager.authorizationStatus` directly; a seam for a one-string change is
  disproportionate. Diff inspection of the branch plus the existing `CardioRecorderTests` staying
  green is sufficient for this finding.
- **F3:** to confirm in the fix diff. **F4/F5:** stand as recorded, no action required.

Status: still **not clear** until the fix commit is reviewed; then visual pass and full UI suite.

## Re-review of fix `7825140` and first visual pass (2026-09-19)

Range `b0d29fa..7825140`: two product lines plus D54/ticket text.

- **F1 resolved.** `CardioRecorder.swift:275` now sets `"Location unavailable."` for
  denied/restricted — identical to the existing `@unknown default` string, so no new words.
  `git grep "enter distance manually"` over app and both test targets at the tip returns only
  `CardioRecorder.swift:243`, the indoor pedometer failure, where the live editor still exists
  and the sentence is still true. No outdoor path promises an absent control. The GPS row was not
  restored. D54 and the ticket record the deletion as a consequence of the user's removal.
- **F3 resolved.** Doc comment reads "an optional trailing symbol", matching the four callers.
- **Evidence read by the reviewer (log lines, not summaries):** `final-build` BUILD SUCCEEDED,
  exit 0. `recorder`: exit 0 and `✔ Test run with 7 tests in 1 suite passed` — the XCTest line
  "Executed 0 tests" in that log is only the XCTest counter; CardioRecorderTests is Swift
  Testing, so the run is not vacuous. Initial `focused` (on `b0d29fa`): `Executed 5 tests, with
  0 failures`, TEST SUCCEEDED, exit 0. `final-focused` and `phone-size` were still running.

**Code review: clear** at `7825140`.

### Visual pass — initial captures (`initial-shots/`, product `b0d29fa`, WT-iPhone 402 pt)

The fix changes no pixels in these states, so the captures remain representative.

- **Start, default.** Two arrowless amber capsules on one row, full single-line labels, equal
  height, icon discs concentric. Measured from the capture: capsules ≈ 170 pt each, 12 pt gap,
  row ≈ 352 pt in ≈ 370 pt available. **This measurement supersedes my F2 source estimate
  (≈ 360 pt), which was pessimistic:** the row would fit even at 393 pt, and has ≈ 45 pt of
  slack on the user's 430 pt phone. F2 is closed pending only the parent's 15 Pro Max capture
  for the record. Trailing clearance between title and capsule end reads balanced against the
  leading disc inset.
- **Start, AccessibilityL.** Stacked, leading-aligned, full labels, no scaling or wrapping;
  same fixture and state as default; hierarchy order unchanged (REVIEW 9 holds).
- **Outdoor live, default.** Timer is the hero; Distance 0.67 km and pace directly beneath; no
  GPS caption or pencil row; Pause is the only amber command (REVIEW 1, 4, 6, 7 hold).
- **Outdoor live, AccessibilityL.** One-column metrics, nothing named by the wireframe is
  truncated, no GPS row. The nav title truncating to "Outdoo…" and the Start footer sliding
  under the tab bar at AXL are pre-existing and outside this ticket.
- Judgement (advisory, no action): at default the hugging pair ends ≈ 18 pt short of the gym
  card's right edge, a slightly ragged right margin. It follows from the user's chosen hugging
  capsules ("not a slab") and I would not stretch them.

**Visual review of the initial captures: clear, no defects for the parent to fix.**

### Still owed before merge clearance

`final-focused` (5) and `phone-size` (1) green with exit codes and TEST lines read; final
exported captures match the initial ones; full local UI suite (81 expected) exit 0. Reviewer
has not seen those and does not clear the merge yet.

## Final visual re-review — 10 exported captures at `7825140` (2026-09-19)

Evidence read directly: `final-focused-exit.txt` = **0**; `final-focused.log` shows all five
named tests passed, `Executed 5 tests, with 0 failures`, `** TEST SUCCEEDED **`. Implementation
worktree at `7825140`, clean apart from the untracked capture folder
`work-record/cardio/screenshots/compact-start-outdoor/` (**parent: commit it before merge** so
the review record travels with the branch).

All ten PNGs opened by the reviewer. The two Start captures are byte-identical (`cmp`) to the
initial ones already reviewed; the outdoor pairs differ only in live timer/HR values.

| Capture | Result |
|---|---|
| Start default | Arrowless pair on one row, full labels, equal height — clear |
| Start AccessibilityL | Stacked, leading-aligned, full labels, same fixture — clear |
| Outdoor top default / AXL | Timer hero; Distance 0.67 km + pace directly under it; no GPS caption/pencil row; Pause sole amber — clear |
| Outdoor details default / AXL | Metrics → Add actions → pinned Pause/End; nothing between metrics and actions; one-column at AXL, no truncation of wireframe items — clear |
| Finish route default / AXL | Map present only after Finish; `GPS` source caption + pencil (saved correction) retained — clear |
| History route default / AXL | Same card, map and `GPS` + pencil retained — clear |

Source honesty holds end to end: the live screen shows the measured distance once, and
provenance ("GPS") plus correction stay on the saved card where the ticket said they would.
Pre-existing and out of scope, unchanged by this ticket: AXL nav title "Outdoo…", content
scrolling beneath the pinned Pause bar / tab bar at AXL.

**Code review: clear. Visual review: clear.** No open findings (F1, F3 resolved; F2 closed by
measurement, 15 Pro Max capture wanted for the record only; F4/F5 informational).

**Merge clearance is conditional on two results the reviewer has not yet seen:**
`phone-size` (1 test, WT-iPhone15ProMax) exit 0 with its PNG showing the row, and the full local
UI suite (81 expected) exit 0 with the TEST line read from the log. If both are green and the
product commit is still `7825140` (docs/captures-only commits on top are fine), the parent may
fast-forward `main` without another review round; any further product change needs re-review.

## Findings closed — matching-phone width evidence (2026-09-19)

- `phone-size-exit.txt` = **0**; `phone-size.log`: `testCardioStartChoicesDefault` passed,
  `** TEST SUCCEEDED **`, destination `WT-iPhone15ProMax`, which `simctl` reports as device type
  `iPhone-15-Pro-Max` — the same model `devicectl` reports for the user's phone.
- `start-iphone15promax.png` opened by the reviewer: both arrowless capsules on one row, full
  single-line labels, equal height. Measured from the capture the row ends ≈ 372 pt of 430 with
  the card edge at ≈ 409 pt — about **37 pt of slack**, so the row is not borderline on the phone.
- `7825140..2caa068` touches no file under `WorkoutTracker/`, either test target or the project:
  records and the 11 PNGs only. Product under review is still `7825140`. The capture folder is
  now committed, closing the note in the previous section.

**All findings closed: F1 resolved, F2 closed by matching-device capture, F3 resolved, F4/F5
informational with no action. Code review clear; visual review clear.**

Remaining for merge clearance: the full local UI suite (81 expected) — exit 0 and the log's
TEST line, with the product commit unchanged. Not yet seen by the reviewer.

## Final merge clearance (2026-09-19)

Read independently by the reviewer from the implementation worktree's artifacts
(`work-record/ui-redesign/results/compact-start-outdoor/`), not from the parent's summary:

- `full-ui-exit.txt` = **0** (written 02:58 EDT).
- `full-ui.log`: `Executed 81 tests, with 0 failures (0 unexpected)`, `** TEST SUCCEEDED **`;
  81 `Test Case … passed` lines, 0 `failed`.
- `full-ui.xcresult` via `xcresulttool … summary`: result **Passed**, total 81, passed 81,
  failed 0, skipped 0, expected failures 0; device WT-iPhone (iPhone 17 Pro).
- Tested code = reviewed code: the suite started 02:09:39, after product commit `7825140`
  (02:02:03); the worktree's app, both test targets and the project show no diff against
  `7825140`. Branch tip `0ffafd9`; `7825140..0ffafd9` is `2caa068` + `0ffafd9`, touching only
  records, STATE and the 11 captures — no product or test file.
- Earlier gates, each read from its own log: final build exit 0; CardioRecorderTests 7/7
  (Swift Testing); focused 5/5; matching iPhone 15 Pro Max 1/1.

The parent reports 24 known non-failing invalid-frame warnings, the class STATE already lists;
I did not recount them and they do not affect the result.

**MERGE CLEARED.** Code review clear, visual review clear, all findings closed, full local UI
suite 81/81 at the reviewed product commit `7825140`. The parent may fast-forward `main` to the
branch tip provided no product/test file changes after `7825140`; any such change voids this
clearance and needs re-review.

Noted at clearance time: the implementation worktree had uncommitted edits to `docs/STATE.md`
and ticket 05 (the parent's result recording) — commit them before the fast-forward.
Not covered by this clearance: device installation and on-phone acceptance (parent/user), and
the denied-location outdoor state, which was verified by source inspection only.
