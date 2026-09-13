#!/bin/bash
# Run from the repository root. Each UI class has its own result bundle and log.
set -u
result_root=work-record/ui-redesign/results
failed=0
for test_class in CoreLoopUITests BarbellUITests ExercisePresetUITests HeartRateUITests WorkoutNameUITests DumbbellCounterpartUITests; do
    xcodebuild test -project WorkoutTracker.xcodeproj -scheme WorkoutTracker \
        -destination 'platform=iOS Simulator,name=WT-iPhone-Codex' \
        -parallel-testing-enabled NO \
        -only-testing:"WorkoutTrackerUITests/$test_class" \
        -resultBundlePath "$result_root/codex-$test_class.xcresult" \
        > "$result_root/codex-$test_class.log" 2>&1
    status=$?
    echo "$test_class: $status"
    if [ "$status" -ne 0 ]; then failed=1; fi
done
exit "$failed"
