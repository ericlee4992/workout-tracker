# Claude review 01 — native cardio design prototypes (design-only)

Reviewed: commit `4f004be` on `ericlee4992/cardio-design-prototype`, diffed against `e51695b`.
Reviewer checkout: `review-cardio-design` (clean, HEAD `4f004be`). Reviewer: Claude, independent
of the author. Date: 2026-09-17.

Scope: design-only review of throwaway mockups against
[ticket 01](issues/01-design-discussion.md), `.agents/skills/ios-design/{SKILL,REFERENCE,REVIEW}.md`
and the user's decisions (one workout with separate lifting/cardio sections; live gym cardio plus
outdoor GPS runs/rides; screens before implementation). This is not product acceptance.
Sample data and stub actions are intentional and are not findings. No simulator tests were run
and no code was modified by this review.

Evidence used: the source diff, all 34 PNGs in `screenshots/` opened and inspected as images,
`gallery.html`, and the capture-job files in the prototype checkout
(`work-record/ui-redesign/results/cardio-prototype/`).

## Verdict

**Not clear as recorded. Three required findings (R1–R3).** All three are record-versus-render
or colour-meaning problems that would mislead the user while choosing a direction; none is a
readability failure. Every string the wireframes name is whole at default and AccessibilityL.
The release-path check passed. The compositions themselves are sound and the three directions
differ in structure, as the skill asks.

Fixing R1–R3 requires either small prototype edits plus a recapture of the affected screens, or
honest amendments to the ticket and gallery copy. Either resolution clears this review; the
choice is the author's. Advisory items (A1–A9) are labelled judgement and are not blocking.

## Verification results

| Check | Result |
|---|---|
| Release path exposure | Passed. `CardioDesignPrototype.swift` is wrapped in `#if DEBUG … #endif` (lines 1 and 507). The app entry (`WorkoutTrackerApp.swift:67-76`) only instantiates it under `#if DEBUG`, AND `-uiTestReset` (which also selects the wiped UI-test store), AND a `CARDIO_SCREEN` environment variable. The Release configuration in `project.pbxproj` defines no `DEBUG` compilation condition, so the prototype does not compile into a Release binary. The capture driver lives in the UI-test target only. No production view, string or identifier changed. |
| Build / captures | `build-exit.txt` = 0; `captures-exit.txt` = 0; `captures.log` shows `CardioPrototypeCaptureUITests` executed 2 tests, 0 failures. This is rendering evidence only. |
| PNG set | 34 files, 1206×2622. Seven AccessibilityL `-scroll2` files are byte-identical to their `-scroll1` (gym, mixed A/B/C, outdoor, picker, start); see A8. |
| Type (REVIEW 5) | No `.system(size:)`; no Light weights; SF only; `Theme.hero` used once per screen. Passed. |
| Motion (REVIEW 10) | No animation added by the prototype; existing button styles honour Reduce Motion. Passed. |
| Copy (REVIEW 11) | No production string or test identifier changed. New strings are recorded as proposals awaiting the user. Passed. |
| Contrast (REVIEW 6) | Text pairs are `TextPrimary`/`TextSecondary` on Background, Card or Fill (all ≥ 6.6:1 per REFERENCE). `TextTertiary` is not used. Amber, `Danger`, `UnitKg` and `Warmup` on ink all exceed 4.5:1. Passed. Colour *meaning* is R2. |
| Dynamic Type (REVIEW 9) | Same fixture and state at default and AccessibilityL for every screen. Metric pairs stack to one column; the session header stacks via `ViewThatFits`; nothing named by the wireframes truncates. Passed, with the fold caveat in R1. |

## Required findings

### R1 — Composition A's ticket claims are contradicted by its own captures

Files: `issues/01-design-discussion.md` (Screen jobs, composition A, Tells);
`gallery.html` (A is labelled "Suggested starting point");
`CardioDesignPrototype.swift:187-216`.
Images: `cardio-mixed-A-default.png`, `cardio-mixed-A-axl.png`, `cardio-mixed-A-axl-scroll1.png`.

- The Tells section answers "Content above fold — deliberate: current activity before
  completed-session detail." In A the completed Lifting summary card comes *before* the live
  Cardio card. At default size the timer is still in the first viewport; at AccessibilityL
  (`cardio-mixed-A-axl.png`) the first viewport ends at the "Indoor Run" card title with the
  timer clipped under the pinned bar, and Pause/End Cardio are two swipes down. The stated
  job for this state ("control the current cardio segment in one tap") is not met above the
  fold at the project's gate size. This is exactly the skill's "layout that only survives at
  the default text size" tell, and the ticket currently says the opposite.
- Composition C has the same ordering (two completed items before the live one) but says so
  in its wireframe, so it is not misleading; only its tell line is inaccurate.

Resolution options: (a) restate the tell honestly per variant and let the user weigh A's
AccessibilityL fold against its familiarity, or (b) reorder A to put the live Cardio card
first with the completed Lifting summary below, recapture A at both sizes, and update the
wireframe. Either is acceptable for a design review; the user should not choose A on the
current description.

### R2 — Heart-rate zone labels use colours that mean something else in this app

Files: `CardioDesignPrototype.swift:311` (`Text("Zone 2")…foregroundStyle(Theme.unitKg)`) and
`:342` (`Text("Zone 3")…foregroundStyle(Theme.warmup)`).
Images: `cardio-gym-A-default.png`, `cardio-gym-A-axl.png`, `cardio-outdoor-A-default.png`,
`cardio-outdoor-A-axl-scroll1.png`.

- SKILL rule: "Colour carries meaning, and the same meaning everywhere… Yellow: warmup… Unit
  colours: unit chips." The gym screen paints "Zone 2" in the kg unit-chip blue and the
  outdoor screen paints "Zone 3" in the warmup-set yellow.
- The app already has a shared zone palette, `HeartRateZone.color` in
  `Features/Design/ZoneColors.swift` (zone 2 = `#80CABE`, zone 3 = `#A5CF9A`, zone 4 = amber,
  zone 5 = `Danger`), used by the live bar, the finish sheet and History. The mockups therefore
  show a zone treatment the shipped app would not use, and the user could approve a look that
  the implementation should not reproduce.

Resolution: use `HeartRateZone.two.color` / `.three.color` (or the existing `Chip`-based
zone label from `HeartRateBar.swift:156-172`) and recapture gym and outdoor, or add a ticket
note that the zone colours in these captures are placeholders and will follow `ZoneColors`.

### R3 — The stated primary control for live cardio is not rendered as primary in A/B/C

Files: `issues/01-design-discussion.md` ("Mixed, cardio live: … the timer is the bold figure
and Pause is its primary control"); `CardioDesignPrototype.swift:210-213, 229-232, 260-261`.
Images: `cardio-mixed-A-default.png`, `cardio-mixed-B-default.png`, `cardio-mixed-C-default.png`,
`cardio-mixed-C-axl-scroll1.png`.

- In all three mixed compositions Pause and End Cardio are both `.secondary`, hug their
  labels (so they are unequal in width), and in A they are centred while everything else in
  the card is leading-aligned. Only the expanded gym and outdoor screens render Pause as
  `.primary`. So the mixed screens have no primary control at all, contrary to the ticket, and
  the two options are neither styled as primary/secondary nor sized as equals (REVIEW 7:
  "equal options equal size; prominence by style, not size").
- In C the two buttons are stacked vertically (the wireframe shows them side by side) and at
  default size End Cardio sits below the pinned Add bar, so it is not on record at default;
  the wireframe block is only visible in the AccessibilityL scroll capture.

Resolution: decide and render one of: Pause `.primary` with End Cardio `.secondary` (matches
the ticket and the expanded screens), or two equal-width secondary buttons with the ticket
amended to say the timer is the only bold element and no accent control is offered in the
collapsed card. Recapture the three mixed screens after the change, plus a default-size
scroll capture for C.

## Advisory (judgement, not blocking)

- **A1 — Mock tab bar misrepresents chrome.** `tabBar` (`:433-448`) paints a solid
  `Theme.elevated` bar with caption labels; on iOS 26 the real tab bar floats on glass and does
  not hyphenate "Work-out / Histo-ry / Exer-cises / Set-tings" as `cardio-start-A-axl.png`
  does. REFERENCE says not to paint a solid bar under floating controls. Harmless for the
  decision (the Start Lifting / Start Cardio pair is what is being judged) but say in the
  gallery note that the tab bar is a stand-in.
- **A2 — Start screen carries three accent-tinted commands.** Start Lifting (`.primary`),
  Start Cardio (`.secondary`, fine) and a `.bordered`-with-accent "Start" pill on the Upper
  Body template card (`:105`). Production template tiles have no inline Start (they open the
  template, ticket 11). The extra pill is a second accent call to action on the screen (SKILL
  "one dominant treatment"); drop it or make it neutral so the capture matches the shipped
  Start screen more closely.
- **A3 — Machine distance reads as a card in a card in A.** The `Theme.fill` field container
  (`distanceRow`, `:371-380`) sits inside the `.card()` Cardio card. The ticket calls it an
  editable field, which is defensible, but at default size the nested rounded fill reads as a
  nested card. In B and C it is not nested. If A is chosen, consider a plain text field row
  with a hairline instead of a filled container.
- **A4 — Icon-only buttons below 44 pt.** The expand arrow in A (`:205`) and the Templates
  "+" (`:96`) are bare `Image` buttons with no minimum frame. Not a mockup problem, but note
  in the implementation spec that they need 44 pt hit regions.
- **A5 — C's live marker does not scale.** The amber "in progress" dot is a fixed 12 pt
  circle (`:251`) while the completed checkmarks scale with type; at AccessibilityL
  (`cardio-mixed-C-axl.png`) the live marker is the smallest thing in the timeline. Use a
  scaled symbol or `@ScaledMetric` if C is chosen.
- **A6 — Two ways to leave cardio.** Every non-Start screen shows both a chevron-down
  toolbar button (returns to Start in the mock) and Finish/Cancel/Done. The chevron is not in
  any wireframe and its production meaning (minimise the live workout?) is unspecified. Decide
  before implementation; in the mock it is only a navigation shortcut.
- **A7 — Zone label without its meter.** Production shows the zone as a `Chip` with a
  five-step meter (colour is not the only carrier, per the comment in `HeartRateBar.swift`).
  The mock shows the word alone. Related to R2; if the zone chip is reused, A7 disappears.
- **A8 — Duplicate scroll captures.** Seven `-axl-scroll2.png` files are byte-identical to
  their `-scroll1.png` (the second swipe hit the end of content). The gallery shows both as
  separate "Scrolled view" figures, which suggests more content than exists. Drop the
  duplicates from the gallery or de-duplicate in the capture driver. Record accuracy, not
  design.
- **A9 — Map mock.** The route polyline and "Start/Now" annotations are illustrative and the
  ticket says so. At AccessibilityL the "Now" label is hidden by MapKit's collision handling;
  acceptable for a mock, but the outdoor spec should define which annotation wins when they
  collide.

Things that are right and worth keeping: one `hero` per screen (the segment timer), `stat`
figures with Caption labels, red reserved for heart rate, amber reserved for the live thing
and selection, the picker as grouped lists with 44 pt+ rows, the summary's six metric pairs
matching ticket 17's accepted pairs, and the sessions header collapsing cleanly at
AccessibilityL.

## Docs-clearance: `c5449c9` on `ericlee4992/sets-completion-ring`

Inspected from the `sets-completion-ring` checkout without switching or mutating this one.
`git diff --stat e51695b c5449c9`: six files, docs only (DECISIONS, STATE, archive README, new
archive snapshot, cardio ticket 01, ring ticket 18). No source or test changes remain on the
branch; the diagnostic UI-test source described in ticket 18 is absent, as the ticket states.

| Check | Result |
|---|---|
| Archived STATE bytes | `docs/archive/STATE-2026-09-17-before-cardio-design.md` at `c5449c9` is byte-identical to `docs/STATE.md` at `e51695b` (`cmp` clean; both md5 `d4b86caa…`). Archive README row added and accurate. |
| Unresolved rows preserved | Everything below "Active task and next action" in STATE is byte-identical between `e51695b` and `c5449c9`; the open-work table keeps all 16 rows. Only the active-task section was rewritten. |
| STATE ↔ ticket ↔ DECISIONS consistency | STATE cites prototype checkpoint `4f004be` and base `e51695b`; both match Git (merge-base of `main` and `c5449c9` is `e51695b`, `origin/main` is `e51695b`). D15 is marked reopened with the same scope words as the ticket and STATE; the Deferred list is amended to match. Ticket 18 status "resolved — user confirmed the ring actually works; no app fix required" matches STATE's "Sets ring report closed". Ticket 01 (short form) says review is running in `review-cardio-design` with the report at this path, which is now true. |
| Links | All relative links in the five changed Markdown files resolve on the branch. The one external link (GitHub blob at `4f004be`) depends on the prototype branch staying pushed; `origin/ericlee4992/cardio-design-prototype` currently contains `4f004be`. |
| Remote | `origin/ericlee4992/sets-completion-ring` contains `c5449c9`. |
| Local evidence | `work-record/ui-redesign/results/18/` exists in that checkout (ignored by Git) with the repro logs/results/exit files the ticket names. |

**Docs clearance: CLEAR.** Two non-blocking notes: (1) `work-record/cardio-design/issues/01-design-discussion.md`
now exists in two different forms, a short one on the ring branch (destined for main) and the
full one on the never-to-merge prototype branch; the ring version links the full one by commit
URL, which is fine as long as the prototype branch is never deleted from the remote. (2) When
the ring branch is fast-forwarded to main, this review file will not be on main either; link
it from the main-side ticket by commit URL the same way, or copy it across.

## Ring closure (ticket 18)

The user confirmed the ring actually works. The diagnostic test passed at 1/1 and 2/2 with
pixel sampling, the reported defect did not reproduce, and the ticket correctly declines to
claim a cause. Closing without an app change is the right call and the record says exactly
what was and was not run. No finding.
