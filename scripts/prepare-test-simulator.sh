#!/bin/bash
# Gets a test simulator ready for fast, reliable runs (testing-workflow ticket 01). Safe to run before every run.
# usage: scripts/prepare-test-simulator.sh [udid]   (default: WT-Floodlight 9E822EF6-DC67-4958-AEA2-D53D2D36D674)
#
# 1. Boots it and leaves it booted. When xcodebuild has to boot a simulator itself it shuts it down again after the
#    run, so every later run pays the boot again (a 3-test unit run: 8 s booted, 41-49 s each time otherwise).
# 2. Keeps the software keyboard on screen in parallel runs. iOS minimises it while it believes a hardware keyboard
#    is attached (`HardwareKeyboardLastSeen`, `AutomaticMinimizationEnabled`). Parallel testing runs on clones that
#    copy these preferences but have no Simulator window to report "no hardware keyboard", so their keyboard sat
#    below the screen (y 976 of 932) and every keyboard check and capture failed. Clones copy the base device's
#    data when they are made, so setting it here reaches them.
set -euo pipefail
device=${1:-9E822EF6-DC67-4958-AEA2-D53D2D36D674}
xcrun simctl bootstatus "$device" -b >/dev/null
xcrun simctl spawn "$device" defaults write com.apple.keyboard.preferences AutomaticMinimizationEnabled -bool false
xcrun simctl spawn "$device" defaults write com.apple.keyboard.preferences HardwareKeyboardLastSeen -bool false
echo "ready: $(xcrun simctl list devices | grep "$device" | sed -E 's/^ +//')"
