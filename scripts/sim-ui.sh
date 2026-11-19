#!/bin/bash
# Simulator screen control for agents (agent-skills 03): MobileBuildMCP's CLI, pinned, with its Sentry telemetry off.
# usage: scripts/sim-ui.sh <mobilebuildmcp arguments…>   e.g. scripts/sim-ui.sh ui-automation snapshot-ui --help
# Builds and tests stay DEVELOPMENT's xcodebuild procedures; use this only to look at and drive the simulator's screen.
#
# Telemetry and the pin cover the daemon too (codex-review-03 #1): stateful tools run in a per-workspace daemon that the
# CLI reuses with whatever environment it was started with. So before a tool call this script uses only a daemon it
# started itself — recorded with its pid and version — whose own environment carries the opt-out; any other daemon for
# this workspace (started bare, by another version, or unverifiable) is stopped and replaced.
set -euo pipefail
expected=2.7.1
export MOBILEBUILDMCP_SENTRY_DISABLED=true
command -v mobilebuildmcp >/dev/null || { echo "mobilebuildmcp missing: npm install -g mobilebuildmcp@$expected" >&2; exit 3; }
actual=$(mobilebuildmcp --version 2>/dev/null)
[ "$actual" = "$expected" ] || { echo "mobilebuildmcp $actual, expected $expected (the pinned version)" >&2; exit 3; }

case "${1:-}" in
  ""|-h|--help|-v|--version|tools|daemon) exec mobilebuildmcp "$@" ;;
esac

daemon_pid() { mobilebuildmcp daemon status 2>/dev/null | sed -nE 's/^ *PID: ([0-9]+).*/\1/p'; }
socket_dir() { mobilebuildmcp daemon status 2>/dev/null | sed -nE 's#^ *Socket: (.*)/d\.sock$#\1#p'; }

# The daemon is trusted only when it is the one this script started (pid and version in the marker), it is still the
# MobileBuildMCP daemon process, and its own environment has the opt-out.
trusted() {
  local pid=$1 marker=$2
  [ -f "$marker" ] && [ "$(cat "$marker")" = "$pid $expected" ] || return 1
  ps -p "$pid" -o command= 2>/dev/null | grep -q "mobilebuildmcp/build/daemon.js" || return 1
  ps eww -p "$pid" 2>/dev/null | tr ' ' '\n' | grep -qx "MOBILEBUILDMCP_SENTRY_DISABLED=true"
}

fresh=0
pid=$(daemon_pid)
if [ -z "$pid" ]; then mobilebuildmcp daemon start >/dev/null; pid=$(daemon_pid); fresh=1; fi
dir=$(socket_dir)
[ -n "$pid" ] && [ -n "$dir" ] || { echo "sim-ui: could not read the daemon's status" >&2; exit 4; }
marker="$HOME/Library/Developer/MobileBuildMCP/sim-ui-$(basename "$dir").pid"
mkdir -p "$(dirname "$marker")"
[ "$fresh" = 1 ] && echo "$pid $expected" > "$marker"
if ! trusted "$pid" "$marker"; then
  mobilebuildmcp daemon stop >/dev/null 2>&1 || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do [ -z "$(daemon_pid)" ] && break; sleep 0.5; done
  [ -z "$(daemon_pid)" ] || { echo "sim-ui: an unverified daemon would not stop (pid $pid)" >&2; exit 4; }
  mobilebuildmcp daemon start >/dev/null
  pid=$(daemon_pid)
  echo "$pid $expected" > "$marker"
  trusted "$pid" "$marker" || { echo "sim-ui: the new daemon (pid $pid) lacks the telemetry opt-out" >&2; exit 4; }
fi
exec mobilebuildmcp "$@"
