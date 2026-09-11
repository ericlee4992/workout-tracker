# Where the project is right now

Updated 2026-09-11 mid-morning (UI redesign COMPLETE on main AND on the phone, tickets 01–09; profiles to 09-17). **START HERE IF YOU ARE COLD:**

000000. **HANDOFF 2026-09-11 (mid-morning) — THE UI REDESIGN IS COMPLETE ON `main` (tickets
   01–09) AND INSTALLED (`2ce4579`, 10:24 EDT, launched remotely). Next: the user's reaction on
   the phone; the follow-ups below.**
   - **`main` = ticket 09 (`ui-redesign-09`, pushed; every redesign branch is pushed and
     fast-forward-merged, zero merge commits) = the phone.** Installed on the user's word
     ("install") with `./scripts/install-on-device.sh`; profiles reused, good to 09-17 — **sign
     again before 2026-09-17** or the app stops launching. Screenshots for 06, 07, 08 and 09
     and the icon were sent; the user has said "looks good" (04/05) and "keep going" — ask for
     a reaction to the whole redesign on the phone.
   - **Ticket 09 (the last)**: `issues/09-empty-states-icon-live-activity.md` — the last plain
     "No … yet" texts → `EmptyState` (Previous Performance's per-layer messages are the recorded
     exception); `scripts/render-app-icon.py` → `AppIcon.png` (amber dumbbell on ink; run the
     script to regenerate); the Live Activity in the app's two colours as literals, its Lock
     Screen content forced to the dark scheme; SPEC "Visual design (D54)" paragraph; D54 final.
     Codex 3 rounds; unit 707/707; full UI suite **61/61**.
   - **The whole redesign, for the record**: 01 design system + 02 active workout (Codex built,
     Claude reviewed, chosen from a side-by-side board), 03 finish summary, 04/05 gear + Settings
     screen, 06 History, 07 Gyms, 08 Exercises + pickers, 09 the rest — each with a ticket file,
     screenshots (`screenshots/<ticket>/`, AccessibilityL captures per screen), Codex reviews
     (`codex-review-<ticket>*.md`) and the full suite before merge. Departures from the plan, all
     recorded: monotone chart; amber (not coral) icon and Live Activity; the model as a caption
     at accessibility sizes; today's calendar ring in `Theme.secondary`.
   - **Follow-ups the reviews surfaced, none blocking**: the empty Gyms tab has no illustration
     (adding a string is new copy — ask the user); `Gym.activeMachines.count` sorts per row (fine
     for a personal list); no four-tag exercise exists to capture `WrapLayout` at width; the
     Live Activity's Lock Screen rendering on wallpaper is unverified by capture. Codex's Orca
     worktree from the design bake-off (`~/orca/workspaces/Health App/ui-redesign-codex`) can be
     removed (`orca worktree rm`).
   - **Running xcodebuild from this harness**: launch every test run DETACHED (a script +
     `python3 -c "subprocess.Popen([script], start_new_session=True, ...)"`; macOS has no
     `setsid`; the script appends `… DONE <code>` to a status file) and poll that file in ≤ 5-min
     foreground waits — background tasks get stopped from outside. Do not run the unit suite
     while Codex and a UI build compete for the machine (the HeartRateMonitor tests are
     wall-clock and flaked twice tonight; always green alone).
   - **Codex reviews: ONE terminal per ticket** — `orca terminal create --worktree active
     --command codex --title "…" --json` → `orca terminal send --terminal <handle> --text
     "$(cat prompt.md)" --enter --wait-submit 20` → poll the report file → `orca terminal close`.
     All closed.

00000. **UI REDESIGN — the user chose Codex's "Ink / Amber" (2026-09-10); MERGED to `main`
   the same day (tickets 01 + 02 + Start-lite) and INSTALLED, launch-verified 2026-09-10 evening
   (`84610c9` = `main`; no schema change; profiles unchanged, 09-17).** The user: "the app seems a bit boring, with mostly
   texts and it essentially doesn't have a clean UI design." Plan (approved, in
   `.scratch/ui-redesign/spec.md`): bold, dark, card-based; dark only; ONE warm accent; muscle-group
   colours + icons; stat tiles + rings; motion + haptics; SF-Symbol empty states; whole app screen
   by screen with screenshots, workout screen first; Settings gets its own screen behind a gear on
   the Workout tab (ticket 05); a generated app icon (ticket 09). **D54** records the visual
   system (amber `#FFB45E`); CLAUDE.md says iOS 26 (was a stale "17+").
   - **How it was chosen**: the same brief went to Claude and to Codex (an Orca worktree, its own
     simulator `WT-iPhone-Codex`); both built tickets 01 + 02 (design system + active workout;
     Codex also took Start); a side-by-side board of all 15 screens × before/Claude/Codex was
     published — https://claude.ai/code/artifact/8d3aa889-2a2b-44ae-8d37-7620377bd3f9 — and the
     user picked Codex's. Record: `.scratch/ui-redesign/issues/01-design-system.md` ("Outcome"),
     `codex-design-report.md` (Codex's own report), `screenshots/{before,claude,codex}`.
   - **Branch `ui-redesign`** = Codex's `b008e5c` + the docs + `RedesignScreenshotUITests` (the
     15-screen review surface, run it for every later ticket) + Claude's review fixes (the header
     ring's count chip no longer overlaps the tick; swipe-delete uses `Theme.danger`). Claude's
     retired branch `ui-redesign-01` is deleted; its screenshots stay in `screenshots/claude`.
     Codex's Orca worktree `~/orca/workspaces/Health App/ui-redesign-codex` (branch
     `ericlee4992/ui-redesign-codex`) can be removed after the merge (`orca worktree rm`).
   - **Verification**: Codex's own run — 699 unit, the 21 gate UI tests, 3 screenshot tests, all
     green. On `ui-redesign` after the fixes: the FULL UI suite — **55 tests, 0 failures** (46 +
     Codex's 3 screenshot tests + the 6 `RedesignScreenshotUITests`).
   - **Next**: the user's reaction on the phone; then
     tickets 03 (finish summary), 04 (Start — mostly done by Codex; finish the gear button),
     05 (Settings screen), 06 History, 07 Gyms, 08 Exercises, 09 empty states + app icon +
     Live Activity, each with screenshots via `RedesignScreenshotUITests` and a Codex review
     (Claude builds, Codex reviews — or the reverse, never the author).

0000. **Machine deletion (`.scratch/machine-deletion/issues/01-delete-machines.md`) MERGED to
   `main` 2026-09-10 — Codex clear after TWO rounds — and INSTALLED 2026-09-10 15:40 EDT
   (`c8843ce` = `main`; no schema change), with FRESH profiles: app and widget both expire
   **2026-09-17 20:14 UTC**. The remote launch was refused (phone locked) — the user opens it.** The user's ask: "delete added
   machines from gym (whether mid workout, or just at gym tab)". Built: a trailing swipe "Delete"
   (no full swipe) and a "Delete Machine…" context-menu item on the machine rows of BOTH the
   Gyms tab and the mid-workout Add-by-Machine sheet, one shared alert ("Delete <label>?" /
   Delete Machine / Cancel), archival underneath (D10 unchanged — history keeps resolving), and a
   "Deleted machines (N)" row per gym → Restore (`EquipmentLifecycle.restore`, the SAME machine
   comes back). Shared component `Features/Gyms/MachineDeletion.swift`. Lesson: on iOS 26 a
   `confirmationDialog` rendered as a centred sheet with NO Cancel (seen in the UI test's
   accessibility tree) — the component uses `.alert`, which always shows both.
   - **Open question found on the way**: tapping a MODEL-LESS machine on the Add-by-Machine
     sheet did nothing in the Simulator (no exercise picker pushed); the one-exercise-model path
     works. The user's machines are scanned, so all have models — verify on the phone before
     chasing; if real, it is its own ticket.
   - Verification: 698/698 unit; `MachineDeletionUITests` 2/2; full UI suite 46/46 on `d35e725`.
   - **Next: the user opens the app (launch-verifies), tries delete/restore at the gym, and
     reports Ask AI + the bigger box (still unreported since 09-06).**

000. **Ask AI (tickets 05 + 06) MERGED to `main` 2026-09-06 — Codex clear after FOUR rounds
   (`codex-review-05..05d`) — and INSTALLED, launch-verified 2026-09-06 12:59 (`3b3c22c` =
   `main`; no schema change).** The user's decisions: button first
   (no automatic send), developer-only keychain key now, other users later — so the client is
   proxy-shaped (`AnthropicMessagesClient.Credential` .apiKey | .bearer, endpoint a parameter).
   **Next: the user pastes their key under Settings → "Ask AI about plates" (the app has NO key
   until then — the button never appears) and tries it at the gym on a plate that fails on-device;
   report the bigger box too. ALSO before 2026-09-11: sign the Apple ID back into Xcode
   (Settings → Accounts) — see the gotcha; the install reused the profiles expiring 09-11 01:08 UTC
   because Xcode had no account to mint fresh ones.**
   - **What is on the branch**: the framing box enlarged (94 % width, 2:1 — user's gym photo
     showed it small); **05** `Domain/PlateTranscription.swift` + `LabelCrop.swift` (pure),
     `Features/Gyms/AskAI.swift` (transport + who answers), `AskAIKeyStore.swift` (keychain),
     `LabelCropRendering.swift`, `Settings/AskAISettingsSheet.swift`, the scan sheet's Ask AI
     section; **06** `Domain/ExerciseProposal.swift`, the New Model sheet's "Suggest exercises with
     AI". D53 added, D34 amended, CLAUDE.md → D53. Tickets: `.scratch/scanner-accuracy/issues/05-…`,
     `06-…` (each with a Resolution and, for 05, the Codex round-1 response).
   - **The experiment that justified it** (`issues/llm-reader-experiment.md`): on the same 41
     plates Claude Sonnet 5 → top-1 10/12 (Vision 8), preselected 6 (5), wrong 0 (0), every
     logo-only brand read, nothing invented, ≈ 0.7¢ a plate. Re-measured with the production
     prompt after Codex round 1: identical (`reports/llm-sonnet-2026-09-06b.md`). `Config/anthropic.key`
     (gitignored) is the developer's key for the tooling; the APP takes its key from the keychain
     via Settings → "Ask AI about plates" — the user has NOT entered it on the phone yet.
   - **Codex round 1** (`codex-review-05.md`) found two highs, both real and fixed in `8fb8b80`:
     the library photo would have left the phone whole (now: no box → no crop → no Ask AI, fail
     closed) and an ask could outlive a rescan (now a cancellable task keyed by identity). Plus:
     bearer credential, `ScanFixture` gated by `fixtureIsEnabled`, pixel-level crop tests, the
     experiment script mirrored to the production prompt.
   - **Codex round 2** (`codex-review-05b.md`, with ticket 06): three mediums, all fixed — a
     near-frame box whose margin became the frame (now nil; the fixture plate sits on a canvas so
     its box is a box), the proposal request outliving Cancel/Add (now a cancelled task), SPEC still
     saying "nothing leaves the phone" (SPEC + D53 now name both opt-in sends) — plus the counting
     client (`AskAIFixtureLedger`, "AI calls: N" under the fixture) and a timeout test.
   - **Codex round 3** (`codex-review-05c.md`): the frame guard was equality-only (now: a crop may
     cover at most 90 % of the photo's area, `LabelCrop.maximumAreaShare`); SPEC/D53/the sheets now
     say EXACTLY what leaves (box + 8 % margin; brand, model, lines + exercise list); the STATE
     placeholder Codex caught is gone. **Round 4: clear** — the ceiling sits above any real box
     (≤ 40.9 % of the photo on a portrait phone).
   - **Verification after round 2**: 697/697 unit; `AskAIUITests` 7/7 + `ScanMachineLabelUITests`
     2/2. The FULL UI suite ran on `6242324`: 43 tests, 42 passed, one cold-launch flake in the Ask
     AI happy path's gym helper (hardened since); after round 2 the full suite ran again on
     `e5ef77c`: **44/44**. Round 3's changes were a crop threshold, wording and a test — covered by
     the unit suite and `AskAIUITests` 7/7 at `9d5e79d`. The full suite takes ~24 min here; run it
     detached (`nohup … &`) and watch the log — a tool timeout killed one run at teardown.
   - **Then**: ROC-IT → Hoist alias and a floor so one generic word cannot reach 44 % (matcher
     tickets), ticket 07 (on-device brand prior + chip), ticket 04 (read quality).


00. **Scanner accuracy — in progress on branch `scanner-accuracy`, tickets in
   `.scratch/scanner-accuracy/`.** The user's complaint: the scanner reads logos as text and
   misreads the brand. Built and measured, not guessed:
   - **01 — corpus + harness (on `main`, `419a04a`).** 41 real name-plate photos (gitignored;
     manifest committed) and `WorkoutTrackerTests/ScannerCorpusHarness.swift`, which runs the
     app's own OCR + matcher over them and writes `reports/latest.md`. Baseline: top-1 7/12,
     preselected 3/12, wrong 0. The rows showed the cause: logos read as corrupted brand tokens
     (`SCYBEX`, `HOISI`, `LieFitness`) that the matcher counts as no brand.
   - **02 — reading repair (merged to `main` 2026-09-05), Codex clear after FOUR rounds.** Brand
     repair only on a line that is nothing but the brand, dictionary- and digit-refused; slash
     split corroborated by one row's name. Result: preselected 3 → 5, top-1 7 → 8, wrong 0.
     **Read the four reviews before touching the matcher again**: rounds 1–2 each found the
     repair manufacturing brands from prose or letting a stray word preselect a sibling; a
     "prefix sibling" exception was tried twice and REMOVED — D33's margin stands.
   - **03 capture-first — MERGED to `main` 2026-09-05, Codex clear after FOUR rounds**
     (`issues/03-capture-first.md`):
     the viewfinder keeps the preview and torch, a plate-shaped framing box, a one-tap shutter,
     one still read once inside the box; the live loop and `LiveScanStabilizer` are deleted.
     Round 1 found the box mapped through AVFoundation's UNROTATED metadata space (a wide box
     became a tall strip) — replaced by pure aspect-fill geometry on the upright photo, pinned
     with numbers — and a rebuilt camera replaying the previous shutter tap. **Only the gym can
     verify the box lands on the plate** (the Simulator has no camera). Then 04 read quality
     (junk filter, burst voting), 07 brand-as-logo (gym prior + brand chip; was 05 until Ask AI took the number).
   - **INSTALLED 2026-09-05 (evening): `1fd8cbf` = `main`**, tickets 02 + 03. The install succeeded
     (`devicectl` lists 0.1.0) but the remote LAUNCH was refused twice with
     `FBSOpenApplicationServiceErrorDomain error 1` — the phone was locked; the user was asked to
     open it. **Not yet launch-verified by anyone.** No schema change in either ticket. Profiles
     reused (app and widget expire 2026-09-11 01:08 UTC). Next: the user's gym report on the
     viewfinder — does the box land on the plate, is focus sharp at arm's length, is it faster.
   - Lesson (memory too): a backgrounded `xcodebuild … | grep` reports grep's exit 0 even when
     tests failed — read `** TEST SUCCEEDED **` in the log before claiming green. And Orca can
     block `terminal send` to a terminal (`agent_prompt_blocked`); start a new Codex terminal
     with the prompt on its command line.
0. **The finish-graph work — branch `finish-graph-and-plain-numbers`, MERGED into `main` 2026-09-05
   (fast-forward; `main` still has zero merge commits) — two tickets in
   `.scratch/finish-graph-and-plain-numbers/`, from the user's first real workout on the
   milestone-9 build (66:51, avg 122, max 141):**
   - **01 — the heart-rate graph redrawn in Apple Fitness's shape.** Thin floating range bars
     (per-bucket LOW/HIGH beside the mean — two new `[Int]` on `Workout`, **export schema 9**),
     merged to at most 110 slots, the axis labelled only at the drawn low/high, clock times, the
     average under the plot. `-uiTestHeartRateHistory` seeds a 60-minute series for the
     screenshot (`history-heart-rate-hour`). **Codex clear after 3 rounds** (01, 01b, 01c); round 1
     found that a fixture flag ALONE never selected the throwaway store — `-uiTestChartHistory`
     had the same hole since milestone 8 — now one guard, `WorkoutTrackerStore.fixtureIsEnabled`.
   - **02 — plain numbers: every on-screen ≈ and "(estimated)" removed, D52.** The user's call,
     twice ("just show number"). Data provenance untouched (`isEstimated`,
     `zonesFromEstimatedMax`, `ProgressPoint`'s per-contributor units, the export). D9/D25/D45
     rows annotated. Codex round 1 (`codex-review-02.md`) found "Est. 1RM" surviving in the chart's
     metric picker, four stale STATE lines, a D45 row that contradicted itself and a D52 clause
     that overstated "no conversion is stored" — fixed; round 2 found two more stale STATE lines;
     **Codex clear after 3 rounds** (02, 02b, 02c).
   - **Merged, pushed, and INSTALLED 2026-09-05 (`3d01052` = `main`), launched OK** — so the two new
     optional arrays on `Workout` migrated the real store. The user said "install" without
     confirming a fresh export; the last export is the 2026-09-04 one taken before the D51
     reclassification. The build reused the existing profiles (app and widget both expire
     **2026-09-11 01:08 UTC** — a rebuild does NOT extend them; delete the profile file first, see
     the gotcha below). The branch pointer `finish-graph-and-plain-numbers` is stale (identical to
     `main`, safe to delete). **Next session's first action: ask what the real graph looks like**
     after a real workout — the fixture is synthetic; only a real hour with AirPods shows whether
     the slot density and the y-range read right. Old workouts draw from means (ticket 01).
   - Housekeeping from the last handoff is DONE (2026-09-04): the three stale milestone branches
     are deleted locally and on GitHub; the old "Codex review 01" terminal is closed. The reviews
     for this branch ran in an Orca terminal last titled "Codex review — finish graph"; whether it
     is still open depends on whether Orca is — check `orca terminal list`, do not assume.
   - **Lesson (memory too):** detect a finished Codex review by the report FILE's mtime, never by
     `orca terminal wait --for tui-idle` — it never fires while Codex sits at "Worked for …", and the
     user had to relay three results before that was noticed.

1. **Milestone 9 is MERGED into `main` (`97b656b`, 2026-09-04, fast-forward — `main` still has zero
   merge commits) and INSTALLED on the phone.** Five tickets: chart per equipment + History chart button (01), workout name (02),
   History calendar (03), dumbbell exercises with a one-time history reclassification (04), and the
   finish summary with a heart-rate graph (05). **All five are Codex-clear** (4, 4, 3, 4 and 6
   rounds; every round's findings and responses are in the ticket files). A sixth ticket was added
   after the install — **06, remove the explanatory helper copy** (user's ask; scope A: tutorials
   go, consequences stay as single lines) — copy-only, **Codex-clear after four rounds** (the rounds turned
   up that several "tutorial" lines were consequences — they came back as single sentences, and
   the chart's ≈ followed each metric's real contributors — until D52 removed every ≈ the next day). Ticket 06 is on the phone too (second
   install of the day, no schema change). (The milestone-7/8/9 branch pointers were deleted on
   2026-09-04 — point 0.)
2. **In flight: the finish-graph branch in point 0.** After it, the likely next actions, in order:
   - **Ask the user what the phone shows now.** Unseen by anyone but them: the charts against real
     history (variation picker naming their actual grips/equipment), a moved session's
     "Reclassified from …" line, the finish sheet's tiles and heart-rate graph after a REAL
     workout (the fixture drew 3 bars; a real hour is ~240), the calendar, naming a workout.
   - **The free Apple Watch experiment** (further down): one workout wearing the watch with nothing
     installed on it, read the source label. Still the single cheapest, highest-value unknown; it
     decides whether `WorkoutTrackerWatch/` is deleted.
   - Then the backlog: milestone 6's second half (plate math, stack increments), the milestone-8
     leftovers (superset reorder, superset grouping in History), the deferred watch companion.
   - **CI: the user said to leave the hanging runner alone (2026-09-04).** Do not spend time on it
     unless asked; the local suites are the gate (CLAUDE.md). The note under Environment gotchas
     stays so nobody rediscovers it.
   - ~~Housekeeping: delete the three stale branch pointers; close the "Codex review 01" terminal.~~
     **Done 2026-09-04** (point 0).
3. **The phone runs `97b656b` = `main` — installed and launch-verified 2026-09-04 (evening),
   after an earlier install of `66bc7d4` that morning (the milestone before ticket 06).**
   The user exported first (CSV+JSON to iCloud Drive, 2026-09-04) — that export is the backup that
   predates D51's reclassification. The launch opened the real store through four optional-field
   additions (`Workout.name`, entry provenance, `heartRateSeries`/basal, the preferences record) and
   catalog v5, and ran the reclassification. **Settings' "History update" row on the real store says 18 sets moved**
   (user report, 2026-09-04) — so the reclassification found real dumbbell-tagged history and the
   export taken just before it is the record of what those 18 sets said before. Profiles still expire **2026-09-11 01:08 UTC** (this build reused the same
   profile; the clock did not move).
4. **Suites on the merged tip: 655 unit green in full; all 37 UI tests green on the branch** — 21 on
   the final tip (ProgressChart, Tooltip, HeartRateSummary, ExercisePreset, Barbell, Dumbbell,
   Export, Calendar, Scan, WorkoutName) and 16 (HeartRate, CoreLoop, HistoryEditing) on `2262b0f`,
   after which only STATE, a metric label and the shared weight-label helper changed. One preset
   test went red once (app unresponsive after Done, no crash report) and passed alone. Before that,
   on `main` at `97b656b`: 644 unit + 36 UI. The full UI
   suite ran on the pre-06 tip as the merge gate, and every class ticket 06 touched (23 tests)
   re-ran green on the final tip; run 2026-09-04 in three pieces (a single full run was
   killed twice at the harness's 10-minute foreground limit; the pieces were CoreLoop+Barbell+
   Dumbbell+Presets, then Presets+Export+HeartRate+Summary+Scan, then Calendar+HistoryEditing+
   Charts+Name). Whole-suite time is now ~22 minutes; run it in chunks under ten if the harness
   caps foreground commands.
5. **Two new locked decisions: D50** (a workout's name is editable in History as a marked edit,
   reopening D47) and **D51** (the one catalog-driven reclassification of frozen snapshots,
   reopening D19/D23/D47 narrowly, with per-row provenance). Both were reopened deliberately only
   after Codex caught the first cuts drifting from the locked decisions — the lesson is in point 7.
6. **The habit that has paid off most here:** the user tests on the device and reports plainly, and
   Codex cross-reviews catch what the tests do not. **The absence-of-a-caller / contract-vs-caller
   family is now NINE deep**: the watch rest countdown, deletion volume, export flags,
   `enableBackgroundDelivery`, `pruneOrphanGroups`, `moveEntry`, the chart preset pooling,
   `chartVariationPicker` (an identifier no test named), and — found by Codex in ticket 05 — the
   coordinator's own comment claiming "Finish it and start new" banked the heart-rate summary
   when that path never reached it, so every replaced workout had lost its aggregates since
   milestone 7. Grep for uncalled funcs and re-read doc comments against callers before closing.
7. **What milestone 9's seventeen Codex rounds taught, in one line each** (details in each
   ticket's "response" sections under `.scratch/milestone-9-history-and-summary/issues/`):
   - A green suite around a fix is not evidence the fix is visible (01).
   - Reusing an existing export column for a new meaning is a silent format change; append (02).
   - "Only its numbers" in D47 is a boundary, not a suggestion — reopen, don't drift (02, 04).
   - A test that passes in the full suite can be order-dependent; Codex's focused runs caught two
     (04: preset label chose by fetch order; 05: none, but the lesson stands).
   - SwiftData refuses a captured enum in a `#Predicate`, optional or not, and the failure is a
     LAUNCH crash when the predicate runs at launch (04).
   - A one-shot version gate for a data migration misses history that arrives later; run it every
     launch behind a cheap count, idempotent by construction (04).
   - `BarMark` on a quantitative x-axis draws no bars; only the screenshot caught it (05).
   - Merging two sensors' samples needs a rule that admits a real handoff and rejects a stray;
     "within 15 s" broke an older regression, "inside a >60 s outage or a sustained run" holds (05).
   - XCUITest: tapping an identified picker row under the keyboard can silently do nothing;
     tapping the row's text works (04). STATE already said this for a second exercise; it bites
     the first when the search has several matches.
   - Unquoted shell heredocs eat backticks in review prompts; quote them (`<<'EOF'`) (03).

Milestones 7 and 8 are merged, installed, and their phone-side features are
confirmed in real use. **Neither is COMPLETE by its own acceptance criteria**, and saying otherwise
was this file's own error until a cross-review caught it: milestone 7's watch companion has never
been compiled or run (a sketch — see below), and milestone 8 still owes superset reordering and
superset grouping in History. Milestone 5 was dropped (**D49**). What remains of the v1 plan is the
second half of milestone 6 (plate math, stack increments) — plus a **critical charting defect found
by cross-review on 2026-08-29**: charts pool presets, contradicting D36. See "Milestone 4" below. The day's work: reorder
exercises, add/remove in history, the chart tooltip, and a reinstall after the signing profile
expired mid-afternoon.
**Read this after `CLAUDE.md`** — SPEC and DECISIONS say what the product is and why; this says
what has actually happened and what to do next. Keep it current; it is the one file that goes
stale fastest.

## Status

Merged and pushed on `main`: **everything, including milestone 9** (`97b656b`, merged 2026-09-04 —
fast-forward, so `main` still has zero merge commits). **644 unit + 36 UI green on 2026-09-04.**
Milestone 9 added 76 unit tests and 9 UI tests across its six tickets (`.scratch/milestone-9-history-and-summary/`).
**Milestones 7 and 8 are both MERGED into `main`** (2026-08-25 and 2026-08-29, both fast-forward —
`main` still has zero merge commits). Their branch pointers, and milestone 9's, were deleted locally
and on GitHub on 2026-09-04; everything they contained is in `main`. **Check `git log --oneline origin/main..main` before
believing `main` is pushed** — it was one commit ahead on 2026-08-29. `github.com/ericlee4992/workout-tracker` (private).

| Shipped | What it is |
|---|---|
| Milestone 2 (`ce32158`) | Core loop on SwiftData — logging, prefill, PRs, snapshots, rest timer |
| Milestone 3 (`798372c`) | CSV/JSON export, D28–D32 — the only backup that exists |
| Label scanning (`64188e2`, `33be96d`; capture-first + reading repair 2026-09-05) | Viewfinder with a framing box and a shutter reads one still of a machine's name plate inside the box, repairs logo misreads, ranks the 1877-model catalog, user confirms (D33–D35) |
| Exercise presets (`33be96d`) | Grips / single-double as variations that **split records** (D36–D38) |
| Collaboration setup (`b5dfac9`) | Signing moved to a gitignored `Config/Local.xcconfig`; CI runs unit tests on every PR |
| Barbell bar weight (2026-08-22) | Pick the bar, type plates per side, log the total (D39–D40). Half of milestone 6, brought forward |
| Milestone 9 (`97b656b`, 2026-09-04) | Chart per equipment + History chart button; workout name (D50); History calendar; 14 dumbbell exercises with the one-time reclassification of dumbbell-tagged history (D51, 18 sets moved on the real store); finish summary with total calories and a heart-rate graph, also in History; explanatory copy removed. Export schema 8 (9 since the finish-graph work, 2026-09-04), CSV 37 columns, catalog v5. 21+4 Codex rounds |

**Milestone 7 — heart rate (D41–D45), committed on branch `milestone-7-heart-rate`.**
Live HR on the workout screen from AirPods Pro 3 or an Apple
Watch, zones, system calories, a heart-rate rest timer, and a finish summary. 8 tickets in
`.scratch/milestone-7-heart-rate/`, all resolved; two Codex rounds run and every critical fixed
(`codex-review.md`, `codex-review-2.md`), each with a regression test in
`CodexReviewRegressionTests`.

The milestone began at `428ab7a`; zone fixes and the completed bar-weight review/fixes are also
committed on `milestone-7-heart-rate` through `4bbe3e8`. **Merged and pushed 2026-08-25.** `main` is `ca67603`; the branch is no longer ahead of it. Merging is the user's call. After the bar fixes, the complete unit suite
is **451 tests across 42 suites**, and the 4 affected UI tests are green (two existing plus two new
regressions).

**Independently re-run on 2026-08-24 (T6's "verify independently" rule): the COMPLETE suite —
451 unit + 21 UI — passed, exit 0.** Codex had run only the 4 affected UI classes; this was all
21, and it confirms nothing elsewhere regressed. This is the number to trust for the branch tip.

**Verified once, so nobody re-derives it:** the **free** Apple account provisions all three
HealthKit entitlements including `background-delivery` — no Developer Program needed. The iPhone
workout-session API is `ios(26.0)`, hence D42. The Apple Watch is **not** a GATT peripheral to the
phone, which is the entire reason a watchOS target exists.

**Partly proven on hardware, 2026-08-23.** The user reported: *"the heart rate correctly measures
during workout."* That is the first real-sensor evidence this milestone has, and it clears the
biggest unknown — the permission flow, the phone's `HKWorkoutSession`, the live feed reaching the
workout screen, and the number itself all work on the device.

**The source question is settled (2026-08-24): the bar read "AirPods."** The phone's own
`HKWorkoutSession` was reading the earbuds, exactly as designed — the Watch was NOT feeding it. So
D41's watch target is still justified and the milestone's design holds as written. Do not reopen
this one.

**The same session found a real bug, now fixed (2026-08-24): no zone ever appeared.** See
"Zones were unreachable" below.

Be precise about what the gym session does and does not cover. **Verified:** a live, correct bpm
from AirPods on the workout screen during a real workout. **Still unverified:** the calorie
figure's plausibility; the heart-rate rest timer (D43); the background alarm with the screen off;
and the entire `WCSession` path.

**Zone boundaries were revised 2026-08-24 after gym use** — every zone read about one too high, so
D45's textbook 50/60/70/80/90 became **55/65/75/85/95** (see DECISIONS). The user is on the 220−age
estimate, which runs low for fit people and inflates every percentage; raising the max was offered
and declined in favour of shifting the boundaries. **Cost, stated plainly: this app's "Zone 3" is
no longer Polar's or Apple's Zone 3.** A measured maximum would let them go back to standard.
The revised numbers are **installed as of 2026-08-25** but have not yet been seen in a gym.

**Zones were verified working on the device (2026-08-24), at the OLD boundaries.** After the `0c9bdeb` install the user set a
maximum and reported: *"The zone feature correctly works."* The user also checked the app's zone
boundaries against an external reference (50/60/70/80/90/100% of max) and confirmed they match —
they are identical to D45 as built, so **no change was made**. Two deliberate extensions beyond
that reference were raised and explicitly left as-is: sub-50% renders "Warm-up" rather than Zone 1,
and a bpm above the recorded maximum stays Zone 5 rather than erroring.

Not established: whether the user supplied a MEASURED maximum or the date-of-birth estimate, so
the DOB path (see the test gap below) is still unconfirmed either way. (The "(estimated)" marking
D45 used to require on screen was removed by D52 on 2026-09-05 — nothing left to see there.)

### The background rest alarm — four attempts, and why the first three failed

**Solved 2026-08-25 (`82a1ddb`), confirmed on the device.** Worth reading in full: the same trap is
waiting for anything else that must happen at a moment in time while the app is not on screen.

**The rule:** iOS promises a backgrounded app NO CPU at a chosen instant. Any feature designed as
"run code when the deadline arrives" is therefore built on something the platform does not offer.
The fix is not to fight for background execution — it is to **remove the need to execute at all**.

The rest deadline is known the moment the rest starts, so the beep is handed to the audio pipeline
THEN, as one asset: `[inaudible dither for N seconds][beep]`. At the deadline nothing runs; the
beep is the next part of a buffer already playing. `RestAlarmTone.restTrackWav`.

Covers **both** rest kinds — a plain timed rest and D43's cap queue identically. Early heart-rate
recovery cannot be queued (its moment is unknowable in advance), so it plays live when the app is
executing, with the queued cap track as the floor.

**Three failed attempts, each fixing a real-but-not-decisive thing:** play at the deadline; add
background modes and move the alarm off the dismissable view; loop an inaudible keep-alive. All
three kept the "execute at the deadline" dependency, which was the actual defect.

**What made it take four rounds, and what to do differently:**

1. **A scheduled local notification firing was read as proof the app was running.** It is not. A
   `UNTimeIntervalNotificationTrigger` is handed to the system in advance and fires whether or not
   the app is alive. That single wrong inference cost two attempts.
2. **Assertions were made without checking Apple's documentation.** "`workout-processing` is
   watchOS-only" was stated as fact and written into the plist as a comment. It is FALSE on iOS 26,
   which brought workout sessions to iPhone. `.mixWithOthers` was likewise blamed and was innocent.
3. **A safeguard was defeated in the function next to it.** `keepAliveSamples` dithers at ±1 LSB so
   output is never digital silence; `startKeepAlive` then set `volume = 0.01`, scaling it to ~3e-7.
4. **The user was right that it should not be complicated.** Their push — *"I don't think this
   should be a complicated problem"* — and their reframing (*the notification already fires at the
   right instant; can it just be audible?*) is what produced the working design. Notification
   sounds play on the phone's ALERT route and iOS gives apps no way to send them to Bluetooth
   headphones — but that reframing exposed the real question: **is an audio route to the AirPods
   open at that moment?**
5. **Two independent consultations disagreed, and that was the point.** Codex first concluded no
   supported API could do this and recommended AlarmKit; Fable 5 found that wrong on iOS 26 and
   validated the pre-rendered design. Re-asked, Codex reversed itself: *"technically narrow but
   practically wrong for this case."* AlarmKit would ALSO have failed — iPhone alarms deliberately
   play through the built-in speaker — so building it would have burned a fifth attempt.

**Not verified:** ducking. It is deliberately not applied to the queued beep, because ducking needs
code at the deadline — the very dependency this removes. The beep mixes over music at full scale.

### Zones were unreachable — fixed and installed 2026-08-24 (`0c9bdeb`)

The user ran a real workout, got live heart rate, and never saw a zone. Two bugs, compounding:

1. **A closed loop.** `MaxHeartRateSheet` is the only place `measuredMaxHeartRate` / `birthDate`
   can be set, and its only entry point was the "· zone estimated" button in `HeartRateBar` —
   which renders only when a zone already exists, which needs the maximum that sheet sets. Both
   fields are nil on a fresh install, so `resolvedMaxHeartRate()` returned nil, no chip rendered,
   no button rendered, and the feature could never be switched on by anybody. D45 says "with no
   basis, show no zones", and the code did that faithfully — while offering no way to supply a
   basis.
2. **Stale after saving.** `resolvedMaxHeartRate()` was read only inside `.task`, which runs once
   per appearance, so a maximum entered mid-workout left `monitor.maxHeartRate` nil for the rest
   of that workout — the setting appearing to do nothing.

Fixes: a "· set up zones" prompt in the bar when there is no maximum (`hrZoneSetup`), a **Heart
rate zones** row in Settings showing the current basis or "Not set", and a re-resolve on the
sheet's `onDismiss`. Two regression tests in `HeartRateUITests` (`testZonesCanBeSetUpFromTheWorkoutScreenAndApplyImmediately`, `testZonesAreReachableFromSettings`). **449 unit + 19 UI green at the time; the branch tip is now 451 + 21** after Codex's bar-weight fixes added two more UI regressions.

One gap, deliberately: the setup test drives the MEASURED-max field, not the date-of-birth toggle. `app.switches["useBirthDate"].tap()` lands on the row label and does not flip the switch — an XCUITest quirk, not an app defect, but it means the DOB path is untested and it is the path a user without a lab test actually takes. Zones themselves are confirmed working on
the device (2026-08-24), but the user did not say which basis they entered, so this gap is still
open: if the DOB toggle was never used, it has not been exercised by anything (the on-screen
"(estimated)" marking it used to drive is gone since D52).

**This is the same class as the watch rest-countdown bug below** — every piece individually
correct, the *absence of a caller* the only defect — and again two Codex rounds did not catch it.
Worth noting the pattern: both were found by a human using the feature, not by review or by tests.
A test asserting "no zone without a basis" passed happily while the basis was unsettable. **When a
feature is gated on a setting, assert the setting is reachable**, not just that the gate works.

Everything still unverified came from `FixtureHeartRateProvider` under `-uiTestHeartRate`.

**The phone is now current with the branch** (`0c9bdeb`, installed 2026-08-24) — the watch
rest-countdown mirror fix rode along with the zone fix.

**Worth knowing how that bug was found**, because it is a class the review process missed: the
watch screen rendered a rest countdown, `WatchLink` carried a `restEndsAt` field — and nothing ever
sent a non-nil one. Every piece was individually correct; only the *absence of a caller* was wrong,
and no test asserts that a message is ever sent. Two Codex rounds did not catch it. It surfaced
while explaining the feature to the user in prose.

**Two things are true and easy to miss:**

1. **Bar weight merged before its cross-review, but that debt is now closed** (see Reviews in
   `DECISIONS.md` and `.scratch/barbell-bar-weight/codex-review*.md`). The review found and fixed
   stale cross-unit input, stale preset-prefill UI, mixed-source carry-forward, invented variable
   bar presets, incomplete bar normalization, and related contract gaps. The D39 invariant remains
   load-bearing: `weightValue` is the total and bar fields are provenance.
2. **Almost none of it has met a real gym.** The scanner has never read a real name plate; no
   preset has been logged against in a session; bar mode has never been used to load a bar. Every
   threshold and layout is tuned against fixtures. Those answers should shape the next session
   more than the backlog does. (One item came off this list on 2026-08-22: an export of the real
   history now exists, in iCloud Drive.)

The app is being **dogfooded in real gym sessions** — that is the current activity. Feedback from
those sessions outranks new features.

## The live install (facts you cannot rediscover from the code)

| Thing | Value |
|---|---|
| Installed commit | **`2ce4579`** — **current with `main`**, installed **2026-09-11 10:24 EDT** and launched remotely (`devicectl … launch` succeeded; the user has not yet confirmed on the phone): the WHOLE UI redesign, tickets 01–09 — new app icon (amber dumbbell), cards everywhere, Settings behind the gear, the Live Activity in the app's colours; no schema change; the binaries were checked for `WrapLayout` (app) and `ActivityTheme` (widget) in their `.debug.dylib`s (Xcode 26 debug builds put the code there, not in the main executable); profiles REUSED, both still expire **2026-09-17 20:14 UTC**. Previously **`84610c9`**, installed and launch-verified 2026-09-10 (evening): the redesign's first two tickets; no schema change; profiles reused (09-17). Over USB — the Wi-Fi tunnel stayed `unavailable` for ten minutes with the phone unlocked on the same network (see gotcha). Previously **`c8843ce`**, installed 2026-09-10 15:40 EDT, launch verified by the user: machine deletion + restore; no schema change. The binary was checked for `deleteMachine` / `restoreMachine`. **Profiles RENEWED**: the Apple ID was back in Xcode, the two profile files were moved aside (backup `~/Desktop/wt-profile-backup-2026-09-10/`) and the build minted fresh ones — app and widget both expire **2026-09-17 20:14 UTC**. Previously **`3b3c22c`**, installed and launch-verified 2026-09-06 12:59: Ask AI (tickets 05–06), the bigger framing box. Previously **`1fd8cbf`**, installed 2026-09-05 (evening), launch not verified then (phone locked): the scanner's reading repair and capture-first viewfinder (tickets 02–03 of the scanner-accuracy work). Previously **`3d01052`**, installed and launch-verified **2026-09-05 (early morning)**: the finish-graph work (Apple-shaped heart-rate chart with per-bucket low/high — a two-array lightweight migration on `Workout` — and D52's plain numbers). Previously **`97b656b`**, installed and launch-verified **2026-09-04 (evening)**; the same day's morning install of `66bc7d4` (milestone 9 before ticket 06) ran the D51 reclassification on the real store — **18 sets moved** — with a CSV+JSON export taken to iCloud Drive immediately before it. Previously **`5a860bc`**, installed and launch-verified **2026-09-03 21:09**. This build carries `3ad382d`, so the device now draws **one chart line per variation** (D36) with a Variation picker; the binary was checked for `chartVariationPicker` before installing, and no SwiftData model changed between `4eb5486` and here, so there was no migration. Previously `4eb5486` — the chart tooltip, one behind `main`. **REINSTALLED 2026-08-29 17:57** after its provisioning profile expired (see the expiry gotcha below); same code, fresh signature, profile now good to **2026-09-05 21:57 UTC**. Originally installed **2026-08-29 17:42**, launch-verified, and the binary checked for the new code before installing (see the device-build gotcha below). Previously `5b962b0` — drag-to-reorder exercises (the workout screen is now a List), plus add/remove exercises in history. Installed **2026-08-29 14:41**, launch-verified. Previously `0f164c8` — reorder exercises mid-workout, add/remove exercises in history. Installed **2026-08-29 13:34**, launch-verified. Previously `629c925` — milestone 8 plus the 2026-08-26 gym fixes (weights shown in the app's own unit; swipe-to-delete). Installed **02:30**, launch-verified. Previously `3e98e33` — all of milestone 8: load-type correction, history editing, progress charts, supersets, and the lock-screen Live Activity. Installed **2026-08-26 02:06** and **launch-verified**, so the THREE-WAY schema migration (`Exercise.loadTypeUserOverridden`, `Workout.historyEditedAt`, `ExerciseEntry.supersetGroupID` + `TemplateItem.supersetGroupID`) opened the user's real store and the app stayed up. Clean-built, and the plists checked before installing: HealthKit strings, `NSSupportsLiveActivities`, `UIBackgroundModes`, and the embedded widget's `NSExtension`. **This build carries the first new TARGET since the watch app** — `WorkoutTrackerWidget`. The **watch companion is still NOT installed** (ticket 02) |
| Previously installed | `82a1ddb` (the working background rest alarm), 2026-08-25 02:11 |
| Previously installed | `f5cc50a` (revised zones + first audible alarm), 2026-08-25 00:06 — the alarm in that build only sounded while the app was on screen |
| Previously installed | `a32755b` (milestone 7 + bar-weight review fixes), 2026-08-24 16:37 — launch-verified; this is the build that migrated `barNormalizedKg` onto the real store |
| Previously installed | `0c9bdeb` (zone-reachability fix), 2026-08-24 00:32 — never launch-verified, superseded hours later |
| Previously installed | Milestone 7's uncommitted working tree, 2026-08-22 23:45. It launched, so the D44/D43/D45 optional fields migrated the user's real store |
| Previously installed | The bar-weight merge (2026-08-22, installed 16:31 — the content is what is now on `main`, built from the working tree just before the merge commit existed). Installed before its Codex pass at the user's request, with a backup taken first (below) |
| Store migration | **Done on the real store, 2026-08-22.** `main` (`a3a6934`) was installed first so an export could be taken, then the branch build; it launched, so `SetRecord.barWeightValue` migrated the user's actual data. `a3a6934` can no longer open that store — the migrated schema is one-way without the export |
| Backup | **Re-exported 2026-09-04 by the user, immediately before the milestone-9 install and its D51 reclassification** — the current backup, and the record of what the 18 moved sets said before. Previously 2026-08-24, before the `barNormalizedKg` migration. Previously: CSV + JSON to iCloud Drive on 2026-08-22 before that schema change — the first copy of the training history off the device. Re-export after any session worth keeping |
| Previous installed commit | `33be96d` (2026-08-12) — export, live label scanning, movement labels, presets |
| iPhone UDID | `00008130-001E10C01E62001C` |
| Apple Team ID | `X68M8SR6NA` — now in `Config/Local.xcconfig` (gitignored), **not** in `project.pbxproj` |
| Signing | **Free** Apple account → builds expire **7 days**. Last signed **10 Sep 2026 (16:14 EDT)**, so **app AND widget both expire 17 Sep 2026 20:14 UTC** (the two clocks agree; see the forced-renewal gotcha below). HealthKit entitlements verified signed INTO the binary, not merely present in the profile. A **rebuild that re-signs** resets the clock; merely reinstalling an already-signed build does
NOT — proved on 2026-08-29, when a 17:42 install kept a 17:46:59 expiry and died four minutes later |
| Bundle ID | `com.ericlee4992.workouttracker` (from `WT_BUNDLE_ID_BASE` in `Config/Local.xcconfig`) |
| Test simulator | `WT-iPhone` (create per CLAUDE.md if missing) |

**Reinstalling** preserves the user's data — same bundle ID keeps the container. Say so before an
install; that phone holds the only copy of the training history until an export is saved off it.

The wizard (`./scripts/install-on-device.sh`) is interactive and meant for a human. With the
signing identity and Developer Mode already in place, the direct path is three commands:

```sh
xcrun devicectl list devices                      # confirm udid 00008130-…, transport, tunnel state
xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -configuration Debug \
  -destination 'platform=iOS,id=00008130-001E10C01E62001C' -allowProvisioningUpdates \
  -derivedDataPath /tmp/wt-device-build build
xcrun devicectl device install app --device 00008130-001E10C01E62001C \
  /tmp/wt-device-build/Build/Products/Debug-iphoneos/WorkoutTracker.app
```

Gotchas seen doing exactly this on 2026-08-11: the phone pairs over **localNetwork**, and its
tunnel reads `disconnected` until something asks for it — the first install attempt died with
`NWError 60 - Operation timed out` and the identical retry succeeded. Do not conclude the phone is
unreachable from one timeout. `devicectl device process launch` additionally needs the phone
**unlocked**, and fails with `FBSOpenApplicationErrorDomain error 7` when it is not; that says
nothing about whether the install worked.

## Milestone 8 — open follow-ups, deliberately deferred

0. **The drag gesture works, confirmed on the device 2026-08-29** — *"drag works, and screen looks
   the same."* That settles both risks of converting the workout screen from a `ScrollView` to a
   `List` (needed because `.onMove` is List-only): the long-press drag does pick a card up without
   an explicit Edit mode, and the row-stripping preserved the card layout.

   **No automated test drives the drag, though.** One was attempted and deleted: it kept failing on
   its precondition — adding a SECOND exercise through the picker sheet — and **the identical test
   fails the same way on the previous commit**, so it was the test rather than the conversion. Two
   things worth knowing for anyone who tries again: **no existing UI test adds two exercises**, so a
   green suite says nothing about that path; and taps on a picker row under an open keyboard are
   unreliable in XCUITest.

All five tickets are built and both Codex rounds' findings are fixed, but these were left and should
not be rediscovered as surprises:

1. ~~`Supersets.nextMember` is dead code.~~ **Deleted 2026-08-29.** It answered "which exercise is
   next in this superset" for an affordance never built, and the A/B badges already convey the
   order. Kept as a note because the SHAPE keeps recurring: this repo has shipped the
   absence-of-a-caller bug **six** times (watch rest countdown, deletion volume, export flags,
   `enableBackgroundDelivery`, `pruneOrphanGroups`, and `WorkoutSession.moveEntry`, uncalled from
   milestone 2 until 2026-08-29). It is the single most reliable defect shape here, and the reviews
   catch it, not the tests. **Grep for uncalled internal funcs before closing any milestone.**
2. ~~Multi-point charts have no tooltip.~~ **Done 2026-08-29.** Touch the chart and a rule marks the
   day, with its as-entered value in a row beneath. Two things worth keeping:
   **`chartXSelection` does not fire for a chart inside a `List` row** — the list's scroll gesture
   wins — so selection uses an explicit `chartOverlay` + `DragGesture(minimumDistance: 0)`. And the
   detail sits in a row rather than a floating annotation, which would overlap the line it describes
   on a phone-width chart and is not reliably queryable by a test.
   Also added: **`-uiTestChartHistory`** (`Domain/ChartFixture.swift`), which seeds four weeks of
   history for one exercise. The simulator has no PAST, so every workout a UI test logs lands on one
   day and collapses into the single-point state — the drawn chart could not otherwise be tested or
   screenshotted. Same reasoning as `-uiTestScanFixture` for the camera. **Extended 2026-09-03 to
   seed THREE variations** (plain, Narrow grip, Wide grip) so the D36 variation picker renders at
   all. The plain series deliberately keeps the most days, because `defaultVariation` opens the
   chart on whichever has the most — that keeps the drawn series identical to what the tooltip test
   already drags across, so the extension is additive rather than a rewrite of that test.
3. **Supersets cannot be reordered, and History does not show grouping.** Both were in ticket 04's
   acceptance criteria. (Exercises CAN now be dragged to reorder, 2026-08-29, which moves a superset
   member as a side effect — but there is no way to reorder WITHIN a group deliberately.)
4. **The D48 invariant test is weak.** It evaluates one synthetic array rather than deriving inputs
   through production code before and after grouping. The invariant holds by inspection
   (`RecordGroupKey` ignores `supersetGroupID`), but the test does not pin it.
5. **The catalog audit from ticket 02 stays undone** — see that ticket for the reasoning.
6. **Installed and CONFIRMED WORKING on the device (2026-08-27).** The user verified the two pieces
   nobody could check from a Mac: *"The lock screen works, and superset also correctly functions."*
   That closes the Live Activity — a new target, a new framework, and a render no test can inspect —
   and the D48 rest rule in a real session. The heart-rate rest timer was confirmed the day before.
   Still unexercised in a gym: history editing/deletion (which act on the only copy of the training
   history), the progress charts against a long series, and the load-type correction.

## What to do next, in priority order

1. **Act on gym feedback.** Six questions are open and no test can answer them. The three newest,
   from the bar mode installed 2026-08-22:
   - Is **plates per side** what the user thinks in while loading, or total plates?
   - In bar mode PREVIOUS shows last session's **total** while the field takes **plates**. Does
     the `= 135 lb` caption reconcile that mid-set, or does it read as two different numbers?
   - Is a bar the user actually owns missing from `BarbellMath.presets`? Custom covers it, but a
     weekly bar belongs in the list.
   And the three still open from before:
   - Does the scanner read a **real** name plate? If it reads it but refuses to preselect, that is
     the D33 gate working, not a bug — a plate that does not name its manufacturer never
     preselects (95% of clean brand+model readings do, 0% of model-name-only ones), because a
     wrong model UUID splits history (D23). Thresholds live in `CatalogMatcher` (0.85 preselect /
     0.35 create-new / 0.08 margin), tuned against the catalog and rendered plates, not
     photographs. Retune only with real misses in hand.
   - Does the **export** look right over the real history in a spreadsheet?
   - Are the **preset chips** reachable one-handed mid-set? Their layout is guesswork.
2. **Milestone 7 is installed and partly proven.** Live heart rate works on the device
   (2026-08-23). What remains unanswered, in rough order of what it would teach:
   - ~~Which sensor produced it?~~ **Answered 2026-08-24: AirPods.** The design holds as written.
   - ~~Do the **zones** look right?~~ **Answered 2026-08-24: yes**, on the device, after the
     reachability fix. Boundaries were also cross-checked against an outside reference and match.
     What was still open — whether the "(estimated)" marking showed for a date-of-birth basis —
     is moot since D52 (2026-09-05) removed the marking; the DOB toggle itself is still unexercised.
   - ~~Is the **calorie** number plausible?~~ **Reported slightly high, 2026-08-24 — no code
     change made, deliberately.** The app never computes calories: it reads the system's own
     `activeEnergyBurned` from `HKLiveWorkoutBuilder`, already configured
     `.traditionalStrengthTraining` / `.indoor`. So the number IS Apple's, and there is no formula
     here to tune — inventing a correction factor would be the false precision D9/D25 exist to
     refuse. Likely causes are all outside the app: a stale weight in Health (most common), no
     Apple Watch so the estimate leans on heart rate alone (which runs high for lifting, since HR
     stays up between sets), and iOS being generous for strength training generally. **Told the
     user to check their weight in Health first.**
   - Does the **heart-rate rest timer** (D43) end a rest when the heart rate comes down, and does
     the alarm say which ended it — recovery or the cap?
   - ~~**Does the alarm fire when the app is not on screen?**~~ **SOLVED AND CONFIRMED ON THE
     DEVICE, 2026-08-25** (`82a1ddb`): *"it worked! the beep now plays with screen off."* See
     "The background rest alarm" below — it took four attempts and the lesson is worth reading
     before touching anything time-based again.
   - Historical, for context on how it was reached: Gym report 2026-08-25: the first
     audible build beeped **only while the app was open** — nothing with the screen off, on another
     app, or on the home screen. Three causes, all fixed in `37c0f2b`: `UIBackgroundModes` was
     missing `workout-processing` (so iOS suspended the workout session and no samples arrived at
     all — the real cause); the alarm lived in the workout SCREEN's state, which C1's minimise
     dismisses; and an audio failure called `assertionFailure`, which traps in a Debug build.
     **The lesson worth keeping: the local notification firing was NOT evidence the app was
     running.** A `UNTimeIntervalNotificationTrigger` is handed to the system in advance and fires
     regardless — it had been read as proof of background execution for two days.
   - **Is the alarm actually audible?** Gym feedback 2026-08-24: the notification fired
     both ways, screen off included, but nothing came through the AirPods — a notification sound
     plays on the phone's alert route and never reaches Bluetooth headphones. The app now
     synthesises a tone and plays it through `AVAudioSession` (`.playback` + `.duckOthers`), with
     recovery and cap sounding different (two rising tones vs three flat). **None of this has been
     heard by a human.** What to listen for: does it cut through gym noise and your own music, does
     the music duck and come back, and does the beep fire **with the screen off** — that last one
     runs off the heart-rate sample tick because a SwiftUI timer stops when the screen sleeps, and
     it needs the new `audio` background mode to play at all.
   - **THE FREE TEST, worth doing before any watch work: wear the Apple Watch during a workout with
     NOTHING installed on it, and read the source label on the heart-rate bar.** The user owns an
     Apple Watch (confirmed 2026-08-25). If the bar says **"Apple Watch"**, the phone's own
     `HKWorkoutSession` is reading the watch directly, **the whole `WorkoutTrackerWatch` target is
     unnecessary, and the right move is to DELETE it** — D41's premise would be wrong. If it says
     "AirPods" or nothing changes, D41 holds and the companion is genuinely needed. This costs
     nothing: no install, no signing, no Developer Mode on the wrist. It was previously written up
     as needing an install; it does not.
   - Does the watch companion install, pair, and stream? Nothing on that path is installed — no
     Apple Watch has ever been reachable from this Mac (`devicectl` sees only the iPhone). It is a
     **separate** install by design — embedding it breaks every simulator test run (ticket 02) —
     and it needs Developer Mode on the watch plus a second bundle id on the same 7-day clock.
   - **Open question nobody has answered:** can the phone WAKE the watch app? The design has the
     phone send "workout started" over `WCSession`, but iOS→watchOS messaging does not reliably
     launch an app that is not running. The likely reality is the user taps the app on their wrist
     first. Only hardware settles it.
   - Does the heart-rate rest alarm fire with the screen off? That is what
     `healthkit.background-delivery` was provisioned for and it has never been observed.
### `WorkoutTrackerWatch/` is a SKETCH, not a feature — do not trust it

**Decided 2026-08-25: build the remaining phone features first, install on the watch later.** That
is the right order and nothing is blocked by it — charts, CSV import and plate math are all
phone-side, and the two-source merge the watch would feed (`CompositeHeartRateProvider`, source
precedence, `dominantSource`) is already built and waiting.

But be clear about what that folder is. `WatchRootView.swift`, `WatchWorkoutModel.swift` and
`WorkoutTrackerWatchApp.swift` were written during milestone 7 and have **never been compiled onto
a watch, never run, and never seen a heartbeat.** Code that has not run once is a sketch. Budget
"write and test", not "install and go", and expect to rewrite parts.

**The specific rot to expect** is the class this project has already been bitten by twice: the
watch screen rendered a rest countdown and `WatchLink` carried a `restEndsAt` field, and **nothing
ever sent a non-nil one**. Every piece individually correct, only the *absence of a caller* wrong.
Two Codex rounds missed it; it surfaced while explaining the feature in prose. Untested mirror code
accumulates exactly that, and the phone side keeps moving underneath it.

So: no test asserts the watch is ever sent anything. When the watch work starts, **assert the
message is SENT**, not merely that the receiver handles it.

3. ~~Milestone 4 — progress charts.~~ **DONE — and it is worth being clear about how, because the
   numbering hides it.** Charts were never built as "milestone 4"; they arrived inside milestone 8
   (ticket 01), and the last piece SPEC asked for — *as-entered tooltips* — landed 2026-08-29 in
   `4eb5486`. All three things SPEC asked for exist: Swift Charts and the as-entered detail row in
   `WorkoutTracker/Features/History/ExerciseProgressView.swift`, normalization in
   `WorkoutTracker/Domain/ProgressSeries.swift`.

   **Two corrections this entry earned in cross-review, worth keeping because both are the kind of
   error that feels safe to write:**

   - It first said the old "next unbuilt milestone" line had been false **for three days**. It had
     not: the as-entered tooltip is *part of SPEC's milestone 4*, and it landed at 17:40 on
     2026-08-29 — about **35 minutes** before the correction. Until then the old line was
     defensible. Do not date a defect from when the FEATURE started; date it from when the last
     acceptance criterion closed.
   - It ended "Nothing in milestone 4 remains." That was false, and the defect was real —
     **FIXED 2026-09-03.** `ProgressSeries` read a nil `presetID` as *accept every preset* while
     `ExerciseProgressView` documented nil as *only sets logged with no preset*, and `ExercisesView`
     passed nothing — so narrow- and wide-grip histories were POOLED into one line, which **D36**
     forbids. The same call passed `exercise.loadType`, the CURRENT type, into a parameter
     documented as the D23 *snapshot* type, so a D47 correction could make old history vanish from
     its own chart.

     The fix removes the ambiguity rather than patching the caller: nil now means the no-preset
     group, as `RecordsMath.groupKeys` has always treated it, and **the chart resolves its variation
     from HISTORY** instead of being handed one by the live exercise. A `ProgressVariationKey`
     (snapshot load type + preset) is the unit; the chart opens on whichever the user has trained
     most, ties going to the plain exercise, and offers a picker when there is history under more
     than one. 8 tests in `ChartPresetScopingTests` — **there were none using presets at all**,
     which is why a caller could contradict its own contract in silence.
4. ~~Milestone 5: Strong CSV import.~~ **DROPPED 2026-08-29 at the user's request** — they have no
   Strong history to bring in, so the whole milestone imports nothing. SPEC's analysis of the format
   (no unit column, no workout id, set tags lost, equipment in the name suffix) stays there in case
   that ever changes; it is the hard part and it is already done.
   Remaining: Milestone 6 is now **half done** — the bar half shipped
   2026-08-22; what remains is computing which plates to load for a target weight, and
   selectorized stack increments.

**Owed from milestone 7's review, deliberately not fixed:** the migration fixture
(`WorkoutTrackerTests/Fixtures/LegacyStore.store`) was generated at `5239ef2` and the phone now
runs the bar-weight build, so the gate opens an older approximation of the real store than it
claims to. Regenerating needs the phone.

**Test-harness fact worth keeping:** a UI-test run started with `-uiTestReset` but WITHOUT
`-uiTestHeartRate` gets a `DisabledHeartRateProvider`. Without that, every XCUITest that starts a
workout summons the HealthKit permission sheet, which covers the screen and turns eight passing
core-loop tests into "button not hittable" — a failure that reads as a layout bug and is not one.

**Known latent bug, found while building bar mode, deliberately not fixed:** `Format.weight`
(`Domain/SharedEnums.swift`) renders to one decimal, and the set row's text becomes the stored
value on completion — so a prefilled 62.25 kg row commits as **62.3**. It only bites weights with
two decimals, which 2.5 lb/1.25 kg plate math does not produce, but it is a silent rewrite of the
user's own numbers. Bar mode's fields dodge it by seeding through `WeightMath.displayNumber`.

## Decisions the user has NOT made yet

- **Adding a human collaborator.** The repo was made ready for one on 2026-08-18 (per-developer
  signing, CI on PRs) and the user was weighing it. If someone joins, **D5 and T6 must be reopened
  deliberately**: D5 says the audience is the developer alone, and T6 justifies agent cross-review
  by there being no second pair of human eyes. Does a human PR approval replace the Codex pass or
  stack with it? Also unresolved: branch protection on `main` may need a paid plan for a private
  repo.
- **Apple Developer Program ($99/yr)** — needed for TestFlight, which is the only sane way to get
  the app to other testers and would also end the 7-day expiry. The user asked about it, weighed a
  free 2–3 family-member pilot first (possible, but every phone must be cabled to the Mac weekly).
  Prep work not started: app icon (**none exists** — App Store Connect rejects uploads without
  one), export-compliance key, upload script.
- **Catalog gaps worth closing** if the user hits them: Atlantis (dealer-sourced only), Titan and
  Sorinex (barely researched), Life Fitness Signature Series (discontinued but still on gym floors
  — the most commercially significant gap). See `docs/catalog-sources/README.md`.

## Environment gotchas that cost real time

- **The phone's Wi-Fi tunnel can stay `unavailable` indefinitely** (2026-09-10 evening: paired,
  unlocked, same network, ten minutes, a device build did not wake it). `xcrun devicectl device
  info details` shows `tunnelState: unavailable`; `xcodebuild` says "Unable to find a destination".
  A USB cable fixed it within seconds. Do not spend more than one retry on Wi-Fi — ask for the cable.

- **Xcode 26.6 had NO Apple ID signed in on 2026-09-06 — a device build cannot mint profiles.
  Resolved by the user by 2026-09-10 (the account list is populated again; the 09-10 build minted
  fresh profiles). Kept because it WILL recur after an Xcode update or a sign-out:**
  Moving the profiles aside (the fresh-7-days trick below) made the build fail with "No Accounts:
  Add a new account in Accounts settings" for both targets; `defaults read com.apple.dt.Xcode
  DVTDeveloperAccountManagerAppleIDLists` shows an empty list, though the team
  (`Eric Lee (Personal Team)`) is still remembered. The profiles were restored from the backup
  (`~/Desktop/wt-profile-backup-2026-09-06/`) and the build signed with them. **Before 2026-09-11
  01:08 UTC the user must sign the Apple ID into Xcode → Settings → Accounts** (password + 2FA —
  not an agent step), then delete the two profile files and rebuild to get a fresh week. Otherwise
  the app dies as "no longer available" on the 11th.

- **`HeartRateMonitorTests.samplesArriveAndBecomeTheCurrentReading` (and once
  `CodexReviewRegressionTests.theFeedStateNamesTheSourceOfTheReadingShown`) fail in a FULL unit
  run on a busy Mac — right after a UI suite, or with Codex reviewing alongside — and pass alone
  every time (13/13 in 0.015 s).** Seen four times on 2026-09-06; untouched since milestone 9.
  They are wall-clock staleness checks. Re-run the suite alone before believing a red; if it keeps
  happening, give the test a fake clock rather than a longer window.

- **The `anthropic` Python SDK (1.4.0) under anaconda dies on every response with
  `APIConnectionError` … `TypeError: process() takes no keyword arguments`.** Anaconda's `brotli`
  1.0.9 predates the `output_buffer_limit` keyword the SDK's bundled `httpx2` passes to the brotli
  decoder. `llm_reader.py` sends `Accept-Encoding: identity` on the client
  (`default_headers`), which sidesteps it without touching the global environment. Any other
  script that talks to the API from this Mac needs the same header or a newer `brotli`.

- **CI on `main` has been hanging in the "Unit tests" step since at least 2026-09-04 01:35 UTC —
  BEFORE milestone 9's code merged.** That run (docs commit `0207a96`) hit the workflow's 60-minute
  timeout; the run for the milestone-9 merge was superseded by `cancel-in-progress` when the docs
  commit landed, and that run was still in "Unit tests" after 20 minutes at the time of writing
  (locally the suite takes 18 s). Every earlier step passes (toolchain check, simulator pick), so
  it is the hosted `macos-26` image or a stuck simulator there, not the code — the same commits are
  green locally (644 unit, 36 UI). CI is a smoke alarm here, not a gate (CLAUDE.md); the local run is
  the gate. **The user chose not to chase this (2026-09-04).** If it is ever picked up: read the uploaded
  `xcodebuild.log` artifact from a timed-out run, and add a per-step timeout well under 60 minutes.

- **CI needs `macos-26`; `macos-15` cannot build this project at all.** D42 raised
  `IPHONEOS_DEPLOYMENT_TARGET` to 26.0 for the iPhone `HKWorkoutSession` API, and `macos-15` ships
  Xcode 16.4 whose newest iOS SDK is 18.5. The job failed in 43 seconds on 2026-08-25 with nothing
  but a deployment-target *warning* to explain it. Raising the target silently broke CI back in
  milestone 7 and it merged unnoticed — the no-PR workflow means CI only ever runs after a merge.
  A guard step now fails immediately with a one-line reason instead. **If CI is red, check the
  toolchain before the code**: the same commit was green locally on Xcode 26.6 (479 unit + 21 UI).

- **Certificate chain.** Apple issues development certs from the WWDR **G3** intermediate. A Mac
  carrying only the original WWDR intermediate (expired 2023-02-07) reports "0 valid identities"
  and `codesign` fails with `errSecInternalComponent` — which reads as *no certificate* when the
  certificate is fine. Fix: install `AppleWWDRCAG3.cer`. Already done here; the install wizard now
  detects and repairs it.
- **Developer Mode** must be ON *and* confirmed after the phone restarts. `devicectl`'s
  `developerModeStatus` can report a stale `disabled` — attempt the build; it is authoritative.
- **Computer-use cannot drive this app.** Synthetic clicks reach the Simulator's UIKit tab bar but
  **not SwiftUI list buttons**. Use the XCUITest target (`WorkoutTrackerUITests/`) instead — that is
  why it exists.
- **A store fixture from the installed commit lives in `WorkoutTrackerTests/Fixtures/`.** Any
  schema change must open it (`LegacyStoreMigrationTests`) before going near the phone — that
  store is the shape of the user's real data, and "SwiftData infers this migration" is a claim,
  not evidence. Regenerate the fixture from the *installed* commit whenever the shape changes.
- **UI tests take ~17 minutes now** (27 tests, 2026-09-03 — it was ~7 at 21) and occasionally flake under load. A single red run is not
  automatically a real failure; re-run the failing test alone before believing it.
- **An app-extension target needs `NSExtension` and version keys, or the SIMULATOR REFUSES TO
  INSTALL THE WHOLE APP.** Adding the widget extension (milestone 8, ticket 05) failed with
  "Simulator device failed to install the application", which takes every XCUITest down with it
  since the runner cannot install the host either. Two causes, in sequence:
  `INFOPLIST_KEY_NSExtensionPointIdentifier` is accepted as a build setting and silently dropped
  (the same trap as `UIBackgroundModes`), so the extension needs its own partial
  `Config/WorkoutTrackerWidget-Info.plist`; and the target inherits no `MARKETING_VERSION` /
  `CURRENT_PROJECT_VERSION`, without which the installer says `bundleVersion must be set`. The
  errors name the extension but present as an app-wide install failure.
- **A device build that TIMES OUT still leaves the previous app in `derivedDataPath`, and
  `devicectl install` will happily ship it.** On 2026-08-29 `xcodebuild` failed with *"Eric's iPhone
  may need to be unlocked to recover from previously reported preparation errors"* — and the very
  next install and launch reported success, having installed a three-hour-old binary. **Nothing in
  the install output says the code is stale.** Check before trusting an install:
  `LC_ALL=C grep -ac "<a string from the new code>" …/WorkoutTracker.app/WorkoutTracker.debug.dylib`
  — note the Swift code lives in `WorkoutTracker.debug.dylib`, not the 92 K launcher stub beside it.
- **The 7-day free-account expiry bites as "this app is no longer available", and it is silent.**
  It happened for real on 2026-08-29: a build installed and launch-verified at **17:42** was dead by
  **17:56**, because its profile expired at **17:46:59** — a four-minute window. The phone does NOT
  say "Unable to Verify App" as folklore suggests; tapping the icon reports **"no longer available"**,
  which reads like a deleted App Store app and sends you looking in entirely the wrong place.
  `devicectl device info apps` still lists the app as installed, so that check misleads too.
  **The authoritative diagnosis is to launch it:** `xcrun devicectl device process launch --device
  <UDID> <bundle-id>` names the real reason ("invalid code signature, inadequate entitlements or its
  profile has not been explicitly trusted"). **To get the date rather than a guess**, decode the
  profiles — they live in `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`, NOT the old
  `~/Library/MobileDevice/` path, which does not exist on this machine:
  `security cms -D -i <uuid>.mobileprovision | plutil -extract ExpirationDate raw -`.
  **The fix** is a normal device build with `-allowProvisioningUpdates`, which mints a fresh 7-day
  profile; the interactive wizard is not needed once its setup stages are done. **Verify the built
  app before installing** — read `WorkoutTracker.app/embedded.mobileprovision`'s expiry and confirm it
  moved, the same distrust the stale-binary gotcha above earns.
- **`-allowProvisioningUpdates` renews only a LAPSED profile — to get a fresh 7 days, DELETE the
  profile file first.** This is the fix for the drift below, and it is not obvious: a rebuild two days
  before expiry re-signs the app but hands it back the SAME nearly-dead profile, so the build looks
  successful and buys you nothing. Xcode only mints a new one when it cannot find a valid existing
  one. On 2026-09-03 the app profile (expiring 2026-09-05) was moved aside from
  `~/Library/Developer/Xcode/UserData/Provisioning Profiles/` and the ordinary device build with
  `-allowProvisioningUpdates` minted a replacement good to **2026-09-11** — a full week instead of two
  days. Back the file up before deleting; if minting fails you have removed a working profile.
  **This also re-syncs the app/widget drift**: both profiles were created in the same build, so both
  now expire within one second of each other.

- **The app and the widget expire on DIFFERENT days, and only the expired one gets renewed.** Each
  profile is minted when first created and renewed only once it has lapsed, so the clocks drift: after
  the 2026-08-29 renewal the app runs to **2026-09-05** while `WorkoutTrackerWidget.appex` still
  carried a profile expiring **2026-09-02**. Expect the Live Activity / widget to fail about **3 days
  16 hours** before the app itself does, which will present as "the lock screen stopped working" with the app
  apparently fine. **This actually happened**: by 2026-09-03 the widget profile had lapsed and been
  removed from disk entirely, so the lock-screen Live Activity was dead for roughly a day while the app
  kept working — nobody reported it, which is worth knowing about how visible that failure really is.
  The forced-renewal above resolved it, but the drift will return if only one of the two ever lapses
  again.
- **A simulator that has failed an install repeatedly needs `xcrun simctl erase`.** After the above
  was fixed the run still died with `Mach error -308 - (ipc/mig) server died`; erasing `WT-iPhone`
  cleared it. A stale simulator looks exactly like a broken build.
- **Changing `INFOPLIST_FILE` needs a CLEAN build, and an incremental one lies.** The app now
  merges a partial `Config/WorkoutTracker-Info.plist` (for `UIBackgroundModes`, which build
  settings cannot express) with the generated keys. The first incremental build after that change
  produced a plist **missing `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription`**
  — and a missing HealthKit usage string is a *crash* on the permission request, not a prompt.
  `clean build` produced the correct merged plist. Verify with
  `plutil -p <built app>/Info.plist` after any plist-affecting change; do not trust the build
  succeeding.
- **`INFOPLIST_KEY_UIBackgroundModes` is silently ignored.** It is accepted as a build setting and
  shows up in `-showBuildSettings`, but Xcode's plist generator only writes an allowlist of
  `INFOPLIST_KEY_*` settings and array-valued keys are not on it. It never reaches the built plist.
  Hence the partial-plist file above.
- **The Simulator has no camera.** Anything camera-driven needs a fixture path to be testable at
  all — hence `-uiTestScanFixture`, which renders a name plate in place of the picker. And a
  missing `INFOPLIST_KEY_NSCameraUsageDescription` is a *crash* on presentation, not a prompt;
  the project generates its Info.plist, so usage strings live in build settings.
- **A `.sheet` attached to a `Section` inside a `List` never presents.** No error, no warning —
  the state flips and nothing happens. Hang presentation off a row *inside* the section. Cost an
  export that silently did nothing (milestone 3, ticket 02); caught only by the XCUITest.

## Working agreements learned the hard way

- **Verify independently.** Twice, an agent reported the suite green and an independent re-run
  failed — once a genuine race (`CONTINUATION MISUSE` from an unfiltered `didSave` observer,
  fixed in `ce32158`). Run the suite yourself before believing a summary.
- **Cross-review is not optional** (T6). Codex reviews of Claude's work have caught, among others:
  template data loss on an empty templated workout, D23 violations where history read live rows,
  and ten duplicate catalog identities that would have split the user's own history. Reviews live
  in `.scratch/*/codex-review*.md`. Milestone 3's pass caught an export that dropped a draft
  entry's equipment and a CRLF-quoting bug that would have corrupted the CSV. The scanner needed
  **two** rounds, and the second round's worst finding was a defect introduced by the first
  round's fix — budget for a re-review after fixing criticals, not just after writing code.
- **State the consequence where the decision is made.** Every review that went well did so because
  a doc comment said what breaks if the rule is broken (usually: "this splits the user's history").
  Comments that only restate the code have caught nothing.
- **Locked decisions get reopened deliberately** — D26 (drop sets) reopened D12 rather than drifting.
- The user prefers **seeing the UI** (screenshots from the simulator) over descriptions of it.
