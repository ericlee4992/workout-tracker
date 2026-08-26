# Adds the Live Activity widget extension (milestone 8, ticket 05).
#
# A new TARGET is the one thing buildable folders cannot do for us, so this
# edits project.pbxproj — the same exception milestone 7 made for the watch app,
# and for the same reason. Source FILES still auto-register; only the target
# definition is scripted.
require 'xcodeproj'

path = 'WorkoutTracker.xcodeproj'
project = Xcodeproj::Project.open(path)

app = project.targets.find { |t| t.name == 'WorkoutTracker' }
raise 'iOS app target missing' unless app

if project.targets.any? { |t| t.name == 'WorkoutTrackerWidget' }
  puts 'widget target already present; nothing to do'
  exit 0
end

widget = project.new_target(:app_extension, 'WorkoutTrackerWidget', :ios, '26.0')

group = project.main_group.new_group('WorkoutTrackerWidget', 'WorkoutTrackerWidget')
shared_group = group.new_group('Shared', 'Shared')

widget_only = ['WorkoutActivityView.swift']
widget_only.each do |name|
  widget.add_file_references([group.new_reference(name)])
end

# The attributes type compiles into BOTH targets, so app and extension can never
# drift about the shape of what they exchange — the same arrangement
# WatchLink.swift uses for the watch.
shared_ref = shared_group.new_reference('WorkoutActivityAttributes.swift')
widget.add_file_references([shared_ref])
app.add_file_references([shared_ref])

widget.build_configurations.each do |c|
  s = c.build_settings
  # Without PRODUCT_NAME the product is literally named ".appex" and the embed
  # phase fails with "Multiple commands produce", which names nothing useful.
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['PRODUCT_BUNDLE_IDENTIFIER'] = '$(WT_BUNDLE_ID_BASE).widget'
  s['INFOPLIST_KEY_CFBundleDisplayName'] = 'Workout'
  s['INFOPLIST_KEY_NSHumanReadableCopyright'] = ''
  s['GENERATE_INFOPLIST_FILE'] = 'YES'
  s['SWIFT_VERSION'] = '5.0'
  s['TARGETED_DEVICE_FAMILY'] = '1'
  s['SKIP_INSTALL'] = 'YES'
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['DEVELOPMENT_TEAM'] = '$(WT_DEVELOPMENT_TEAM)'
  # NSExtensionPointIdentifier must say this is a WidgetKit extension, or it
  # installs and silently never appears.
  s['INFOPLIST_KEY_NSExtensionPointIdentifier'] = 'com.apple.widgetkit-extension'
end

# Embed into the app, or the extension ships nowhere.
embed = app.build_phases.find { |p|
  p.respond_to?(:name) && p.name == 'Embed Foundation Extensions'
}
embed ||= app.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
embed.add_file_reference(widget.product_reference)
app.add_dependency(widget)

project.save
puts "added WorkoutTrackerWidget (#{project.targets.map(&:name).join(', ')})"
