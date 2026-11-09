#!/bin/bash
# Quick simulator exploration: launch the built app with fixtures and take screenshots, without writing a test.
# For "does this look right" checks of new or changed screens (DEVELOPMENT → Verification scope). Capture tests
# stay for screens worth guarding.
#
# usage: scripts/explore.sh [options] [-- <extra launch arguments>]
#   -d <udid>      simulator (default: WT-Floodlight 9E822EF6-DC67-4958-AEA2-D53D2D36D674)
#   -a <app>       built WorkoutTracker.app (default: newest under $DERIVED or ~/Library/Developer/Xcode/DerivedData)
#   -o <dir>       output folder for the PNGs (default: ./explore-shots, created)
#   -n <name>      file-name prefix (default: shot)
#   -s <list>      comma-separated looks to capture: light, dark, light-axl, dark-axl (default: light)
#   -w <seconds>   wait after launch before the screenshot (default: 4)
#   -f <fixtures>  fixture set: sample (design sample + history + gyms; the default), empty, none (your own store)
#
# Each look relaunches the app (fixture stores are throwaway and rebuilt on every launch). Motion and location are
# granted first so no permission alert covers the screen. The appearance is set with `simctl ui` and restored after.
# Text size uses the same launch argument as the capture tests. The app stays open on the last look, so you can
# keep exploring by hand; a relaunch from the Home Screen drops the fixture store.
set -euo pipefail

device=9E822EF6-DC67-4958-AEA2-D53D2D36D674
app=""; out=./explore-shots; name=shot; looks=light; wait=4; fixtures=sample
while getopts "d:a:o:n:s:w:f:" opt; do
  case $opt in
    d) device=$OPTARG ;; a) app=$OPTARG ;; o) out=$OPTARG ;; n) name=$OPTARG ;;
    s) looks=$OPTARG ;; w) wait=$OPTARG ;; f) fixtures=$OPTARG ;;
    *) sed -n 2,18p "$0"; exit 2 ;;
  esac
done
shift $((OPTIND - 1)); [ "${1:-}" = "--" ] && shift
extra=("$@")

if [ -z "$app" ]; then
  roots=("${DERIVED:-}" "$HOME/Library/Developer/Xcode/DerivedData")
  app=$(for r in "${roots[@]}"; do [ -n "$r" ] && [ -d "$r" ] && \
          find "$r" -path "*Debug-iphonesimulator/WorkoutTracker.app" -maxdepth 6 -type d 2>/dev/null; done \
        | while read -r p; do echo "$(stat -f %m "$p") $p"; done | sort -rn | head -1 | cut -d' ' -f2-)
fi
[ -d "$app" ] || { echo "No built WorkoutTracker.app found; build first or pass -a." >&2; exit 1; }
bundle=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$app/Info.plist")

case $fixtures in
  sample) args=(-uiTestReset -uiTestDesignSample -uiTestDesignHistory -uiTestDesignGyms) ;;
  empty)  args=(-uiTestReset) ;;
  none)   args=() ;;
  *) echo "unknown fixture set: $fixtures" >&2; exit 2 ;;
esac

# Boot once and leave it booted: a shut-down simulator costs ~35 s on every later run (testing-workflow ticket 01).
xcrun simctl bootstatus "$device" -b >/dev/null
xcrun simctl install "$device" "$app"
for service in motion location; do xcrun simctl privacy "$device" grant "$service" "$bundle"; done

before=$(xcrun simctl ui "$device" appearance)
mkdir -p "$out"
IFS=, read -ra list <<< "$looks"
for look in "${list[@]}"; do
  case $look in
    light|dark) scheme=$look; size=() ;;
    light-axl|dark-axl) scheme=${look%-axl}; size=(-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityL) ;;
    *) echo "unknown look: $look" >&2; exit 2 ;;
  esac
  xcrun simctl ui "$device" appearance "$scheme"
  xcrun simctl launch --terminate-running-process "$device" "$bundle" \
    ${args[@]+"${args[@]}"} ${size[@]+"${size[@]}"} ${extra[@]+"${extra[@]}"} >/dev/null
  sleep "$wait"
  file="$out/$name-$look.png"
  xcrun simctl io "$device" screenshot "$file" >/dev/null 2>&1
  echo "$file"
done
if [ "$before" = light ] || [ "$before" = dark ]; then xcrun simctl ui "$device" appearance "$before"; fi
