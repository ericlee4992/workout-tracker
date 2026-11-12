#!/bin/bash
# usage: drive.sh <label> [P1_X=1 ...]   runs the P1 UI driver (Release build) and prints per-phase hitches
label=$1; shift
D=9E822EF6-DC67-4958-AEA2-D53D2D36D674
cd /Users/ericlee06/.paseo/worktrees/1qmeipq9/perf-01-workout-lag
envs=(); for e in "$@"; do envs+=("TEST_RUNNER_$e"); done
env ${envs[@]+"${envs[@]}"} xcodebuild test-without-building -project WorkoutTracker.xcodeproj -scheme WorkoutTracker \
  -sdk iphonesimulator -configuration Release -destination "id=$D" -derivedDataPath /tmp/p1/dd ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  -parallel-testing-enabled NO -only-testing:WorkoutTrackerUITests/P1WorkoutLagUITests > /tmp/p1/drive-$label.log 2>&1
echo "xcodebuild exit $? ; $(grep -E '\*\* TEST|Executed' /tmp/p1/drive-$label.log | tail -2 | tr '\n' ' ')"
data=$(xcrun simctl get_app_container $D com.example.workouttracker data)
cp "$data/tmp/p1probe.log" /tmp/p1/probe-$label.log
echo "== $label"; python3 -I /tmp/p1/tools/phases.py /tmp/p1/drive-$label.log /tmp/p1/probe-$label.log
