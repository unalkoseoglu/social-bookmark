# Uncomment the next line to define a global platform for your project
platform :ios, '13.0'

target 'Social Bookmark' do
  use_frameworks!

  # OneSignal Push Notifications - sadece ana app için
  pod 'OneSignalXCFramework', '>= 5.0.0', '< 6.0'

  target 'Social BookmarkTests' do
    inherit! :search_paths
  end

  target 'Social BookmarkUITests' do
    # Pods for testing
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
    end
  end
end
