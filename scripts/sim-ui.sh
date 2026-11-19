#!/bin/bash
# Simulator screen control for agents (agent-skills 03): MobileBuildMCP's CLI, pinned, with its Sentry telemetry off.
# usage: scripts/sim-ui.sh <mobilebuildmcp arguments…>   e.g. scripts/sim-ui.sh ui-automation snapshot-ui --help
# Builds and tests stay DEVELOPMENT's xcodebuild procedures; use this only to look at and drive the simulator's screen.
#
# Telemetry off covers every process, not only this one (codex-review-03 #1, 03b): the CLI and its per-workspace daemon
# read `.mobilebuildmcp/config.yaml` (`sentryDisabled: true`) from the workspace root before they start Sentry
# (`hydrateSentryDisabledEnvFromProjectConfig`), whoever starts them; this script runs from that root, refuses to run
# without the file, and also exports the opt-out. The pin covers the daemon too: a running daemon serves tools only when
# its own registry entry (`daemon.json`: pid, version, start time) matches the status pid and the pinned version and it
# started after the config last changed; otherwise it is
# stopped, and the tool call starts a fresh one from the pinned CLI. Endpoint overrides (`--socket`) are refused.
set -euo pipefail
expected=2.7.1
root=$(cd "$(dirname "$0")/.." && pwd -P)
cd "$root"
grep -qx "sentryDisabled: true" .mobilebuildmcp/config.yaml 2>/dev/null \
  || { echo "sim-ui: $root/.mobilebuildmcp/config.yaml must say 'sentryDisabled: true'" >&2; exit 3; }
export MOBILEBUILDMCP_SENTRY_DISABLED=true
command -v mobilebuildmcp >/dev/null || { echo "mobilebuildmcp missing: npm install -g mobilebuildmcp@$expected" >&2; exit 3; }
actual=$(mobilebuildmcp --version 2>/dev/null)
[ "$actual" = "$expected" ] || { echo "mobilebuildmcp $actual, expected $expected (the pinned version)" >&2; exit 3; }
for arg in "$@"; do
  case "$arg" in --socket|--socket=*) echo "sim-ui: --socket is not allowed (it would bypass the daemon check)" >&2; exit 2 ;; esac
done

case "${1:-}" in
  ""|-h|--help|-v|--version|tools|daemon) exec mobilebuildmcp "$@" ;;
esac

# The running daemon's pid (empty when none) and its registry entry's "pid version" (empty when unreadable).
status_pid() { mobilebuildmcp daemon status 2>/dev/null | sed -nE 's/^ *PID: ([0-9]+).*/\1/p'; }
registry() {
  local logs
  logs=$(mobilebuildmcp daemon status 2>/dev/null | sed -nE 's/^ *Logs: (.*)$/\1/p')
  [ -n "$logs" ] || return 0
  # "ok" also needs the daemon started after the config file last changed: one started earlier may predate it.
  python3 -I -c 'import json,os,sys
from datetime import datetime
d = json.load(open(sys.argv[1]))
started = datetime.fromisoformat(d["startedAt"].replace("Z", "+00:00")).timestamp()
print(d["pid"], d["version"], "ok" if started >= os.path.getmtime(sys.argv[2]) else "stale")' \
    "$(dirname "$(dirname "$logs")")/state/daemon/daemon.json" .mobilebuildmcp/config.yaml 2>/dev/null || true
}

pid=$(status_pid)
if [ -n "$pid" ] && [ "$(registry)" != "$pid $expected ok" ]; then
  mobilebuildmcp daemon stop >/dev/null 2>&1 || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do [ -z "$(status_pid)" ] && break; sleep 0.5; done
  [ -z "$(status_pid)" ] || { echo "sim-ui: an unverified daemon would not stop (pid $pid)" >&2; exit 4; }
fi
exec mobilebuildmcp "$@"
