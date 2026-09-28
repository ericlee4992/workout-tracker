Independent review (T6) of ticket 11 of the Floodlight redesign: System surfaces and cleanup — the Live
Activity and Dynamic Island (with +15s / Skip / Pause / Resume on the card), the rest-complete
notifications, the app icon, removing `Theme` and the pre-redesign components, and the D59 decision record,
on branch `ericlee4992/redesign-floodlight-system`. Range: `ericlee4992/redesign-floodlight-ai-routine..HEAD`
(stacked on ticket 10's tip `0fa6814`). Claude implemented; you review. Run in the checkout
`/tmp/wt-floodlight/system` and stay in it.

Read first: AGENTS.md; `work-record/redesign-floodlight/issues/01-implement-redesign.md` (user decisions,
area order item 10); `issues/11-system.md` (scope, the user's four decisions of 2026-09-28 — lock-screen
commands built, Cardio split into ticket 12, the Live Activity following the system appearance, the violet
dumbbell icon — implementation, failed approaches, strings, verification); `.claude/skills/ios-design/REVIEW.md`;
DECISIONS D22, D26, D43–D46, D48, D52, D57 and the new D59 (plus the D47 / D56 amendments and D54 marked
superseded). Prototype captures `reference/prototype-system/{dark,light}/`; prototype source (read-only)
`/Users/ericlee06/orca/workspaces/Health App/redesign-prototype/RedesignPrototype/Sources/Screens/System/`.
Actual captures: `captures/11/` (the gallery states, the real card in the Simulator, the icon). The old
widget: `git show ericlee4992/redesign-floodlight-ai-routine:WorkoutTrackerWidget/WorkoutActivityView.swift`.

Review for:
1. **Commands from the card** (`WorkoutActivityIntents.swift`, `WorkoutActivityCommands.swift`): each does what
   the in-app button does — the store, the rest notification, the audible alarm (`broadcastRest`), the Watch
   mirror, the cardio recorder's sensors — whether the live screen is up, minimised or not built (a cold
   background launch: the handler is installed in the app's `init`; the fallback controller adopts the card).
   A stale card must not edit a finished, deleted or different workout, nor add to a rest that has run out.
   Races: the live screen's own state (`restEnd`, `restTotal`, `lastRestResult`, `degradedRestSetID`) after an
   external change (`didApply`), a heart-rate rest being evaluated while +15s arrives, a superset rest.
2. **The content** (`WorkoutActivityContent`, the live screen's `activityState()` cache and `lastRestResult`):
   the next set / line / marker / superset letter / PREVIOUS against the live screen's rules; total and done
   counts; the rest kind (timer / heart rate / fallback) and the inferred result when a rest runs out unobserved
   (`shownResult`); D44 (no reading is absent) and D45 (a zone only with a maximum); the cache key — can a
   change leave the card stale (e.g. an edit to the next set's value, a machine change, a template rename)?
   Cost: what runs on the 2-second tick.
3. **The controller**: the stale date at the rest's end; adoption of an existing card and ending cards of other
   workouts (can it end a card it should keep, or keep an orphan?); `settle`; every workout-ending path still
   ends the card.
4. **The widget views** (`WorkoutActivityViews.swift`, `WorkoutActivityView.swift`) against the prototype and the
   ticket: resting / ready / cardio / the four rest results, the island's compact, minimal and expanded regions,
   the 160-pt budget, the xLarge cap, light and dark, system-ticked timers only (D46), the palette literals against
   `Look.floodlight` / `floodlightLight`, VoiceOver labels (the countdown and clocks must be read with their time).
5. **The gallery** (`ActivityGalleryView`, `-uiTestActivityGallery`): test-only, cannot affect a normal launch;
   the static ring is gallery-only.
6. **Theme / Legacy removal**: every former reader moved with its behaviour and identifiers intact (the cardio
   views, the machine sheets' empty state and unit badge, RootView's tint); nothing deleted was still used; the
   cardio views' layout unchanged (their restyle is ticket 12).
7. **Icon**: the three appearances in `AppIcon.appiconset` and the render script.
8. **Docs**: D59 lists every user decision tickets 01–11 said to record "with the D54 entry" (read each ticket's
   "User decisions" and "Open items handed on"), correctly and without overclaiming; SPEC's visual design; the
   ios-design skill no longer names deleted files.
9. **Tests and verification scope** per DEVELOPMENT: `WorkoutActivityContentTests`, `FloodlightSystemUITests`
   (assertions that could pass vacuously; the real-activity test's arithmetic), the neighbour classes chosen.

Do NOT run xcodebuild or simctl. Do not modify files other than the report. Report findings by
severity (critical / high / medium / low) with file:line and a concrete failure case, or say
"clear" in one paragraph. Write the report to `work-record/redesign-floodlight/codex-review-11.md`.
