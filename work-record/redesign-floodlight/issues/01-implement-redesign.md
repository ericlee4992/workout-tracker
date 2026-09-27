# 01 — Implement the Floodlight redesign in the real app

Type: feature
Status: ready — handed off 2026-09-26 for a fresh session; no product code written yet

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
