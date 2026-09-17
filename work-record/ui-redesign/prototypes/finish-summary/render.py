"""Render a standalone SwiftUI design harness; never builds or installs WorkoutTracker."""
from pathlib import Path
import subprocess, plistlib, tempfile, time
HERE = Path(__file__).resolve().parent
OUTPUT = HERE.parents[1] / 'screenshots' / '17'
DEVICE = '432F2F5D-E694-4140-99C2-B398DE9D360F'
BUNDLE = 'com.workouttracker.design.finishsummary'
def run(*args):
    return subprocess.run(args, check=True, text=True, capture_output=True).stdout.strip()
def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    build = Path(tempfile.mkdtemp(prefix='wt-finish-preview-'))
    app = build / 'FinishPreview.app'
    app.mkdir()
    plist = dict(CFBundleExecutable='FinishPreview', CFBundleIdentifier=BUNDLE,
                 CFBundleName='Finish Preview', CFBundlePackageType='APPL',
                 CFBundleVersion='1', CFBundleShortVersionString='1.0',
                 MinimumOSVersion='26.0', LSRequiresIPhoneOS=True,
                 UIDeviceFamily=[1], UILaunchScreen={},
                 UISupportedInterfaceOrientations=['UIInterfaceOrientationPortrait'])
    (app / 'Info.plist').write_bytes(plistlib.dumps(plist))
    sdk = run('xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path')
    print('Compiling native preview', flush=True)
    run('xcrun', '--sdk', 'iphonesimulator', 'swiftc', '-parse-as-library',
        '-target', 'arm64-apple-ios26.0-simulator', '-sdk', sdk,
        str(HERE / 'FinishSummaryPreview.swift'), '-o', str(app / 'FinishPreview'))
    run('codesign', '--force', '--sign', '-', str(app))
    run('xcrun', 'simctl', 'bootstatus', DEVICE, '-b')
    run('xcrun', 'simctl', 'status_bar', DEVICE, 'override', '--time', '9:41', '--batteryState', 'charged', '--batteryLevel', '100')
    run('xcrun', 'simctl', 'install', DEVICE, str(app))
    for direction in ['A', 'B', 'C']:
        for size, category in [('default', 'UICTContentSizeCategoryL'), ('axl', 'UICTContentSizeCategoryAccessibilityL')]:
            for anchor in ['top', 'stats', 'graph', 'zones', 'exercises', 'actions']:
                subprocess.run(['xcrun','simctl','terminate',DEVICE,BUNDLE], capture_output=True)
                run('xcrun', 'simctl', 'launch', DEVICE, BUNDLE, '-direction', direction, '-anchor', anchor,
                    '-UIPreferredContentSizeCategoryName', category)
                time.sleep(2.5)
                filename = OUTPUT / f'{direction}-{size}-{anchor}.png'
                run('xcrun', 'simctl', 'io', DEVICE, 'screenshot', str(filename))
                print(filename.name, flush=True)
    print(f'Built harness: {app}', flush=True)
if __name__ == '__main__':
    try:
        main()
    except subprocess.CalledProcessError as exc:
        print(exc.stdout)
        print(exc.stderr)
        raise
