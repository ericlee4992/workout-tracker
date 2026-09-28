# 11 — Floodlight: System surfaces and cleanup

Type: feature (part of [01](01-implement-redesign.md), area order item 10)
Status: in progress
Implementer: Claude. Reviewer: Codex.
Branch: `ericlee4992/redesign-floodlight-system` (scratch checkout `/tmp/wt-floodlight/system`),
stacked on the ticket-10 AI-routine tip `0fa6814` (Codex clear). Nothing merged to `main`; nothing installed.

## User decisions (2026-09-28, asked in session)

1. **The Live Activity's commands are built:** +15s and Skip while resting, Pause / Resume during
   cardio, on the Lock Screen card and in the expanded Dynamic Island. They are App Intents that run in
   the app and change the workout exactly as the in-app buttons do (rest end, notification, audible
   alarm, Watch mirror, the activity itself). A tap anywhere else opens the app. (The prototype marked
   them PROPOSED.)
2. **Cardio becomes its own ticket 12**, before the release-candidate pass. The Cardio area (ticket 01
   area 3: activity picker, live cardio panel, distance editor, cardio cards, the cardio-only History
   detail) never had a ticket; tickets 04 and 05 deferred its restyle to "the Cardio area". Here the cardio
   views only move from `Theme` to the Look tokens, with no layout change; ticket 12 restyles them to the
   prototype. The Anatomy-cardio question was answered the same day in another session: "keep cardio plain
   floodlight" (recorded in ticket 01 on `ericlee4992/redesign-floodlight`, `c9c973e`; D59).
3. **The Live Activity follows the system appearance** (a light Lock Screen gives the Floodlight Light
   card, a dark one Floodlight dark), not the app's Appearance setting. The Dynamic Island is black in
   both.
4. **App icon: the current dumbbell in the Floodlight palette** (violet `#B25CFF` plates, deeper violet
   bar, on ink `#060708`), with Dark and Tinted versions. Not the prototype's "lit stack". The Live
   Activity header's small mark is the same dumbbell.

Record decisions 1–4 with the D54 entry (this ticket writes it).

## Scope

Ticket 01 area 10. Reference: prototype captures 2026-09-28 into `../reference/prototype-system/{dark,light}/`
(`LOOKS=final APPEARANCE=dark|light AXL=1 SETTLE=5 scripts/capture.sh all … Z01 Z01:p2 Z01:p3 Z01:cardio
Z01:cardio-p2 Z01:cardio-target Z01:cardio-target-paused Z01:best Z01:superset Z01:warmup Z01:ready Z01:nohr
Z01:nogym Z01:light Z02 Z02:p2 Z03 Z03:timer Z03:recovered Z03:cap Z03:noreading Z04 Z05`, dark then light,
one at a time; blank or mid-animation shots retaken with SETTLE=9).

1. **Z01 Live Activity** (`WorkoutTrackerWidget/`), Floodlight, three states:
   - **Resting:** header (dumbbell mark · the exercise · the workout clock); the instrument — the
     draining rest ring with its hourglass, "Rest" over the system-ticked countdown (a "New best" mark on
     the label line when the set that started the rest was a new best), **+15s** and **Skip**; footer —
     "Next · Set 3 · 110 lb × 8" (or "Next · <exercise>"), the heart reading with its zone meter, the
     sets ring with "7/18".
   - **Ready** (rest over): the next set's marker (with its superset letter), "Next" over "110 lb × 8",
     "PREVIOUS" over last time's value; footer — the gym, heart, sets. When the rest ended while the app
     was not running an update, the card is re-rendered at the rest's end (the content's stale date) and
     draws the ready state from what it already holds.
   - **Cardio:** header (the workout's name · workout clock); instrument — the planned-target ring (or the
     plain ring) with the activity glyph, the activity over its system-ticked clock ("Paused" and a frozen
     clock when paused), **Pause / Resume**; footer — distance, pace or speed, the target minutes, heart.
   - **Rest result (Z03):** after a rest ends, the ready footer draws how it ended until the next set is
     completed: the drained ring and its length (timer), the reading under the target mark (recovered),
     the capped clock with the reading over the mark (cap), the struck heart with the timer that took over
     (no reading).
   - **Dynamic Island:** compact (the live glyph · the countdown / cardio clock / "7/18"), minimal (the
     glyph), expanded (glyph or next marker · the big figure · name, the support line, heart · the
     commands or the sets readout).
   - Type is capped at xLarge inside the activity and the island (their heights are fixed by the system).
2. **Z03 notifications:** the banner is the system's; the app owns the title/body and the icon. The
   existing copy stays ("Rest complete" + "Time for your next set." / "Heart rate down to N bpm — ready for
   your next set." / "Time is up — your heart rate didn't reach the target." / "No heart rate reading —
   resting by the timer instead."). The icon is decision 4's.
3. **Z02 app icon:** decision 4 — `scripts/render-app-icon.py` redrawn; `AppIcon.appiconset` gets the
   default, Dark (transparent ground: iOS draws its dark tile) and Tinted (greyscale on transparent)
   appearances.
4. **Remove `Theme` and the `Legacy*` components.** Move every remaining reader to the Look tokens and
   delete `Theme.swift` and the pre-redesign components that nothing uses; keep behaviour and identifiers.
   Nothing reads the old `Colors/*` assets (deleted in the foundation). The `ios-design` skill's direction
   and tokens are rewritten for Floodlight (they still name `Theme.swift` and amber).
5. **Z04 / Z05** (Home and Live at AccessibilityL): checks against the prototype, not new screens.
6. **The D54 decision record** in `docs/DECISIONS.md` (see "D54 entry" below) and SPEC's visual design
   paragraph.

## Prototype features the real app lacked (approved with the prototype unless noted)

- The Live Activity's ready and cardio states, the next-set line, the sets ring "7/18", the heart zone
  meter, the new-best mark, the planned-target ring, the cardio figures, the rest-result footer, the
  expanded island's layout. +15s / Skip / Pause were PROPOSED — decision 1 approved them.
- Not ported: the prototype's 4-second "best moment" line (the set and "+5 lb") — a Live Activity update
  that lives four seconds spends the system's update budget on a flourish; the persistent "New best" mark
  on the rest label says the same. Not ported: the prototype's icon page and Home Screen mock (they are
  system chrome), the lit-stack icon (decision 4).

## Screen jobs, bold element (ios-design steps 1–2)

- **Resting card:** exists to say how long is left and what is next; the eye lands on the countdown, the
  thumb on Skip. Runner-up (the next-set line) is footnote.
- **Ready card:** exists to say what to load; the eye lands on "110 lb × 8".
- **Cardio card:** exists to show the segment's time; the eye lands on the clock; Pause is the one command.
- **Compact island:** one glyph, one figure (the countdown / clock / sets).

Wireframe (Lock Screen, resting):

```
┌──────────────────────────────────────────────┐
│ [▮] Seated Chest Press                 18:42 │  header: mark · name · workout clock
│ (◔)  Rest [NEW BEST]            [+15s][Skip] │  instrument: ring · label/time · pills
│      1:24                                    │   (time = the largest thing)
│ Next · Set 3 · 110 lb × 8     ♥128 ▬▬▬  ◔7/18 │  footer: next · heart · sets
└──────────────────────────────────────────────┘
```

## Tells (ios-design step 4)

- Same container on everything: absent — one card, the system's.
- Chips: absent (the superset letter is an outlined marker, the zone a meter).
- All-caps: deliberate — "PREVIOUS", the live row's column header, as in the live workout.
- Middle dots: deliberate — the next-set line is the live workout's own string.
- Accent everywhere: absent — violet on the rest ring, Skip / Pause and the compact figure (the live
  thing and its one command).
- Equal full-width blocks: absent.
- Only survives default size: answered by the xLarge cap (system budget) and AX captures of the gallery.

## Strings

Unchanged: the four notification bodies, "Rest complete", the gym name, the exercise name.
New on the Lock Screen / island (all from the prototype): "Rest", "Next", "PREVIOUS", "Next · Set N · …",
"N/M", "Time", "Paused", "+15s", "Skip", "Pause", "Resume", "min", "bpm", "New best"; VoiceOver: "Add 15
seconds", "Skip rest", "Rest, 1:24 left", "N of M sets", "N beats per minute", "Workout time".
Removed: the old card's "N sets" and "Zone N" capsule (now the sets ring and the zone meter).

## Rules kept

D46 (the app pushes, the system ticks: every countdown and clock is `Text(timerInterval:)` /
`ProgressView(timerInterval:)`, nothing is app-ticked); one owner of the activity and every ending path
ends it (`WorkoutActivityController`); UI-test runs post no real activity unless a test asks for it;
D43 heart-rate rest (cap, degrade, recovered); D22/D26/D48 rest rules; D44 absent heart rate renders as
absent; D45 zone only with a maximum.

## Implementation

- **Shared with the widget** (`WorkoutTrackerWidget/Shared/`, compiled into the app and the widget; pbxproj
  entries added for both targets): `WorkoutActivityAttributes.swift` — the state gained optional fields
  (zone level, total sets, rest start, rest kind, new-best flag, rest result, the next set, cardio, the
  workout title; an older payload still decodes) and the pure reading (`phase`, `shownResult`,
  `headerTitle`, `restFractionLeft`); `WorkoutActivityViews.swift` — the Floodlight palette as literals
  (light/dark, the island always dark), the card, the island regions, the commands;
  `WorkoutActivityIntents.swift` — `WorkoutActivityIntent` (`LiveActivityIntent`, not discoverable) and the
  bridge the app installs.
- **Widget** (`WorkoutActivityView.swift`): only places the shared views in the Lock Screen and island slots.
- **App**: `WorkoutActivityContent` builds the state from the store (the live screen's rules for the next set
  and its line, `PerformanceHistory.reference` for PREVIOUS, `SetBadgeMath` for the new-best flag,
  `RestTimerService.restPlan` for the rest kind); `WorkoutActivityCommands` applies a pressed command through
  the same services as the in-app buttons (`RestTimerService.add/skip` + `broadcastRest`; the cardio recorder
  when it records this workout, else `CardioSession`), posts `didApply` for the live screen, re-pushes the
  card and **waits for the update to reach the system** before the intent returns. Installed in the app's
  `init` (a command can be what launched the app); RootView gives it the coordinator and the controller.
  The live screen keeps the slow part of the state cached (history queries) and refreshes heart and cardio
  every tick, tracks how the last rest ended (recovered; expiry while on screen), and re-reads its rest on
  `didApply`.
- **Controller**: the content's stale date is the rest's end (the card redraws as ready without the app);
  `settle()` awaits the last update; a start adopts this workout's card if the system still shows it (app
  relaunch, cold background launch) and ends any card left by another workout.
- **Gallery** (`ActivityGalleryView`, test-only, `-uiTestActivityGallery <state>`): the widget's own views for
  15 sample states on a wallpaper, for captures at every size and appearance.
- **Icon**: `scripts/render-app-icon.py` writes Default, Dark and Tinted; `AppIcon.appiconset` lists all three.
- **Cleanup**: `Theme.swift`, `ButtonStyles`, `CardStyle`, `Chip` (`LegacyChip`, `UnitChip`), `EmptyState`,
  `MuscleGroupStyle`, `ProgressRing`, `StatTile`, `ZoneColors`, `HeartRateBar`, `RestTimerBar` and
  `HeroCapsuleLabel` deleted (nothing on screen used the last six); the cardio views, the machine sheets' empty
  state and unit badge, RootView's tint moved to Look tokens with no layout change. `ThemeTests` →
  `MuscleMapAssetTests`. Nothing reads `Colors/*` (deleted in the foundation). `rg "Theme\.|Legacy[A-Z]"`
  finds nothing in the app, the widget or the tests (`LegacyStoreMigrationTests` is the store migration).
- **Docs**: DECISIONS D59 (supersedes D54; D47 and D56 amendments), SPEC "Visual design", the ios-design skill.

## Found on the way (failed approaches)

- A timer `ProgressView` is a ring only inside a widget; in the app it is a spinner. The gallery draws the
  ring's fraction at render time (`activityDrawsRingsStatically`); the widget keeps the system-ticked ring.
- The real Lock Screen ignored `Font.system(_:weight:)`'s weight (heavy text rendered regular, the width
  kept); `Font.system(_:).weight(_:)` renders as designed. Seen only on the real card (`sys-ui-9` vs `-10`).
- The first press of an interactive activity is swallowed by iOS's "Allow Live Activities from …?" prompt
  (later "Always Allow"); the real test answers it.
- `+15s` applied but the card did not redraw: the update ran in a detached task and the intent returned first,
  letting the app be suspended. The intent now waits for the update (`settle`). The card then redraws about a
  second later; the test waits and reopens Notification Center before its shot.
- The +15s assertion first measured elapsed time from the press instead of from the first reading.

## Strings (as implemented)

New on the Lock Screen / island (prototype): "Rest", "Next", "PREVIOUS", "Time", "Paused", "+15s", "Skip",
"Pause", "Resume", "min", "bpm", "sets", "N/M", "NEW BEST"; the next-set line is the live rest bar's.
VoiceOver: "Add 15 seconds", "Skip rest", "Last time …", "N of M sets", "N beats per minute[, Zone N]",
"Superset A", "Target N minutes", the rest results ("Rested 2:00", "108 beats per minute, under 110", "4:00 cap
reached, 128 beats per minute, over 110", "No heart rate reading, rested 2:00"). Removed: the old card's
"N sets" line and "Zone N" capsule. No "All sets done": with no next set the card shows "18/18 sets".

## Verification

Runner `/tmp/wt-floodlight/sys-run.sh <name> build|test …` (derived data `/tmp/wt-floodlight/dd-sys`); logs,
`.exit` files and result bundles `/tmp/wt-floodlight/results/sys-*`.

- Prototype captures: dark and light both exit 0 (46 each). Blank or mid-animation shots were retaken with
  SETTLE=9 (dark: Z01:cardio ×2, Z01:cardio-p2 AXL, Z01:light AXL, Z01:p2, Z02; light: Z01:cardio-target AXL);
  all 92 have content. Noted: the prototype's light island draws dark text on black (its bug; the real island
  is always dark).
- `sys-build-1` (exit 65: `LookRadii` has no `inner`), `sys-build-2` exit 0 (Theme removal).
- `sys-build-3`…`-7`: exit 0 (Live Activity, gallery, tests).
- `sys-ui-1` (exit 65): the real card was posted and +15s tapped, but iOS's permission prompt took the tap.
  `sys-ui-2` (exit 65): unit target did not compile (main-actor `mainContext`). `sys-ui-3` (exit 65): unit 22/22;
  the real test failed on the elapsed-time arithmetic (the log showed the command applied). `sys-ui-4` (65):
  same, with logging. `sys-ui-5` exit 0 but the card had not redrawn → `settle`. `sys-ui-6`/`-7` exit 0, the card
  still raced the shot. `sys-ui-8` (65): the app did not reach the live screen in 15 s (a one-off; `-9` passed).
  `sys-ui-9` exit 0: after Skip the card shows the ready state; after +15s the countdown moved. `sys-ui-10`
  exit 0: heavy type on the real card.
- `sys-ui-11` (on `c6e93af`; exit 65 from one unit case): **UI 56/56** — `FloodlightSystemUITests` 5/5 (the four
  gallery passes, 15 states each, and the real card), `FloodlightWorkoutTabUITests`, `FloodlightLiveUITests`
  10/10, `CardioUITests` (the cardio views on Look tokens), `HeartRateUITests` (the recovered / degraded rest
  paths the live screen now records), `CoreLoopUITests` (the machine sheets' empty state and unit badge),
  `FloodlightFinishUITests` (the cardio summary card). **Unit 898/899**: the one failure is
  `SeedingTests.reconcileIsCheapOnceSeeded`, a timing bound (`perRun < 0.05`) — it passed alone in `sys-ui-12`;
  the machine's load average was ~16 then (other sessions' simulators busy).
- `sys-ui-12` (on `6cc310d`: the VoiceOver fix for the card's timers, the title in the cache key): unit
  `SeedingTests` + `WorkoutActivityContentTests` 28/28; `FloodlightSystemUITests` 5/5; `FloodlightLiveUITests`
  9/10 — `testCorrectingAFreshBestBelowTheRecordTakesTheBandAway` timed out on a 3 s wait. `sys-ui-13` (the two
  band tests ×2) failed differently each time (a launch that stayed on the Workout tab; a typed value lost) under
  the same load. After shutting down this session's idle prototype simulator, `sys-ui-14`: **`FloodlightLiveUITests`
  10/10** (exit 0).
- Captures `../captures/11/` (70): Z01 gallery × 15 states × light/dark × Default/AXL (from `sys-ui-12`), the real
  card (resting, after +15s, after Skip → ready), the app after Skip, the compact island over the Home Screen;
  Z02 the icon's three appearances and the Home Screen; Z04/Z05 Home and Live at AXL (from `sys-ui-11`).
  Compared with the prototype in `/tmp/wt-floodlight/results/sys-sheets/compare-{dark,light}.png`.
- Scope rationale (DEVELOPMENT): new feature (the commands) → its unit tests + a real-system flow; the live
  screen's rest handling and activity push changed → the live, heart-rate-rest and finish flows; views moved off
  `Theme` → the screens that show them (cardio, the machine sheets); the unit suite whole (cheap). The full UI suite
  is the release-candidate pass after ticket 12.
- Z04 / Z05 check: Home and Live at AccessibilityL match the prototype's composition (the week starts on the
  phone's first weekday — ticket 02's flagged decision). Not exercised: VoiceOver by a person, a real device (the
  Lock Screen of an iPhone, the Watch mirror after a lock-screen command), a cold background launch by an intent
  (unit-tested path only), the Dynamic Island's expanded view on the Simulator (the gallery shows it).

## Progress

- 2026-09-28: started in a fresh session. Verified the checkout (`0fa6814`, clean, pushed). Read STATE,
  tickets 01 and 10, the prototype System area, the widget and the activity controller. Prototype captured
  (dark, light). User decisions 1–4. Ticket written (`1a9ab08`); Theme removed (`2e0a62f`); Live Activity,
  commands, icon, D59 (`c6e93af`); VoiceOver and docs (`6cc310d`). Another session recorded the same day that
  cardio stays plain Floodlight (ticket 01, `c9c973e` on the main redesign branch) — reflected in D59 and STATE.
