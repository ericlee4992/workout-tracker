# 03 — Simulator control for agents: MobileBuildMCP trial

Status: **trial passed — in review** (branch `ericlee4992/simulator-control` off `main` `eb431b3a`).
Type: task (tooling trial)

## The user's request (2026-11-18)

"go ahead with that first" — after Claude proposed MobileBuildMCP (getsentry/MobileBuildMCP, formerly XcodeBuildMCP)
so an agent can tap, swipe, type and screenshot in the simulator (the gap in machine-settings 01's prototype: no touch
tool). Plan agreed: pinned version, telemetry off, screen control only (builds and tests stay DEVELOPMENT's), a trial
on My settings; drop it if it is flaky on Xcode 27.

## The tool

- `mobilebuildmcp` **2.7.1** (npm, `repository` getsentry/MobileBuildMCP; GitHub release v2.7.1, 2026-09-23 — the
  rename; Xcode 27 Device Hub UI automation came in 2.7.0). MIT.
- Installed into the user-local Node with an exact version (`npm install -g mobilebuildmcp@2.7.1`); uninstall is one
  line. Its `init` (which installs its skills, telling agents to replace `xcodebuild`) is **not** run.
- Called only through `scripts/sim-ui.sh`, which sets the telemetry opt-out on every call.
- CLI only for the trial; MCP registration (which would load its tools into every session) deferred until it passes.

## Pass criteria (written before the first tap)

On WT-iPhone27 with a fresh build of `main` and the `-uiTestDesignMySettings` fixture, driven by the CLI from the UI
snapshot (targets found by label/identifier, not guessed coordinates):
1. Tap the chest press's My settings line → the editor opens; type a change; Save → the line shows it.
2. Open the chest press card's "⋯" → My Settings… → the editor opens; Cancel.
3. Scroll to the Shoulder Press card's "Add My Settings" chip and tap it → the editor opens.
4. Minimise the workout → Train → Gyms → Iron Temple → Cable Station → its "My settings · Low Row" row.
5. Screenshots taken by the tool match what the flow should show.
- The whole flow **twice in a row** without manual help; time per step recorded.
- No macOS permission prompt is accepted without the user (stop and ask).
- Fails if: targets can't be found from the snapshot, taps land wrong or flake, or it needs coordinates by eye.

## Progress

### 2026-11-18 — the trial

- Release check first: GitHub release v2.7.1 (2026-09-23) is the latest and carries the rename; npm `mobilebuildmcp`
  2.7.1 points at getsentry/MobileBuildMCP (the old `xcodebuildmcp` stops at 2.7.0); Device Hub support since 2.7.0.
- Installed `mobilebuildmcp@2.7.1` into the user-local Node (151 packages). The installed code reads
  `MOBILEBUILDMCP_SENTRY_DISABLED` (or `SENTRY_DISABLED`) in `build/utils/sentry-config.js`; `scripts/sim-ui.sh`
  exports it and refuses any version but 2.7.1. The daemon the CLI started carried the variable (checked with `ps
  eww`); `daemon stop` ended it.
- App: `main` `eb431b3a` built (`xcodebuild build` exit 0, `build/sim-control-build.log`), installed on WT-iPhone27,
  launched with `-uiTestReset -uiTestDesignSample -uiTestDesignLive -uiTestDesignGyms -uiTestDesignMySettings`.
- **Pass 1 (step by step):** all four steps passed, every target found in the snapshot by its accessibility
  identifier (`mySettings.cardLine`, `mySettings.field`, `mySettings.save`, `mySettings.menuItem`,
  `mySettings.addChip`, `minimizeWorkout`, `gymRow.Iron Temple`, `machineRow.Cable Station`,
  `mySettings.machineRow.Low Row`); the screenshot matched the Cable Station page.
- **Passes 2 and 3 (the whole flow unattended, a throwaway script outside the repo, relaunching the app each time):**
  0 failures each, 160 s and 158 s (step 1 ~38 s, 2 ~30 s, 3 ~34 s, 4 ~56 s). Criteria 1–5 met; no macOS permission
  prompt appeared.
- **Found limits:** `type-text` takes US-keyboard characters only ("·" failed with `ACTION_FAILED`; plain text
  worked); every action is slow (~10–13 s, snapshots 4–13 s).
- Left behind: `~/Library/Developer/MobileBuildMCP` (12 KB); nothing in the repository.

**Decision (Claude, within the user's "go ahead"):** keep it, CLI only. `scripts/sim-ui.sh`, a DEVELOPMENT section
(*Simulator screen control*: the loop, the limits, the update steps) and one AGENTS.md line. **No MCP registration:**
the CLI through Bash does everything the trial needed and loads nothing into every session's context.

```
Verified: the trial above (3 passes, 0 failures in the 2 unattended ones); xcodebuild build exit 0; links in the
  changed docs resolve
Not verified: other screens and gestures (long-press, drag); the physical-device tools (unused)
Known flaky: none seen
```
