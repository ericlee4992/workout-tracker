# Agent-skills 03 — independent review, round 4

Reviewed `84a3a2f3..61bb8a91` on `ericlee4992/simulator-control`, HEAD `61bb8a91dfcd3ca55522145142d070f7405157cd`. Read STATE, the ticket, round-4 brief, prior findings, updated wrapper/config/docs and relevant installed MobileBuildMCP 2.7.1 source. The working tree was clean before this report.

## Findings

No new findings within the stated developer-tool scope. All four round-3 findings are resolved.

## Standards

- **#1, environment socket override:** the wrapper clears exported `MOBILEBUILDMCP_`, `XCODEBUILDMCP_` and `XCODEBUILDCLI_` variables before restoring only the telemetry opt-out. It rejects endpoint arguments, then requires both daemon status and registry metadata to name the repository root. A permitted status check with foreign socket/log-path environment values still reached the same repository daemon, confirming those overrides were removed.
- **#2, unreadable status:** `read_status` requires successful command completion and recognizable Running/Not running output. Callers check its result explicitly, including after a failed stop. A timeout or parse failure now aborts; only a successfully confirmed Not running state permits continuation after replacement. A daemon that remains running exhausts the bounded wait and aborts.
- **#3, registry/log coupling:** registry discovery now uses the socket's workspace hash and the package's workspace state layout rather than the log location. The candidate metadata must match the root, status PID, version 2.7.1 and configuration timestamp. Installed `workspace-identity.js`, `socket-path.js` and `log-paths.js` confirm that layout. A custom log location no longer forces restarts; verified normal reuse preserves element-reference state.

No outstanding standards findings.

## Spec

- **#4, configuration scope:** DEVELOPMENT, the configuration comment and ticket now correctly state that loading is relative to the process working directory, without ancestor search. The wrapper moves to the root, requires the config and exports the opt-out; normal daemon startup uses the workspace root. Bare subdirectory calls are explicitly excluded from that config guarantee and agents are directed through the wrapper.
- The footprint and physical-device exclusions remain accurate. The ticket maps all four fixes to the code and records author cases A–J, including fault injections. These are author-reported runs, not reviewer reruns.
- The accepted status-to-call replacement interval remains documented in the ticket. No additional concrete telemetry-defeating path was found within the intended use on this Mac. This clearance does not claim atomic enforcement against a separate installation replacing the daemon in that interval.

No outstanding spec findings.

## Verification

Read-only/tooling checks, all exit 0:

- `bash -n scripts/sim-ui.sh`.
- `scripts/sim-ui.sh --version`: `2.7.1`.
- `scripts/sim-ui.sh daemon status`: existing repository daemon PID 54343.
- `MOBILEBUILDMCP_SOCKET=/tmp/review-unused-foreign.sock MOBILEBUILDMCP_DAEMON_LOG_PATH=/tmp/review-unused-log.log scripts/sim-ui.sh daemon status`: same PID, workspace, normal socket and normal log location. No foreign endpoint was contacted and no log file was created by this status-only check.
- Read-only Node imports of the installed package's workspace/socket/registry helpers matched the wrapper's registry layout. Registry metadata named this root and version 2.7.1. Its start time currently predates the config mtime, so a guarded tool call would replace it; status commands intentionally bypass that replacement path. No replacement was attempted.
- Read-only invocation of the actual config hydration function with both opt-out variables cleared in the child process set `MOBILEBUILDMCP_SENTRY_DISABLED=true` from the root config. No Sentry initialization or tool action was invoked.
- Documentation: **34 relative file links, 5 anchors, 0 broken**.
- `git diff --check 84a3a2f3..61bb8a91`: clean.
- `scripts/check-secrets.sh --all`: clean.

Standards: 0 outstanding findings. Spec: 0 outstanding findings.

Verified: all four fixes by source/consistency review; shell syntax, version/status, environment-override removal, registry layout, root config loading, links/anchors, whitespace and secret checks.
Not verified: live fault injection or daemon replacement, trial replay, simulator actions, builds, network capture or physical-device operations. The author's A–J cases were not rerun. No phone, Apple account, backups, deployment or desktop-control access. Only this report was written.
Known flaky: no reviewer UI trial; the author reports none in the selected runs.

Verdict: clear
