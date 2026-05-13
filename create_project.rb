require 'xcodeproj'

PROJECT_NAME = 'KeirinPredictor'
BUNDLE_ID = 'com.tokyonasu.keirinpredictor'
TEAM_ID = '83VGKGSQUH'

project_path = File.expand_path("#{PROJECT_NAME}.xcodeproj", __dir__)
project = Xcodeproj::Project.new(project_path)
target = project.new_target(:application, PROJECT_NAME, :ios, '17.0')

target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = BUNDLE_ID
  config.build_settings['DEVELOPMENT_TEAM'] = TEAM_ID
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  config.build_settings['MARKETING_VERSION'] = ENV.fetch('APP_VERSION', '1.1')
  config.build_settings['CURRENT_PROJECT_VERSION'] = ENV.fetch('BUILD_NUMBER', '1')
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['INFOPLIST_FILE'] = 'KeirinPredictor/Info.plist'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
end

main_group = project.main_group
app_group = main_group.new_group(PROJECT_NAME, PROJECT_NAME)
engine_group = app_group.new_group('Engine', 'Engine')
models_group = app_group.new_group('Models', 'Models')
views_group = app_group.new_group('Views', 'Views')

def add_sources(group, target, names)
  names.each do |name|
    ref = group.new_file(name)
    target.add_file_references([ref])
  end
end

add_sources(app_group, target, ['KeirinPredictorApp.swift'])

add_sources(engine_group, target, [
  'DataLoader.swift',
  'NotificationManager.swift',
  'PredictionEngine.swift',
  'PredictionTracker.swift'
])

add_sources(models_group, target, ['PlayerStats.swift'])

add_sources(views_group, target, [
  'BannerAdView.swift',
  'ContentView.swift',
  'KeirinDesign.swift',
  'LoadingView.swift',
  'PlayerDatabaseView.swift',
  'PredictionView.swift',
  'RaceDetailView.swift',
  'RaceListView.swift',
  'ResultsListView.swift',
  'TrackingView.swift',
  'VenueInfoView.swift'
])

assets_ref = app_group.new_file('Assets.xcassets')
target.add_file_references([assets_ref])
privacy_ref = app_group.new_file('PrivacyInfo.xcprivacy')
target.add_resources([privacy_ref])

resources_group = app_group.new_group('Resources', 'Resources')
['player_stats.json', 'venue_stats.json', 'line_matrix.json', 'today_entries.json'].each do |name|
  ref = resources_group.new_file(name)
  target.add_resources([ref])
end

app_group.new_file('Info.plist')

project.save
puts "Created #{project_path}"
