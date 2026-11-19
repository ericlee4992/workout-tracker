# Agent-skills 03 — independent review, round 2

Reviewed `440b6cc9..2efd32a5` on `ericlee4992/simulator-control`, HEAD `2efd32a5ab6c8958a302f4173fde0e28cdb245c2`. Read STATE, the ticket, both review briefs, the previous report, the updated wrapper/docs/trial runner and relevant installed MobileBuildMCP 2.7.1 source. The working tree was clean before this report.

## Findings

1. **P2 — Verify the endpoint that actually receives the tool call.** `scripts/sim-ui.sh:21–22` checks the default daemon without the caller's arguments, while line 50 forwards all arguments unchanged. MobileBuildMCP accepts `--socket <path>` and `--socket=<path>` anywhere in the command arguments and prioritizes that endpoint (`build/cli.js:35–44,123–126` in the installed package). Thus a call such as `scripts/sim-ui.sh ui-automation snapshot-ui --simulator-id <udid> --socket <other-daemon-socket>` can validate daemon A, then invoke existing daemon B without checking its telemetry or version. **Fix:** reject endpoint overrides in all supported forms, or resolve one effective endpoint and use it consistently for status, start/stop, trust validation and final execution. Cover an override pointing to an untrusted existing daemon. No such tool invocation was executed during this review.

2. **P2 — Bind the trust marker to verified daemon version and process-instance identity.** `scripts/sim-ui.sh:35–40,45–48` writes `$pid $expected` after `daemon start`, treating success as proof that this wrapper created that process. Installed `build/cli/commands/daemon.js:139–145` returns success when a daemon is already running. If another opted-out daemon from a different package installation/version appears between the empty status and start, the wrapper stamps **its own expected version** onto the other process's PID. `trusted()` at lines 28–30 checks only that marker, a generic command-path substring and the opt-out; it cannot establish the actual version. A leftover marker plus a recycled PID belonging to another opted-out MobileBuildMCP daemon has the same weakness. **Fix:** validate the actual daemon's version and instance/start identity before recording trust, and reject/retry if that identity changes during acquisition. The package registry includes `version`, `startedAt` and `instanceId` (`build/daemon/daemon-registry.js:43–48`; registration in `build/daemon.js`), which can support that check. A private wrapper-managed endpoint is another way to avoid adopting ordinary CLI daemons. A successful “already running” response must not itself establish ownership. Cover a competing startup and PID reuse with a changed instance/version.

Installed-source paths above are relative to `/Users/ericlee06/.local/lib/node_modules/mobilebuildmcp/`. Both findings are static, deterministic control-flow issues; neither was reproduced by starting or replacing a daemon.

## Standards

Round-1 P2 #1 is only partially resolved. Ordinary unmarked-daemon replacement and trusted normal reuse are now checked, and normal reuse preserves element-reference state. The two bypasses above remain. Initial unreadable status fails through `set -e`/`pipefail`; a failed stop with a still-readable running daemon is rechecked and refused rather than directly authorizing the tool call. These failure paths were inspected, not fault-injected.

Standards: 2 P2 findings remain.

## Spec

Round-1 P3 #2 is resolved. DEVELOPMENT and the ticket now distinguish persistent state/logs from temporary sockets and returned screenshot files, explain capture retention/deletion, and exclude physical-device tools. The updated flow timing is labelled separately from the original trial.

The five live daemon cases and 187-second flow are author-reported evidence, not reviewer runs. The newly retained trial runner makes the action sequence inspectable. It prints a failure count but does not exit nonzero for failures, and contains no screenshot command; it is a historical smoke aid, not an exit-code regression test or a reproduction of the screenshot criterion by itself. This does not contradict the recorded manual screenshot check in pass 1.

Spec: no additional finding beyond the two remaining daemon-guarantee failures above.

## Checks performed

- `bash -n scripts/sim-ui.sh`: exit 0.
- `bash -n work-record/agent-skills/03-trial-flow.sh`: exit 0; runner not executed.
- `scripts/sim-ui.sh --version`: exit 0, `2.7.1`.
- `scripts/sim-ui.sh daemon status`: exit 0; reported an existing running daemon, PID 46306, in this workspace. The status command bypasses the wrapper's trust path, so this is status evidence only, not proof that the daemon passed verification.
- Relative Markdown links/anchors in AGENTS.md, DEVELOPMENT.md and ticket 03: **32 file links, 5 anchors, 0 broken**, exit 0.
- `git diff --check 440b6cc9..2efd32a5`: exit 0.
- `scripts/check-secrets.sh --all`: exit 0, clean.

Verified: wrapper/runner shell syntax, permitted version/status commands, document links/anchors, whitespace and secret checks; source inspection of argument routing, trust-marker writes, daemon reuse/start semantics and corrected storage documentation.
Not verified: live race/failure/PID-reuse scenarios, daemon replacement, trial replay, simulator UI or physical-device actions, builds, network egress. No phone, Apple account, backups, deployment or desktop-control access. Only this report was written.
Known flaky: no UI trial run by the reviewer; the ticket reports none in the author's selected runs.

Verdict: not clear
