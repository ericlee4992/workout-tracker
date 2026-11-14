#!/bin/bash
# TestFlight archive and upload (DEVELOPMENT → TestFlight build checklist, steps 4–5).
#
#   scripts/testflight.sh archive [out-dir]   in the release-build checkout, detached at the main commit to ship
#   scripts/testflight.sh upload <archive>     upload that archive to App Store Connect
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

  # What must be true of a build testers install.
  local app widget server google signed
  app=$(ls -d "$path"/Products/Applications/*.app | head -1)
  [ -d "$app" ] || die "no app in the archive"
  for bundle in "$app" "$app"/PlugIns/*.appex; do
    [ -d "$bundle" ] || continue
    local v b
    v=$($plistbuddy -c "Print :CFBundleShortVersionString" "$bundle/Info.plist")
    b=$($plistbuddy -c "Print :CFBundleVersion" "$bundle/Info.plist")
    [ "$v" = "$version" ] && [ "$b" = "$build" ] || die "$(basename "$bundle") is $v ($b), expected $version ($build)"
    echo "  $(basename "$bundle"): $v ($b)"
  done
  server=$($plistbuddy -c "Print :WTServerURL" "$app/Info.plist" 2>/dev/null || true)
  case "$server" in
    https://*) case "$server" in *localhost*|*127.0.0.1*) die "WTServerURL points at this Mac: $server" ;; esac ;;
    *) die "WTServerURL is not a production https URL: '${server}'" ;;
  esac
  echo "  WTServerURL: production https"
  google=$($plistbuddy -c "Print :WTGoogleClientID" "$app/Info.plist" 2>/dev/null || true)
  [ -n "$google" ] || die "WTGoogleClientID is empty"
  echo "  WTGoogleClientID: present"
  signed=$(codesign -dv "$app" 2>&1 | sed -n 's/^TeamIdentifier=//p')
  [ "$signed" = "$team" ] || die "signed by team '$signed', expected $team"
  echo "  team: matches Config/Local.xcconfig"
  echo "ARCHIVE OK: $path"
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
  if grep -q "Failed to Use Accounts\|App Store Connect access for" "$log"; then
    echo "testflight: Xcode is not signed in to App Store Connect." >&2
    echo "  The user signs in at Xcode → Settings → Accounts (Apple Account, team $team), then run upload again." >&2
    exit 2
  fi
  if [ $status -ne 0 ] || ! grep -q "Upload succeeded" "$log"; then
    grep -E "error" "$log" | head -10 >&2 || true
    die "upload failed (exit $status) — see $log"
  fi
  echo "UPLOAD OK: Upload succeeded ($(date '+%Y-%m-%d %H:%M %Z'))"
}

case "${1:-}" in
  archive) shift; archive "${1:-}" ;;
  upload) shift; upload "${1:-}" ;;
  *) echo "usage: scripts/testflight.sh archive [out-dir] | upload <archive>" >&2; exit 1 ;;
esac
