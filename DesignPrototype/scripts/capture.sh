#!/bin/bash
# PROTOTYPE — build the redesign prototype and capture screens in the WT-Redesign simulator.
#
#   scripts/capture.sh <areas|all> <out-dir> <SCREEN[:variant]> [...]
#
#   <areas>   comma-separated Screens/ folders to build for real (e.g. "History" or
#             "Exercises,Settings"); every other area is replaced by its placeholder in Stubs/.
#             "all" builds the real tree with no stubs.
#   LOOKS     env var, default "floodlight anatomy paper carbon" (add "final" for the ★ look).
#   APPEARANCE env var, unset by default: light|dark|system passes "-appearance" (the final
#             look's Appearance setting). File names are unchanged; use one out-dir per value.
#   AXL=1     env var: also capture every screen at AccessibilityL ("-axl" suffix).
#
# Builds happen in a private copy (/tmp/wt-proto-build) so half-written files in other areas
# never break your build. A lock serialises builds and captures across agents.
# Output: <out-dir>/<SCREEN>[-variant]-<look>[-axl].png plus build.log. Exit status is the
# build's; a failed build prints the first errors.
set -uo pipefail

ROOT="/Users/ericlee06/orca/workspaces/Health App/redesign-prototype/RedesignPrototype"
BUNDLE="com.ericlee4992.workouttracker.redesignprototype"
LOOKS="${LOOKS:-floodlight anatomy paper carbon}"
# Pool of simulator slots; each has its own lock, build tree and derived data.
SIMS=(9B1D17D2-347F-431C-AC6D-F019BAB675CA EB4328A1-87BD-4850-A3B2-A6E604701F1C C2C1595C-55E3-4535-83D7-9102B330E32E)

AREAS="$1"; OUT="$2"; shift 2
mkdir -p "$OUT"

# --- take a free slot (a lock older than 20 min is stale) ---
SLOT=""
while [ -z "$SLOT" ]; do
  for i in "${!SIMS[@]}"; do
    L="/tmp/wt-redesign-slot-$i.lock"
    if [ -d "$L" ] && [ -n "$(find "$L" -maxdepth 0 -mmin +20 2>/dev/null)" ]; then rm -rf "$L"; fi
    if mkdir "$L" 2>/dev/null; then SLOT=$i; break; fi
  done
  [ -z "$SLOT" ] && sleep 5
done
LOCK="/tmp/wt-redesign-slot-$SLOT.lock"
SIM="${SIMS[$SLOT]}"
BUILD="/tmp/wt-proto-build-$SLOT"
DD="/tmp/wt-proto-dd-$SLOT"
trap 'rm -rf "$LOCK"' EXIT
echo "slot $SLOT (sim $SIM) acquired $(date +%T) for $AREAS" >&2

# --- private build tree ---
mkdir -p "$BUILD"
rsync -a --delete "$ROOT/RedesignPrototype.xcodeproj" "$BUILD/"
rsync -a --delete --exclude 'Screens/_Stubs' "$ROOT/Sources/" "$BUILD/Sources/"
rm -rf "$BUILD/Sources/Screens/_Stubs"
if [ "$AREAS" != "all" ]; then
  IFS=',' read -r -a KEEP <<< "$AREAS"
  for d in "$BUILD/Sources/Screens"/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"; keep=0
    for k in "${KEEP[@]}"; do [ "$name" = "$k" ] && keep=1; done
    [ $keep = 1 ] || rm -rf "$d"
  done
  mkdir -p "$BUILD/Sources/Screens/_Stubs"
  for s in "$ROOT/Stubs"/*.swift; do
    name="$(basename "$s" .swift)"; keep=0
    for k in "${KEEP[@]}"; do [ "$name" = "$k" ] && keep=1; done
    [ $keep = 1 ] || cp "$s" "$BUILD/Sources/Screens/_Stubs/"
  done
fi

xcodebuild -project "$BUILD/RedesignPrototype.xcodeproj" -scheme RedesignPrototype \
  -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath "$DD" build > "$OUT/build.log" 2>&1
status=$?
if [ $status -ne 0 ]; then
  echo "BUILD FAILED (exit $status) — $OUT/build.log" >&2
  grep -E 'error:' "$OUT/build.log" | sort -u | head -40 >&2
  exit $status
fi
echo "build ok" >&2

xcrun simctl boot "$SIM" 2>/dev/null
xcrun simctl bootstatus "$SIM" -b >/dev/null 2>&1
xcrun simctl status_bar "$SIM" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 >/dev/null 2>&1
xcrun simctl install "$SIM" "$DD/Build/Products/Debug-iphonesimulator/RedesignPrototype.app" || exit 1
# Warm-up: the first launches after an install sit on the launch screen for several seconds.
for w in 1 2; do
  xcrun simctl launch --terminate-running-process "$SIM" "$BUNDLE" -hideSwitcher YES -freezeClock YES >/dev/null 2>&1
  sleep 4
done

shoot() { # screen variant look axl
  local scr="$1" var="$2" look="$3" axl="$4" name="$1"
  local args=(-look "$look" -screen "$scr" -freezeClock YES -hideSwitcher YES)
  [ -n "${APPEARANCE:-}" ] && args+=(-appearance "$APPEARANCE")
  [ -n "$var" ] && { args+=(-variant "$var"); name="$name-$var"; }
  name="$name-$look"
  [ "$axl" = 1 ] && { args+=(-axl YES); name="$name-axl"; }
  xcrun simctl launch --terminate-running-process "$SIM" "$BUNDLE" "${args[@]}" >/dev/null 2>&1
  sleep "${SETTLE:-3}"
  xcrun simctl io "$SIM" screenshot "$OUT/$name.png" >/dev/null 2>&1 && echo "$OUT/$name.png"
}

for item in "$@"; do
  scr="${item%%:*}"; var=""; [ "$item" != "$scr" ] && var="${item#*:}"
  for look in $LOOKS; do
    shoot "$scr" "$var" "$look" 0
    [ "${AXL:-0}" = 1 ] && shoot "$scr" "$var" "$look" 1
  done
done
exit 0
