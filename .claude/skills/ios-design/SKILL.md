---
name: ios-design
description: Design, restyle or review a screen of this iPhone app — its composition, hierarchy, type, colour and Dynamic Type — before any screen-level UI change, when mocking a screen for the user, or when the user says a screen looks off, boring or generic.
---

# iOS design for this app

A screen is designed, not styled. Styling applies the tokens to whatever is there; designing decides
what is there, in what order, and which ONE thing the eye lands on. The first redesign pass
(tickets 01–09, `.scratch/ui-redesign/`) styled: it put the same card, chip and uppercase label on
everything, and the user's verdict was "the design is not there". This skill exists so the second
pass composes.

## The brief

- **What it is**: a private gym logger for one person. Used one-handed, mid-set, under gym lighting,
  glancing for two seconds. Every screen's job is a glance or a tap, never reading.
- **The user's words**: "the app seems a bit boring, with mostly texts and it essentially doesn't have
  a clean UI design"; after the first pass, "the design is not there", the Start screen "seems a bit
  off". Bold, dark, card-based was the direction chosen (D54); the execution is what fell short.
- **The system** (D54, `Features/Design/Theme.swift`): dark only; ink surfaces; ONE warm accent, amber
  `#FFB45E` with near-black text on it; warmup yellow; heart rate red; a fixed colour + SF Symbol per
  muscle group. Components: `.card()`, `Chip`, `StatTile`, `ProgressRing`, `EmptyState`, `WrapLayout`,
  `.primary` / `.secondary` buttons. The copy policy: the design adds shape, colour and motion,
  never words; every string and accessibility identifier the UI tests read stays.
- **Reference apps** (described from memory, not screenshots — say so if you cite them to the user):
  - *Apple Fitness*: the summary is three rings and a handful of big numbers with small labels;
    one accent per activity type; generous type; cards only where content is a group.
  - *Hevy*: Start is a hero "Start Empty Workout" over routine cards that show the routine's
    exercises as a line of text; the log is an exercise header over a compact set table; dark.
  - *Strong*: a workout tab that is one big Start button and a two-column grid of template cards.
  What they share: one hero per screen, numbers big and labels small, lists for lists.

## Process

1. **Name the screen's job and its one bold element.** Write one sentence: "This screen exists so
   the user can ___ in one tap; the eye lands on ___." Every other element is quiet. Done when the
   sentence names one element, and a second candidate has been demoted in writing.
2. **Compose in reading order.** Top-leading is where the eye starts; the thumb reaches the bottom
   third. The hero action goes where the thumb is or where the eye starts, never both places. Sketch
   the composition as an ASCII wireframe. When the user is choosing, sketch three that differ in
   structure, not in colour. Done when each wireframe fits one screen at the default text size and
   the bold element is obvious from the sketch alone.
3. **Mock before code when the change is structural.** Use the `design` canvas: phone-sized artboards
   in the app's tokens, one per direction, sent to the user to pick and tweak. A restyle of one
   element skips this. Done when the user has picked, or said to proceed.
4. **Check against the tells** (below) and the rules. Done when every tell is answered with either
   "not present" or the reason it is deliberate.
5. **Build with the tokens and components**, extending `Features/Design/` when a component is
   missing rather than styling inline. Read [`REFERENCE.md`](REFERENCE.md) for the numbers.
6. **Capture and look.** `RedesignScreenshotUITests` at the default size AND at AccessibilityL
   (`-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityL`); open the PNGs and
   look at them as pictures. Every AXL capture in the first pass found a defect the default-size
   capture hid. Done when every string is whole at both sizes and the bold element is still first.
7. **Hand the reviewer** [`REVIEW.md`](REVIEW.md) — the cross-reviewer grades against it, not against
   taste.

## Rules

- **One bold element per screen.** Spend the accent there: the hero button, the live workout, the
  one number that matters. Everything else is ink, grey and white. Two amber things compete; three
  is a screen with no point.
- **Cards group; they do not decorate.** A card says "these things belong together". A list of
  like items is a list (rows, hairline separators, one container). A single item in a card is a
  box around a sentence — remove the card. Never nest a card in a card.
- **Numbers big, labels small.** A figure the user glances at is `stat` (title2 rounded bold) or
  `hero`; its label is `caption` in secondary. Never the reverse.
- **Type is the system's.** Text styles, not point sizes: Large Title for the screen, Headline for a
  row title, Body for content, Subhead/Footnote for support, Caption for labels. Weights Regular
  to Bold; never Light. One family (SF; SF Rounded only for the numerals the app already rounds).
- **Colour carries meaning once.** Amber = the action or the live thing. Red = heart rate.
  Yellow = warmup. Muscle colours = muscle groups. A colour used for decoration steals from the
  meaning it has elsewhere. Text on ink: `TextPrimary`, `TextSecondary`, `TextTertiary`; contrast
  4.5:1 minimum, 7:1 for small text, and `Hairline` (7 % white) is invisible as a ring or a stroke
  — it separates, it never outlines.
- **Controls are 44 pt and prominent by style, not size.** One, at most two, prominent buttons per
  view. Equal options get equal size. The primary role never destroys.
- **Lists are lists.** A grouped list with system row styles beats a stack of custom cards for
  anything with more than three like items. Swipe actions and context menus stay on rows.
- **Sheets do one task.** Cancel pairs with Done; one sheet at a time; long flows are pushed
  screens, not stacked sheets.
- **The tab bar navigates; it never acts.** Five tabs at most, filled symbols, one-word labels;
  actions live in toolbars or on the screen.
- **Dynamic Type is a layout, not a font size.** Rows stack their trailing accessories under the
  text at accessibility sizes; chips wrap (`WrapLayout`); tiles scale (`@ScaledMetric`); nothing
  truncates that the user needs.
- **Motion answers the user.** A completed set, a started workout, a finished timer. Nothing moves
  on its own except the pulse that means "live".
- **Empty is an invitation.** `EmptyState` with the existing string, one action under it.
- **Words are fixed.** The copy policy stands: reuse existing strings; a new string is a product
  decision the user makes, not a design choice.

## Tells

The first pass matched every one of these; two independent design skills list them as the marks of
generated UI. Answer each for the screen in hand:

- The same rounded card on everything, one radius regardless of hierarchy.
- Too many pills and tags; a chip where a caption would do.
- An ALL-CAPS eyebrow label above every section.
- Meta strings joined with middle dots.
- Near-black plus one bright accent used everywhere, so the accent stops meaning anything.
- Three full-width blocks of equal weight stacked, none leading.
- A phone-sized website: hero, then sections, then dead space.
- Too much above the fold, or a screen that is half empty below it.
- A control styled like content or content styled like a control (a picker that looks like a
  button, a title in accent that does nothing).
- Text that only survives at the default size.
