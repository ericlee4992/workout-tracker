# Current project state

Updated **2026-10-13** (paid team, App Store Connect record, server resources, ticket 01b, first TestFlight upload).
The previous STATE (Floodlight delivery, the Oct 10–11 free re-sign, the Oct 3 public-beta handoff) is archived
byte-for-byte: [STATE before TestFlight](archive/STATE-2026-10-13-before-testflight.md). Verify Git on resume.

## NOW: TestFlight build 0.1.0 (1) uploaded, processing at Apple

- **`main` = `936b18f`** (pushed; origin confirmed): Floodlight + live-workout fixes 01/02 + public-beta 01 B/C
  records + the server's D1 id + **ticket 01b** (the `workout-processing` background mode removed; the post-beep
  keep-alive restart). Merged by fast-forward at the user's go-ahead ("merge into main once Codex clears");
  `beta-deploy-01` and `beta-01b-background-mode` were rebased onto it first (force-with-lease pushed).
- **Uploaded 2026-10-13 ~03:02 EDT:** version 0.1.0 build 1 from `936b18f`, "Upload succeeded"; evidence in
  [ticket 01 → Phase E](../work-record/public-beta/issues/01-paid-team-testflight.md). Not yet seen in App Store
  Connect (processing). **This branch** `ericlee4992/beta-01e-testflight` holds this STATE and the phase E record.
- **Next (ticket 01 phase E):** the build appears in TestFlight → answer export compliance if asked → add it to the
  internal group **"Developer"** by hand (automatic distribution is off) → **Gate S over USB** (app closed) → the
  user installs from the TestFlight app with the app closed (stop if it offers only delete-and-install) → launch,
  Export JSON, counts equal Gate S → the user turns **off TestFlight Automatic Updates** → the backup-bridge proof
  (E4) → Live Activity, widget, home-screen name "Stacked".

## The phone

- iPhone 15 Pro Max, iOS 27.0, UDID `00008130-001E10C01E62001C`, bundle `com.ericlee4992.workouttracker`.
- **Installed: `fd88791`** (ticket 01b's last test build; app code identical to `main` `936b18f`), development
  signing on the **paid team** — profiles app `c8b27150…`, widget `0e309c14…`, both to **2027-10-13T04:33Z** (no
  weekly re-sign any more). Phone check passed (the user, 2026-10-13: beep while locked/minimized, no repeat after an
  AirPod route change, next rest beeps, heart rate verified by the user).
- **Latest verified backup:** `~/WorkoutTracker-Backups/2026-10-13-paid-team/` — `capture-2` before the year-long
  install and `after-install` after the user's check (every old row preserved; 30 workouts). Captures need USB;
  Wi-Fi copies fail. The app stays closed during a capture; a failed process query proves nothing.
- Known, accepted: a long workout title truncates beside Cancel (seen with "Seated Che…"). Pre-existing, open: the
  minimized workout's Live Activity heart rate gets no recurring update (ticket 01b, R3-P1).

## ACTIVE: public beta ("Stacked")

Plan: **[spec](../work-record/public-beta/spec.md)**, decision **D60**, tickets
[`work-record/public-beta/issues/`](../work-record/public-beta/issues/). Conventions: one branch per ticket off `main`;
Claude implements, Codex reviews to "clear" in a visible Orca terminal (watch the report file); the user's go-ahead
before every merge; `scripts/check-secrets.sh --staged` before every commit (public repo); secrets typed or piped by
the user locally, never in chat or the repo; decline desktop control (`orca computer …`); the user accepts legal
terms themselves; Claude never enters credentials.

| Ticket | State (evidence in each ticket) |
|---|---|
| 01 paid team + TestFlight | **B done** (paid team kept Team ID `X68M8SR6NA`; app IDs unchanged, so **D's delete/restore is not needed**). **C done**: App Store Connect app **"Stacked: Gym Log"** (Apple ID `6822152192`, SKU `stacked-ios`; "Stacked" was taken; home-screen name stays "Stacked"), TestFlight internal group "Developer", automatic distribution off, the user as tester. Year-long dev build installed in place and checked. **E: build 1 uploaded**; steps 2–5 next (see NOW). |
| 01b background mode | **Done, merged** (`936b18f`): Codex clear round 4; unit 31/31; phone check passed. |
| 02 onboarding | Merged (`4823d46`). On the phone since the paid-team build; reaches testers with TestFlight. |
| 03 server + Sign in with Apple | Server half merged. **Cloudflare (2026-10-13):** wrangler logged in; D1 `stacked` (`3652ad5c-7c0b-4b75-874b-6ab2ad7ce8ec`, in `server/wrangler.jsonc`), migrations 0001–0005 applied remotely; R2 bucket `stacked-feedback`. **Not deployed.** Left (server/README "First deploy"): Sign in with Apple key (.p8) and the capability on the bundle ID, `APPLE_TEAM_ID`, `wrangler secret put` APPLE_KEY_ID / APPLE_PRIVATE_KEY / TOKEN_ENC_KEY / OPENAI_API_KEY (the user types them), `npm run deploy` with the user's approval. App half next (unblocks 05, 06's app switch, signed-in 07). |
| 04 Google sign-in | Held: the user's Google Cloud OAuth client; after 03's app half. |
| 05 profile | Merged (mock approved + server side); wiring waits on 03's app half. |
| 06 AI proxy | Server half merged; app switch after 03; deployed CPU/adversarial checks before external testers. |
| 07 feedback | Merged; row hidden until `WT_SERVER_URL` is set. |
| 08 external testers | Privacy draft merged, unpublished; needs the user's answers (legal name, support email, retention, App Privacy choices). |
| 09 App Store | Not started. |

## Next action

1. Ticket 01 phase E (see NOW). Check App Store Connect for the processed build; the tab is open in the user's Chrome.
2. Server first deploy (03), then 03's app half → 05/06/07 wiring; 04 later; 08 answers; 09.
3. Clean-up when E is done: scratch checkouts `/tmp/wt-resign` (detached `b83cf39`) and `/tmp/wt-live02` (detached
   `936b18f`, holds the paid-team `Config/Local.xcconfig`; used for archiving).
4. Still waiting on the user from before: visual acceptance of the Floodlight redesign on the phone. Not yet exercised
   anywhere: VoiceOver by a person, Reduce Motion at runtime, real GPS and sensors on the redesigned cardio screens,
   Lock Screen commands on a device, a restore from a backup on a phone, a non-US simulator region.

Simulators: **WT-Floodlight** `9E822EF6-DC67-4958-AEA2-D53D2D36D674` (iOS 27; targeted runs), **WT-Onboarding**
`2CEC4AD8-F702-421F-B3B2-D68C302A3453` (sample data only), **WT-Backup-01** `A3D88C6F-6426-427A-9A0E-CF11A93798B1`
(Gate S round trips; erase after every use).

## Found 2026-10-02 (pre-existing, not caused by the public-beta work)

- **iOS CI ("Tests" workflow) fails on every `main` run since the Floodlight merge `4765b76` (2026-09-29):** the build
  stops compiling `WorkoutTracker/Features/ActiveWorkout/LiveSetRow.swift` on the `macos-26` runner (Xcode 26); the same
  code builds and tests locally on Xcode 27. A runner-image/SDK mismatch to look at with the deferred hosted-CI work.
  The new "Server" workflow (secret scan + server tests, Linux) passed on `e455222`.
- **Three UI tests fail on `main` too** (ticket 02's regression run): `FloodlightHistoryUITests` light/dark captures at
  `:100` ("a multi-day series draws", likely date-dependent since the month changed) and
  `CoreLoopUITests.testModelPickerFiltersAndSearchesDownToOneModel` (:274, the known model-picker flake). A small
  follow-up ticket.

## Still open from before the redesign (unchanged; details in the archived STATE)

- [AI ticket 06 — private device acceptance](../work-record/ai-gym/issues/06-device-acceptance.md): after the
  September 22 update, the phone checks were never reported. These cover all generated templates visible without a
  restart, Scan Machine inside template setup, preserved preferences and equipment, and old history visible. Also
  gym recognition and routine feedback. Do not ask for the OpenAI key in chat; the Mac credential
  `~/.config/workouttracker/openai.env` (0600) is not bundled.
- [Cardio hardware checks](../work-record/cardio/issues/02-device-acceptance.md): pause/reconnect, phone-position
  accuracy, background GPS, mixed sessions. The Watch companion has never been built or installed.
- [Deferred work](../work-record/deferred-work.md): scanner/picker, history/calculation, supersets, precision,
  migration/restore, HR, Watch, catalog, public launch and CI follow-ups. Non-failing invalid-frame warnings, the
  hosted CI runner hang, and actual Orca workspace Sleep also remain deferred.

## Other sessions and scratch state (do not clean without asking)

- The main checkout `/Users/ericlee06/orca/projects/Health App` is on `ericlee4992/redesign-visual-proposal`
  (a separate Codex session's visual proposal, superseded by the Floodlight decision; not merged).
- **Worktree clean-up 2026-10-01 (user's choice):** removed every clean, pushed or merged checkout — the eleven
  `/tmp/wt-floodlight/*` scratch checkouts and sixteen older Orca worktrees (ai-gym-and-routines, ai-template-followup,
  cardio-*, codex-project-setup, compact-start-outdoor, finish-summary-*, restore-start-capsules,
  review-cardio-implementation, session-handoff*, sets-completion-ring, verification-policy); their branches remain in
  Git and on origin. `/tmp/wt-floodlight/` keeps `results/` (test logs, xcresults), `shots/`, the runner scripts and
  `dd-device/` (the binary installed on 2026-09-29); the other derived data was deleted.
- **Kept for a later look (not removed):** worktrees whose branches exist only on this Mac, some with uncommitted
  files — `ai-schema-baseline`, `ai-template-followup-review`, `cardio-api-research`, `redesign-prototype` (the
  tappable Simulator prototype of the Floodlight look; one uncommitted file), and the `review-*` checkouts (Codex/Claude
  review reports, some untracked). Save or push before removing any of them. `redesign-floodlight` (the redesign's
  Orca worktree, identical to `main`) can be closed once no session runs in it. Simulator **WT-Floodlight**
  `9E822EF6-DC67-4958-AEA2-D53D2D36D674` (iOS 27); WT-iPhone27 / WT-iPhone kept for regression and compatibility.
- The Graft index is a git-ignored local cache per checkout: rebuilt in this worktree 2026-10-01 (graft 0.18.0); the
  main checkout's is older (`graft build` refreshes it).
- **Branches on origin with commits not in `main`, all deliberately unmerged records** (nothing else is unmerged):
  `ericlee4992/redesign-visual-proposal` (4, the superseded 09-24 visual proposal, the main checkout's branch),
  `ericlee4992/cardio-design-prototype` (3, 09-17 cardio prototypes), `ericlee4992/finish-summary-second-pass` (3,
  09-17 finish-summary exploration), `ericlee4992/review-cardio-implementation` (3, 09-18 review records),
  `ui-redesign-16-active-workout` (1, a ticket-16 docs note). Every `redesign-floodlight*` branch is in `main`.
