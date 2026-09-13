# Codex cross-review — docs commits 0cdcd19 + 43ee775

Run 2026-08-29 with `codex exec --sandbox read-only` (gpt-5.6-sol, reasoning effort high).
Prompt: `codex-review-prompt.md`. Verified independently by Claude before acting; every
finding below was confirmed against the repo. Streaming transcript discarded (651 KB of
reasoning); this is Codex's final report verbatim.

## Spec

1. **Critical — milestone 4 still has a historical-integrity defect.**

   - Claimed: [STATE.md:376](</Users/ericlee06/orca/projects/Health App/docs/STATE.md:376>) says nothing remains.
   - Actual: charts pool histories from different presets. [ExercisesView.swift:130](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Features/Exercises/ExercisesView.swift:130>) passes no `presetID`; [ProgressSeries.swift:94](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Domain/ProgressSeries.swift:94>) interprets nil as “accept every preset,” contradicting the no-preset contract at [ExerciseProgressView.swift:23](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Features/History/ExerciseProgressView.swift:23>) and D36 at [DECISIONS.md:44](</Users/ericlee06/orca/projects/Health App/docs/DECISIONS.md:44>). Narrow- and wide-grip records can therefore be combined.
   - The same call passes the exercise’s current live load type, despite [ExerciseProgressView.swift:20](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Features/History/ExerciseProgressView.swift:20>) claiming it receives a snapshot load type. Old history can disappear after a future-only correction.
   - No chart test exercises presets.

   The three requested pieces themselves are present:

   - Swift Charts: [ExerciseProgressView.swift:1](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Features/History/ExerciseProgressView.swift:1>) and line 90.
   - Normalized common axes: [ProgressSeries.swift:124](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Domain/ProgressSeries.swift:124>) reads `normalizedKg`; [ExerciseProgressView.swift:230](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Features/History/ExerciseProgressView.swift:230>) converts that canonical value into one display unit.
   - As-entered selection detail: [ExerciseProgressView.swift:125](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Features/History/ExerciseProgressView.swift:125>), lines 168–180 and 266–274; exercised by [ProgressChartTooltipUITests.swift:18](</Users/ericlee06/orca/projects/Health App/WorkoutTrackerUITests/ProgressChartTooltipUITests.swift:18>).

2. **High — the new header falsely calls milestones 7 and 8 complete and phone-confirmed.**

   [STATE.md:3](</Users/ericlee06/orca/projects/Health App/docs/STATE.md:3>) contradicts the same document:

   - Milestone 7’s watch companion has never run or been installed and is explicitly called a sketch at [STATE.md:345](</Users/ericlee06/orca/projects/Health App/docs/STATE.md:345>) and lines 362–365. Ticket 04 still has every hardware acceptance box open.
   - Milestone 8 still lacks superset reordering and History grouping—ticket-04 acceptance criteria—at [STATE.md:264](</Users/ericlee06/orca/projects/Health App/docs/STATE.md:264>).
   - Charts, history editing, and load-type correction remain unexercised in a gym at lines 275–276.

3. **High — “false for three days” is false.**

   [STATE.md:380](</Users/ericlee06/orca/projects/Health App/docs/STATE.md:380>) says the former “next unbuilt milestone” statement had been false for three days. But `4eb5486` explicitly says it “closes the ticket-01 gap” by adding the required tooltip on August 29 at 17:40. Until then milestone 4 was incomplete under SPEC’s own definition. The old sentence became obsolete roughly 35 minutes before `0cdcd19`, not three days earlier.

4. **High — SPEC’s export description is stale.**

   - [SPEC.md:94](</Users/ericlee06/orca/projects/Health App/docs/SPEC.md:94>) says 34 CSV columns; [ExportCSV.swift:22](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Domain/ExportCSV.swift:22>) contains 35, including `supersetGroupID`.
   - [SPEC.md:95](</Users/ericlee06/orca/projects/Health App/docs/SPEC.md:95>) says JSON schema version 4; [ExportSnapshot.swift:29](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Domain/ExportSnapshot.swift:29>) defines version 5.

5. **Medium — the expiry aftermath is corroborated, but the complete story is not independently reproducible.**

   Decoding the two current profiles proves:

   - App: created `2026-08-29T21:57:28Z`, expires `2026-09-05T21:57:28Z`.
   - Widget: created `2026-08-26T06:05:48Z`, expires `2026-09-02T06:05:48Z`.
   - The new Xcode profile directory exists; the old MobileDevice directory does not.

   However, the replaced profile is gone, so the old `17:46:59` expiry and the phone’s exact dialog cannot now be independently reproduced. “Only renews once lapsed” and the predicted widget failure presentation are inference from one event, not retained evidence.

   Also, [STATE.md:484](</Users/ericlee06/orca/projects/Health App/docs/STATE.md:484>) says the widget may fail “up to three days” earlier; the two recorded expiries differ by about **3 days 15 hours 52 minutes**.

## Standards

1. **High — milestone 5 was dropped without reopening locked D16.**

   [SPEC.md:111](</Users/ericlee06/orca/projects/Health App/docs/SPEC.md:111>) reverses D16, which says Strong import ships in v1 at [DECISIONS.md:24](</Users/ericlee06/orca/projects/Health App/docs/DECISIONS.md:24>). `CLAUDE.md` requires locked decision changes to be recorded in `DECISIONS.md`; neither commit edits it.

   SPEC also still calls Strong CSV an “import target, milestone 5” at [SPEC.md:101](</Users/ericlee06/orca/projects/Health App/docs/SPEC.md:101>).

2. **High — the current-status test figure is stale and wrong.**

   [STATE.md:14](</Users/ericlee06/orca/projects/Health App/docs/STATE.md:14>) says “561 unit + 25 UI green.” Target inspection finds 560 `@Test` declarations and 26 UI test methods. More decisively, `4eb5486` itself reports **560 unit + 26 UI green** after adding the tooltip UI test. No later complete run supports 561+25.

3. **High — branch and push status is false.**

   [STATE.md:16](</Users/ericlee06/orca/projects/Health App/docs/STATE.md:16>) says both milestone branches are identical to `main`.

   - `main`: `0cdcd19`
   - milestone 7: `ca67603`, 27 commits behind
   - milestone 8: `74dbbd9`, 6 commits behind
   - `origin/main`: `43ee775`, one commit behind local `main`

   Thus they are not identical, and not everything currently on main is pushed.

4. **High — the expiry edit creates an internal signing contradiction.**

   [STATE.md:192](</Users/ericlee06/orca/projects/Health App/docs/STATE.md:192>) records a fresh profile at 17:57, while [STATE.md:204](</Users/ericlee06/orca/projects/Health App/docs/STATE.md:204>) still says last signed at 13:34. “Each reinstall resets the clock” is also disproved by the 17:42 install retaining the 17:46 expiry: rebuilding/re-signing resets it, installing alone does not.

5. **Low — the new chart path is wrong.**

   [STATE.md:380](</Users/ericlee06/orca/projects/Health App/docs/STATE.md:380>) cites `Features/History/ExerciseProgressView.swift`, which does not exist from repo root. The path is `WorkoutTracker/Features/History/ExerciseProgressView.swift`. Normalization logic also spans `Domain/ProgressSeries.swift`, rather than living entirely in the cited view.

## Judgment

The rewrite is worse for a cold agent. It leaves completed work as item 3 under “What to do next,” spends six lines narrating chronology, and buries an absolute conclusion that conceals a real chart defect. The lede should be the sole remaining planned work and unresolved integrity risks, not a postmortem about numbering.

Milestone 6’s concrete description is otherwise accurate: the code accepts a bar and aggregate plates-per-side, while denomination selection and selectorized-stack increments remain unbuilt.

Summary: **Standards — 5 findings, worst the unrecorded D16 reversal. Spec/factual correctness — 5 findings, worst the still-broken preset/load-type chart scoping.** No files were modified.
