#!/bin/zsh
# Restore a container capture into a disposable Simulator and have the app export it as JSON
# (public beta ticket 01; DEVELOPMENT → Container backup and restore, Gate S).
#
#   simulator_export.sh <capture-dir> <out.json> <simulator-udid> <derived-data-dir> [bundle-id]
#
# <derived-data-dir> must hold a `build-for-testing` of the WorkoutTracker scheme for the Simulator with the real
# bundle ID (this checkout's Config/Local.xcconfig), built from the commit the phone runs. The simulator's name
# must start with "WT-Backup": its copy of the app is replaced, and other sessions' simulators must never be.
# Compare the result with the phone's own export: compare_exports.py <phone-export> <out.json>.
set -euo pipefail

CAPTURE="$1"; OUT="$2"; SIM="$3"; DD="$4"; BID="${5:-com.ericlee4992.workouttracker}"
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"
APP="$DD/Build/Products/Debug-iphonesimulator/WorkoutTracker.app"

NAME=$(xcrun simctl list devices -j | python3 -c "import json,sys
for r in json.load(sys.stdin)['devices'].values():
    for d in r:
        if d['udid']=='$SIM': print(d['name'])")
[[ "$NAME" == WT-Backup* ]] || { echo "refusing: simulator '$NAME' is not a WT-Backup* simulator" >&2; exit 2; }
[[ -f "$CAPTURE/Library/Application Support/default.store" ]] || { echo "no store in $CAPTURE" >&2; exit 2; }
[[ "$(plutil -extract CFBundleIdentifier raw "$APP/Info.plist")" == "$BID" ]] || { echo "built app is not $BID" >&2; exit 2; }

xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl bootstatus "$SIM" -b >/dev/null
xcrun simctl terminate "$SIM" "$BID" 2>/dev/null || true
xcrun simctl uninstall "$SIM" "$BID"
xcrun simctl install "$SIM" "$APP"          # not launched: the store must not be created first
C=$(xcrun simctl get_app_container "$SIM" "$BID" data)
for p in "Library/Application Support" "Library/Preferences/$BID.plist" "Documents"; do
  if [[ -e "$CAPTURE/$p" ]]; then mkdir -p "$C/$(dirname "$p")"; cp -Rp "$CAPTURE/$p" "$C/$(dirname "$p")/"; fi
done

LOG="${OUT%.json}.xcodebuild.log"
set +e
TEST_RUNNER_WT_BACKUP_EXPORT=1 xcodebuild test-without-building -project "$ROOT/WorkoutTracker.xcodeproj" \
  -scheme WorkoutTracker -destination "id=$SIM" -derivedDataPath "$DD" \
  -only-testing:WorkoutTrackerUITests/BackupExportUITests > "$LOG" 2>&1
STATUS=$?
set -e
xcrun simctl terminate "$SIM" "$BID" 2>/dev/null || true
grep -q "BACKUP-EXPORT CARD:" "$LOG" || { echo "export test did not run (skipped or failed): $LOG" >&2; exit 1; }
[[ $STATUS -eq 0 ]] && grep -q "Executed 1 test, with 0 failures" "$LOG" \
  || { echo "export test failed (xcodebuild exit $STATUS): $LOG" >&2; exit 1; }
grep -o "BACKUP-EXPORT CARD: .*" "$LOG" | head -1

C=$(xcrun simctl get_app_container "$SIM" "$BID" data)
EXPORT=$(find "$C/tmp/Exports" -name "*.json" -type f -print0 | xargs -0 ls -t | head -1)
[[ -n "$EXPORT" ]] || { echo "no export written" >&2; exit 1; }
cp "$EXPORT" "$OUT"
echo "round-trip export: $OUT"
