# 01 — Implement the Floodlight redesign in the real app

Type: feature
Status: in progress — see Progress → Handoff (2026-09-26 end of session 1)

## Request and user decisions (2026-09-24 → 09-26, all explicit)

- 09-24: "Redesign the entire app (every little thing)… more interactive, creative, and engaging…
  feel free to completely change from current theme." Wanted visuals first, then asked to
  interact with it in the Simulator instead of images.
- Three directions were built as a native prototype (A Floodlight, B Anatomy, C Paper Club
  with light Paper and dark Carbon), switchable in one Simulator app. Judges: A won taste fit and
  usability, C won engagement.
- **Chosen look (09-26):** "keep Floodlight's design, but bring Paper Club's workout screen design
  to it", plus **switchable dark and light theme**. Built in the prototype as the ★ look
  ("Floodlight + Paper workout"). User: "looks good".
  - Everywhere = Floodlight (they especially like Home's "This week" and the Finish screen).
  - The live lifting workout = Paper Club's structure (round set markers, pencil→ink dashed
    draft fields, stamp + ripple check circles, yellow highlighter "New best", circular icon
    buttons, bordered equipment row, dashed Add Set, inverse rest slab, add block and
    "Discard Workout…" at the end), re-skinned in Floodlight type (SF Pro Expanded heavy) and
    violet action (#B25CFF dark / #7A2EE0 light).
  - Cardio stays Floodlight. The user said they liked Anatomy's cardio screen best but did not
    ask for it; offered, unanswered. Ask before changing.
  - **Appearance setting:** Settings → Appearance: System / Light / Dark. Floodlight Light
    palette with measured contrast is in the prototype's `Look/FinalLook.swift` header.
- **Implementer:** Claude builds, Codex independently reviews (user chose this, swapping the
  usual AGENTS.md roles for this task).
- **Rollout:** all at once. Every screen redesigned, tested and reviewed before one phone
  install. **Not** a separate app: the user rejected installing the prototype separately.
  They want their real app changed, with their real data.
- **New wording/features approved as shown in the prototype.** Examples: "This week", "New best",
  "First time", "Next · Set 3 · 110 × 8", template "Last run"/"Times run"/"Avg. time",
  Appearance setting, "Discard Workout…" at the end of the live list, "Ask AI about plates" →
  "Ask AI". List every new string in this ticket as you implement. The user can still veto
  any of them. The Week streak is a PROPOSED feature and NOT shown; keep it off.
- This reopens **D54**: palette, dark-only, surfaces, type, the copy freeze and the icon.
  Record a new decision in DECISIONS before merge. Product rules stay: D52 plain numbers,
  D56–D58 AI consent/recognition, explicit cardio Start, frozen history, as-entered units,
  deliberate set creation, no long-press menus on template tiles, no per-exercise muscle
  icons, no live map during cardio.

## Source of truth for the design

- **Prototype (the reference implementation):**
  `/Users/ericlee06/orca/workspaces/Health App/redesign-prototype/RedesignPrototype/`
  (branch `ericlee4992/redesign-prototype`; untracked, not committed, about 54k lines). Its
  own Model/ is a simplified stand-in, so port the Look system and screen layouts, not its
  data layer.
  - `Sources/Look/Look.swift`, `Sources/Look/FinalLook.swift` (the ★ look and light palette),
    `Sources/Look/Components/*` (surfaces, buttons, rings, set rows, rest bar, charts, week
    widget, muscle maps, lists).
  - `Sources/Screens/<Area>/*` for each screen's layout. `Sources/Screens/Live/*` has the
    ★ composition (the composed Paper-structure look inside LiveWorkoutScreen).
  - Run it: `scripts/capture.sh all <outdir> <ScreenID>`. Env: `LOOKS=final`,
    `APPEARANCE=light|dark`. Simulator WT-Redesign `9B1D17D2-347F-431C-AC6D-F019BAB675CA`
    (Xcode 27 shows simulators in DeviceHub.app, not Simulator.app).
- **Copied here (durable):** `../reference/`
  - `captures/dark|light/*-final.png`: the approved screens in both appearances.
  - `directions/A|B|C-SPEC.md`: tokens, type, motion, per-look treatments.
  - `look-api.md`: the prototype component API.
  - `brief/`: screen inventories of the real app with every string and identifier,
    constraints (the UI-test identifier contract), domain data, user-taste history and the
    visual audits of the old UI.
  - `screen-list.md`: the 69 screen/state checklist.
- Comparison page (the user shared it for opinions):
  https://claude.ai/artifact/JFFzS2TTg2HrYe5RjoDp8L. The earlier direction canvas:
  https://claude.ai/artifact/KrTxxAr24VA7hKRZrEJuY7

## Plan (proposed; the next session confirms and refines it)

1. Read AGENTS.md, this ticket, `reference/brief/constraints.md` (UI-test contract) and
   DEVELOPMENT verification scope. Branch: `ericlee4992/redesign-floodlight` in
   `/Users/ericlee06/orca/workspaces/Health App/redesign-floodlight` (Orca worktree, at `a0364f2`).
2. Foundation: replace `Features/Design/` (Theme, components) with the ★ Floodlight system,
   light and dark, keeping the real muscle-map assets. Add the Appearance setting to
   AppPreferences; this is an optional field, so follow DEVELOPMENT's migration/backup
   guidance. Remove the forced `.dark`.
3. Restyle every real screen area to the prototype, one ticket per area (Workout/Templates,
   Live + sheets, Cardio, Finish, History, Gyms + Scan, Exercises, Settings, AI routine, Live
   Activity/widget + app icon). Keep behaviour and UI-test identifiers, and update UI tests
   where structure changed. New data shown (week summary, new bests, last-time comparison,
   template stats, next-set preview) is derived from existing data; the prototype's
   `Model/Derived.swift` shows the logic. Implement it properly in Domain with unit tests (see
   `reference/brief/domain-data.md` §3 for the rules: warmups excluded, assisted lower is
   better, ties are not PRs, first time is not a PR).
4. Verification: whole-app redesign = DEVELOPMENT escalation (full UI suite plus unit tests),
   Default + AccessibilityL captures, Reduce Motion. Codex independent review to "clear",
   per AGENTS.md.
5. Install on the phone (all at once): fresh full backup, **signing renewal**, install,
   launch, data-preservation check.

## Progress

### 2026-09-26 — foundation (Claude)

Verified on resume: worktree branch `ericlee4992/redesign-floodlight` at main `a0364f2`; this
ticket and `reference/` were untracked and are now committed (`2a1b787`, pushed). The prototype
(`redesign-prototype/RedesignPrototype/`) is still untracked in its own checkout.

Done (build: `xcodebuild … -sdk iphonesimulator build` exit 0):
- Ported the prototype Look system into `WorkoutTracker/Features/Design/Look/` (tokens, Floodlight
  Light, live-workout look, all components). The unchosen Anatomy study and the Paper/Carbon week,
  study token tables and switcher are not ported; the Paper structure survives only as the live
  workout's base (`Look.paperClubStructure`). `LookFormat` adapts formatting to the real app
  (`WeightMath.displayNumber`, device locale). Support values: `SetValue`, `LiveSetState`,
  `HRSlot` (= `HeartRateSeriesMath.DisplaySlot`), `FinishTileKind`; `Domain/WeekSummary.swift`
  holds the week-card value types (builder + tests come with the Workout area).
- **Appearance setting — refinement of plan step 2:** stored per device with `@AppStorage("appearance")`
  (`AppearanceSetting`), not as an `AppPreferences` attribute. Reasons: no SwiftData schema change,
  migration or export-format change for a display preference; it must be readable before the model
  container opens; appearance is a per-device choice. Settings row `appearanceSetting`
  (System / Light / Dark). Launch argument `-appearance light|dark` works for captures/tests.
- Removed the forced `.preferredColorScheme(.dark)`; the window root applies `.lookLayer()`.
- Transitional bridge: `Theme` tokens now resolve to the Floodlight palette dynamically (light/dark)
  and `AccentColor` is violet (#7A2EE0 light / #B25CFF dark), so not-yet-rebuilt screens stay
  legible in both schemes. The old `Colors/*` asset set is deleted. Old components colliding with
  new names are renamed `Legacy*` (`LegacyChip`, `LegacyPrimaryButtonStyle`,
  `LegacySecondaryButtonStyle`, `LegacySetRowView`, `LegacyTemplateTile`) until their screens move.
- Simulator for this branch: **WT-Floodlight** `9E822EF6-DC67-4958-AEA2-D53D2D36D674`
  (iPhone 15 Pro Max, iOS 27.0; simulator bundle id `com.example.workouttracker`).

New visible string so far: "Appearance" with options "System", "Light", "Dark" (approved in the
prototype).

### Area order (each: restyle → targeted tests + captures → Codex review to clear)

1. Workout tab (Home: gym picker, Start pair, This week, template tiles, Ask AI row) + template
   detail/editor. Week summary builder in Domain with unit tests.
2. Live lifting workout + its sheets (the Paper-structure look), rest bar, finish flow entry.
3. Cardio (picker, live panel, distance editor).
4. Finish receipt.
5. History (list, calendar, detail, edit set, progress chart).
6. Gyms + machine editor + model picker + scan.
7. Exercises tab + presets.
8. Settings + export + Ask AI settings.
9. AI routine flow.
10. Live Activity / widget + app icon; remove `Theme`/legacy components; D54 decision record.

### Session 2 — 2026-09-26/27 (checkpoint)

| Branch | Tip | State |
|---|---|---|
| `ericlee4992/redesign-floodlight-live` | `0ca7868` | ticket 03 **Codex clear after 3 rounds** |
| `ericlee4992/redesign-floodlight-finish` | `1c3fc99` | ticket 04 **Codex clear after 3 rounds** |
| `ericlee4992/redesign-floodlight-history` | see `git log` | ticket 05 History **Codex clear after 3 rounds** |

Both review terminals closed. Logs/results: `/tmp/wt-floodlight/results/`; ticket 03/04
captures are committed under `../captures/03/`, `../captures/04/`. Pre-existing iOS 27 UI
failures left: Gyms model picker (CoreLoop :252), History HR section (HeartRateSummary :66).
Ticket 05 (History) Codex clear 2026-09-27 on its own branch from the finish tip; details and
verification in `issues/05-history.md` (on that branch). Next: ticket 06 Gyms + scan (fix the
model-picker test), on a new branch from the history tip. D47 reopening for notes (user,
2026-09-27) goes into DECISIONS with the D54 entry.

### Handoff — 2026-09-26, end of session 1 (context full; continue in a new session)

**Branches (all pushed to origin; stacked, each on the previous):**

| Branch | Tip | Content | State |
|---|---|---|---|
| `ericlee4992/redesign-floodlight` | see `git log` (after `b2c0329`) | foundation `b22f2c0`, ticket 02 `934a5ba` + fixes `37f16a0`, `ed82fdb` | ticket 02 **Codex clear** (3 rounds) |
| `ericlee4992/redesign-floodlight-live` | `9d07a9c` | ticket 03 live workout (two WIP commits + record) | implemented + tested; **Codex review not started** |
| `ericlee4992/redesign-floodlight-finish` | `cb90a5b` | ticket 04 finish receipt WIP | builds; first batch `finish-ui-1` **14/14 passed** (4 capture runs + 10 finish flows); captures not yet reviewed |

The live/finish branches were worked in scratch checkouts `/tmp/wt-floodlight/{live,finish}`
(git worktrees of this repo; /tmp may be cleared — recreate with `git worktree add` or check the
branches out in an Orca worktree). Logs/result bundles/captures: `/tmp/wt-floodlight/results/`,
`/tmp/wt-floodlight/shots/` (ephemeral; ticket 02's captures are committed in
`../captures/02/`). Simulator **WT-Floodlight** `9E822EF6-DC67-4958-AEA2-D53D2D36D674`.
Codex review terminal: Orca "Codex review — Floodlight 02" (`term_e2829166…`) — close it or reuse.

**Next steps, in order:**
1. Ticket 03: squash the two WIP commits (optional), write `codex-review-03-prompt.md` (model on
   `codex-review-02-prompt.md`; range `ed82fdb…` → live tip), run Codex in a visible Orca terminal,
   iterate to clear. Ticket file: `issues/03-live-workout.md` (on the live branch).
2. Ticket 04 (finish): the first batch passed 14/14 (log `/tmp/wt-floodlight/results/finish-ui-1.log`; re-run if /tmp is gone) — `FloodlightFinishUITests` (4 captures: finishes the `-uiTestDesignLive`
   fixture, taps "Keep Original" on the drift dialog) and the finish flows listed in the batch
   command (CoreLoop empty finish / View in History, HistoryTemplate, HeartRate finishing summary,
   RedesignScreenshot test02/test03, Cardio capture+save); look at the captures against
   `reference/captures/*/F01-final.png`; add unit tests for `FinishReceipt.build` and the new
   `SetBadgeMath.outcomes` (previous best; history limited to sets before the workout started);
   write `issues/04-finish.md`; Codex review. Remaining F-screen items not yet ported: the
   heart-rate plate/zone card restyle (shared with History), cardio card restyle, reveal motion.
3. Then areas in ticket order: History (month card + week lists, calendar, detail, edit set,
   progress chart; fix the pre-existing History HR-section test), Gyms + scan (fix the model-picker
   test), Exercises (fix the search-field tests; exercise detail screen from template rows),
   Settings/export, AI routine (pre-existing AXL equipment test), cardio focus, Live Activity +
   icon, remove `Theme`/`Legacy*`, DECISIONS entry reopening D54, full UI suite, then install.

**Decisions to put to the user** (also in tickets 02/03): week starts on the phone's first
weekday (prototype showed Monday); dropping a card into a superset joins it; Discard moved to
"Discard Workout…" at the end of the live list; PREVIOUS short form "105 × 8"; sheets keep system
lists in Floodlight colours rather than the prototype's custom sheets; Cardio stays Floodlight
(Anatomy's cardio screen was offered, unanswered).

## Blockers and facts for the install

- **Xcode has no Apple account signed in:** the device build failed with "No Accounts". The
  user must add their Apple ID in Xcode → Settings → Accounts before any phone build.
- The real app's app/widget profiles **expired 2026-09-24 03:16 EDT**, so the installed app
  (product 9f733a2) likely won't launch. Renewal and backup follow DEVELOPMENT.
- The phone is paired and available: `00008130-001E10C01E62001C`.

## Other sessions' state (do not touch)

- The main checkout `/Users/ericlee06/orca/projects/Health App` is on
  `ericlee4992/redesign-visual-proposal`. That is a separate Codex session's pushed visual
  proposal (browser mock, D54 note, STATE edits), not merged and superseded by this
  decision. Tell the user; don't merge or delete it without asking.
- main = origin/main = `a0364f2`.
