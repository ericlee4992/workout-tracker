#!/bin/bash
# TestFlight archive and upload (DEVELOPMENT → TestFlight build checklist, steps 4–5).
#
#   scripts/testflight.sh archive [out-dir]   in the release-build checkout, detached at the main commit to ship
#   scripts/testflight.sh upload <archive>     upload that archive to App Store Connect
#   scripts/testflight.sh check <archive>      rerun the archive checks on an existing archive
#
# Why a script: the export options file used to live in /tmp and was lost twice between builds, breaking the upload.
# It is now written fresh on every upload from the team ID in Config/Local.xcconfig (gitignored — the team ID stays out
# of this public repository), so nothing has to survive between runs.
#
# Exit codes: 0 done; 1 a check or command failed; 2 Xcode is not signed in to App Store Connect (the user signs in
# at Xcode → Settings → Accounts — an agent cannot enter the password or the two-factor code), then run upload again.
set -euo pipefail

root=$(git rev-parse --show-toplevel)
cd "$root"
project=WorkoutTracker.xcodeproj
plistbuddy=/usr/libexec/PlistBuddy

die() { echo "testflight: $*" >&2; exit 1; }

team_id() {
  local config=Config/Local.xcconfig
  [ -f "$config" ] || die "$config is missing (copy Config/Local.xcconfig.example and set WT_DEVELOPMENT_TEAM)"
  local team
  team=$(sed -n 's/^[[:space:]]*WT_DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*\([A-Z0-9]\{10\}\)[[:space:]]*$/\1/p' "$config" | tail -1)
  [ -n "$team" ] || die "no 10-character WT_DEVELOPMENT_TEAM in $config"
  echo "$team"
}

# The one value every target must share; dies if the targets disagree.
project_setting() {
  local values
  values=$(grep -o "$1 = [^;]*;" "$project/project.pbxproj" | sort -u)
  [ "$(echo "$values" | wc -l | tr -d ' ')" = 1 ] || die "$1 differs between targets: $(echo "$values" | tr '\n' ' ')"
  echo "$values" | sed "s/^$1 = //; s/;$//"
}

archive() {
  local out=${1:-}
  [ -z "$(git status --porcelain)" ] || die "the checkout has changes; archive a clean commit"
  local version build commit team
  version=$(project_setting MARKETING_VERSION)
  build=$(project_setting CURRENT_PROJECT_VERSION)
  commit=$(git rev-parse --short HEAD)
  team=$(team_id)
  out=${out:-/tmp/stacked-release-$version-$build}
  mkdir -p "$out"
  local path="$out/Stacked-$version-$build-$commit.xcarchive"
  echo "Archiving $version ($build) at $commit → $path"
  if ! xcodebuild -project "$project" -scheme WorkoutTracker -configuration Release -destination generic/platform=iOS \
      -archivePath "$path" -allowProvisioningUpdates archive > "$out/archive.log" 2>&1; then
    grep -E "error:" "$out/archive.log" | head -10 >&2 || true
    die "archive failed — see $out/archive.log"
  fi
  grep -q "ARCHIVE SUCCEEDED" "$out/archive.log" || die "no ARCHIVE SUCCEEDED in $out/archive.log"
  check "$path"
  echo "ARCHIVE OK: $path"
}

# What must be true of a build testers install: run after every archive, and on its own (`check`).
check() {
  local path=${1:-}
  [ -n "$path" ] && [ -d "$path" ] || die "usage: scripts/testflight.sh check <path to .xcarchive>"
  local version build team
  version=$(project_setting MARKETING_VERSION)
  build=$(project_setting CURRENT_PROJECT_VERSION)
  team=$(team_id)
  local app widget server google signed production app_id widget_id
  app=$(ls -d "$path"/Products/Applications/*.app 2>/dev/null | head -1)
  [ -d "$app" ] || die "no app in the archive"
  # The Live Activity widget must be embedded: an archive without it would install and lose the Lock Screen card.
  widget="$app/PlugIns/WorkoutTrackerWidget.appex"
  [ -d "$widget" ] || die "the widget (WorkoutTrackerWidget.appex) is missing from the archive"
  app_id=$($plistbuddy -c "Print :CFBundleIdentifier" "$app/Info.plist")
  widget_id=$($plistbuddy -c "Print :CFBundleIdentifier" "$widget/Info.plist")
  [ "$widget_id" = "$app_id.widget" ] || die "widget identifier $widget_id is not $app_id.widget"
  for bundle in "$app" "$widget"; do
    local v b
    v=$($plistbuddy -c "Print :CFBundleShortVersionString" "$bundle/Info.plist")
    b=$($plistbuddy -c "Print :CFBundleVersion" "$bundle/Info.plist")
    [ "$v" = "$version" ] && [ "$b" = "$build" ] || die "$(basename "$bundle") is $v ($b), expected $version ($build)"
    echo "  $(basename "$bundle"): $v ($b)"
  done
  # Exactly the production server Config/Shared.xcconfig names — a Local.xcconfig override (a local or staging
  # server) must never ship. xcconfig writes `//` as `/$()/`.
  production=$(sed -n 's/^[[:space:]]*WT_SERVER_URL[[:space:]]*=[[:space:]]*\(.*[^[:space:]]\)[[:space:]]*$/\1/p' \
    Config/Shared.xcconfig | tail -1 | sed 's|/\$()/|//|')
  case "$production" in https://*) ;; *) die "no https WT_SERVER_URL in Config/Shared.xcconfig" ;; esac
  server=$($plistbuddy -c "Print :WTServerURL" "$app/Info.plist" 2>/dev/null || true)
  [ "$server" = "$production" ] || die "WTServerURL is '$server', not the production server $production"
  echo "  WTServerURL: the production server"
  google=$($plistbuddy -c "Print :WTGoogleClientID" "$app/Info.plist" 2>/dev/null || true)
  [ -n "$google" ] || die "WTGoogleClientID is empty"
  echo "  WTGoogleClientID: present"
  signed=$(codesign -dv "$app" 2>&1 | sed -n 's/^TeamIdentifier=//p')
  [ "$signed" = "$team" ] || die "signed by team '$signed', expected $team"
  echo "  team: matches Config/Local.xcconfig"
}

upload() {
  local path=${1:-}
  [ -n "$path" ] && [ -d "$path" ] || die "usage: scripts/testflight.sh upload <path to .xcarchive>"
  local team scratch
  team=$(team_id)
  scratch=$(mktemp -d)
  # Expanded now: `scratch` is local and gone by the time the EXIT trap runs.
  trap "rm -rf '$scratch'" EXIT
  cat > "$scratch/UploadOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>signingStyle</key><string>automatic</string>
  <key>teamID</key><string>$team</string>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST
  plutil -lint "$scratch/UploadOptions.plist" > /dev/null || die "the generated UploadOptions.plist is not valid"
  local log
  log="$(dirname "$path")/upload.log"
  echo "Uploading $(basename "$path") (log: $log)"
  set +e
  xcodebuild -exportArchive -archivePath "$path" -exportOptionsPlist "$scratch/UploadOptions.plist" \
    -exportPath "$scratch/export" -allowProvisioningUpdates > "$log" 2>&1
  local status=$?
  set -e
  if [ $status -eq 0 ] && grep -q "Upload succeeded" "$log"; then
    echo "UPLOAD OK: Upload succeeded ($(date '+%Y-%m-%d %H:%M %Z'))"
    return 0
  fi
  if grep -q "Failed to Use Accounts\|App Store Connect access for" "$log"; then
    echo "testflight: Xcode is not signed in to App Store Connect." >&2
    echo "  The user signs in at Xcode → Settings → Accounts (Apple Account, team $team), then run upload again." >&2
    exit 2
  fi
  grep -E "error" "$log" | head -10 >&2 || true
  die "upload failed (exit $status) — see $log"
}

case "${1:-}" in
  archive) shift; archive "${1:-}" ;;
  upload) shift; upload "${1:-}" ;;
  check) shift; check "${1:-}" && echo "CHECK OK" ;;
  *) echo "usage: scripts/testflight.sh archive [out-dir] | upload <archive> | check <archive>" >&2; exit 1 ;;
esac
