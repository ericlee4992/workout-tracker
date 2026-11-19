# Agent-skills 03 — independent review, round 3

Reviewed `2efd32a5..84a3a2f3` on `ericlee4992/simulator-control`, HEAD `84a3a2f32785a0558ec03078e5b19fb9be64373f`. Read STATE, the ticket, round-3 brief, previous findings, updated wrapper/config/docs and installed MobileBuildMCP 2.7.1 source. Working tree was clean before this report.

## Standards

1. **P2 — Close the environment-based socket override.** `scripts/sim-ui.sh:23–25` rejects argument overrides, but retains `MOBILEBUILDMCP_SOCKET`. Installed `build/daemon/socket-path.js:35–38` honors that environment variable before resolving the workspace. Pointing it to a 2.7.1 daemon started in another workspace after this repository's config mtime makes both status and execution use that foreign daemon. The check at lines 40–47 accepts its PID/version/start time without checking its workspace or telemetry configuration. That process never read this repository's config and may still have telemetry enabled. This requires no concurrent replacement and is outside the accepted pin-only race. **Fix:** reject or unset the endpoint environment override before all CLI calls, or explicitly resolve the intended workspace/socket and validate the daemon's matching workspace/config provenance. Cover a foreign workspace daemon with telemetry enabled.

2. **P2 — Do not interpret unreadable post-stop status as confirmed absence.** `scripts/sim-ui.sh:48–50` ignores a failed stop and then tests only whether `$(status_pid)` has empty output. If status times out or otherwise fails, the substitution's nonzero exit does not make `[ -z "" ]` fail; the loop breaks and the final emptiness test permits execution. A daemon that remains alive but temporarily cannot answer status can therefore recover and serve the final call without passing validation. **Fix:** capture both status success and parsed state explicitly; continue only on a successful response confirming “Not running,” and fail closed on timeout/parse/transport errors. Preserve the distinction already enforced by the initial standalone `pid=$(status_pid)` assignment. Cover failed stop followed by unreadable status. This is an errors-as-absence path, not the accepted version-swap race.

3. **P2 — Resolve the registry independently of the daemon log location.** `scripts/sim-ui.sh:35–43` infers `state/daemon/daemon.json` by taking two parent directories of the reported log path. MobileBuildMCP permits `MOBILEBUILDMCP_DAEMON_LOG_PATH` and `daemon --daemon-log-path`; installed `build/daemon.js:83–88` applies the log override, while `build/daemon/socket-path.js:28–30` still locates the registry through the workspace filesystem layout. With an inherited custom log path, each wrapper call fails this inferred lookup, stops the otherwise valid daemon and creates another with the same custom logging configuration. The next tap loses the preceding snapshot's element references. **Fix:** derive the registry from the actual workspace identity/layout API or registry metadata, not from Logs. Verify repeated snapshot/action calls with custom logging preserve the daemon instance.

## Spec

4. **P3 — Limit the config claim to the directory actually loaded.** `docs/DEVELOPMENT.md:211–213` and `.mobilebuildmcp/config.yaml:1–2` say telemetry is off for every CLI call/process in the repository, whoever starts it. Installed `loadProjectConfig` reads `<cwd>/.mobilebuildmcp/config.yaml` directly; it does not search ancestor directories. A read-only call to the actual hydration function with both opt-out variables removed produced `true` for the repository root and `unset` for `WorkoutTracker/`. A bare CLI started in that subdirectory hydrates before resolving its workspace and therefore does not get the root opt-out before `initSentry`. The wrapper's own `cd` and export cover its calls, and normal background daemon startup uses the workspace root, but the broader claim is false. **Fix:** document that scope precisely and require the opt-out environment variable for bare invocations from other working directories, or implement and verify a mechanism that covers those invocations. Qualify the ticket's residual explanation accordingly.

Standards: 3 P2 findings. Spec: 1 P3 finding.

## What is fixed and what remains

The argument forms `--socket value` and `--socket=value` are now rejected by inspection. The fabricated pid/version marker has been replaced with the daemon's actual registry version and start time. Normal CLI startup calls config hydration before `initSentry` (`build/cli.js:114–115`); daemon startup also hydrates before Sentry (`build/daemon.js:120–123`), and `startDaemonBackground` uses `cwd: opts.workspaceRoot`. The root config loads successfully. Footprint documentation remains corrected.

The explicitly accepted interval between status validation and tool execution remains documented in the ticket; no separate finding is raised merely for that interval. The findings above concern additional paths not covered by the claimed pin-only residual. Author-reported live cases and the 186-second flow were not independently rerun.

Installed-source paths above are relative to `/Users/ericlee06/.local/lib/node_modules/mobilebuildmcp/`. Findings 1–3 are established by source/control-flow inspection, not live daemon replacement or fault injection.

## Checks performed

- `bash -n scripts/sim-ui.sh`: exit 0.
- `scripts/sim-ui.sh --version`: exit 0, `2.7.1`.
- `scripts/sim-ui.sh daemon status`: exit 0; existing daemon PID 50747 reported this workspace. This command bypasses the wrapper trust path, so it is status evidence only.
- Read-only Node import of `hydrateSentryDisabledEnvFromProjectConfig`, clearing both opt-out variables in that child process before each call: repository root → `MOBILEBUILDMCP_SENTRY_DISABLED=true`; repository `WorkoutTracker/` subdirectory → unset. No Sentry initialization, CLI action or daemon operation was invoked by this check.
- Relative Markdown links/anchors in AGENTS.md, DEVELOPMENT.md and ticket 03: **33 file links, 5 anchors, 0 broken**, exit 0.
- `git diff --check 2efd32a5..84a3a2f3`: exit 0.
- `scripts/check-secrets.sh --all`: exit 0, clean.

Verified: shell syntax, allowed version/status commands, actual root/subdirectory config hydration, document links/anchors, whitespace and secret checks; static daemon routing, registry lookup and failure handling review.
Not verified: live foreign-socket/custom-log/status-failure cases, daemon replacement, trial replay, simulator actions, builds, network capture or physical-device operations. No phone, Apple account, backups, deployment or desktop-control access. Only this report was written.
Known flaky: no reviewer UI trial; the ticket reports none in the author's runs.

Verdict: not clear
