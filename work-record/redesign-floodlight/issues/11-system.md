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
   prototype and asks the open Anatomy-cardio question (ticket 01).
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

## Verification (planned)

- Unit: the content-state builder (resting / ready / cardio / results, total sets, next line, previous),
  the command centre (routes to the live screen; cold path edits the store: +15s, skip, pause/resume;
  wrong workout is ignored).
- UI: an in-app activity gallery (launch argument, test-only) renders the real widget views for every
  state — captures light/dark × Default/AXL; one real Live Activity in the Simulator (a real activity
  posted, the Lock Screen / island captured, +15s and Skip pressed on it); Z04/Z05 captures; neighbours
  of the Theme removal per DEVELOPMENT.

## Progress

- 2026-09-28: started in a fresh session. Verified the checkout (`0fa6814`, clean, pushed). Read STATE,
  tickets 01 and 10, the prototype System area, the widget and the activity controller. Prototype captured
  (dark). User decisions 1–4. Ticket written.
