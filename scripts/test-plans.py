#!/usr/bin/env python3
"""Writes the named test groups as Xcode test plans in TestPlans/ (testing-workflow ticket 01).

Choosing a test scope = choosing a plan: `xcodebuild test -testPlan <Name> …`. Claude and Codex run the same sets.
Every UI test class must sit in exactly one area plan; this script fails if a class is missing, listed twice, or
listed but gone, so a new test class cannot silently fall outside the area plans. Full selects nothing and therefore
always runs every test in both targets.

    python3 scripts/test-plans.py          # rewrite the plans
    python3 scripts/test-plans.py --check  # exit 1 if the plans are stale or a class is unmapped (no writes)

Edit AREAS below when adding a UI test class, then run without --check.
"""
import json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PROJECT = "container:WorkoutTracker.xcodeproj"
UNIT = {"containerPath": PROJECT, "identifier": "1A0000000000000000000012", "name": "WorkoutTrackerTests"}
UI = {"containerPath": PROJECT, "identifier": "1A0000000000000000000022", "name": "WorkoutTrackerUITests"}
# In every UI plan; sorts first, so a serial run starts with it. In a parallel run it lands on one clone only.
WARM_UP = "AAAWarmUpUITests"

AREAS = {
    "TodayTrain": [
        "TodayUpNextUITests", "TemplateDetailUITests", "TemplateMachinesUITests", "FloodlightWorkoutTabUITests",
        "LogFoodUITests", "LogFoodFlowUITests", "TodayFoodUITests", "ScanFoodUITests", "BarcodeSearchUITests",
        "KoreanFoodUITests",
    ],
    "Workout": [
        "CoreLoopUITests", "FloodlightLiveUITests", "FloodlightFinishUITests", "CardioUITests",
        "FloodlightCardioUITests", "BarbellUITests", "DumbbellCounterpartUITests", "ExercisePresetUITests",
        "HeartRateUITests", "HeartRateSummaryUITests", "WorkoutNameUITests", "FloodlightSystemUITests", "LivePrefillUITests",
        "LiveRecentUITests",
    ],
    "HistoryProgress": [
        "FloodlightHistoryUITests", "HistoryCalendarUITests", "HistoryEditFlowsUITests", "HistoryEditingUITests",
        "HistoryTemplateUITests", "CardioHistoryDeleteUITests", "FloodlightProgressUITests", "ProgressChartUITests",
        "ProgressChartTooltipUITests", "NutritionProgressUITests",
    ],
    "GymsExercises": [
        "FloodlightGymsUITests", "GymsFlowsUITests", "MachineDeletionUITests", "FloodlightScanUITests",
        "ScanMachineLabelUITests", "FloodlightExercisesUITests",
    ],
    "ProfileAI": [
        "FloodlightProfileUITests", "FloodlightSettingsUITests", "FloodlightAccountUITests", "FloodlightGoogleUITests",
        "FloodlightAIAccessUITests", "FloodlightAIRoutineUITests", "AskAIUITests", "FloodlightFeedbackUITests",
        "FloodlightTourUITests", "FloodlightWhatsNewUITests", "ExportUITests", "BackupExportUITests",
        "SafetyCopyUITests", "NutritionGoalsUITests", "GoalSetupUITests", "BodyWeightUITests", "AppleHealthUITests",
    ],
    # The older per-screen design-review suites (D54, the Codex design).
    "Review": ["RedesignScreenshotUITests", "CodexScreenshotUITests"],
}


def ui_classes():
    found = set()
    for path in (ROOT / "WorkoutTrackerUITests").rglob("*.swift"):  # sub-folders compile into the target too
        found |= set(re.findall(r"^(?:final )?class (\w+)\s*:\s*XCTestCase", path.read_text(), re.M))
    return found


def plan(targets):
    return {
        "configurations": [{"id": "6F1E3D2C-0001-4A00-9000-000000000001", "name": "Default", "options": {}}],
        # No coverage: nothing reads it, and collecting it costs time on every run.
        "defaultOptions": {"codeCoverage": False},
        "testTargets": targets,
        "version": 1,
    }


def plans():
    out = {"Unit": plan([{"target": UNIT}]), "Full": plan([{"target": UNIT}, {"target": UI}])}
    for name, classes in AREAS.items():
        out[name] = plan([{"selectedTests": [WARM_UP] + classes, "target": UI}])
    return out


def main():
    check = "--check" in sys.argv[1:]
    listed = [c for classes in AREAS.values() for c in classes]
    actual = ui_classes() - {WARM_UP}
    problems = []
    for c in sorted({c for c in listed if listed.count(c) > 1}):
        problems.append(f"{c} is in more than one area")
    for c in sorted(actual - set(listed)):
        problems.append(f"{c} is in no area plan (add it to AREAS)")
    for c in sorted(set(listed) - actual):
        problems.append(f"{c} is listed but has no test class")
    if WARM_UP not in ui_classes():
        problems.append(f"{WARM_UP} is missing")
    directory = ROOT / "TestPlans"
    for name, body in plans().items():
        path = directory / f"{name}.xctestplan"
        text = json.dumps(body, indent=2, sort_keys=True) + "\n"
        if check:
            if not path.exists() or path.read_text() != text:
                problems.append(f"{path.relative_to(ROOT)} is stale (run scripts/test-plans.py)")
        else:
            directory.mkdir(exist_ok=True)
            path.write_text(text)
    for p in problems:
        print("test-plans:", p, file=sys.stderr)
    sys.exit(1 if problems else 0)


main()
