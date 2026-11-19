# 03 — Simulator control for agents: MobileBuildMCP trial

Status: **done — Codex clear (round 4), merged into `main`**; branch `ericlee4992/simulator-control` kept.
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
- Left behind: state and logs in `~/Library/Developer/MobileBuildMCP` (12 KB); nothing in the repository. (Also, found
  in review: the daemon socket and returned screenshots under `$TMPDIR` — see round 1.)

**Decision (Claude, within the user's "go ahead"):** keep it, CLI only. `scripts/sim-ui.sh`, a DEVELOPMENT section
(*Simulator screen control*: the loop, the limits, the update steps) and one AGENTS.md line. **No MCP registration:**
the CLI through Bash does everything the trial needed and loads nothing into every session's context.

```
Verified: the trial above (3 passes, 0 failures in the 2 unattended ones); xcodebuild build exit 0; links in the
  changed docs resolve
Not verified: other screens and gestures (long-press, drag); the physical-device tools (unused)
Known flaky: none seen
```

### Codex round 1 — not clear (1 × P2, 1 × P3), fixed

[Report](../codex-review-03.md).
1. **P2 — a reused daemon escaped the opt-out and the pin.** Stateful tools run in a per-workspace daemon the CLI
   reuses with its original environment. `scripts/sim-ui.sh` now runs a tool only through a daemon it started itself:
   a marker `~/Library/Developer/MobileBuildMCP/sim-ui-<socket dir>.pid` holds its pid and version, and the process's
   own environment must carry `MOBILEBUILDMCP_SENTRY_DISABLED=true`; any other daemon is stopped and replaced (a
   trusted one is reused, so element refs survive between calls). Checked live: (0) a daemon with no marker →
   replaced; (b) a trusted one → reused, same pid; (c) one started bare, telemetry **on** → replaced by one with it
   off; (d) a marker naming another version → replaced; (a) none running → started and recorded. Then the whole flow
   again: 0 failures, 187 s.
2. **P3 — the footprint.** DEVELOPMENT and this ticket now name the socket (`$TMPDIR/mobilebuildmcp-<hash>/`) and the
   returned screenshots (`$TMPDIR`; keep one in the ticket's captures or delete it), and that physical-device tools
   are not used.
- The trial's runner is kept as [`03-trial-flow.sh`](../03-trial-flow.sh) (it relaunches the app on WT-iPhone27).

### Codex round 2 — not clear (2 × P2), redesigned

[Report](../codex-review-03b.md): (1) a `--socket` argument could send the call to a daemon the script never checked;
(2) the round-1 marker trusted whatever answered "already running" and could not prove a daemon's version.

Rather than harden the per-process checks further, telemetry is now off **by the tool's own configuration**: it reads
`.mobilebuildmcp/config.yaml` from the workspace root (`hydrateSentryDisabledEnvFromProjectConfig`, called by the CLI,
the daemon — whose working directory is the workspace root (`startDaemonBackground`, `cwd: opts.workspaceRoot`) — and
the MCP server) and sets the opt-out before `initSentry`. The committed file says `sentryDisabled: true`; verified by
running that function with no opt-out in the environment (→ `true`). `scripts/sim-ui.sh` (rewritten): runs from the
repository root; refuses without that file; exports the opt-out; refuses `--socket` and `--socket=…`; serves a call
through a running daemon only when its own registry entry (`state/daemon/daemon.json`, written by the daemon) has the
status pid, version 2.7.1 and a start time after the config file's last change — otherwise stops it, and the call
starts a fresh one from the pinned CLI. The round-1 marker files are gone.

Checked live: (1) a daemon started before the config file → replaced; (2) a verified one → reused (same pid); (3) one
started bare, no opt-out in its environment → reused, since the config covers it; (4) a registry naming 2.7.0 →
replaced; (5) `--socket x` and `--socket=x` → refused, exit 2; (6) the config file moved away → refused, exit 3;
(7) no daemon → the call starts one. The whole flow again: 0 failures, 186 s.
Residual (accepted): the status check and the call are separate commands, so a daemon swapped in between them is not
re-checked; only the pin is at risk, and only from another install racing on the same machine. (Round 3 narrowed the
config's reach: it is read from the working directory, not "every process in the repository".)

### Codex round 3 — not clear (3 × P2, 1 × P3), fixed

[Report](../codex-review-03c.md).
1. *`MOBILEBUILDMCP_SOCKET` (an environment socket override)*: the script now unsets every `MOBILEBUILDMCP_`,
   `XCODEBUILDMCP_` and `XCODEBUILDCLI_` variable before re-exporting only the opt-out, and requires the daemon status
   to name this root.
2. *An unreadable status read as "not running"*: `read_status` returns failure unless the status command succeeds and
   says Running (with pid and socket) or Not running; any failure stops the script (exit 4), before and after a stop.
3. *The registry found through the log path*: the registry is now found by the socket's workspace hash
   (`workspaces/*-<hash>/state/daemon/daemon.json`) and must name this root, the status pid, 2.7.1 and a start after the
   config's change; `--daemon-log-path` is refused and `MOBILEBUILDMCP_DAEMON_LOG_PATH` cleared.
4. *P3 — the config's reach*: DEVELOPMENT, the config file's comment and this ticket now say it is read from the working
   directory (the script's root and the daemon), not from a subdirectory.

Checked live: a reused daemon kept its pid across calls (A, B); `MOBILEBUILDMCP_SOCKET=/tmp/foreign/d.sock` ignored
(C); `MOBILEBUILDMCP_DAEMON_LOG_PATH` ignored and the daemon kept across two calls (D); `--daemon-log-path` refused,
exit 2 (E); a call from `WorkoutTracker/` works (F); a registry naming 2.7.0 → replaced (G); with a fake
`mobilebuildmcp` first on PATH, an unreadable status → exit 4 before anything runs (H), and an unreadable status after
a failed stop → exit 4 (I); the whole flow: 0 failures, 170 s (J).

### Codex round 4 — clear

[Report](../codex-review-03d.md): all four round-3 findings resolved, no new ones; Codex checked the override removal
with foreign socket/log variables on a status call, the registry layout against the package's own helpers, and the
root config loading. The accepted residual stays documented. README's layout table names `.mobilebuildmcp/`,
`scripts/sim-ui.sh` and the agent skills. Merged into `main` by fast-forward.
