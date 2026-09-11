---
name: ios-design
description: Design, restyle or review a screen of this iPhone app — its composition, hierarchy, type, colour and Dynamic Type — before any screen-level UI change, when mocking a screen for the user, or when the user says a screen looks off, boring or generic.
---

# iOS design for this app

A screen is designed, not styled. Styling applies the tokens to whatever is there; designing
decides what is there, in what order, and which one thing the eye lands on.

## The brief

- **What it is**: a private gym logger for one person. Used one-handed, mid-set, under gym lighting,
  glancing for two seconds. Every screen's job is a glance or a tap, never reading.
- **The direction** (D54): bold, dark, card-based; ink surfaces; one warm accent, amber `#FFB45E`;
  a fixed colour and SF Symbol per muscle group. Tokens and components in
  `Features/Design/Theme.swift`; the full palette, sizes and names in [`REFERENCE.md`](REFERENCE.md).
- **The copy policy**: the design adds shape, colour and motion, never words. Every visible string
  and accessibility identifier the UI tests read stays; a new string is the user's decision.
- **Reference apps** — from memory, not screenshots; say so when citing them to the user:
  - *Apple Fitness*, the Summary tab: the Move ring (three rings only with a Watch: Move,
    Exercise, Stand) and big numbers with small labels; cards only where content is a group.
  - *Hevy*, the Workout tab: a "Start Empty Workout" hero over routine cards that list their
    exercises in one line (documented); the log is an exercise header over a compact set table.
  - *Strong*, Start Workout: one big Start button over template cards (the grid layout is
    unverified).
  The lesson taken from them: one hero per screen, numbers big and labels small, lists for lists.

## Process

1. **Name the screen's job, state and bold element.** Write, in the ticket: "In the ___ state
   this screen exists so the user can ___ in one tap; the eye lands on ___." One sentence per
   state that changes the composition (Start with and without a live workout are two states).
   Done when each sentence names one element and the runner-up is demoted in writing.
2. **Compose in reading order.** The eye starts top-leading; the thumb rests in the bottom
   third. Put the bold element at one of the two, never both, and say which. Sketch the initial
   viewport as an ASCII wireframe with relative sizes (which block is largest, which are equal);
   a scrolling collection continues below it. When the user is choosing, sketch three that differ
   in structure, not colour. Done when the wireframe is in the ticket and every block is named.
3. **Mock before code when the structure changes.** Use the `design` canvas (phone-sized
   artboards in the app's tokens, one per direction); if the canvas is unavailable, a SwiftUI
   `#Preview` screenshot per direction. Send them to the user. Done when the user has picked or
   said to proceed; a one-element restyle skips this step.
4. **Answer the tells** (below) in the ticket, each as "absent" or "deliberate: <functional
   reason or the accepted composition>". Author preference is not a reason. Done when every
   tell has a line.
5. **Build** with the tokens and components, extending `Features/Design/` when a component is
   missing. Done when the build is green and the screen's gate tests (the ticket names them,
   with counts) pass.
6. **Capture and look.** In `RedesignScreenshotUITests`, the SAME fixture and state at the
   default size and at AccessibilityL (the project's gate; it is the first accessibility size,
   not the largest), scrolled so every block the wireframe names is on record; add the capture
   if the screen has none. Open the PNGs and look at them as pictures. Done when every string
   the wireframe names is whole at both sizes and the bold element is still first.
7. **Cross-review to clear.** Hand the reviewer the ticket (job, state, wireframe, exceptions,
   captures) and [`REVIEW.md`](REVIEW.md). Done when the reviewer says "clear" after the fixes,
   with the captures retaken for any fix that moved a pixel.

## Rules

- **One dominant treatment per screen state.** The bold element is the only CALL TO ACTION or
  figure with an accent fill or the largest content type. Excluded from that count: the
  navigation title (chrome), and amber as a state — the selected tab, a selected chip, a
  completed set — because a state is not a call to action. A second accent-filled command or a
  second accent-coloured content title on the same screen competes, and one steps down.
- **Cards group.** A card contains a group, or one item with internal structure (a template with
  its exercises, a stat with its label). A card around a single line of text is a box around a
  sentence: remove it. A set of like items is a list. Never a card in a card. Peer cards share a
  radius; hierarchy comes from size, position and surface, not from changing the radius.
- **Numbers big, labels small.** A glanceable figure is `stat` (Title 2 rounded bold) or, once
  per screen, `hero` (Large Title rounded black — the one Black weight in the app); its label is
  Caption in secondary. Several `stat` figures on one screen are fine; one `hero` is the limit.
- **Type is the system's.** Text styles, not point sizes: Large Title or `hero` for the screen,
  Headline (`cardTitle`) for a row title, Body for content, Subhead/Footnote for support, Caption
  for labels. Regular to Bold, plus `hero`'s Black; never Light. SF only; Rounded where the
  tokens already use it.
- **Colour carries meaning, and the same meaning everywhere.** Amber: the action or the live
  thing, and selection. Red (`Danger`): heart rate, failure sets, destruction. Yellow: warmup.
  `Drop`: drop sets. Unit colours: unit chips. Muscle colours: muscle groups. A colour used for
  decoration steals from its meaning. Contrast: 4.5:1 minimum, 7:1 the target for small text —
  the measured pairs are in REFERENCE.md; `TextTertiary` is not for essential text on
  `SurfaceElevated` or `SurfaceFill`. `Hairline` (7 % white) separates and borders a filled
  card; it is never the only thing that draws a shape.
- **Controls: 44 pt hit region minimum; prominence by style, not size.** One, at most two,
  prominent buttons per view. Equal options get equal size. The primary role never destroys.
  A collapsed selection control (a `Menu` standing in for a picker) shows its current value and
  a disclosure indicator and never wears the primary style; a segmented picker shows its
  options; a command menu (ellipsis) shows its symbol — each keeps its native affordance.
- **Lists are lists.** More than three like items: a list (rows, hairline separators, one
  container) rather than a stack of cards; swipe actions and context menus stay on rows.
- **Sheets do one task and keep their commit semantics.** A sheet with STAGED edits offers
  Cancel and its commit verb (Save, Add); a sheet whose edits apply immediately (presets, the
  deleted-machines list) and a sheet that only shows offer Close or Done; Back only in a
  multi-step flow; never all three. Prolonged flows are pushed screens or a full-screen cover.
- **The tab bar navigates; it never acts.** Up to five tabs, filled symbols, one-word labels;
  actions live in toolbars or on the screen.
- **Dynamic Type is a layout, not a font size.** Rows stack trailing accessories under the text
  at accessibility sizes; chips wrap (`WrapLayout`); tiles scale (`@ScaledMetric`); the order
  of the hierarchy is kept; nothing the user needs truncates.
- **Motion answers the user.** A completed set, a started workout, a finished timer, plus the
  pulse that means "live". Under Reduce Motion each animation is suppressed or replaced by a
  crossfade — reading the setting is not honouring it.
- **Empty is an invitation.** `EmptyState` with the existing string and one action under it.

## Tells

Patterns that read as generated when they appear regardless of the content. Each is answered in
the ticket (step 4); some are right here and say so:

- The same container on everything regardless of role (a card around a title, a card around a
  button).
- A chip where a caption would do; a row wearing more than two chips.
- An all-caps label above every section.
- Middle-dot metadata — deliberate here for the frozen stat lines such as "1 exercise · 1 set".
- The accent on so many things it stops marking anything.
- Two or three full-width blocks of equal weight stacked, none leading.
- A phone-sized website: hero, sections, dead space.
- More than the job needs above the fold, or a first viewport half empty while the job sits
  below it.
- A control dressed as the primary command (a picker in the accent) or the primary command
  dressed as content.
- A layout that only survives at the default text size.
