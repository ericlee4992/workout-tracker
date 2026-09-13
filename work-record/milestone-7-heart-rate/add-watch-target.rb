require 'xcodeproj'
path = 'WorkoutTracker.xcodeproj'
project = Xcodeproj::Project.open(path)

app = project.targets.find { |t| t.name == 'WorkoutTracker' }
raise 'iOS app target missing' unless app

# --- the watchOS app target ---
watch = project.new_target(:application, 'WorkoutTrackerWatch', :watchos, '26.0')

group = project.main_group.new_group('WorkoutTrackerWatch', 'WorkoutTrackerWatch')
shared_group = group.new_group('Shared', 'Shared')

watch_only = ['WorkoutTrackerWatchApp.swift', 'WatchRootView.swift']
watch_only.each do |name|
  ref = group.new_reference(name)
  watch.add_file_references([ref])
end

# The wire format compiles into BOTH targets, so they cannot drift.
shared_ref = shared_group.new_reference('WatchLink.swift')
watch.add_file_references([shared_ref])
app.add_file_references([shared_ref])

watch.build_configurations.each do |c|
  s = c.build_settings
  # The gem does not set PRODUCT_NAME, and without it the product is literally
  # named ".app" — which collides with the embed phase's output and fails as
  # "Multiple commands produce ... /.app", an error that names nothing useful.
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['PRODUCT_BUNDLE_IDENTIFIER'] = '$(WT_BUNDLE_ID_BASE).watchkitapp'
  # Usage strings are what you say to the user; ENTITLEMENTS are what the system
  # checks. Without these the watch's HKWorkoutSession never opens and the
  # companion runs while producing no reading at all (codex-review 3.1).
  s['CODE_SIGN_ENTITLEMENTS'] = 'Config/WorkoutTrackerWatch.entitlements'
  s['DEVELOPMENT_TEAM'] = '$(WT_DEVELOPMENT_TEAM)'
  s['INFOPLIST_KEY_WKApplication'] = 'YES'
  s['INFOPLIST_KEY_WKCompanionAppBundleIdentifier'] = '$(WT_BUNDLE_ID_BASE)'
  s['INFOPLIST_KEY_NSHealthShareUsageDescription'] =
    'Your heart rate is measured on your wrist during a workout and sent to your iPhone. It never leaves your devices.'
  s['INFOPLIST_KEY_NSHealthUpdateUsageDescription'] =
    'Workouts you log are saved to Health so your rings and history stay accurate.'
  s['GENERATE_INFOPLIST_FILE'] = 'YES'
  s['TARGETED_DEVICE_FAMILY'] = '4'
  s['SDKROOT'] = 'watchos'
  s['WATCHOS_DEPLOYMENT_TARGET'] = '26.0'
  s['SWIFT_VERSION'] = '5.0'
  s['CURRENT_PROJECT_VERSION'] = '1'
  s['MARKETING_VERSION'] = '1.0'
  s['SKIP_INSTALL'] = 'YES'
  # An iOS deployment target on a watchOS product is meaningless and makes
  # xcodebuild warn about a platform mismatch.
  s.delete('IPHONEOS_DEPLOYMENT_TARGET')
end

# --- deliberately NOT embedded in the phone app ---
#
# The obvious move is an "Embed Watch Content" copy phase plus a target
# dependency, so installing the phone installs the watch. It was tried on
# 2026-08-22 and it breaks everything else:
#
#   MIInstallableBundle _performCompanionWatchAppValidationForWatchApp
#   App installation failed: Unable to Install "WorkoutTracker"
#
# An iOS app carrying a watch app will not install on a simulator that has no
# PAIRED watch simulator — which killed the whole unit suite locally, and would
# kill CI too, since the runner's "Pick a simulator" step takes whatever iPhone
# exists and pairs nothing.
#
# So the watch app stays an independent product. `WKCompanionAppBundleIdentifier`
# above still establishes the companion relationship; the cost is that the watch
# app is installed by building its own scheme to the watch, rather than riding
# along with the phone. That is a per-install chore for one developer, against
# breaking every test run for everyone.
#
# `app` is left untouched here on purpose.
_ = app

project.save

# A SHARED scheme, explicitly. Without one, `xcodebuild -scheme
# WorkoutTrackerWatch` synthesises a scheme that drags the companion iOS app in
# and tries to compile Vision/CoreImage for watchOS — an error that reads like a
# broken target and is really a missing scheme.
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(watch)
scheme.set_launch_target(watch)
scheme.save_as(path, 'WorkoutTrackerWatch', true)

puts "watch target created: #{watch.name} (#{watch.platform_name}) #{watch.deployment_target}"
