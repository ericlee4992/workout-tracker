# Active Workout — Codex directions, ticket 16

Two design proposals for comparison, led by **A**. The ticket's Step 1 job/state sentences are used as given; Claude's directions and the app source are unchanged. These are static design artboards, not implemented app behavior.

| Artboard | Idea | Preview |
|---|---|---|
| [CodexA.dc.html](CodexA.dc.html) | Familiar cards, quieter supporting information; the current set leads. | [Logging PNG](renders/CodexA.png) |
| [CodexARest.dc.html](CodexARest.dc.html) | The same composition hands emphasis to the countdown. | [Resting PNG](renders/CodexARest.png) |
| [CodexB.dc.html](CodexB.dc.html) | An open set ledger gives the working row more physical room. | [Logging PNG](renders/CodexB.png) |

## A — Familiar, quieter

**One-line idea:** Keep the current screen's exercise cards and table; spend prominence on the set being logged.

- **Logging:** Set 2 has the only amber command, its completion button. A neutral row surface and Title 2 inputs join the fields to that command. Elapsed time becomes a caption beside the gym, the completion ring becomes a small neutral state indicator, and Add Exercise, Add by Machine, Add Set, Finish and previous performance all step down. Completed sets retain a small amber tick, with no amber disc behind their number. The heart rate keeps its semantic danger colour but loses stat-sized emphasis.
- **Resting:** The 1:58 countdown at the thumb is the only hero figure. The upcoming set keeps its values and controls but loses its filled completion button, row highlight and large inputs. Skip and +15s are neutral controls in the timer group; neither gets an independent amber fill. The illustrated rest follows completed set 1; set 2 remains the next uncompleted set.
- **Empty:** With no current set, Add Exercise takes the primary treatment; Add by Machine remains an equally sized alternative. This follows the supplied state brief and is not a separate rendered fixture.
- **Keyboard:** Retain the existing collapsing header and scroll the focused field above the real keyboard. This is an implementation requirement, not simulated in these boards.
- **Main trade-off:** The persistent add controls keep both entry paths reachable, but consume vertical space. During rest, only the next exercise's heading appears initially; its machine and rows continue in the scroll area. At accessibility sizes, the add controls move to the end of that scroll area so the timer does not crowd out the log.

Reading order and relative sizes:

```text
minimize · Cancel · editable title · Finish       small chrome
Iron Temple                  12 min   ring/count small status
heart rate · zone · calories / source            quiet group
┌ Seated Chest Press            options/history ┐
│ machine row                                  │
│ SET  PREVIOUS       WEIGHT  REPS              │
│ 1    previous       60 lb   10       tick     │
│ 2    previous      [60 lb] [10]      AMBER    │ ← logging focus
│ 3    —              60 lb   10       circle   │
│                    Add Set                   │
└──────────────────────────────────────────────┘
Lat Pulldown card continues in the scroll area
[Add Exercise]             [Add by Machine]       neutral
[Rest  1:58                       +15s   Skip]    ← resting focus only
```

## B — The working row

**One-line idea:** Remove the exercise card walls and enlarge only the current row inside a continuous, fully labelled ledger.

- **Logging:** The current row is the one large surface, with a Large Title weight figure, a Title 2 rep figure and a taller amber completion target. PREVIOUS stays beside the inputs, and completed/planned rows remain editable in place. The heart-rate container and machine fill disappear; their information and controls remain. Elapsed time, progress, the add commands and exercise tools stay quiet.
- **Resting:** Intended handoff matches A: the enlarged row returns to ordinary row height and input type, its complete control becomes neutral, and the pinned countdown becomes the one hero. The rest controls use A's layout. Only A's resting state is rendered in this delivery.
- **Empty / keyboard:** Same state behavior as A. No exercise pager, new navigation command or rewritten labels.
- **Main trade-off:** Bigger current inputs improve a quick glance and tap, but move the next exercise farther down and lose the familiar card boundaries. Changing the current row would also change row height; implementation must preserve the user's scroll anchor.

```text
same chrome and quiet status as A
heart rate / source on the page, no card
Seated Chest Press                    tools
machine row on the page
SET  PREVIOUS       WEIGHT  REPS
1    previous       60 lb   10         tick
╭─────────────────────────────────────────╮
│ 2  previous      [60 lb] [10]   AMBER   │ ← largest content group
╰─────────────────────────────────────────╯
3    —              60 lb   10         circle
                   Add Set
───────────────────────────────────────────
Lat Pulldown and its table continue below
[Add Exercise]             [Add by Machine]
```

## Retained content and fixture

Both directions retain Cancel, the editable workout title and pencil, Finish, minimize, gym, elapsed time, the small progress ring/count, heart rate, zone and zone meter, calories, the source/edit-zones row, machine selection, exercise options, previous performance, SET/PREVIOUS/WEIGHT/REPS, all set markers and menus, inputs, unit chips, completion controls, Add Set, Add Exercise and Add by Machine. Rest adds the existing Rest, countdown, +15s and Skip. No new visible instruction, heading or action label was added.

Fixture: Iron Temple, 12 min; Seated Chest Press on Chest Press / Life Fitness Insignia Series; set 1 done at 60 lb × 10, set 2 current, set 3 planned, then Lat Pulldown / Hammer Strength with its two 80 lb × 10 rows. Heart rate 128 bpm, Zone 3, 142 cal. The 3/8 sets status is retained from Claude's supplied composition; it is a workout-wide fixture count rather than a count recomputed from the five illustrated rows. Rest is frozen at 1:58 for comparison. “Test data · edit zones” is existing app copy for the fixture reading and estimated zone setup.

## Accessibility and motion

The rest bar explicitly changes to two rows at accessibility sizes: countdown first; equal-width +15s and Skip controls beneath it. Each button has a nonshrinking, nonwrapping label. The fix is the extra row and available width, not `nowrap` alone. Large-text navigation wraps the full editable title onto its own line. Set columns reflow into a marker/previous/completion row above labelled WEIGHT and REPS fields. No essential text is dimmed with opacity.

[renders/CodexARest-AXL.png](renders/CodexARest-AXL.png) is a browser **large-text layout study**, not an iOS Dynamic Type test. It verifies the proposed rest composition at 390 px with 28 px button labels. Real AccessibilityL validation remains part of a future SwiftUI implementation. All illustrated buttons have at least 44 × 44 px regions; the timer actions grow to 56 px high in the study.

Motion intent: completing a set settles its filled command into the small completed tick and hands emphasis to the timer. The next working row receives emphasis when rest ends or is skipped. B's row expansion must not move the touched row unexpectedly. No looping decorative pulse; Reduce Motion uses an immediate update or short crossfade. The comparison boards are deliberately frozen.

## Design tells

- **Same container everywhere:** absent. A cards group exercises and live metrics; B uses one ledger, with a surface only for its active row. Machine/field fills are controls, not nested content cards.
- **Unnecessary chips:** absent. Unit chips stay as selectors; gym, elapsed and count are plain text.
- **All-caps label above every section:** absent. Only the existing table labels remain.
- **Middle-dot metadata:** deliberate: existing source/edit-zones punctuation; no invented metadata strings.
- **Accent everywhere:** absent. Logging has one filled completion command; resting has one hero countdown. The small completed tick remains state, not another command.
- **Equal-weight full-width blocks:** absent. The exercise dominates the compact live-metrics group; add controls remain neutral.
- **Phone-sized website:** absent. Native-sized controls, tight rows, safe-area space, actual scrolling content; no marketing headings or decorative sections.
- **Too much above the job / empty viewport:** absent. The elapsed hero is gone and the working set is visible in both default logging boards; following exercise content continues below.
- **Picker dressed as primary:** absent. Set-type chevrons, unit selectors and machine disclosure are neutral; completion is a command.
- **Default-size-only layout:** deliberate separate large-text composition, rendered for A rest; native Dynamic Type remains untested in this design-only task.

## Reproduction and render check

`python3 build.py --render` regenerates the three `.dc.html` files, their plain HTML render copies, `canvas.json`, and four PNGs. CSS is inline and starts from the used primitives in the supplied `_common.css`. Every canvas file uses DirectionA's exact document shell with `./support.js`, `<x-dc>`, `<helmet><style>`, and `<div class="phone">`. The canvas host supplies `support.js`; the plain render copies do not require that runtime.

The render command uses the requested installed Chrome binary with `--headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=2 --window-size=390,844 --screenshot=… file://…`. Each resulting PNG is 780 × 1688 pixels, representing a 390 × 844 phone at 2×. All four final PNGs were opened and visually inspected. No fake status bar or keyboard is drawn. No app source, Xcode build or simulator command was used.
