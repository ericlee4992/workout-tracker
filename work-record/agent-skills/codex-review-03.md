# Agent-skills 03 — independent review, round 1

Reviewed `eb431b3a..440b6cc9` on `ericlee4992/simulator-control`, HEAD `440b6cc98889d0e98b4cdd6bc350096683534850`. Read STATE, AGENTS.md, the ticket/brief, review-round, the DEVELOPMENT changes, wrapper and relevant installed package source. Working tree was clean before this report.

## Standards

1. **P2 — Verify the daemon as well as the CLI before promising telemetry off and a pinned version.** `scripts/sim-ui.sh:7–11` exports the opt-out and checks the version of the newly started CLI process only. A daemon previously started by a bare CLI invocation for this workspace is reused with its original environment; the wrapper cannot turn off that existing process's telemetry. A still-running daemon from a different package version can likewise survive a package replacement if its wire protocol is compatible. Snapshot/tap calls therefore need not execute with the advertised version and opt-out, contradicting DEVELOPMENT.md:209–211,223–224.

   Installed source under `/Users/ericlee06/.local/lib/node_modules/mobilebuildmcp/` establishes the path: `manifests/tools/snapshot_ui.yaml:10–11` and `tap.yaml:11–12` mark them stateful; `build/runtime/tool-invoker.js:249–257,395–405` routes CLI calls to an already-running daemon without transferring the environment. `build/cli/daemon-control.js:120–139` also accepts an existing daemon; the version error checks the protocol, not the package. `build/daemon/daemon-server.js:74–85` exposes neither package version nor telemetry state in status. `build/utils/sentry.js:211–232,319–337` initializes/emits using the daemon's own environment, including invocation metrics when enabled.

   **Fix:** establish a wrapper-managed daemon with known version and telemetry provenance, or refuse an unverified existing daemon before sending tool requests. Isolate it from ordinary CLI daemon reuse or explicitly validate and replace the incompatible instance. Preserve the managed daemon across snapshot/action calls: restarting on every call would discard the element-reference state. Cover pre-existing telemetry-enabled and wrong-version daemon cases in the next verification, not only a fresh daemon's inherited environment. This finding is established by source inspection; I did not start a telemetry-enabled daemon or send a UI request.

## Spec

2. **P3 — Include temporary capture and socket locations in the footprint documentation.** `docs/DEVELOPMENT.md:224` and `work-record/agent-skills/issues/03-simulator-control.md:56` identify only `~/Library/Developer/MobileBuildMCP`. The documented path-return screenshot operation retains its JPEG under Node's `os.tmpdir()`: installed `build/mcp/tools/ui-automation/screenshot.js:173–177,253–263` deletes the original PNG but returns the optimized JPEG without deleting it (PNG remains instead if optimization fails). `build/daemon/socket-path.js:16–27` also places the socket under `os.tmpdir()/mobilebuildmcp-<workspace hash>/d.sock`. An agent using the stated directory as the complete cleanup inventory would leave captures behind. **Fix:** distinguish persistent logs/state from temporary sockets and returned screenshot files; document preserving a needed capture in the ticket's artifact location or deleting that specific returned file after use. Correct the ticket's footprint statement or qualify it to persistent state.

Standards: 1 P2 finding. Spec: 1 P3 finding.

## Other conclusions

- Installed package metadata and the allowed version check both identify **2.7.1**. The wrapper's missing-command and version-mismatch branches fail closed with exit 3 by inspection; `exec mobilebuildmcp "$@"` preserves arguments containing spaces. Those failure branches and spaced arguments were not dynamically exercised.
- Fresh daemon spawning does inherit the exported opt-out (`daemon-control.js:85–96`). Installed `sentry-config.js` and `sentry.js` recognize `MOBILEBUILDMCP_SENTRY_DISABLED=true`. Upstream's [privacy documentation](https://github.com/getsentry/xcodebuildmcp.com/blob/main/app/docs/_content/privacy.mdx) documents that setting as disabling the SDK; this does not fix an already-running daemon's environment.
- The [v2.7.1 release notes](https://github.com/getsentry/MobileBuildMCP/releases/tag/v2.7.1) confirm the rename, environment-variable prefix and state-directory name. The [v2.7.0 release notes](https://github.com/getsentry/MobileBuildMCP/releases/tag/v2.7.0) confirm Device Hub simulator support. No upstream claim substitutes for the installed-source daemon check above.
- The inspected UI-automation paths target simulators. Physical-device workflows also exist in the package, and this wrapper forwards arbitrary arguments; it is not a command allowlist. The existing project instructions limit its use to simulator screen control. An explicit sentence excluding physical-device tools would clarify that boundary; no additional demonstrated phone-access defect was found or exercised.
- The allowed help output matches the snapshot workflow. Installed `type_text.js` explicitly rejects unsupported text with a US-keyboard-only message, supporting the documented limitation. The project's builds/tests/installs remain assigned to xcodebuild/simctl; no tool init or MCP registration was introduced by this diff.
- The ticket records one exploratory pass and two unattended passes, matching the requested two consecutive unattended runs. I did not replay them or independently confirm their timings/screenshots: the throwaway trial runner and its per-step artifacts are not identified by path in the ticket. The named build log ends `BUILD SUCCEEDED`; this is inspected author evidence, not a reviewer build. Keeping the CLI without MCP registration is consistent with the trial's purpose.
- Source inspection did not establish an additional outbound service in the inspected simulator-screen routes when telemetry is genuinely disabled. No network capture or exhaustive audit of all package workflows/dependencies was performed; the unrestricted wrapper's other workflows are outside the claimed screen-only use.

## Checks performed

- `scripts/sim-ui.sh --version`: exit 0, `2.7.1`.
- `scripts/sim-ui.sh ui-automation snapshot-ui --help`: exit 0; inspected the simulator-id and snapshot help. No simulator was driven.
- `bash -n scripts/sim-ui.sh`: exit 0.
- Relative documentation links: **30 file links and 5 anchors checked, 0 broken**, exit 0.
- `git diff --check eb431b3a..440b6cc9`: exit 0.
- `scripts/check-secrets.sh --all`: exit 0, clean.
- Read installed package metadata/source and upstream primary release/privacy pages; no package installation, daemon start/stop, UI action or build was run.

Verified: wrapper version/help and shell syntax; documentation links/anchors, whitespace and secret checks; static analysis of telemetry initialization, daemon reuse, screenshot storage and simulator targeting.
Not verified: replay of the trial, live daemon provenance, network egress capture, missing/wrong-version runtime cases, physical-device tools, other screens or gestures. No phone, Apple account, backups, deployment or desktop-control access. Only this report was written.
Known flaky: no runtime UI trial was performed by this reviewer; the author reports none in the two unattended passes.

Verdict: not clear
