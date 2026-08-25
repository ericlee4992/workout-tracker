# Where the project is right now

Updated 2026-08-24 — milestone 7 (heart rate) complete, reviewed, installed; live HR and zones
confirmed in a real gym; the deferred bar-weight cross-review is complete and its fixes are
installed and launch-verified on the phone (16:37).
**Read this after `CLAUDE.md`** — SPEC and DECISIONS say what the product is and why; this says
what has actually happened and what to do next. Keep it current; it is the one file that goes
stale fastest.

## Status

Merged and pushed on `main`: **everything, including milestone 7** (`ca67603`, merged 2026-08-25). **479 unit + 21 UI green.**
**Milestone 7 (heart rate) is MERGED into `main`** (2026-08-25, fast-forward — `main` still has
zero merge commits). The `milestone-7-heart-rate` branch is now identical to `main` and can be
deleted whenever convenient. `github.com/ericlee4992/workout-tracker` (private).

| Shipped | What it is |
|---|---|
| Milestone 2 (`ce32158`) | Core loop on SwiftData — logging, prefill, PRs, snapshots, rest timer |
| Milestone 3 (`798372c`) | CSV/JSON export, D28–D32 — the only backup that exists |
| Label scanning (`64188e2`, `33be96d`) | Live camera reads a machine's name plate, ranks the 1877-model catalog, user confirms (D33–D35) |
| Exercise presets (`33be96d`) | Grips / single-double as variations that **split records** (D36–D38) |
| Collaboration setup (`b5dfac9`) | Signing moved to a gitignored `Config/Local.xcconfig`; CI runs unit tests on every PR |
| Barbell bar weight (2026-08-22) | Pick the bar, type plates per side, log the total (D39–D40). Half of milestone 6, brought forward |

**Milestone 7 — heart rate (D41–D45), committed on branch `milestone-7-heart-rate`.**
Live HR on the workout screen from AirPods Pro 3 or an Apple
Watch, zones, system calories, a heart-rate rest timer, and a finish summary. 8 tickets in
`.scratch/milestone-7-heart-rate/`, all resolved; two Codex rounds run and every critical fixed
(`codex-review.md`, `codex-review-2.md`), each with a regression test in
`CodexReviewRegressionTests`.

The milestone began at `428ab7a`; zone fixes and the completed bar-weight review/fixes are also
committed on `milestone-7-heart-rate` through `4bbe3e8`. **Merged and pushed 2026-08-25.** `main` is `ca67603`; the branch is no longer ahead of it. Merging is the user's call. After the bar fixes, the complete unit suite
is **451 tests across 42 suites**, and the 4 affected UI tests are green (two existing plus two new
regressions).

**Independently re-run on 2026-08-24 (T6's "verify independently" rule): the COMPLETE suite —
451 unit + 21 UI — passed, exit 0.** Codex had run only the 4 affected UI classes; this was all
21, and it confirms nothing elsewhere regressed. This is the number to trust for the branch tip.

**Verified once, so nobody re-derives it:** the **free** Apple account provisions all three
HealthKit entitlements including `background-delivery` — no Developer Program needed. The iPhone
workout-session API is `ios(26.0)`, hence D42. The Apple Watch is **not** a GATT peripheral to the
phone, which is the entire reason a watchOS target exists.

**Partly proven on hardware, 2026-08-23.** The user reported: *"the heart rate correctly measures
during workout."* That is the first real-sensor evidence this milestone has, and it clears the
biggest unknown — the permission flow, the phone's `HKWorkoutSession`, the live feed reaching the
workout screen, and the number itself all work on the device.

**The source question is settled (2026-08-24): the bar read "AirPods."** The phone's own
`HKWorkoutSession` was reading the earbuds, exactly as designed — the Watch was NOT feeding it. So
D41's watch target is still justified and the milestone's design holds as written. Do not reopen
this one.

**The same session found a real bug, now fixed (2026-08-24): no zone ever appeared.** See
"Zones were unreachable" below.

Be precise about what the gym session does and does not cover. **Verified:** a live, correct bpm
from AirPods on the workout screen during a real workout. **Still unverified:** the calorie
figure's plausibility; the heart-rate rest timer (D43); the background alarm with the screen off;
and the entire `WCSession` path.

**Zone boundaries were revised 2026-08-24 after gym use** — every zone read about one too high, so
D45's textbook 50/60/70/80/90 became **55/65/75/85/95** (see DECISIONS). The user is on the 220−age
estimate, which runs low for fit people and inflates every percentage; raising the max was offered
and declined in favour of shifting the boundaries. **Cost, stated plainly: this app's "Zone 3" is
no longer Polar's or Apple's Zone 3.** A measured maximum would let them go back to standard.
The revised numbers are **installed as of 2026-08-25** but have not yet been seen in a gym.

**Zones were verified working on the device (2026-08-24), at the OLD boundaries.** After the `0c9bdeb` install the user set a
maximum and reported: *"The zone feature correctly works."* The user also checked the app's zone
boundaries against an external reference (50/60/70/80/90/100% of max) and confirmed they match —
they are identical to D45 as built, so **no change was made**. Two deliberate extensions beyond
that reference were raised and explicitly left as-is: sub-50% renders "Warm-up" rather than Zone 1,
and a bpm above the recorded maximum stays Zone 5 rather than erroring.

Not established: whether the user supplied a MEASURED maximum or the date-of-birth estimate, so
the DOB path (see the test gap below) is still unconfirmed either way. Also still unseen: the
"(estimated)" marking that D45 requires when the basis is 220−age.

### The background rest alarm — four attempts, and why the first three failed

**Solved 2026-08-25 (`82a1ddb`), confirmed on the device.** Worth reading in full: the same trap is
waiting for anything else that must happen at a moment in time while the app is not on screen.

**The rule:** iOS promises a backgrounded app NO CPU at a chosen instant. Any feature designed as
"run code when the deadline arrives" is therefore built on something the platform does not offer.
The fix is not to fight for background execution — it is to **remove the need to execute at all**.

The rest deadline is known the moment the rest starts, so the beep is handed to the audio pipeline
THEN, as one asset: `[inaudible dither for N seconds][beep]`. At the deadline nothing runs; the
beep is the next part of a buffer already playing. `RestAlarmTone.restTrackWav`.

Covers **both** rest kinds — a plain timed rest and D43's cap queue identically. Early heart-rate
recovery cannot be queued (its moment is unknowable in advance), so it plays live when the app is
executing, with the queued cap track as the floor.

**Three failed attempts, each fixing a real-but-not-decisive thing:** play at the deadline; add
background modes and move the alarm off the dismissable view; loop an inaudible keep-alive. All
three kept the "execute at the deadline" dependency, which was the actual defect.

**What made it take four rounds, and what to do differently:**

1. **A scheduled local notification firing was read as proof the app was running.** It is not. A
   `UNTimeIntervalNotificationTrigger` is handed to the system in advance and fires whether or not
   the app is alive. That single wrong inference cost two attempts.
2. **Assertions were made without checking Apple's documentation.** "`workout-processing` is
   watchOS-only" was stated as fact and written into the plist as a comment. It is FALSE on iOS 26,
   which brought workout sessions to iPhone. `.mixWithOthers` was likewise blamed and was innocent.
3. **A safeguard was defeated in the function next to it.** `keepAliveSamples` dithers at ±1 LSB so
   output is never digital silence; `startKeepAlive` then set `volume = 0.01`, scaling it to ~3e-7.
4. **The user was right that it should not be complicated.** Their push — *"I don't think this
   should be a complicated problem"* — and their reframing (*the notification already fires at the
   right instant; can it just be audible?*) is what produced the working design. Notification
   sounds play on the phone's ALERT route and iOS gives apps no way to send them to Bluetooth
   headphones — but that reframing exposed the real question: **is an audio route to the AirPods
   open at that moment?**
5. **Two independent consultations disagreed, and that was the point.** Codex first concluded no
   supported API could do this and recommended AlarmKit; Fable 5 found that wrong on iOS 26 and
   validated the pre-rendered design. Re-asked, Codex reversed itself: *"technically narrow but
   practically wrong for this case."* AlarmKit would ALSO have failed — iPhone alarms deliberately
   play through the built-in speaker — so building it would have burned a fifth attempt.

**Not verified:** ducking. It is deliberately not applied to the queued beep, because ducking needs
code at the deadline — the very dependency this removes. The beep mixes over music at full scale.

### Zones were unreachable — fixed and installed 2026-08-24 (`0c9bdeb`)

The user ran a real workout, got live heart rate, and never saw a zone. Two bugs, compounding:

1. **A closed loop.** `MaxHeartRateSheet` is the only place `measuredMaxHeartRate` / `birthDate`
   can be set, and its only entry point was the "· zone estimated" button in `HeartRateBar` —
   which renders only when a zone already exists, which needs the maximum that sheet sets. Both
   fields are nil on a fresh install, so `resolvedMaxHeartRate()` returned nil, no chip rendered,
   no button rendered, and the feature could never be switched on by anybody. D45 says "with no
   basis, show no zones", and the code did that faithfully — while offering no way to supply a
   basis.
2. **Stale after saving.** `resolvedMaxHeartRate()` was read only inside `.task`, which runs once
   per appearance, so a maximum entered mid-workout left `monitor.maxHeartRate` nil for the rest
   of that workout — the setting appearing to do nothing.

Fixes: a "· set up zones" prompt in the bar when there is no maximum (`hrZoneSetup`), a **Heart
rate zones** row in Settings showing the current basis or "Not set", and a re-resolve on the
sheet's `onDismiss`. Two regression tests in `HeartRateUITests` (`testZonesCanBeSetUpFromTheWorkoutScreenAndApplyImmediately`, `testZonesAreReachableFromSettings`). **449 unit + 19 UI green at the time; the branch tip is now 451 + 21** after Codex's bar-weight fixes added two more UI regressions.

One gap, deliberately: the setup test drives the MEASURED-max field, not the date-of-birth toggle. `app.switches["useBirthDate"].tap()` lands on the row label and does not flip the switch — an XCUITest quirk, not an app defect, but it means the DOB path is untested and it is the path a user without a lab test actually takes. Zones themselves are confirmed working on
the device (2026-08-24), but the user did not say which basis they entered, so this gap is still
open: if the DOB toggle was never used, neither it nor the "(estimated)" marking has been exercised
by anything.

**This is the same class as the watch rest-countdown bug below** — every piece individually
correct, the *absence of a caller* the only defect — and again two Codex rounds did not catch it.
Worth noting the pattern: both were found by a human using the feature, not by review or by tests.
A test asserting "no zone without a basis" passed happily while the basis was unsettable. **When a
feature is gated on a setting, assert the setting is reachable**, not just that the gate works.

Everything still unverified came from `FixtureHeartRateProvider` under `-uiTestHeartRate`.

**The phone is now current with the branch** (`0c9bdeb`, installed 2026-08-24) — the watch
rest-countdown mirror fix rode along with the zone fix.

**Worth knowing how that bug was found**, because it is a class the review process missed: the
watch screen rendered a rest countdown, `WatchLink` carried a `restEndsAt` field — and nothing ever
sent a non-nil one. Every piece was individually correct; only the *absence of a caller* was wrong,
and no test asserts that a message is ever sent. Two Codex rounds did not catch it. It surfaced
while explaining the feature to the user in prose.

**Two things are true and easy to miss:**

1. **Bar weight merged before its cross-review, but that debt is now closed** (see Reviews in
   `DECISIONS.md` and `.scratch/barbell-bar-weight/codex-review*.md`). The review found and fixed
   stale cross-unit input, stale preset-prefill UI, mixed-source carry-forward, invented variable
   bar presets, incomplete bar normalization, and related contract gaps. The D39 invariant remains
   load-bearing: `weightValue` is the total and bar fields are provenance.
2. **Almost none of it has met a real gym.** The scanner has never read a real name plate; no
   preset has been logged against in a session; bar mode has never been used to load a bar. Every
   threshold and layout is tuned against fixtures. Those answers should shape the next session
   more than the backlog does. (One item came off this list on 2026-08-22: an export of the real
   history now exists, in iCloud Drive.)

The app is being **dogfooded in real gym sessions** — that is the current activity. Feedback from
those sessions outranks new features.

## The live install (facts you cannot rediscover from the code)

| Thing | Value |
|---|---|
| Installed commit | **`37c0f2b`** — the background rest alarm. Installed **2026-08-25 00:28** and launch-verified. Clean-built (`rm -rf /tmp/wt-device-build`) and the plist checked BEFORE installing: `UIBackgroundModes` = `[audio, workout-processing]`, both HealthKit strings present. No schema change. The **watch companion is still NOT installed**: no Apple Watch has ever been reachable from this Mac (ticket 02) |
| Previously installed | `f5cc50a` (revised zones + first audible alarm), 2026-08-25 00:06 — the alarm in that build only sounded while the app was on screen |
| Previously installed | `a32755b` (milestone 7 + bar-weight review fixes), 2026-08-24 16:37 — launch-verified; this is the build that migrated `barNormalizedKg` onto the real store |
| Previously installed | `0c9bdeb` (zone-reachability fix), 2026-08-24 00:32 — never launch-verified, superseded hours later |
| Previously installed | Milestone 7's uncommitted working tree, 2026-08-22 23:45. It launched, so the D44/D43/D45 optional fields migrated the user's real store |
| Previously installed | The bar-weight merge (2026-08-22, installed 16:31 — the content is what is now on `main`, built from the working tree just before the merge commit existed). Installed before its Codex pass at the user's request, with a backup taken first (below) |
| Store migration | **Done on the real store, 2026-08-22.** `main` (`a3a6934`) was installed first so an export could be taken, then the branch build; it launched, so `SetRecord.barWeightValue` migrated the user's actual data. `a3a6934` can no longer open that store — the migrated schema is one-way without the export |
| Backup | **Re-exported 2026-08-24 by the user, before the `barNormalizedKg` migration** — the current backup. Previously: CSV + JSON to iCloud Drive on 2026-08-22 before that schema change — the first copy of the training history off the device. Re-export after any session worth keeping |
| Previous installed commit | `33be96d` (2026-08-12) — export, live label scanning, movement labels, presets |
| iPhone UDID | `00008130-001E10C01E62001C` |
| Apple Team ID | `X68M8SR6NA` — now in `Config/Local.xcconfig` (gitignored), **not** in `project.pbxproj` |
| Signing | **Free** Apple account → builds expire **7 days**. Last signed **25 Aug 2026** (00:28), so expires **~1 Sep 2026**. HealthKit entitlements verified signed INTO the binary, not merely present in the profile. Each reinstall resets the clock |
| Bundle ID | `com.ericlee4992.workouttracker` (from `WT_BUNDLE_ID_BASE` in `Config/Local.xcconfig`) |
| Test simulator | `WT-iPhone` (create per CLAUDE.md if missing) |

**Reinstalling** preserves the user's data — same bundle ID keeps the container. Say so before an
install; that phone holds the only copy of the training history until an export is saved off it.

The wizard (`./scripts/install-on-device.sh`) is interactive and meant for a human. With the
signing identity and Developer Mode already in place, the direct path is three commands:

```sh
xcrun devicectl list devices                      # confirm udid 00008130-…, transport, tunnel state
xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -configuration Debug \
  -destination 'platform=iOS,id=00008130-001E10C01E62001C' -allowProvisioningUpdates \
  -derivedDataPath /tmp/wt-device-build build
xcrun devicectl device install app --device 00008130-001E10C01E62001C \
  /tmp/wt-device-build/Build/Products/Debug-iphoneos/WorkoutTracker.app
```

Gotchas seen doing exactly this on 2026-08-11: the phone pairs over **localNetwork**, and its
tunnel reads `disconnected` until something asks for it — the first install attempt died with
`NWError 60 - Operation timed out` and the identical retry succeeded. Do not conclude the phone is
unreachable from one timeout. `devicectl device process launch` additionally needs the phone
**unlocked**, and fails with `FBSOpenApplicationErrorDomain error 7` when it is not; that says
nothing about whether the install worked.

## What to do next, in priority order

1. **Act on gym feedback.** Six questions are open and no test can answer them. The three newest,
   from the bar mode installed 2026-08-22:
   - Is **plates per side** what the user thinks in while loading, or total plates?
   - In bar mode PREVIOUS shows last session's **total** while the field takes **plates**. Does
     the `= 135 lb` caption reconcile that mid-set, or does it read as two different numbers?
   - Is a bar the user actually owns missing from `BarbellMath.presets`? Custom covers it, but a
     weekly bar belongs in the list.
   And the three still open from before:
   - Does the scanner read a **real** name plate? If it reads it but refuses to preselect, that is
     the D33 gate working, not a bug — a plate that does not name its manufacturer never
     preselects (95% of clean brand+model readings do, 0% of model-name-only ones), because a
     wrong model UUID splits history (D23). Thresholds live in `CatalogMatcher` (0.85 preselect /
     0.35 create-new / 0.08 margin), tuned against the catalog and rendered plates, not
     photographs. Retune only with real misses in hand.
   - Does the **export** look right over the real history in a spreadsheet?
   - Are the **preset chips** reachable one-handed mid-set? Their layout is guesswork.
2. **Milestone 7 is installed and partly proven.** Live heart rate works on the device
   (2026-08-23). What remains unanswered, in rough order of what it would teach:
   - ~~Which sensor produced it?~~ **Answered 2026-08-24: AirPods.** The design holds as written.
   - ~~Do the **zones** look right?~~ **Answered 2026-08-24: yes**, on the device, after the
     reachability fix. Boundaries were also cross-checked against an outside reference and match.
     What is still open is narrower: **is the "(estimated)" marking visible** when the basis is a
     date of birth rather than a measured maximum (D45)? That is the one part of the zone feature
     no one has seen work.
   - ~~Is the **calorie** number plausible?~~ **Reported slightly high, 2026-08-24 — no code
     change made, deliberately.** The app never computes calories: it reads the system's own
     `activeEnergyBurned` from `HKLiveWorkoutBuilder`, already configured
     `.traditionalStrengthTraining` / `.indoor`. So the number IS Apple's, and there is no formula
     here to tune — inventing a correction factor would be the false precision D9/D25 exist to
     refuse. Likely causes are all outside the app: a stale weight in Health (most common), no
     Apple Watch so the estimate leans on heart rate alone (which runs high for lifting, since HR
     stays up between sets), and iOS being generous for strength training generally. **Told the
     user to check their weight in Health first.**
   - Does the **heart-rate rest timer** (D43) end a rest when the heart rate comes down, and does
     the alarm say which ended it — recovery or the cap?
   - ~~**Does the alarm fire when the app is not on screen?**~~ **SOLVED AND CONFIRMED ON THE
     DEVICE, 2026-08-25** (`82a1ddb`): *"it worked! the beep now plays with screen off."* See
     "The background rest alarm" below — it took four attempts and the lesson is worth reading
     before touching anything time-based again.
   - Historical, for context on how it was reached: Gym report 2026-08-25: the first
     audible build beeped **only while the app was open** — nothing with the screen off, on another
     app, or on the home screen. Three causes, all fixed in `37c0f2b`: `UIBackgroundModes` was
     missing `workout-processing` (so iOS suspended the workout session and no samples arrived at
     all — the real cause); the alarm lived in the workout SCREEN's state, which C1's minimise
     dismisses; and an audio failure called `assertionFailure`, which traps in a Debug build.
     **The lesson worth keeping: the local notification firing was NOT evidence the app was
     running.** A `UNTimeIntervalNotificationTrigger` is handed to the system in advance and fires
     regardless — it had been read as proof of background execution for two days.
   - **Is the alarm actually audible?** Gym feedback 2026-08-24: the notification fired
     both ways, screen off included, but nothing came through the AirPods — a notification sound
     plays on the phone's alert route and never reaches Bluetooth headphones. The app now
     synthesises a tone and plays it through `AVAudioSession` (`.playback` + `.duckOthers`), with
     recovery and cap sounding different (two rising tones vs three flat). **None of this has been
     heard by a human.** What to listen for: does it cut through gym noise and your own music, does
     the music duck and come back, and does the beep fire **with the screen off** — that last one
     runs off the heart-rate sample tick because a SwiftUI timer stops when the screen sleeps, and
     it needs the new `audio` background mode to play at all.
   - Does the watch companion install, pair, and stream? **No Apple Watch has ever been visible to
     this Mac** (`devicectl` sees only the iPhone), so nothing on that path is installed. It is a
     **separate** install by design — embedding it breaks every simulator test run (ticket 02) —
     and it needs Developer Mode on the watch plus a second bundle id on the same 7-day clock.
   - **Open question nobody has answered:** can the phone WAKE the watch app? The design has the
     phone send "workout started" over `WCSession`, but iOS→watchOS messaging does not reliably
     launch an app that is not running. The likely reality is the user taps the app on their wrist
     first. Only hardware settles it.
   - Does the heart-rate rest alarm fire with the screen off? That is what
     `healthkit.background-delivery` was provisioned for and it has never been observed.
3. **Milestone 4 — progress charts** (Swift Charts; normalized axes, as-entered tooltips). The
   next unbuilt milestone, and what makes the logged history worth looking at.
4. Milestone 5: Strong CSV import. Milestone 6 is now **half done** — the bar half shipped
   2026-08-22; what remains is computing which plates to load for a target weight, and
   selectorized stack increments.

**Owed from milestone 7's review, deliberately not fixed:** the migration fixture
(`WorkoutTrackerTests/Fixtures/LegacyStore.store`) was generated at `5239ef2` and the phone now
runs the bar-weight build, so the gate opens an older approximation of the real store than it
claims to. Regenerating needs the phone.

**Test-harness fact worth keeping:** a UI-test run started with `-uiTestReset` but WITHOUT
`-uiTestHeartRate` gets a `DisabledHeartRateProvider`. Without that, every XCUITest that starts a
workout summons the HealthKit permission sheet, which covers the screen and turns eight passing
core-loop tests into "button not hittable" — a failure that reads as a layout bug and is not one.

**Known latent bug, found while building bar mode, deliberately not fixed:** `Format.weight`
(`Domain/SharedEnums.swift`) renders to one decimal, and the set row's text becomes the stored
value on completion — so a prefilled 62.25 kg row commits as **62.3**. It only bites weights with
two decimals, which 2.5 lb/1.25 kg plate math does not produce, but it is a silent rewrite of the
user's own numbers. Bar mode's fields dodge it by seeding through `WeightMath.displayNumber`.

## Decisions the user has NOT made yet

- **Adding a human collaborator.** The repo was made ready for one on 2026-08-18 (per-developer
  signing, CI on PRs) and the user was weighing it. If someone joins, **D5 and T6 must be reopened
  deliberately**: D5 says the audience is the developer alone, and T6 justifies agent cross-review
  by there being no second pair of human eyes. Does a human PR approval replace the Codex pass or
  stack with it? Also unresolved: branch protection on `main` may need a paid plan for a private
  repo.
- **Apple Developer Program ($99/yr)** — needed for TestFlight, which is the only sane way to get
  the app to other testers and would also end the 7-day expiry. The user asked about it, weighed a
  free 2–3 family-member pilot first (possible, but every phone must be cabled to the Mac weekly).
  Prep work not started: app icon (**none exists** — App Store Connect rejects uploads without
  one), export-compliance key, upload script.
- **Catalog gaps worth closing** if the user hits them: Atlantis (dealer-sourced only), Titan and
  Sorinex (barely researched), Life Fitness Signature Series (discontinued but still on gym floors
  — the most commercially significant gap). See `docs/catalog-sources/README.md`.

## Environment gotchas that cost real time

- **Certificate chain.** Apple issues development certs from the WWDR **G3** intermediate. A Mac
  carrying only the original WWDR intermediate (expired 2023-02-07) reports "0 valid identities"
  and `codesign` fails with `errSecInternalComponent` — which reads as *no certificate* when the
  certificate is fine. Fix: install `AppleWWDRCAG3.cer`. Already done here; the install wizard now
  detects and repairs it.
- **Developer Mode** must be ON *and* confirmed after the phone restarts. `devicectl`'s
  `developerModeStatus` can report a stale `disabled` — attempt the build; it is authoritative.
- **Computer-use cannot drive this app.** Synthetic clicks reach the Simulator's UIKit tab bar but
  **not SwiftUI list buttons**. Use the XCUITest target (`WorkoutTrackerUITests/`) instead — that is
  why it exists.
- **A store fixture from the installed commit lives in `WorkoutTrackerTests/Fixtures/`.** Any
  schema change must open it (`LegacyStoreMigrationTests`) before going near the phone — that
  store is the shape of the user's real data, and "SwiftData infers this migration" is a claim,
  not evidence. Regenerate the fixture from the *installed* commit whenever the shape changes.
- **UI tests take ~7 minutes** and occasionally flake under load. A single red run is not
  automatically a real failure; re-run the failing test alone before believing it.
- **Changing `INFOPLIST_FILE` needs a CLEAN build, and an incremental one lies.** The app now
  merges a partial `Config/WorkoutTracker-Info.plist` (for `UIBackgroundModes`, which build
  settings cannot express) with the generated keys. The first incremental build after that change
  produced a plist **missing `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription`**
  — and a missing HealthKit usage string is a *crash* on the permission request, not a prompt.
  `clean build` produced the correct merged plist. Verify with
  `plutil -p <built app>/Info.plist` after any plist-affecting change; do not trust the build
  succeeding.
- **`INFOPLIST_KEY_UIBackgroundModes` is silently ignored.** It is accepted as a build setting and
  shows up in `-showBuildSettings`, but Xcode's plist generator only writes an allowlist of
  `INFOPLIST_KEY_*` settings and array-valued keys are not on it. It never reaches the built plist.
  Hence the partial-plist file above.
- **The Simulator has no camera.** Anything camera-driven needs a fixture path to be testable at
  all — hence `-uiTestScanFixture`, which renders a name plate in place of the picker. And a
  missing `INFOPLIST_KEY_NSCameraUsageDescription` is a *crash* on presentation, not a prompt;
  the project generates its Info.plist, so usage strings live in build settings.
- **A `.sheet` attached to a `Section` inside a `List` never presents.** No error, no warning —
  the state flips and nothing happens. Hang presentation off a row *inside* the section. Cost an
  export that silently did nothing (milestone 3, ticket 02); caught only by the XCUITest.

## Working agreements learned the hard way

- **Verify independently.** Twice, an agent reported the suite green and an independent re-run
  failed — once a genuine race (`CONTINUATION MISUSE` from an unfiltered `didSave` observer,
  fixed in `ce32158`). Run the suite yourself before believing a summary.
- **Cross-review is not optional** (T6). Codex reviews of Claude's work have caught, among others:
  template data loss on an empty templated workout, D23 violations where history read live rows,
  and ten duplicate catalog identities that would have split the user's own history. Reviews live
  in `.scratch/*/codex-review*.md`. Milestone 3's pass caught an export that dropped a draft
  entry's equipment and a CRLF-quoting bug that would have corrupted the CSV. The scanner needed
  **two** rounds, and the second round's worst finding was a defect introduced by the first
  round's fix — budget for a re-review after fixing criticals, not just after writing code.
- **State the consequence where the decision is made.** Every review that went well did so because
  a doc comment said what breaks if the rule is broken (usually: "this splits the user's history").
  Comments that only restate the code have caught nothing.
- **Locked decisions get reopened deliberately** — D26 (drop sets) reopened D12 rather than drifting.
- The user prefers **seeing the UI** (screenshots from the simulator) over descriptions of it.
