source 'https://github.com/CocoaPods/Specs.git'

# Uncomment the next line to define a global platform for your project
platform :ios, '15.0'

# Comment the next line if you're not using Swift and don't want to use dynamic frameworks
use_frameworks!

def shared_pods
     pod 'YapDatabase', :git => 'https://github.com/tladesignz/YapDatabase.git' #'~> 4.0'
     pod 'LibProofMode',
        :git => 'https://gitlab.com/guardianproject/proofmode/libproofmode-ios.git', :branch => 'main'
end

target 'Save' do
    shared_pods
end

target 'ShareExtension' do
    shared_pods
end

target 'Save Screenshots' do
    shared_pods
end

# Fix Xcode 15 compile issues.
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['OA_APP_GROUP'] = '$(inherited)'
      config.build_settings['DEVELOPMENT_TEAM'] = '$(inherited)'
    end
    if target.respond_to?(:name) and !target.name.start_with?("Pods-")
      target.build_configurations.each do |config|
        if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 12
          config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
        end
      end
    end
  end
end
