#!/bin/bash
# Simulator screen control for agents (agent-skills 03): MobileBuildMCP's CLI, pinned, with its Sentry telemetry off.
# usage: scripts/sim-ui.sh <mobilebuildmcp arguments…>   e.g. scripts/sim-ui.sh ui-automation snapshot-ui --help
# Builds and tests stay DEVELOPMENT's xcodebuild procedures; use this only to look at and drive the simulator's screen.
#
# Telemetry: the CLI and its per-workspace daemon read `.mobilebuildmcp/config.yaml` (`sentryDisabled: true`) from
# their working directory before they start Sentry (`hydrateSentryDisabledEnvFromProjectConfig`; no ancestor search).
# This script runs from the repository root, so its calls and the daemon (started with the workspace root as its
# directory) read it; it refuses to run without the file and also exports the opt-out. A bare `mobilebuildmcp` from a
# subdirectory does not read it — use this script.
# The daemon (codex-review-03, 03b, 03c): every other MOBILEBUILDMCP_/XCODEBUILDMCP_/XCODEBUILDCLI_ variable is cleared
# (no socket, log-path or cwd overrides) and `--socket` / `--daemon-log-path` are refused, so the call reaches this
# workspace's default daemon. That daemon serves a call only when a successful status names this root, and its own
# registry entry (found by the socket's workspace hash, checked to name this root) has the status pid, version 2.7.1 and
# a start time after the config file last changed; otherwise it is stopped (confirmed by a successful "Not running")
# and the call starts a fresh one from the pinned CLI. Any unreadable status stops the script.
set -euo pipefail
expected=2.7.1
root=$(cd "$(dirname "$0")/.." && pwd -P)
cd "$root"
grep -qx "sentryDisabled: true" .mobilebuildmcp/config.yaml 2>/dev/null \
  || { echo "sim-ui: $root/.mobilebuildmcp/config.yaml must say 'sentryDisabled: true'" >&2; exit 3; }
for var in $(compgen -e | grep -E '^(MOBILEBUILDMCP|XCODEBUILDMCP|XCODEBUILDCLI)_' || true); do unset "$var"; done
export MOBILEBUILDMCP_SENTRY_DISABLED=true
command -v mobilebuildmcp >/dev/null || { echo "mobilebuildmcp missing: npm install -g mobilebuildmcp@$expected" >&2; exit 3; }
actual=$(mobilebuildmcp --version 2>/dev/null)
[ "$actual" = "$expected" ] || { echo "mobilebuildmcp $actual, expected $expected (the pinned version)" >&2; exit 3; }
for arg in "$@"; do
  case "$arg" in
    --socket|--socket=*|--daemon-log-path|--daemon-log-path=*)
      echo "sim-ui: $arg is not allowed (it would bypass the daemon check)" >&2; exit 2 ;;
  esac
done

case "${1:-}" in
  ""|-h|--help|-v|--version|tools|daemon) exec mobilebuildmcp "$@" ;;
esac

fail() { echo "sim-ui: $*" >&2; exit 4; }

# One successful status read: sets st_running (yes/no), st_pid, st_workspace, st_socket; returns 1 when unreadable.
read_status() {
  local out
  out=$(mobilebuildmcp daemon status 2>/dev/null) || return 1
  st_workspace=$(sed -nE 's/^ *Workspace: (.*)$/\1/p' <<<"$out" | head -1)
  st_pid=$(sed -nE 's/^ *PID: ([0-9]+).*/\1/p' <<<"$out")
  st_socket=$(sed -nE 's/^ *Socket: (.*)$/\1/p' <<<"$out")
  if grep -q "Daemon Status: Running" <<<"$out" && [ -n "$st_pid" ] && [ -n "$st_socket" ]; then st_running=yes
  elif grep -q "Daemon Status: Not running" <<<"$out"; then st_running=no
  else return 1; fi
}

# The daemon's own registry entry, found by its socket's workspace hash (not the log location): prints "ok" when it
# names this root, the status pid and the pinned version, and started after the config file last changed.
registry_ok() {
  local hash entry
  hash=$(basename "$(dirname "$st_socket")"); hash=${hash#mobilebuildmcp-}
  for entry in "$HOME"/Library/Developer/MobileBuildMCP/workspaces/*-"$hash"/state/daemon/daemon.json; do
    [ -f "$entry" ] || continue
    python3 -I -c 'import json,os,sys
from datetime import datetime
d = json.load(open(sys.argv[1]))
started = datetime.fromisoformat(d["startedAt"].replace("Z", "+00:00")).timestamp()
good = (d["workspaceRoot"] == sys.argv[2] and str(d["pid"]) == sys.argv[3] and d["version"] == sys.argv[4]
        and started >= os.path.getmtime(sys.argv[5]))
print("ok" if good else "no")' "$entry" "$root" "$st_pid" "$expected" .mobilebuildmcp/config.yaml 2>/dev/null || true
    return
  done
}

read_status || fail "could not read the daemon's status"
[ "$st_workspace" = "$root" ] || fail "the daemon status names another workspace ($st_workspace)"
if [ "$st_running" = yes ] && [ "$(registry_ok)" != ok ]; then
  old=$st_pid
  mobilebuildmcp daemon stop >/dev/null 2>&1 || true
  stopped=no
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    read_status || fail "could not read the daemon's status after stopping pid $old"
    [ "$st_running" = no ] && { stopped=yes; break; }
    sleep 0.5
  done
  [ "$stopped" = yes ] || fail "an unverified daemon would not stop (pid $old)"
fi
exec mobilebuildmcp "$@"
