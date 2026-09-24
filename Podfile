# Uncomment the next line to define a global platform for your project
platform :ios, '18.0'

target 'SpiceMonk' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for SpiceMonk
  pod 'GoogleMaps'
  pod 'GooglePlaces'
  pod 'FirebaseCore'
  pod 'FirebaseMessaging'
  pod 'lottie-ios'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      current = config.build_settings['IPHONEOS_DEPLOYMENT_TARGET']
      if current.nil? || current.to_f < 15.0
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      end
    end
  end
end
