# Native redesign prototype — architecture contract

A THROWAWAY SwiftUI prototype of the whole redesigned app, runnable in the iOS Simulator, with
in-memory sample data and a floating switcher between three looks (A Floodlight, B Anatomy,
C Paper Club). It answers "what should the app look and feel like?" — not production code.
No persistence, no HealthKit/camera/network/AI calls (all simulated), no tests.

- Checkout: `/Users/ericlee06/orca/workspaces/Health App/redesign-prototype` (branch
  `ericlee4992/redesign-prototype`). Project: `RedesignPrototype/RedesignPrototype.xcodeproj`,
  one app target, sources in the filesystem-synchronized folder `RedesignPrototype/Sources/`
  (any file added there is compiled — no pbxproj edits). NEVER touch `WorkoutTracker/`, the
  real `WorkoutTracker.xcodeproj`, or the main checkout `/Users/ericlee06/orca/projects/Health App`.
- Toolchain: Xcode 27, iOS 26.0 deployment, Swift 5 mode with `SWIFT_DEFAULT_ACTOR_ISOLATION =
  MainActor` (everything is main-actor by default; fine for a UI prototype).
- Simulator: `WT-Redesign` (iPhone 15 Pro Max, iOS 27.0) UDID `9B1D17D2-347F-431C-AC6D-F019BAB675CA`.
  Only the integrator boots/installs on it. Screen authors do NOT run simulators.
- Bundle id `com.ericlee4992.workouttracker.redesignprototype`, display name "Redesign".

## Folder layout (Sources/)

```
App/            PrototypeApp.swift (@main), RootView.swift (tabs, covers, routing)
Model/          Models.swift, SampleData.swift, Store.swift, Derived.swift, Format.swift,
                Simulators.swift (HR script, cardio distance, AI/scan delays)
Look/           Look.swift (LookID, Look tokens, environment), Components/*.swift
Prototype/      LookSwitcher.swift, ScreenIndex.swift (jump to any state), ScreenID.swift
Screens/<Area>/ one folder per area: Workout, Templates, AI, Live, Cardio, Finish, History,
                Gyms, Scan, Exercises, Settings, System
```

## Naming rules (parallel authors must not collide)

- Types in `Screens/<Area>/` are prefixed with the area: `HistoryListScreen`,
  `HistoryCalendarSheet`, `LiveSetRow`… Private helpers are `private`/`fileprivate`.
- Never edit files outside your own area folder. If you need something from Model or Look that
  does not exist, add it in your area as `<Area>Support.swift` using extensions with
  area-prefixed names (`extension Store { func historyMonthSummary() … }`), and list it in your
  report so the integrator can promote it.
- Every screen is a `View` whose initializer takes only simple values (ids, enums) — it reads
  data from `@Environment(Store.self)` and the look from `@Environment(\.look)`.

## Store (Model/Store.swift) — `@Observable final class Store`

Injected at the root with `.environment(store)`. Holds all sample data and the live session.
Screens mutate it through methods (no persistence). It must support every flow in
`screen-list.md`: start lifting/cardio/template, add exercise/by machine, add/complete/delete
sets, set types (W/F/D), supersets, bar mode, rest timer (Date-based end, +15s, skip,
heart-rate rest), live heart-rate script (1 Hz, the fixture sequence) with zone, new-best
detection on completion, cardio start/pause/resume/end with simulated distance, finish →
summary pushed to history, save as template, template CRUD, gyms/machines CRUD + deleted list,
simulated AI routine generation and simulated scan results (specific/ambiguous/generic), settings.

## Look (Look/Look.swift)

```swift
enum LookID: String, CaseIterable, Identifiable { case floodlight, anatomy, paperClub }
struct Look { let id: LookID; /* tokens: colours by meaning, fonts by role, radii, spacing,
  surface style, button styles, motion flags */ }
extension EnvironmentValues { @Entry var look: Look = .floodlight }
```
Colour tokens by MEANING (never by hue name): ground, surface, surfaceRaised, surfaceSheet,
hairline, textPrimary/Secondary/Tertiary, action, onAction, live, positive (new best),
heartRate, destructive, warmup, drop, failure, family(chest/back/shoulders/arms/legs),
zone(0...5), unitKg/unitLb. Fonts by ROLE: largeTitle, title, headline, body, subhead,
footnote, caption, heroNumber, statNumber, timer (all built from system text styles so Dynamic
Type scales; width/design via `.fontWidth`/`.fontDesign`). Components switch on `look.id` only
for the documented signature variants (surfaces, capsule style, set-complete effect, week
widget, new-best badge, finish celebration).

## Prototype chrome

- `LookSwitcher`: a small floating capsule at the top-trailing safe area (above content, below
  the status bar), visually distinct from every look (system material, SF Mono caption):
  "◀  A · Floodlight  ▶" + a grid button that opens `ScreenIndex`. Draggable to the other side.
  Switching look animates a crossfade. Always visible, including over sheets/covers (host it in
  an overlay window or on each presentation root).
- `ScreenIndex`: a sheet listing every screen/state in `screen-list.md` by ID and name, grouped
  by row; tapping one resets the relevant store state and navigates there (e.g. "S05 Result —
  Ambiguous" opens Gyms › Iron Temple › Scan with the ambiguous result).
- Launch arguments for automated captures: `-look floodlight|anatomy|paperClub`
  `-screen <ID>` (e.g. `-screen H03`), `-hideSwitcher YES`. The app opens directly in that
  state, fully rendered, no animation pending.

## Verification each author runs (no simulator)

Typecheck your files together with the foundation (and without `App/`):
```
cd "/Users/ericlee06/orca/workspaces/Health App/redesign-prototype/RedesignPrototype/Sources"
xcrun --sdk iphonesimulator swiftc -typecheck -target arm64-apple-ios26.0-simulator \
  -default-isolation MainActor -module-name RedesignPrototype \
  $(find Model Look Prototype -name '*.swift') $(find Screens/<YourArea> -name '*.swift')
```
(If `-default-isolation` is not accepted by this swiftc, use `-Xfrontend -default-isolation
-Xfrontend MainActor`, or add `@MainActor` where needed.) Zero errors is required. Warnings OK.
